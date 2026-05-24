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
| Codex CLI | Shell function `codex-bell` (rings on exit; hooks stdout is isolated) |
| OpenCode | Local plugin under `~/.config/opencode/plugins/zed-bell.js` (writes BEL to stderr) |

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
- Adds `codex-bell` shell function for Codex CLI (hooks do not support terminal bell)
- Installs OpenCode local plugin for `permission.asked`, `session.idle`, and `session.error` (writes BEL to stderr to bypass TUI stdout capture)
- Warns when Linux `inotify` watcher limits are too low for many concurrent Zed/OpenCode sessions
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

## OpenCode Notes

OpenCode local plugins are supported by placing JavaScript modules in:

```text
~/.config/opencode/plugins/
```

This project installs:

```text
~/.config/opencode/plugins/zed-bell.js
```

The plugin writes BEL to **stderr** because OpenCode's TUI captures stdout; stderr passes through to the host terminal (Zed). It rings on:

- `permission.asked`
- `session.idle`
- `session.error`

If `opencode run` appears to hang after adding or changing plugins, first check
Linux inotify capacity. On busy remote dev hosts, Zed, language servers, Codex,
Claude Code, and OpenCode can exhaust the default watcher quota. The symptom can
look like a plugin bug while the real error in OpenCode logs is:

```text
inotify_add_watch ... failed: No space left on device
```

Check the current limits:

```bash
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
```

Recommended host-level values for multi-agent remote development:

```bash
sudo sysctl -w fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=1024
printf '%s\n' \
  'fs.inotify.max_user_watches = 524288' \
  'fs.inotify.max_user_instances = 1024' | sudo tee /etc/sysctl.d/60-agent-inotify.conf
```

## Uninstall

```bash
./uninstall.sh
```

Restores original configs from backups.

## License

MIT
