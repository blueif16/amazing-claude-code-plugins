# CloudMate on WSL + WezTerm

Migrate the full CloudMate worktree workflow from macOS/iTerm2 to Windows/WSL/WezTerm.

## What Changes from macOS

| Component | macOS | WSL/Windows |
|-----------|-------|-------------|
| Terminal | iTerm2 | WezTerm |
| tmux integration | `-CC` control mode | Native WSL domain (no `-CC`) |
| Keyboard shortcuts | iTerm2 Key Bindings → "Send tmux command" | WezTerm `config.keys` → `SendString` / `action_callback` |
| Notifications | `osascript` (native macOS) | `powershell.exe` toast via BurntToast (or `notify-send`) |
| Lazygit popup | iTerm2 Hotkey Window (dedicated profile) | WezTerm `SpawnCommandInNewTab` keybinding |
| Package manager | `brew install` | `apt install` + manual for lazygit |
| Homebrew paths | `/opt/homebrew/bin/` | System PATH (`/usr/bin/`, `/usr/local/bin/`) |
| Clipboard in tmux | `pbcopy` / `pbpaste` | `clip.exe` / `powershell.exe Get-Clipboard` (WSL interop) |

Everything else — the scripts, skill, commands, worktree workflow, Agent Teams, CodeRabbit pipeline — works identically.

## Quick Install

```bash
cd ~/favprojects/amazing-claude-code-plugins/cloudmate
bash win/install.sh
```

This handles deps, script installation (with cross-platform notification patching), skill/command copying, and settings.json. Follow the manual steps it prints at the end.

## Manual Setup (step by step)

### 1. System Dependencies

```bash
sudo apt update
sudo apt install -y tmux jq

# GitHub CLI
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md
(type -p wget >/dev/null || sudo apt install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -qO "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update && sudo apt install gh -y

gh auth login

# lazygit (binary release — apt doesn't have it)
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit /usr/local/bin/lazygit
```

### 2. Scripts to ~/.cc/

```bash
mkdir -p ~/.cc

# Cross-platform notify helper (replaces osascript)
cp win/notify.sh ~/.cc/notify.sh && chmod +x ~/.cc/notify.sh

# Core scripts (these are platform-agnostic)
for f in send-exit.sh post-session.sh discard.sh merge.sh status.sh fix-cr.sh; do
  cp setup/$f ~/.cc/$f && chmod +x ~/.cc/$f
done

# Scripts that need notification patching (have osascript)
for f in open_pr.sh patch-findings.sh; do
  cp setup/$f ~/.cc/$f
  # Replace osascript notify() with cross-platform version
  sed -i '/^notify() {/,/^}/c\source ~/.cc/notify.sh' ~/.cc/$f
  chmod +x ~/.cc/$f
done

# Lazygit popup (WSL version — no /opt/homebrew paths)
cp win/lazygit-popup.sh ~/.cc/lazygit-popup.sh && chmod +x ~/.cc/lazygit-popup.sh
```

### 3. Skill + Commands

```bash
# User-level (available across all projects)
mkdir -p ~/.claude/skills/cloudmate/references
cp skills/cloudmate/SKILL.md ~/.claude/skills/cloudmate/SKILL.md
cp skills/cloudmate/references/*.md ~/.claude/skills/cloudmate/references/

mkdir -p ~/.claude/commands
cp commands/*.md ~/.claude/commands/
```

### 4. Claude Settings

Add to `~/.claude/settings.json`:

```json
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
```

### 5. WezTerm Keybindings

Your `.wezterm.lua` already has the core CloudMate bindings (`Ctrl+Shift+W/P/D/S`). Add the lazygit popup:

```lua
-- In config.keys table:
{
    key = "g",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnCommandInNewTab({
        args = { "zsh", "-c", "$HOME/.cc/lazygit-popup.sh" },
    }),
},
```

See `win/wezterm-cloudmate.lua` for the full keybinding reference.

### 6. twork Shell Function

Add to `~/.zshrc`:

```bash
cat win/twork.zsh >> ~/.zshrc
source ~/.zshrc
```

### 7. tmux Clipboard (for vi copy-mode)

Add to `~/.tmux.conf`:

```bash
# WSL clipboard integration
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "clip.exe"
bind -T copy-mode-vi Enter send -X copy-pipe-and-cancel "clip.exe"

# Paste from Windows clipboard
bind ] run "powershell.exe -command 'Get-Clipboard' | tmux load-buffer - && tmux paste-buffer"
```

### 8. (Optional) Windows Toast Notifications

For rich notifications that appear in Windows Action Center:

```powershell
# In PowerShell (Admin)
Install-Module -Name BurntToast -Force
```

Without BurntToast, the notify helper falls back to a basic system tray balloon. Both work, BurntToast just looks nicer and supports action buttons.

## Keybinding Reference

| Shortcut | Action | Notes |
|----------|--------|-------|
| `Ctrl+Shift+W` | New worktree pane (`claude -w` + post-session chain) | Spawns in tmux split |
| `Ctrl+Shift+P` | Ship PR (push → create PR → merge → push main) | Focus the target pane first |
| `Ctrl+Shift+D` | Discard worktree + close pane | Focus the target pane first |
| `Ctrl+Shift+S` | Status dashboard (`status.sh --watch`) | Opens in small bottom split |
| `Ctrl+Shift+G` | Lazygit popup (auto-detects active worktree) | Opens in new WezTerm tab |

## Key Difference: No -CC Mode

On macOS, iTerm2's `-CC` tmux integration mode lets iTerm2 render tmux panes as native tabs/splits. WezTerm on Windows doesn't support this — it uses its own "WSL domain" to connect to WSL directly.

This means:
- **tmux runs inside WezTerm**, not alongside it
- **tmux panes are tmux panes** (not WezTerm splits) — you navigate with `Ctrl+B` prefix
- The CloudMate keybindings work by **sending shell commands** into the active tmux session via `SendString`
- `twork` creates a tmux session directly (no tmuxinator needed)

In practice this barely matters. The workflow is identical: `twork` → `Ctrl+Shift+W` → `/cm` → `Ctrl+Shift+P`.

## Troubleshooting

**"tmux: command not found" after Ctrl+Shift+W**
You're not inside a tmux session. Run `twork` first, or start tmux manually.

**Notifications not showing**
Install BurntToast (`Install-Module -Name BurntToast -Force` in PowerShell). Without it, notifications fall back to tray balloons which some Windows configs suppress.

**lazygit opens in wrong directory**
Happens if no tmux session is running. lazygit-popup.sh reads `pane_activity` from tmux — no tmux means it falls back to `$HOME`.

**Clipboard not working in tmux vi-mode**
Make sure `clip.exe` is accessible from WSL: `which clip.exe` should return `/mnt/c/Windows/system32/clip.exe`. If not, add `/mnt/c/Windows/system32` to your PATH.

**Agent Teams panes don't appear**
Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and `CLAUDE_CODE_TEAMMATE_MODE=tmux` in `~/.claude/settings.json`. Also confirm Claude Code v2.1.19+.

## Files in This Directory

| File | Purpose |
|------|---------|
| `SETUP-WSL.md` | This guide |
| `install.sh` | One-shot automated installer |
| `notify.sh` | Cross-platform notification helper (replaces `osascript`) |
| `twork.zsh` | `twork` shell function for `~/.zshrc` |
| `lazygit-popup.sh` | Lazygit worktree popup (Linux paths, no Homebrew) |
| `wezterm-cloudmate.lua` | WezTerm keybinding reference snippet |
