#!/usr/bin/env bash
# Set up key bindings for tmux-claude-agents plugin

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPLAY_SCRIPT="$PLUGIN_DIR/scripts/display.sh"

# Read user-configurable options (set in tmux.conf via @claude-agents-key, etc.)
key=$(tmux show-option -gqv "@claude-agents-key" 2>/dev/null)
key="${key:-A}"  # default: prefix + A

popup_width=$(tmux show-option -gqv "@claude-agents-popup-width" 2>/dev/null)
popup_width="${popup_width:-70%}"

popup_height=$(tmux show-option -gqv "@claude-agents-popup-height" 2>/dev/null)
popup_height="${popup_height:-80%}"

# Open popup panel with the agents dashboard
tmux bind-key "$key" display-popup \
    -w "$popup_width" \
    -h "$popup_height" \
    -E "bash '$DISPLAY_SCRIPT'"

# prefix + shift+A → one-shot (non-interactive, for scripting)
tmux bind-key "$(echo "$key" | tr '[:lower:]' '[:upper:]')" display-popup \
    -w "$popup_width" \
    -h "$popup_height" \
    -E "bash '$DISPLAY_SCRIPT' --once; read -r -s -n 1"
