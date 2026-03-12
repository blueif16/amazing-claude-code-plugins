# CloudMate twork v2 — WezTerm native panes + tmux for agents only
# Add this to your ~/.zshrc (replaces twork v1)
#
# Behavior: run `twork` in any shell tab. It spawns a NEW WezTerm tab
# with the full workspace layout, leaving your original shell intact
# (like iTerm2 + tmux -CC on Mac).
#
# Layout (new tab, WezTerm native splits):
#   ┌────────────────┬───────────────────┐
#   │                │ agent (tmux       │
#   │   nvim / shell │  inside for       │
#   │                │  Agent Teams)     │
#   │                ├───────────────────┤
#   │                │ status --watch    │
#   └────────────────┴───────────────────┘
#
# Your original tab stays as a plain shell (control console).
#
# Usage:
#   cd ~/your-project && twork         # opens workspace in new tab
#   cd ~/your-project && twork --here  # use current tab instead
#   cd ~/your-project && twork --bare  # new tab, just nvim, add agents with Ctrl+Shift+W

twork() {
    local dir="${1:-$(pwd)}"
    local here=false
    local bare=false

    for arg in "$@"; do
        case "$arg" in
            --here) here=true ;;
            --bare) bare=true ;;
        esac
    done

    dir=$(cd "$dir" && pwd) || { echo "❌ Cannot resolve $dir"; return 1; }

    # ── Bail to tmux fallback if not in WezTerm ─────────────────
    if ! command -v wezterm &>/dev/null; then
        echo "⚠ wezterm CLI not found, falling back to tmux layout"
        _twork_tmux_fallback "$dir"
        return $?
    fi

    if $here; then
        # --here: build layout in the current tab (v2 original behavior)
        _twork_build_layout "$dir" "$bare"
        return $?
    fi

    # ── Default: spawn a new tab, build layout there ────────────
    # This is the Mac-like behavior: your current shell stays put.

    local new_pane
    new_pane=$(wezterm cli spawn --new-window --cwd "$dir" 2>/dev/null || \
               wezterm cli spawn --cwd "$dir" 2>/dev/null)

    if [ -z "$new_pane" ]; then
        echo "⚠ Could not spawn new tab, building layout here instead"
        _twork_build_layout "$dir" "$bare"
        return $?
    fi

    if $bare; then
        # Just nvim in the new tab
        wezterm cli send-text --pane-id "$new_pane" -- "nvim .\n" 2>/dev/null
        return 0
    fi

    # Build the full layout in the new tab's pane

    # Right split → agent pane (50% width)
    local agent_pane
    agent_pane=$(wezterm cli split-pane --right --percent 50 --pane-id "$new_pane" \
        --cwd "$dir" -- zsh -c '
            printf "\033]1337;SetUserVar=cloudmate_role=%s\007" "$(echo -n agent | base64)"
            SESSION="cc-$(date +%s)"
            tmux new-session -d -s "$SESSION" -c "'"$dir"'"
            TMUX_PANE=$(tmux list-panes -t "$SESSION" -F "#{pane_id}" | head -1)
            printf "\033]1337;SetUserVar=tmux_pane_id=%s\007" "$(echo -n "$TMUX_PANE" | base64)"
            printf "\033]1337;SetUserVar=tmux_session=%s\007" "$(echo -n "$SESSION" | base64)"
            tmux send-keys -t "$SESSION" "claude; ~/.cc/post-session.sh $TMUX_PANE" Enter
            tmux attach -t "$SESSION"
        ' 2>/dev/null)

    if [ -n "$agent_pane" ]; then
        # Bottom split of agent → status (25% height)
        wezterm cli split-pane --bottom --percent 25 --pane-id "$agent_pane" \
            --cwd "$dir" -- zsh -c '~/.cc/status.sh --watch' 2>/dev/null
    fi

    # Focus left pane and launch nvim
    wezterm cli activate-pane --pane-id "$new_pane" 2>/dev/null
    wezterm cli send-text --pane-id "$new_pane" -- "nvim .\n" 2>/dev/null

    echo "⚡ Workspace opened in new tab → $(basename "$dir")"
}

# ── Build layout in the CURRENT tab ────────────────────────────
_twork_build_layout() {
    local dir="$1"
    local bare="$2"

    cd "$dir" || return 1

    local base_pane
    base_pane=$(wezterm cli list --format json 2>/dev/null | \
        jq -r '.[] | select(.is_active) | .pane_id' 2>/dev/null)

    if [ -z "$base_pane" ]; then
        echo "⚠ Cannot detect WezTerm pane, falling back to tmux"
        _twork_tmux_fallback "$dir"
        return $?
    fi

    if [ "$bare" = "true" ]; then
        nvim .
        return 0
    fi

    # Right split → agent
    local agent_pane
    agent_pane=$(wezterm cli split-pane --right --percent 50 --pane-id "$base_pane" \
        --cwd "$dir" -- zsh -c '
            printf "\033]1337;SetUserVar=cloudmate_role=%s\007" "$(echo -n agent | base64)"
            SESSION="cc-$(date +%s)"
            tmux new-session -d -s "$SESSION" -c "'"$dir"'"
            TMUX_PANE=$(tmux list-panes -t "$SESSION" -F "#{pane_id}" | head -1)
            printf "\033]1337;SetUserVar=tmux_pane_id=%s\007" "$(echo -n "$TMUX_PANE" | base64)"
            printf "\033]1337;SetUserVar=tmux_session=%s\007" "$(echo -n "$SESSION" | base64)"
            tmux send-keys -t "$SESSION" "claude; ~/.cc/post-session.sh $TMUX_PANE" Enter
            tmux attach -t "$SESSION"
        ' 2>/dev/null)

    if [ -n "$agent_pane" ]; then
        wezterm cli split-pane --bottom --percent 25 --pane-id "$agent_pane" \
            --cwd "$dir" -- zsh -c '~/.cc/status.sh --watch' 2>/dev/null
    fi

    wezterm cli activate-pane --pane-id "$base_pane" 2>/dev/null
    nvim .
}

# ── Fallback: tmux layout for non-WezTerm environments ─────────
_twork_tmux_fallback() {
    local dir="$1"
    local name=$(basename "$dir")

    cd "$dir" || return 1

    if tmux has-session -t "$name" 2>/dev/null; then
        tmux attach-session -t "$name"
        return 0
    fi

    tmux new-session -d -s "$name" -c "$dir"
    tmux send-keys -t "$name" "nvim ." Enter
    tmux split-window -h -t "$name" -c "$dir"
    tmux send-keys -t "$name" "claude -w" Enter
    tmux split-window -v -t "$name" -l 15 -c "$dir"
    tmux send-keys -t "$name" "~/.cc/status.sh --watch" Enter
    tmux select-pane -t "$name:.0"
    tmux attach-session -t "$name"
}
