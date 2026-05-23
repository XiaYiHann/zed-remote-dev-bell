#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[install]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }

backup_file() {
    local file="$1"
    if [[ -f "$file" && ! -f "$file.bak.zedbell" ]]; then
        cp "$file" "$file.bak.zedbell"
        info "Backed up $file"
    fi
}

remove_managed_block() {
    local file="$1"
    local name="$2"
    if [[ -f "$file" ]]; then
        sed -i "/# >>> zed-remote-dev-bell ${name}/,/# <<< zed-remote-dev-bell ${name}/d" "$file"
    fi
}

remove_legacy_aliases() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sed -i '/# zed-remote-dev-bell: ring terminal bell when Codex CLI exits/d' "$file"
        sed -i '/# zed-remote-dev-bell: ring terminal bell when OpenCode exits/d' "$file"
        sed -i '/alias codex-bell=/d' "$file"
        sed -i '/alias opencode-bell=/d' "$file"
    fi
}

check_inotify_capacity() {
    local watches_file="/proc/sys/fs/inotify/max_user_watches"
    local instances_file="/proc/sys/fs/inotify/max_user_instances"
    if [[ ! -r "$watches_file" ]]; then
        return
    fi

    local watches
    watches="$(cat "$watches_file")"
    if (( watches < 262144 )); then
        warn "fs.inotify.max_user_watches is $watches; OpenCode/Zed can hang when watcher quota is exhausted."
        warn "Recommended host fix:"
        cat <<'EOF'
  sudo sysctl -w fs.inotify.max_user_watches=524288 fs.inotify.max_user_instances=1024
  printf '%s\n' \
    'fs.inotify.max_user_watches = 524288' \
    'fs.inotify.max_user_instances = 1024' | sudo tee /etc/sysctl.d/60-agent-inotify.conf
EOF
    fi

    if [[ -r "$instances_file" ]]; then
        local instances
        instances="$(cat "$instances_file")"
        if (( instances < 1024 )); then
            warn "fs.inotify.max_user_instances is $instances; 1024 is recommended for many concurrent agent sessions."
        fi
    fi
}

if ! command -v python3 &>/dev/null; then
    echo "python3 is required"
    exit 1
fi

info "Installing zed-remote-dev-bell..."

# ── Helper script ──
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/scripts/zed-bell" "$HOME/.local/bin/zed-bell"
chmod +x "$HOME/.local/bin/zed-bell"
info "Installed ~/.local/bin/zed-bell"

# ── Claude Code ──
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
if [[ -f "$CLAUDE_SETTINGS" ]]; then
    if ! grep -q "zed-remote-dev-bell" "$CLAUDE_SETTINGS" 2>/dev/null; then
        backup_file "$CLAUDE_SETTINGS"
    fi
    export _ZB_PATH="$CLAUDE_SETTINGS"
    python3 << 'PYEOF'
import json, os
path = os.environ["_ZB_PATH"]
with open(path, "r") as f:
    data = json.load(f)

data.setdefault("hooks", {})

hooks = {
    "Stop": {
        "description": "Terminal bell on task completion (zed-remote-dev-bell)",
        "hooks": [{"type": "command", "command": "~/.local/bin/zed-bell"}]
    },
    "Notification": {
        "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
        "description": "Terminal bell when input needed (zed-remote-dev-bell)",
        "hooks": [{"type": "command", "command": "~/.local/bin/zed-bell"}]
    }
}

for key, entry in hooks.items():
    current = data["hooks"].setdefault(key, [])
    if not any(item.get("description") == entry["description"] for item in current):
        current.append(entry)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
    info "Patched Claude Code settings.json"
else
    cat > "$CLAUDE_SETTINGS" << 'JSONEOF'
{
  "hooks": {
    "Stop": [
      {
        "description": "Terminal bell on task completion (zed-remote-dev-bell)",
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/zed-bell"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
        "description": "Terminal bell when input needed (zed-remote-dev-bell)",
        "hooks": [
          {
            "type": "command",
            "command": "~/.local/bin/zed-bell"
          }
        ]
      }
    ]
  }
}
JSONEOF
    info "Created Claude Code settings.json"
fi

# ── Codex CLI ──
# Codex CLI hooks stdout is isolated; it does NOT support terminalSequence.
# We use a shell function instead: it preserves arguments and exit status.
if command -v codex &>/dev/null; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]]; then
            remove_managed_block "$rc" "codex"
            remove_legacy_aliases "$rc"
            cat >> "$rc" << 'EOF'

# >>> zed-remote-dev-bell codex
codex-bell() {
    codex "$@"
    local status=$?
    "$HOME/.local/bin/zed-bell" --raw
    return "$status"
}
# <<< zed-remote-dev-bell codex
EOF
            info "Added 'codex-bell' function to $rc"
        fi
    done
else
    warn "Codex CLI not found in PATH, skipping"
fi

# ── OpenCode ──
# OpenCode local plugins can emit BEL directly. If OpenCode appears to hang while
# loading plugins, first check inotify watcher quota rather than disabling plugins.
if command -v opencode &>/dev/null; then
    check_inotify_capacity
    mkdir -p "$HOME/.config/opencode/plugins"
    cp "$SCRIPT_DIR/plugins/opencode-zed-bell.js" "$HOME/.config/opencode/plugins/zed-bell.js"
    info "Installed ~/.config/opencode/plugins/zed-bell.js"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]]; then
            remove_managed_block "$rc" "opencode"
            remove_legacy_aliases "$rc"
        fi
    done
else
    warn "OpenCode not found in PATH, skipping"
fi

echo ""
info "Done! Restart your AI tools for hooks to take effect."
