#!/usr/bin/env bash
# Display panel for tmux-claude-agents plugin
# Run inside a tmux pane; use `watch` or loop for live updates.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agents.sh"

REFRESH_INTERVAL="${CLAUDE_AGENTS_REFRESH:-2}"
ONE_SHOT="${1:-}"  # pass --once to print once and exit

# Terminal width
COLS=$(tput cols 2>/dev/null || echo 80)

# ────────────────────────── helpers ──────────────────────────

hr() {
    local char="${1:-─}"
    printf '%*s\n' "$COLS" '' | tr ' ' "$char"
}

center() {
    local text="$1"
    local plain
    plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local pad=$(( (COLS - ${#plain}) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf '%*s%b\n' "$pad" '' "$text"
}

# ────────────────────────── header ──────────────────────────

print_header() {
    local now
    now=$(date '+%H:%M:%S')
    echo ""
    center "${BOLD}${CYAN} Claude Agents Monitor${RESET}  ${GRAY}${now}${RESET}"
    echo ""
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
    echo -e "  ${BLUE}┌─────────────────────────────────────────────────────────┐${RESET}"

    # Status line (print badge on its own line — ANSI codes break printf widths)
    echo -e "  ${BLUE}│${RESET}  $(status_badge "$status")"
    echo -e "  ${BLUE}│${RESET}"

    # PID & session
    printf "  \e[0;34m│\e[0m  \e[0;90mPID      \e[0m  \e[1m%s\e[0m\n" "$pid"
    printf "  \e[0;34m│\e[0m  \e[0;90mSession  \e[0m  \e[0;36m%s\e[0m…\n" "$short_id"

    # Directory
    printf "  \e[0;34m│\e[0m  \e[0;90mDirectory\e[0m  \e[1;33m%s\e[0m\n" "$short_cwd"

    # Uptime & kind
    printf "  \e[0;34m│\e[0m  \e[0;90mUptime   \e[0m  %s   \e[0;90m[%s]\e[0m\n" "$uptime" "$kind"

    # Tmux location
    if [[ -n "$pane_label" ]]; then
        printf "  \e[0;34m│\e[0m  \e[0;90mTmux     \e[0m  %s\n" "$pane_label"
    fi

    echo -e "  ${BLUE}└─────────────────────────────────────────────────────────┘${RESET}"
    echo ""
}

# ────────────────────────── summary bar ──────────────────────────

print_summary() {
    local total="$1" working="$2" thinking="$3" waiting="$4" idle="$5"
    echo -e "  ${GRAY}Total: ${BOLD}${total}${RESET}  ${GRAY}|  ${GREEN}${BOLD}Working: ${working}${RESET}  ${GRAY}|  ${YELLOW}${BOLD}Thinking: ${thinking}${RESET}  ${GRAY}|  \033[0;35m${BOLD}Approval: ${waiting}${RESET}  ${GRAY}|  Idle: ${idle}${RESET}"
    hr "─"
}

# ────────────────────────── keybindings hint ──────────────────────────

print_footer() {
    echo ""
    echo -e "  ${GRAY}q${RESET} quit   ${GRAY}r${RESET} refresh   ${GRAY}^C${RESET} exit"
}

# ────────────────────────── main render ──────────────────────────

render() {
    COLS=$(tput cols 2>/dev/null || echo 80)
    clear

    print_header

    local agents
    mapfile -t agents < <(list_agents)

    if [[ ${#agents[@]} -eq 0 ]]; then
        echo ""
        center "${GRAY}No Claude agents found.${RESET}"
        echo ""
        center "${GRAY}Start a Claude Code session to see it here.${RESET}"
        echo ""
    else
        local total=0 working=0 thinking=0 waiting=0 idle=0

        for entry in "${agents[@]}"; do
            local pid="${entry%%:*}"
            local session_file="${entry#*:}"

            # Resolve pane once per agent (shared with card render)
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
}

# ────────────────────────── run mode ──────────────────────────

if [[ "$ONE_SHOT" == "--once" ]]; then
    render
    exit 0
fi

# Interactive loop
while true; do
    render

    # Non-blocking key read with timeout
    if read -r -s -n 1 -t "$REFRESH_INTERVAL" key 2>/dev/null; then
        case "$key" in
            q|Q) clear; exit 0 ;;
            r|R) continue ;;
        esac
    fi
done
