# CloudMate twork function for WSL + WezTerm
# Add this to your ~/.zshrc (or ~/.bashrc)
#
# Usage:
#   cd ~/your-project && twork
#
# Layout:
#   ┌────────────────┬───────────────────┐
#   │                │ claude -w          │
#   │   nvim         ├───────────────────┤
#   │                │ status.sh --watch  │
#   └────────────────┴───────────────────┘
#
# Re-running `twork` attaches to the existing session.
# WezTerm handles the tmux connection natively (no -CC needed).

twork() {
    local dir="${1:-$(pwd)}"
    local name=$(basename "$dir")

    cd "$dir" || { echo "❌ Cannot cd to $dir"; return 1; }

    # Attach if session already exists
    if tmux has-session -t "$name" 2>/dev/null; then
        tmux attach-session -t "$name"
        return 0
    fi

    # Create new session with layout
    tmux new-session -d -s "$name" -c "$dir"

    # Left pane: nvim
    tmux send-keys -t "$name" "nvim ." Enter

    # Right pane: claude -w (worktree mode)
    tmux split-window -h -t "$name" -c "$dir"
    tmux send-keys -t "$name" "claude -w" Enter

    # Bottom-right pane: status dashboard
    tmux split-window -v -t "$name" -l 15 -c "$dir"
    tmux send-keys -t "$name" "~/.cc/status.sh --watch" Enter

    # Focus left (nvim) pane
    tmux select-pane -t "$name:.0"

    # Attach
    tmux attach-session -t "$name"
}
