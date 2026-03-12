-- CloudMate v2 keybinding reference for WezTerm (WSL)
-- Full config lives in ~/.wezterm.lua — this is just a reference.
--
-- Architecture change from v1:
--   v1: tmux handles layout → WezTerm sees 1 pane → no pane detection
--   v2: WezTerm handles layout → native pane detection → click to focus
--       tmux only runs INSIDE agent panes for Agent Teams

local wezterm = require("wezterm")
local act = wezterm.action

-- ── CloudMate Workflow Keys ────────────────────────────────────
-- These use WezTerm native pane:split() instead of tmux split-window.
-- Agent panes are tagged with user var cloudmate_role=agent.

local cloudmate_keys = {

    -- Ctrl+Shift+W — New agent in a native WezTerm split
    -- Spawns a right split, runs claude inside a minimal tmux session.
    -- User var tagging lets Ship/Discard identify agent panes.
    {
        key = "w",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            pane:split({
                direction = "Right",
                size = 0.5,
                args = { "zsh", "-c", table.concat({
                    'printf "\\033]1337;SetUserVar=cloudmate_role=%s\\007" $(echo -n agent | base64)',
                    'SESSION="cc-$(date +%s)"',
                    'tmux new-session -d -s "$SESSION" -c "$(pwd)"',
                    'TMUX_PANE=$(tmux list-panes -t "$SESSION" -F "#{pane_id}" | head -1)',
                    'printf "\\033]1337;SetUserVar=tmux_pane_id=%s\\007" $(echo -n "$TMUX_PANE" | base64)',
                    'printf "\\033]1337;SetUserVar=tmux_session=%s\\007" $(echo -n "$SESSION" | base64)',
                    'tmux send-keys -t "$SESSION" "claude -w; ~/.cc/post-session.sh $TMUX_PANE" Enter',
                    'tmux attach -t "$SESSION"',
                }, " && ")},
            })
        end),
    },

    -- Ctrl+Shift+P — Ship PR (click agent pane first)
    {
        key = "p",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            local uv = pane:get_user_vars()
            if uv.cloudmate_role == "agent" then
                local tp = uv.tmux_pane_id or ""
                pane:send_text(table.concat({
                    'PANE="' .. tp .. '"',
                    '[ -z "$PANE" ] && PANE=$(tmux display-message -p "#{pane_id}")',
                    'echo pr > /tmp/.cc-action-${PANE}',
                    '~/.cc/send-exit.sh ${PANE}',
                }, " && ") .. "\n")
            else
                window:toast_notification("CloudMate",
                    "Focus an agent pane first, then Ctrl+Shift+P", nil, 3000)
            end
        end),
    },

    -- Ctrl+Shift+D — Discard worktree (click agent pane first)
    {
        key = "d",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            local uv = pane:get_user_vars()
            if uv.cloudmate_role == "agent" then
                local tp = uv.tmux_pane_id or ""
                pane:send_text(table.concat({
                    'PANE="' .. tp .. '"',
                    '[ -z "$PANE" ] && PANE=$(tmux display-message -p "#{pane_id}")',
                    'echo discard > /tmp/.cc-action-${PANE}',
                    '~/.cc/send-exit.sh ${PANE}',
                }, " && ") .. "\n")
            else
                window:toast_notification("CloudMate",
                    "Focus an agent pane first, then Ctrl+Shift+D", nil, 3000)
            end
        end),
    },

    -- Ctrl+Shift+S — Status dashboard (native bottom split)
    {
        key = "s",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window, pane)
            pane:split({
                direction = "Bottom",
                size = 0.25,
                args = { "zsh", "-c", "~/.cc/status.sh --watch" },
            })
        end),
    },

    -- Ctrl+Shift+G — Lazygit popup (new tab)
    {
        key = "g",
        mods = "CTRL|SHIFT",
        action = wezterm.action.SpawnCommandInNewTab({
            args = { "zsh", "-c", "$HOME/.cc/lazygit-popup.sh" },
        }),
    },
}

-- ── Pane Navigation (new in v2) ────────────────────────────────
-- These replace tmux Ctrl+B + arrow. Click also works because
-- each pane is a native WezTerm pane.

local nav_keys = {
    { key = "LeftArrow",  mods = "ALT", action = act.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "ALT", action = act.ActivatePaneDirection("Right") },
    { key = "UpArrow",    mods = "ALT", action = act.ActivatePaneDirection("Up") },
    { key = "DownArrow",  mods = "ALT", action = act.ActivatePaneDirection("Down") },
    { key = "h", mods = "ALT", action = act.ActivatePaneDirection("Left") },
    { key = "l", mods = "ALT", action = act.ActivatePaneDirection("Right") },
    { key = "k", mods = "ALT", action = act.ActivatePaneDirection("Up") },
    { key = "j", mods = "ALT", action = act.ActivatePaneDirection("Down") },
    { key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },
    { key = "e", mods = "CTRL|SHIFT", action = act.PaneSelect },
}
