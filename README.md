# tmux-agents-panel

A tmux plugin that displays a persistent live panel showing all running Claude Code agents — their status, working directory, uptime, and tmux pane location. Refreshes in place with no flicker.

## Features

- **Persistent toggle pane** — `prefix + A` opens a split pane; press again to close it
- **Flicker-free rendering** — entire frame is buffered and written atomically, cursor hidden during updates
- **4 agent statuses** — Working, Thinking, Waiting Approval, Idle
- **Approval detection** — reads the agent's terminal to detect Claude Code permission prompts
- **Session info** — PID, session ID (short), working directory, uptime, interactive/headless kind
- **Tmux location** — resolves which `window:pane` the agent lives in
- **Status bar widget** — compact `🤖 2W 1T 1A 0I` indicator for your status line
- **TPM compatible** — standard plugin format

## Requirements

- tmux ≥ 3.2
- bash ≥ 4
- python3 (stdlib only — used for JSON parsing and timestamp calculation)

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
```

Add to `~/.tmux.conf`:

```tmux
run '~/.tmux/plugins/tmux-agents-panel/tmux-claude-agents.tmux'
```

## Usage

| Keybinding | Action |
|---|---|
| `prefix + A` | Toggle the agents pane (create if absent, kill if present) |
| `q` (inside pane) | Close the agents pane |
| `r` (inside pane) | Force immediate refresh |
| `^C` (inside pane) | Exit |

The pane opens as a split alongside your current window. Focus stays on your original pane after creation.

## Configuration

```tmux
# ~/.tmux.conf

# Keybinding to toggle the panel (default: A → prefix + A)
set -g @claude-agents-key "A"

# Pane position: right (default) | left | top | bottom
set -g @claude-agents-position "right"

# Pane size: columns for right/left, lines for top/bottom (default: 50)
set -g @claude-agents-size "50"
```

```bash
# Refresh interval in seconds (default: 2)
export CLAUDE_AGENTS_REFRESH=2
```

## Status bar widget

Add to your tmux status line:

```tmux
set -g status-right "#(~/.tmux/plugins/tmux-agents-panel/scripts/statusline.sh) | %H:%M"
```

Output example: `🤖 3 2W 1T 1A 0I`

Counters: **W** Working · **T** Thinking · **A** Waiting Approval · **I** Idle

## Agent status detection

| Badge | Status | Condition |
|---|---|---|
| `● WORKING` (green) | Working | Claude has active child processes — a tool or shell command is running |
| `◉ THINKING` (yellow) | Thinking | CPU > 5%, no child processes — LLM inference in progress |
| `⏸ WAITING APPROVAL` (magenta) | Waiting Approval | Low CPU, no children, approval/confirmation prompt detected in terminal |
| `○ IDLE` (gray) | Idle | Low CPU, no children, no prompt visible — awaiting next user message |

Approval detection captures the last 8 lines of the agent's tmux pane and matches patterns such as `[y/n]`, `(y/n)`, `Allow?`, `press enter`, `> ` etc. Falls back to **Idle** if the agent is not running inside a tmux pane.

## How it works

Claude Code writes session metadata to `~/.claude/sessions/{pid}.json` on startup:

```json
{
  "pid": 12345,
  "sessionId": "085db2f0-...",
  "cwd": "/home/user/my-project",
  "startedAt": 1789112643269,
  "kind": "interactive",
  "entrypoint": "cli"
}
```

The plugin scans that directory, verifies each PID is still alive, and reads the fields directly — no process argument parsing required. Working directory and uptime are derived from this file; status is inferred from process state and terminal content.

## File layout

```
tmux-agents-panel/
├── tmux-claude-agents.tmux    # TPM entry point
└── scripts/
    ├── agents.sh              # Agent discovery, status detection, helpers
    ├── display.sh             # Flicker-free pane renderer (buffered loop)
    ├── toggle.sh              # Create / kill the persistent pane
    ├── keybindings.sh         # Tmux key binding registration
    └── statusline.sh          # Compact status bar widget
```
