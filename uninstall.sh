#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[uninstall]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }

restore_or_remove() {
    local file="$1"
    if [[ -f "$file.bak.zedbell" ]]; then
        cp "$file.bak.zedbell" "$file"
        rm "$file.bak.zedbell"
        info "Restored $file from backup"
    elif [[ -f "$file" ]]; then
        rm "$file"
        info "Removed created $file"
    else
        warn "No backup or file found for $file"
    fi
}

remove_managed_block() {
    local file="$1"
    local name="$2"
    if [[ -f "$file" ]]; then
        sed -i "/# >>> zed-remote-dev-bell ${name}/,/# <<< zed-remote-dev-bell ${name}/d" "$file"
    fi
}

info "Uninstalling zed-remote-dev-bell..."

# ── Remove helper script ──
if [[ -f "$HOME/.local/bin/zed-bell" ]]; then
    rm "$HOME/.local/bin/zed-bell"
    info "Removed ~/.local/bin/zed-bell"
fi

# ── Restore Claude Code ──
restore_or_remove "$HOME/.claude/settings.json"

# ── Restore Codex CLI ──
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]]; then
        remove_managed_block "$rc" "codex"
        sed -i '/# zed-remote-dev-bell: ring terminal bell when Codex CLI exits/d' "$rc"
        sed -i '/alias codex-bell=/d' "$rc"
        info "Removed codex-bell integration from $rc"
    fi
done

# ── Restore OpenCode ──
if [[ -f "$HOME/.config/opencode/plugins/zed-bell.js" ]]; then
    rm -f "$HOME/.config/opencode/plugins/zed-bell.js"
    info "Removed ~/.config/opencode/plugins/zed-bell.js"
fi

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc" ]]; then
        remove_managed_block "$rc" "opencode"
        sed -i '/# zed-remote-dev-bell: ring terminal bell when OpenCode exits/d' "$rc"
        sed -i '/alias opencode-bell=/d' "$rc"
        info "Removed legacy opencode-bell alias from $rc"
    fi
done

info "Uninstall complete."
