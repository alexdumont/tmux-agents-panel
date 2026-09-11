#!/usr/bin/env bash
# Display panel for tmux-claude-agents plugin
# Run inside a tmux pane; use `watch` or loop for live updates.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agents.sh"

REFRESH_INTERVAL="${CLAUDE_AGENTS_REFRESH:-2}"
ONE_SHOT="${1:-}"  # pass --once to print once and exit

# Terminal width
COLS=$(tput cols 2>/dev/null || echo 80)

# Output buffer — all render functions append here; flushed atomically at the end.
_BUF=""

_buf() { _BUF+="$*"$'\n'; }

# ────────────────────────── helpers ──────────────────────────

hr() {
    local char="${1:-─}"
    _buf "$(printf '%*s' "$COLS" '' | tr ' ' "$char")"
}

center() {
    local text="$1"
    local plain
    plain=$(printf '%b' "$text" | sed 's/\x1b\[[0-9;]*[mK]//g')
    local pad=$(( (COLS - ${#plain}) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    _buf "$(printf '%*s%b' "$pad" '' "$text")"
}

# ────────────────────────── header ──────────────────────────

print_header() {
    local now
    now=$(date '+%H:%M:%S')
    _buf ""
    center "${BOLD}${CYAN} Claude Agents Monitor${RESET}  ${GRAY}${now}${RESET}"
    _buf ""
    hr "─"
}

# ────────────────────────── agent card ──────────────────────────

print_agent_card() {
    local pid="$1"
    local session_file="$2"

    local session_id cwd started kind
    session_id=$(_session_field "$session_file" sessionId)
    cwd=$(_session_field "$session_file" cwd)
    started=$(_session_field "$session_file" startedAt)
    kind=$(_session_field "$session_file" kind)

    # Resolve tmux pane once — used for both status detection and display
    local pane_row pane_id pane_label
    pane_row=$(get_tmux_pane "$pid")
    pane_id="${pane_row%% *}"                 # first field: %3
    pane_label="${pane_row#* }"               # remaining:   1:0 zsh

    local status
    status=$(get_agent_status "$pid" "$pane_id")

    local uptime=""
    [[ -n "$started" ]] && uptime=$(human_uptime "$started")

    local short_cwd
    short_cwd=$(short_path "$cwd" 50)

    local short_id="${session_id:0:8}"

    # Card top border
    _buf "  ${BLUE}┌─────────────────────────────────────────────────────────┐${RESET}"

    # Status line (badge on its own line — ANSI codes break printf widths)
    _buf "  ${BLUE}│${RESET}  $(status_badge "$status")"
    _buf "  ${BLUE}│${RESET}"

    # PID & session
    _buf "$(printf "  \e[0;34m│\e[0m  \e[0;90mPID      \e[0m  \e[1m%s\e[0m" "$pid")"
    _buf "$(printf "  \e[0;34m│\e[0m  \e[0;90mSession  \e[0m  \e[0;36m%s\e[0m…" "$short_id")"

    # Directory
    _buf "$(printf "  \e[0;34m│\e[0m  \e[0;90mDirectory\e[0m  \e[1;33m%s\e[0m" "$short_cwd")"

    # Uptime & kind
    _buf "$(printf "  \e[0;34m│\e[0m  \e[0;90mUptime   \e[0m  %s   \e[0;90m[%s]\e[0m" "$uptime" "$kind")"

    # Tmux location
    if [[ -n "$pane_label" ]]; then
        _buf "$(printf "  \e[0;34m│\e[0m  \e[0;90mTmux     \e[0m  %s" "$pane_label")"
    fi

    _buf "  ${BLUE}└─────────────────────────────────────────────────────────┘${RESET}"
    _buf ""
}

# ────────────────────────── summary bar ──────────────────────────

print_summary() {
    local total="$1" working="$2" thinking="$3" waiting="$4" idle="$5"
    _buf "  ${GRAY}Total: ${BOLD}${total}${RESET}  ${GRAY}|  ${GREEN}${BOLD}Working: ${working}${RESET}  ${GRAY}|  ${YELLOW}${BOLD}Thinking: ${thinking}${RESET}  ${GRAY}|  \033[0;35m${BOLD}Approval: ${waiting}${RESET}  ${GRAY}|  Idle: ${idle}${RESET}"
    hr "─"
}

# ────────────────────────── keybindings hint ──────────────────────────

print_footer() {
    _buf ""
    _buf "  ${GRAY}q${RESET} quit   ${GRAY}r${RESET} refresh   ${GRAY}^C${RESET} exit"
}

# ────────────────────────── main render ──────────────────────────

render() {
    COLS=$(tput cols 2>/dev/null || echo 80)

    # Reset buffer before collecting output
    _BUF=""

    print_header

    local agents
    mapfile -t agents < <(list_agents)

    if [[ ${#agents[@]} -eq 0 ]]; then
        _buf ""
        center "${GRAY}No Claude agents found.${RESET}"
        _buf ""
        center "${GRAY}Start a Claude Code session to see it here.${RESET}"
        _buf ""
    else
        local total=0 working=0 thinking=0 waiting=0 idle=0

        for entry in "${agents[@]}"; do
            local pid="${entry%%:*}"
            local session_file="${entry#*:}"

            local pane_row pane_id
            pane_row=$(get_tmux_pane "$pid")
            pane_id="${pane_row%% *}"

            local status
            status=$(get_agent_status "$pid" "$pane_id")

            (( total++ ))
            case "$status" in
                working)          (( working++ )) ;;
                thinking)         (( thinking++ )) ;;
                waiting_approval) (( waiting++ )) ;;
                idle)             (( idle++ )) ;;
            esac

            print_agent_card "$pid" "$session_file"
        done

        print_summary "$total" "$working" "$thinking" "$waiting" "$idle"
    fi

    print_footer

    # ── Atomic flush — move cursor to top, dump buffer, erase leftover lines ──
    # \033[H  : cursor to row 1 col 1 (no screen clear, no flash)
    # \033[J  : erase from cursor to end of screen (removes stale lines)
    printf '\033[H%b\033[J' "$_BUF"
}

# ────────────────────────── run mode ──────────────────────────

if [[ "$ONE_SHOT" == "--once" ]]; then
    render
    exit 0
fi

# Hide cursor during live updates to reduce visual noise
printf '\033[?25l'
trap 'printf "\033[?25h\033[H\033[J"' EXIT INT TERM

# Interactive loop
while true; do
    render

    # Non-blocking key read with timeout
    if read -r -s -n 1 -t "$REFRESH_INTERVAL" key 2>/dev/null; then
        case "$key" in
            q|Q) exit 0 ;;
            r|R) continue ;;
        esac
    fi
done
