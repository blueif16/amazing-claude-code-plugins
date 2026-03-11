#!/bin/zsh
# lazygit-popup.sh — Open lazygit in the most recently active tmux pane's directory.
# WSL/Linux version (no /opt/homebrew paths).
#
# How it works:
#   pane_activity is each pane's last I/O unix timestamp.
#   The CC agent pane you're watching has the highest value (continuous output),
#   so lazygit always opens the correct worktree. No hooks, no focus tracking.
#
# WezTerm integration:
#   Unlike iTerm2's Hotkey Window, WezTerm uses a keybinding to spawn a new tab/pane.
#   Add to your .wezterm.lua keys table:
#
#     {
#         key = "g",
#         mods = "CTRL|SHIFT",
#         action = wezterm.action.SpawnCommandInNewTab({
#             args = { "zsh", "-c", "~/.cc/lazygit-popup.sh" },
#         }),
#     },

DIR=$(tmux list-panes -a -F "#{pane_activity} #{pane_current_path}" 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)

cd "${DIR:-$HOME}"
exec lazygit
