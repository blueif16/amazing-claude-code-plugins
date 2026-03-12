# CloudMate v2 on WSL + WezTerm

Native pane detection — click an agent pane to target it with Ship/Discard.

## Architecture (v2 vs v1)

```
v1 (broken pane detection):          v2 (native pane detection):
┌── WezTerm pane 0 ──────────────┐   ┌── WezTerm 0 ──┬── WezTerm 1 ──┐
│ ┌─ tmux 0 ──┬── tmux 1 ──────┐│   │               │  agent (tmux  │
│ │            │               ││   │  nvim/shell   │  inside for   │
│ │  nvim      │  claude       ││   │               │  Agent Teams) │
│ │            ├── tmux 2 ──────┤│   │               ├── WezTerm 2 ──┤
│ │            │  status.sh    ││   │               │  status.sh   │
│ └────────────┴───────────────┘│   └───────────────┴──────────────┘
│     WezTerm sees: 1 pane      │        WezTerm sees: 3 panes ✓
└────────────────────────────────┘
```

**v1 problem:** tmux owns layout → WezTerm sees one pane → `Ctrl+Shift+P` can't tell which agent you're looking at.

**v2 fix:** WezTerm owns layout → each split is a native pane → click = focus → keybindings target the right agent. tmux only runs inside agent panes for Agent Teams compatibility.

## What Changes from v1

| Behavior | v1 | v2 |
|----------|----|----|
| Layout manager | tmux | WezTerm native panes |
| Pane navigation | `Ctrl+B` + arrow | Click, `Alt+h/j/k/l`, or `Alt+Arrow` |
| Zoom a pane | `Ctrl+B z` | `Ctrl+Shift+Z` |
| Ship PR targeting | Must Ctrl+B to tmux pane first | Click agent pane, then `Ctrl+Shift+P` |
| Visual pane picker | N/A | `Ctrl+Shift+E` |
| Session persistence | tmux keeps everything | nvim/status don't survive disconnect; agents do (tmux inside) |

## What Stays the Same

Everything else — scripts, skill, commands, Agent Teams, CodeRabbit pipeline, lazygit popup — is identical.

## Quick Install

```bash
cd ~/favprojects/amazing-claude-code-plugins/cloudmate
bash win/install.sh
```

Then copy `~/.wezterm.lua` from `C:\Users\ran\Downloads\.wezterm.lua` to your WezTerm config location (usually `C:\Users\ran\.wezterm.lua`).

## Manual Setup (step by step)

### 1. System Dependencies

Same as before:

```bash
sudo apt update
sudo apt install -y tmux jq

# gh CLI
(type -p wget >/dev/null || sudo apt install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -qO "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update && sudo apt install gh -y

gh auth login

# lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit /usr/local/bin/lazygit
```

### 2. Scripts to ~/.cc/

Same as v1 — `install.sh` handles this.

### 3. Skill + Commands

Same as v1 — `install.sh` handles this.

### 4. Claude Settings

Same as v1:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_TEAMMATE_MODE": "tmux"
  }
}
```

### 5. WezTerm Config (THE BIG CHANGE)

Copy the new `.wezterm.lua` to your Windows home:

```powershell
# In PowerShell
Copy-Item "$env:USERPROFILE\Downloads\.wezterm.lua" "$env:USERPROFILE\.wezterm.lua"
```

Key additions in v2:
- `pane_focus_follows_mouse = true` — hover to focus
- `inactive_pane_hsb` — dims unfocused panes so you see where focus is
- Native pane navigation: `Alt+h/j/k/l` and `Alt+Arrow`
- `Ctrl+Shift+Z` to zoom/unzoom (replaces tmux prefix+z)
- `Ctrl+Shift+E` for visual pane picker
- Agent panes tagged with `cloudmate_role=agent` user var
- Ship/Discard check the user var before executing

### 6. twork Shell Function (UPDATED)

Replace the old twork in `~/.zshrc`:

```bash
# Remove old twork first, then add new one
# (or just re-source after install.sh)
echo "" >> ~/.zshrc
cat win/twork.zsh >> ~/.zshrc
source ~/.zshrc
```

v2 `twork` uses `wezterm cli split-pane` to create native splits. Falls back to the old tmux layout if you're not in WezTerm (SSH, etc).

### 7. tmux Clipboard

Still needed for agent panes (tmux runs inside them):

```bash
# ~/.tmux.conf
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "clip.exe"
bind -T copy-mode-vi Enter send -X copy-pipe-and-cancel "clip.exe"
bind ] run "powershell.exe -command 'Get-Clipboard' | tmux load-buffer - && tmux paste-buffer"
```

### 8. (Optional) BurntToast

```powershell
Install-Module -Name BurntToast -Force
```

## Keybinding Reference (v2)

### CloudMate Workflow

| Shortcut | Action | Notes |
|----------|--------|-------|
| `Ctrl+Shift+W` | New agent in native right split | Tags pane with user var |
| `Ctrl+Shift+P` | Ship PR | Click agent pane first |
| `Ctrl+Shift+D` | Discard worktree | Click agent pane first |
| `Ctrl+Shift+S` | Status dashboard | Native bottom split |
| `Ctrl+Shift+G` | Lazygit popup | New WezTerm tab |

### Pane Navigation (new in v2)

| Shortcut | Action |
|----------|--------|
| `Alt+h/j/k/l` | Move focus (vim-style) |
| `Alt+Arrow` | Move focus (arrow keys) |
| `Alt+Shift+Arrow` | Resize pane |
| `Ctrl+Shift+Z` | Zoom/unzoom pane |
| `Ctrl+Shift+E` | Visual pane picker |
| Mouse hover | Focus follows mouse |

### General

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+1-4` | Jump to tab |
| `Ctrl+Shift+F` | Search scrollback |
| `Ctrl+Shift+X` | Vi copy mode |
| `Ctrl+Shift+Space` | Quick select (URLs, paths) |

## Troubleshooting

**"wezterm CLI not found" in twork**
The `wezterm` CLI binary must be in PATH inside WSL. WezTerm usually sets this up, but if not:
```bash
echo 'export PATH="$PATH:/mnt/c/Program Files/WezTerm"' >> ~/.zshrc
```

**Agent pane doesn't get tagged (Ship/Discard shows toast)**
The `SetUserVar` escape sequence requires WezTerm 20230408+. Check `wezterm --version`.

**Status pane opens in wrong place**
`Ctrl+Shift+S` splits the currently focused pane. Focus the right-side agent pane first if you want status below it.

**"focus follows mouse" is annoying**
Set `config.pane_focus_follows_mouse = false` in `.wezterm.lua` and use click or `Alt+h/j/k/l` instead.

**Session persistence**
nvim and status panes don't survive a WezTerm restart (they're not inside tmux). Agent panes DO survive because they use tmux internally. For full persistence, use `twork` to recreate the layout — the tmux agent sessions will still be running, just `tmux attach -t cc-*`.

## Files in This Directory

| File | Purpose |
|------|---------|
| `SETUP-WSL.md` | This guide (v2) |
| `install.sh` | One-shot automated installer |
| `notify.sh` | Cross-platform notification helper |
| `twork.zsh` | `twork` v2 shell function (native panes + tmux fallback) |
| `lazygit-popup.sh` | Lazygit worktree popup |
| `wezterm-cloudmate.lua` | WezTerm keybinding reference snippet (v2) |
