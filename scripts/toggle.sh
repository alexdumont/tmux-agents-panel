#!/usr/bin/env bash
# Toggle the persistent Claude agents pane (create or kill).
# Called by the tmux key binding via run-shell.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPLAY_SCRIPT="$PLUGIN_DIR/scripts/display.sh"

# tmux option used to track the live pane ID across invocations
PANE_OPTION="@claude-agents-pane-id"

# ── Read config ──────────────────────────────────────────────
position=$(tmux show-option -gqv "@claude-agents-position" 2>/dev/null)
position="${position:-right}"   # right | left | top | bottom

size=$(tmux show-option -gqv "@claude-agents-size" 2>/dev/null)
size="${size:-50}"              # columns (right/left) or lines (top/bottom)

# ── Check if pane still alive ────────────────────────────────
pane_id=$(tmux show-option -gqv "$PANE_OPTION" 2>/dev/null)

pane_alive() {
    [[ -n "$pane_id" ]] && \
        tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF "$pane_id"
}

# ── Toggle ───────────────────────────────────────────────────
if pane_alive; then
    # Pane exists → kill it (toggle off)
    tmux kill-pane -t "$pane_id"
    tmux set-option -g "$PANE_OPTION" ""
else
    # Build split-window flags based on desired position
    case "$position" in
        right)  split_flags=(-h -l "$size" -d) ;;
        left)   split_flags=(-h -l "$size" -d -b) ;;
        bottom) split_flags=(-v -l "$size" -d) ;;
        top)    split_flags=(-v -l "$size" -d -b) ;;
        *)      split_flags=(-h -l 50 -d) ;;
    esac

    # Create pane, capture its ID, keep focus on original pane (-d flag above)
    new_pane=$(tmux split-window "${split_flags[@]}" \
        -P -F '#{pane_id}' \
        "bash '$DISPLAY_SCRIPT'" 2>/dev/null)

    if [[ -z "$new_pane" ]]; then
        tmux display-message "tmux-agents-panel: failed to create pane"
        exit 1
    fi

    tmux set-option -g "$PANE_OPTION" "$new_pane"
fi
