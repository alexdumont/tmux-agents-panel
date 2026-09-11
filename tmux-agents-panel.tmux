#!/usr/bin/env bash
# tmux-agents-panel — TPM-compatible entry point
# Tracks Claude Code agent sessions: status, working directory, uptime.
#
# Options (set in tmux.conf before loading plugin):
#   set -g @claude-agents-key          "A"    # prefix + A to open panel
#   set -g @claude-agents-popup-width  "70%"
#   set -g @claude-agents-popup-height "80%"

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$PLUGIN_DIR/scripts/keybindings.sh"
