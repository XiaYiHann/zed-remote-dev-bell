# Zed Remote Dev Bell

Zero-system-notification terminal bell setup for AI dev tools in [Zed](https://zed.dev/) remote SSH sessions.

## Problem

When using Zed on macOS to develop on a remote Linux server:

- You run Claude Code, OpenCode, or Codex CLI in Zed's integrated terminal
- Long tasks finish while Zed is backgrounded
- Existing notification tools target macOS Notification Center (which requires local access)
- You just want a **blue dot on the Zed terminal tab**, not a desktop popup

## Solution

Hook all three AI tools to emit a terminal `BEL` (`\a`) on completion. Zed's terminal already shows a blue activity indicator on unfocused tabs when they receive BEL.

| Tool | Mechanism |
|------|-----------|
| Claude Code | `terminalSequence` JSON output via hooks |
| Codex CLI | Shell alias `codex-bell` (rings on exit; hooks stdout is isolated) |
| OpenCode | `process.stderr.write('\x07')` in plugin (bypasses TUI stdout capture) |

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/XiaYiHann/zed-remote-dev-bell/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/XiaYiHann/zed-remote-dev-bell.git
cd zed-remote-dev-bell
./install.sh
```

## What It Does

- Creates `~/.local/bin/zed-bell` helper script
- Patches `~/.claude/settings.json` with `Stop` + `Notification` hooks
- Adds `codex-bell` shell alias for Codex CLI (hooks do not support terminal bell)
- Installs OpenCode plugin `zed-bell` globally
- Backs up original configs before modifying

## Requirements

- Zed editor with remote SSH development
- `claude` (Claude Code CLI) or `codex` (OpenAI Codex CLI) or `opencode` installed
- Python 3 (for the helper script)

## Test

1. Open a second terminal tab in Zed
2. In the first tab, run any of the AI tools and start a long task
3. Switch to the second tab
4. When the task finishes, the first tab should show a **blue activity dot**

## Uninstall

```bash
./uninstall.sh
```

Restores original configs from backups.

## License

MIT
