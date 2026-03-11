-- CloudMate keybindings for WezTerm (WSL)
-- Copy these into your ~/.wezterm.lua config.keys table.
--
-- These replace the iTerm2 keybindings from the macOS setup.
-- The core workflow is the same: spawn → work → ship/discard.
--
-- Differences from macOS/iTerm2:
--   - iTerm2 "Send tmux command" → WezTerm SendString (shell-level, not tmux-level)
--   - iTerm2 Hotkey Window for lazygit → WezTerm SpawnCommandInNewTab
--   - No -CC tmux integration (WezTerm uses native WSL domain instead)

local wezterm = require("wezterm")
local act = wezterm.action

local function shell(cmd)
    return act.SendString(cmd .. "\n")
end

-- ── CloudMate Workflow Keys ────────────────────────────────────
local cloudmate_keys = {

    -- Ctrl+Shift+W — New worktree pane (claude -w + post-session chain)
    {
        key = "w",
        mods = "CTRL|SHIFT",
        action = shell(
            "tmux split-window -h 'claude -w; ~/.cc/post-session.sh $TMUX_PANE'"
        ),
    },

    -- Ctrl+Shift+P — Ship PR: write action file → trigger exit → post-session picks up
    {
        key = "p",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(_, pane)
            pane:send_text(table.concat({
                "PANE=$(tmux display-message -p '#{pane_id}')",
                "echo pr > /tmp/.cc-action-${PANE}",
                "~/.cc/send-exit.sh ${PANE}",
            }, " && ") .. "\n")
        end),
    },

    -- Ctrl+Shift+D — Discard worktree
    {
        key = "d",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(_, pane)
            pane:send_text(table.concat({
                "PANE=$(tmux display-message -p '#{pane_id}')",
                "echo discard > /tmp/.cc-action-${PANE}",
                "~/.cc/send-exit.sh ${PANE}",
            }, " && ") .. "\n")
        end),
    },

    -- Ctrl+Shift+S — Status dashboard (small split below)
    {
        key = "s",
        mods = "CTRL|SHIFT",
        action = shell("tmux split-window -v -l 15 '~/.cc/status.sh --watch'"),
    },

    -- Ctrl+Shift+G — Lazygit popup (replaces iTerm2 Hotkey Window)
    -- Opens in a new WezTerm tab, auto-detects the active agent's worktree.
    -- Close with 'q' — the tab closes when lazygit exits.
    {
        key = "g",
        mods = "CTRL|SHIFT",
        action = wezterm.action.SpawnCommandInNewTab({
            args = { "zsh", "-c", "$HOME/.cc/lazygit-popup.sh" },
        }),
    },
}
