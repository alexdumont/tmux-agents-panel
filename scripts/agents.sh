#!/usr/bin/env bash
# Core agent detection script for tmux-agents-panel plugin

SESSIONS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

# Return list of active Claude agent PIDs with session data
list_agents() {
    [[ ! -d "$SESSIONS_DIR" ]] && return

    for session_file in "$SESSIONS_DIR"/*.json; do
        [[ -f "$session_file" ]] || continue

        local pid
        pid=$(python3 -c "import json,sys; d=json.load(open('$session_file')); print(d.get('pid',''))" 2>/dev/null)
        [[ -z "$pid" ]] && continue

        # Check the process is still alive
        kill -0 "$pid" 2>/dev/null || { rm -f "$session_file" 2>/dev/null; continue; }

        echo "$pid:$session_file"
    done
}

# Get session field from JSON
_session_field() {
    local file="$1" field="$2"
    python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$field',''))" 2>/dev/null
}

# Patterns that indicate Claude Code is waiting for user approval/input.
# Matches Claude Code's permission prompts and the human-turn ">" prompt.
_APPROVAL_PATTERN='(\[y[[:space:]]*/[[:space:]]*n\]|\(y/n\)|yes/no|Allow\?|allow this|Deny\?|approve|Do you want|press enter|Hit enter|> $)'

# Check if a tmux pane's recent output contains an approval/input prompt.
# $1 = tmux pane ID (e.g. "%3"). Returns 0 if prompt detected, 1 otherwise.
_pane_waiting_approval() {
    local pane_id="$1"
    [[ -z "$pane_id" ]] && return 1

    # Capture last 8 lines, strip ANSI codes, look for prompt patterns
    local content
    content=$(tmux capture-pane -t "$pane_id" -p -S -8 2>/dev/null \
              | sed 's/\x1b\[[0-9;]*[mK]//g')

    echo "$content" | grep -qiE "$_APPROVAL_PATTERN"
}

# Get agent status: working | thinking | waiting_approval | idle
# $1 = pid, $2 = tmux pane ID (optional, enables approval detection)
get_agent_status() {
    local pid="$1"
    local pane_id="${2:-}"

    # Active child processes → Claude is running a tool/command
    local children
    children=$(pgrep -P "$pid" 2>/dev/null | wc -l)
    if [[ "$children" -gt 0 ]]; then
        echo "working"
        return
    fi

    # High CPU, no children → LLM inference in progress
    local cpu
    cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ')
    cpu=${cpu%.*}
    if [[ -n "$cpu" && "$cpu" -gt 5 ]]; then
        echo "thinking"
        return
    fi

    # Low CPU, no children → check terminal content for approval prompt
    if _pane_waiting_approval "$pane_id"; then
        echo "waiting_approval"
        return
    fi

    echo "idle"
}

# Human-readable uptime from epoch ms
human_uptime() {
    local started_ms="$1"
    # Use Python for reliable ms timestamp (date +%3N is not portable)
    local now_ms
    now_ms=$(python3 -c "import time; print(int(time.time()*1000))")
    local diff_s=$(( (now_ms - started_ms) / 1000 ))

    if [[ "$diff_s" -lt 60 ]]; then
        echo "${diff_s}s"
    elif [[ "$diff_s" -lt 3600 ]]; then
        printf "%dm%ds" $(( diff_s / 60 )) $(( diff_s % 60 ))
    else
        printf "%dh%dm" $(( diff_s / 3600 )) $(( (diff_s % 3600) / 60 ))
    fi
}

# Shorten a path for display
short_path() {
    local path="$1"
    local max="${2:-45}"

    # Replace $HOME with ~
    path="${path/#$HOME/~}"

    if [[ ${#path} -le "$max" ]]; then
        echo "$path"
        return
    fi

    # Keep last two components
    local base
    base=$(basename "$path")
    local parent
    parent=$(basename "$(dirname "$path")")
    echo "…/$parent/$base"
}

# Status badge with color
status_badge() {
    local status="$1"
    case "$status" in
        working)          echo -e "${GREEN}${BOLD}● WORKING${RESET}" ;;
        thinking)         echo -e "${YELLOW}${BOLD}◉ THINKING${RESET}" ;;
        waiting_approval) echo -e "\033[0;35m${BOLD}⏸ WAITING APPROVAL${RESET}" ;;
        idle)             echo -e "${GRAY}○ IDLE${RESET}" ;;
        *)                echo -e "${GRAY}? UNKNOWN${RESET}" ;;
    esac
}

# Find the tmux pane hosting this PID (best-effort).
# Prints two space-separated fields: pane_id  display_label
# e.g. "%3  1:0 zsh"
# Returns nothing if not found.
get_tmux_pane() {
    local pid="$1"
    local cur="$pid"

    for _ in $(seq 1 10); do
        local ppid
        ppid=$(awk '{print $4}' /proc/"$cur"/stat 2>/dev/null)
        [[ -z "$ppid" || "$ppid" -le 1 ]] && break

        local row
        row=$(tmux list-panes -a \
            -F '#{pane_pid} #{pane_id} #{window_index}:#{pane_index} #{window_name}' \
            2>/dev/null | awk -v p="$ppid" '$1==p{print $2" "$3" "$4}')

        if [[ -n "$row" ]]; then
            echo "$row"   # "%3 1:0 zsh"
            return
        fi
        cur="$ppid"
    done
}
