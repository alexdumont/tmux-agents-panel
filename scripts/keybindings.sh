#!/usr/bin/env bash
# Set up key bindings for tmux-agents-panel plugin

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOGGLE_SCRIPT="$PLUGIN_DIR/scripts/toggle.sh"

# Read user-configurable key (set in tmux.conf via @claude-agents-key)
key=$(tmux show-option -gqv "@claude-agents-key" 2>/dev/null)
key="${key:-A}"  # default: prefix + A

# Toggle the persistent agents pane
tmux bind-key "$key" run-shell "bash '$TOGGLE_SCRIPT'"
