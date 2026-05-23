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
    backup_file "$CLAUDE_SETTINGS"
    export _ZB_PATH="$CLAUDE_SETTINGS"
    python3 << 'PYEOF'
import json, os
path = os.environ["_ZB_PATH"]
with open(path, "r") as f:
    data = json.load(f)

if "hooks" not in data:
    data["hooks"] = {}

hooks = {
    "Stop": [{
        "description": "Terminal bell on task completion (zed-remote-dev-bell)",
        "hooks": [{"type": "command", "command": "~/.local/bin/zed-bell"}]
    }],
    "Notification": [{
        "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
        "description": "Terminal bell when input needed (zed-remote-dev-bell)",
        "hooks": [{"type": "command", "command": "~/.local/bin/zed-bell"}]
    }]
}

for key, val in hooks.items():
    if key not in data["hooks"]:
        data["hooks"][key] = val
    else:
        data["hooks"][key].extend(val)

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
# We use a shell alias instead: rings bell when Codex exits.
if command -v codex &>/dev/null; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q "alias codex-bell=" "$rc" 2>/dev/null; then
            cat >> "$rc" << 'EOF'

# zed-remote-dev-bell: ring terminal bell when Codex CLI exits
alias codex-bell='codex; printf "\a"'
EOF
            info "Added 'codex-bell' alias to $rc"
        fi
    done
else
    warn "Codex CLI not found in PATH, skipping"
fi

# ── OpenCode ──
# OpenCode v1.15.x has upstream bugs that cause `opencode run` to hang indefinitely
# when plugin event hooks are registered. We use a shell alias instead.
if command -v opencode &>/dev/null; then
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q "alias opencode-bell=" "$rc" 2>/dev/null; then
            cat >> "$rc" << 'EOF'

# zed-remote-dev-bell: ring terminal bell when OpenCode exits
alias opencode-bell='opencode; printf "\a"'
EOF
            info "Added 'opencode-bell' alias to $rc"
        fi
    done
else
    warn "OpenCode not found in PATH, skipping"
fi

echo ""
info "Done! Restart your AI tools for hooks to take effect."
