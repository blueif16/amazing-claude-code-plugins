#!/bin/bash
# install.sh — One-shot CloudMate installer for WSL (Ubuntu)
#
# What it does:
#   1. Installs system deps (tmux, jq, gh, lazygit)
#   2. Copies setup scripts to ~/.cc/ with cross-platform notify() patched in
#   3. Copies skill + commands to ~/.claude/
#   4. Configures ~/.claude/settings.json (Agent Teams, statusline, hooks)
#   5. Prints remaining manual steps (WezTerm config, .zshrc additions)
#
# Usage:
#   cd /path/to/amazing-claude-code-plugins/cloudmate
#   bash win/install.sh
#
# Re-running is safe — it overwrites existing files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"  # cloudmate/ root
WIN_DIR="$SCRIPT_DIR/win"
SETUP_DIR="$SCRIPT_DIR/setup"

GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
DIM='\033[2m'
BOLD='\033[1m'
R='\033[0m'

log()  { echo -e "${GREEN}✓${R} $*"; }
warn() { echo -e "${YELLOW}⚠${R} $*"; }
info() { echo -e "${CYAN}→${R} $*"; }
header() { echo -e "\n${BOLD}═══ $* ═══${R}"; }

# ── Pre-flight checks ─────────────────────────────────────────
if ! grep -qi microsoft /proc/version 2>/dev/null && [ "$(uname)" != "Linux" ]; then
    warn "This script is designed for WSL/Linux. On macOS, use the standard install."
fi

if [ ! -d "$SETUP_DIR" ]; then
    echo "❌ Run from the cloudmate/ directory: cd cloudmate && bash win/install.sh"
    exit 1
fi

# ── 1. System dependencies ────────────────────────────────────
header "1/5 System Dependencies"

install_if_missing() {
    local cmd="$1"
    local install_cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        log "$cmd already installed ($(command -v $cmd))"
    else
        info "Installing $cmd..."
        eval "$install_cmd"
        log "$cmd installed"
    fi
}

sudo apt-get update -qq 2>/dev/null

install_if_missing tmux "sudo apt-get install -y tmux"
install_if_missing jq   "sudo apt-get install -y jq"

# gh CLI
if ! command -v gh &>/dev/null; then
    info "Installing GitHub CLI..."
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y))
    sudo mkdir -p -m 755 /etc/apt/keyrings
    out=$(mktemp) && wget -qO "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq && sudo apt install gh -y
    log "gh installed"
else
    log "gh already installed"
fi

# lazygit
if ! command -v lazygit &>/dev/null; then
    info "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin/lazygit
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
    log "lazygit installed"
else
    log "lazygit already installed"
fi

# ── 2. Copy scripts to ~/.cc/ ─────────────────────────────────
header "2/5 Setup Scripts → ~/.cc/"

mkdir -p ~/.cc

# Cross-platform notify helper
cp "$WIN_DIR/notify.sh" ~/.cc/notify.sh
chmod +x ~/.cc/notify.sh
log "notify.sh (cross-platform)"

# Copy each setup script, patching osascript notify() to source our helper
SCRIPTS=(send-exit.sh post-session.sh open_pr.sh discard.sh status.sh merge.sh fix-cr.sh patch-findings.sh)

for script in "${SCRIPTS[@]}"; do
    src="$SETUP_DIR/$script"
    dst="$HOME/.cc/$script"

    if [ ! -f "$src" ]; then
        warn "$script not found in setup/, skipping"
        continue
    fi

    # Copy the script
    cp "$src" "$dst"

    # Patch: replace any osascript-based notify() function with our cross-platform version.
    if grep -q 'osascript' "$dst" 2>/dev/null; then
        sed -i '/^notify() {/,/^}/c\
# Cross-platform notifications (patched by win/install.sh)\
source ~/.cc/notify.sh' "$dst"
        log "$script (patched notify)"
    else
        log "$script"
    fi

    chmod +x "$dst"
done

# Lazygit popup (WSL version, no /opt/homebrew)
cp "$WIN_DIR/lazygit-popup.sh" ~/.cc/lazygit-popup.sh
chmod +x ~/.cc/lazygit-popup.sh
log "lazygit-popup.sh (WSL)"

# ── 3. Skill + Commands → ~/.claude/ ──────────────────────────
header "3/5 Skill + Commands → ~/.claude/"

# Skill
mkdir -p ~/.claude/skills/cloudmate/references
cp "$SCRIPT_DIR/skills/cloudmate/SKILL.md" ~/.claude/skills/cloudmate/SKILL.md
log "skills/cloudmate/SKILL.md"

for ref in "$SCRIPT_DIR/skills/cloudmate/references/"*.md; do
    [ -f "$ref" ] || continue
    cp "$ref" ~/.claude/skills/cloudmate/references/
    log "references/$(basename "$ref")"
done

# Commands
mkdir -p ~/.claude/commands
for cmd_file in "$SCRIPT_DIR/commands/"*.md; do
    [ -f "$cmd_file" ] || continue
    cp "$cmd_file" ~/.claude/commands/
    log "commands/$(basename "$cmd_file")"
done

# ── 4. settings.json ──────────────────────────────────────────
header "4/5 Claude Settings"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    warn "settings.json already exists — not overwriting"
    info "Verify these keys are set:"
    echo '  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1", "CLAUDE_CODE_TEAMMATE_MODE": "tmux" }'
else
    cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_TEAMMATE_MODE": "tmux"
  },
  "permissions": {
    "allow": [
      "Bash(npm:*)", "Bash(npx:*)", "Bash(node:*)",
      "Bash(git add:*)", "Bash(git commit:*)", "Bash(git status:*)",
      "Bash(git diff:*)", "Bash(git log:*)", "Bash(git branch:*)",
      "Bash(grep:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(mkdir:*)",
      "Edit(*)", "Write(*)", "Read(*)"
    ],
    "deny": [
      "Bash(git push --force:*)",
      "Bash(git reset --hard:*)"
    ]
  }
}
SETTINGS
    log "settings.json created with Agent Teams + permissions"
fi

# ── 5. Summary + manual steps ─────────────────────────────────
header "5/5 Manual Steps Remaining"

echo ""
echo -e "${BOLD}A. Add twork to ~/.zshrc:${R}"
echo -e "   ${DIM}echo \"\" >> ~/.zshrc && cat ${WIN_DIR}/twork.zsh >> ~/.zshrc && source ~/.zshrc${R}"
echo ""
echo -e "${BOLD}B. Add lazygit keybinding to ~/.wezterm.lua:${R}"
echo -e "   ${DIM}See ${WIN_DIR}/wezterm-cloudmate.lua for the Ctrl+Shift+G binding${R}"
echo ""
echo -e "${BOLD}C. Authenticate GitHub CLI:${R}"
echo -e "   ${DIM}gh auth login${R}"
echo ""
echo -e "${BOLD}D. (Optional) Install BurntToast for rich Windows notifications:${R}"
echo -e "   ${DIM}In PowerShell (Admin): Install-Module -Name BurntToast -Force${R}"
echo ""
echo -e "${BOLD}E. (Optional) Install CodeRabbit for PR reviews:${R}"
echo -e "   ${DIM}cd your-project && bash $SETUP_DIR/setup-coderabbit.sh .${R}"
echo ""
echo -e "${GREEN}${BOLD}CloudMate installed for WSL.${R} Run ${CYAN}twork${R} in any project to start."
