# tmux-agents-panel

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
set -g @plugin 'alexdumont/tmux-agents-panel'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/alexdumont/tmux-agents-panel ~/.tmux/plugins/tmux-agents-panel
# Add to ~/.tmux.conf:
run '~/.tmux/plugins/tmux-agents-panel/tmux-agents-panel.tmux'
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
set -g status-right "#(~/.tmux/plugins/tmux-agents-panel/scripts/statusline.sh) | %H:%M"
```

Output example: `🤖 3 2W 1T 1A 0I`

## Agent status detection

| Badge | Status | Condition |
|---|---|---|
| `● WORKING` | Working | Claude has active child processes (running shell commands, tools) |
| `◉ THINKING` | Thinking | CPU usage > 5%, no child processes (LLM inference in progress) |
| `⏸ WAITING APPROVAL` | Waiting Approval | Low CPU, no children + approval/confirmation prompt detected in the agent's terminal |
| `○ IDLE` | Idle | Low CPU, no children, no prompt visible (awaiting next user message) |

Approval detection reads the last 8 lines of the agent's tmux pane and matches patterns such as `[y/n]`, `Allow?`, `press enter`, `(y/n)`, etc. Falls back to **Idle** if the agent is not running inside a tmux pane.

## File layout

```
tmux-agents-panel/
├── tmux-agents-panel.tmux   # TPM entry point
├── scripts/
│   ├── agents.sh             # Agent detection & helpers
│   ├── display.sh            # Pane renderer (live loop)
│   ├── toggle.sh             # Create/kill the persistent pane
│   ├── keybindings.sh        # Tmux key binding setup
│   └── statusline.sh         # Compact status bar widget
└── README.md
```

Claude Code stores session metadata in `~/.claude/sessions/{pid}.json`, which this plugin reads to get the working directory, session ID, and start time without parsing process arguments.