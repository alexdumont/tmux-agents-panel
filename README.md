# tmux-claude-agents

A tmux plugin that opens a live panel showing all running Claude Code agents — their status (Working / Thinking / Idle), working directory, uptime, and tmux pane location.

## Features

- **Live popup panel** — refreshes every 2 s (configurable)
- **Status detection** — Working (child process running), Thinking (high CPU), Idle
- **Session info** — PID, session ID, directory, uptime, kind
- **Tmux location** — resolves which window:pane the agent lives in
- **Status bar widget** — compact `🤖 2W 1T 0I` indicator
- **TPM compatible** — standard plugin format

## Requirements

- tmux ≥ 3.2 (for `display-popup`)
- bash ≥ 4
- python3 (stdlib only — for JSON parsing)

## Installation

### Via TPM (recommended)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'your-user/tmux-claude-agents'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/your-user/tmux-claude-agents ~/.tmux/plugins/tmux-claude-agents
# Add to ~/.tmux.conf:
run '~/.tmux/plugins/tmux-claude-agents/tmux-claude-agents.tmux'
```

## Usage

| Keybinding | Action |
|---|---|
| `prefix + A` | Toggle persistent agents pane (create or kill) |
| `q` (inside pane) | Close the agents pane |
| `r` (inside pane) | Force refresh |

## Configuration

```tmux
# ~/.tmux.conf

# Keybinding to open the panel (default: A)
set -g @claude-agents-key "A"

# Pane position: right (default) | left | top | bottom
set -g @claude-agents-position "right"

# Pane size: columns for right/left, lines for top/bottom (default: 50)
set -g @claude-agents-size "50"

# Refresh interval in seconds (default: 2)
# Set in your environment:
# export CLAUDE_AGENTS_REFRESH=3
```

## Status bar widget

Add to your tmux status line:

```tmux
set -g status-right "#(~/.tmux/plugins/tmux-claude-agents/scripts/statusline.sh) | %H:%M"
```

Output example: `🤖 3 2W 1I`

## Agent status detection

| Status | Condition |
|---|---|
| **Working** | Claude has active child processes (running shell commands, tools) |
| **Thinking** | CPU usage > 5% but no child processes (LLM inference in progress) |
| **Idle** | Low CPU, no children (waiting for user input) |

## File layout

```
tmux-claude-agents/
├── tmux-claude-agents.tmux   # TPM entry point
├── scripts/
│   ├── agents.sh             # Agent detection & helpers
│   ├── display.sh            # Pane renderer (live loop)
│   ├── toggle.sh             # Create/kill the persistent pane
│   ├── keybindings.sh        # Tmux key binding setup
│   └── statusline.sh         # Compact status bar widget
└── README.md
```

Claude Code stores session metadata in `~/.claude/sessions/{pid}.json`, which this plugin reads to get the working directory, session ID, and start time without parsing process arguments.