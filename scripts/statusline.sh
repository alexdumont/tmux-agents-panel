#!/usr/bin/env bash
# Status line component for tmux-claude-agents plugin
# Usage: add to tmux status-right:
#   set -g status-right "#{?#{!=:#{@claude-agents-status},},#(~/.tmux/plugins/tmux-claude-agents/scripts/statusline.sh),}"
# Or simply:
#   set -g status-right "#(path/to/statusline.sh) | %H:%M"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agents.sh" 2>/dev/null || exit 0

mapfile -t agents < <(list_agents 2>/dev/null)

total=${#agents[@]}

if [[ "$total" -eq 0 ]]; then
    # No agents running — print nothing (or a subtle indicator)
    printf ""
    exit 0
fi

working=0
thinking=0
idle=0

for entry in "${agents[@]}"; do
    local_pid="${entry%%:*}"
    status=$(get_agent_status "$local_pid")
    case "$status" in
        working)  (( working++ )) ;;
        thinking) (( thinking++ )) ;;
        idle)     (( idle++ )) ;;
    esac
done

# Compact status for tmux status bar
# Format: 🤖 2W 1T 0I  (Working / Thinking / Idle)
out=" 🤖 ${total}"

if [[ "$working" -gt 0 ]]; then
    out+=" #[fg=green]${working}W#[default]"
fi
if [[ "$thinking" -gt 0 ]]; then
    out+=" #[fg=yellow]${thinking}T#[default]"
fi
if [[ "$idle" -gt 0 ]]; then
    out+=" ${idle}I"
fi

printf "%s" "$out"
