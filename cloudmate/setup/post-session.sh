#!/bin/bash
# Post-session wrapper — runs after claude -w exits (via shell semicolon chain).
# Reads action from temp file (set by iTerm shortcut), defaults to "pr".
#
# Usage: post-session.sh $TMUX_PANE
#   Called automatically — do not run manually.

LOG="/tmp/cc-post-session.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

PANE_ID="$1"
ACTION_FILE="/tmp/.cc-action-${PANE_ID}"
DIR_FILE="/tmp/.cc-dir-${PANE_ID}"

log "=== post-session started ==="
log "PANE_ID=$PANE_ID"

# Try to get directory from temp file (written by shortcut before /exit)
if [ -f "$DIR_FILE" ]; then
    WORKTREE_DIR=$(cat "$DIR_FILE")
    rm -f "$DIR_FILE"
else
    # Fallback to pwd
    WORKTREE_DIR=$(pwd)
fi

# ── Read action, default to "pr" ──────────────────────────────
ACTION="pr"
if [ -f "$ACTION_FILE" ]; then
    ACTION=$(cat "$ACTION_FILE")
    rm -f "$ACTION_FILE"
fi
log "ACTION=$ACTION"

# ── Change to worktree directory FIRST ──────────────────────────
cd "$WORKTREE_DIR" || {
    log "ERROR: Cannot cd to $WORKTREE_DIR"
    exit 1
}

log "WORKTREE_DIR=$WORKTREE_DIR"
log "BRANCH=$(git branch --show-current 2>/dev/null)"
log "ACTION_FILE=$ACTION_FILE exists=$([ -f "$ACTION_FILE" ] && echo yes || echo no)"

# ── Safety commit (always, regardless of action) ──────────────
git add -A 2>/dev/null
if ! git diff-index --quiet HEAD 2>/dev/null; then
    log "Uncommitted changes found, doing safety commit"
    git commit -m "session-end checkpoint" 2>/dev/null || true
else
    log "Working tree clean, no safety commit needed"
fi

MAIN_BRANCH=$(git worktree list | head -1 | awk '{print $1}' | xargs -I{} git -C {} branch --show-current 2>/dev/null || echo "main")
AHEAD=$(git log "$MAIN_BRANCH"..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
log "Commits ahead of $MAIN_BRANCH: $AHEAD"

# ── Dispatch ──────────────────────────────────────────────────
log "Dispatching action=$ACTION"
case "$ACTION" in
    pr)
        log "Starting PR creation in background"
        # Run in detached tmux session (non-blocking)
        tmux new-session -d -s "pr-$(date +%s)" \
            "cd '$WORKTREE_DIR' && ~/.cc/open_pr.sh '$WORKTREE_DIR' 2>&1 | tee -a '$LOG'"
        log "PR creation started in background session"

        # Foreground mode (blocking) - uncomment to revert:
        # log "Calling open_pr.sh"
        # ~/.cc/open_pr.sh "$WORKTREE_DIR" 2>&1 | tee -a "$LOG"
        # log "open_pr.sh exit code=${PIPESTATUS[0]}"
        ;;
    discard)
        log "Calling discard.sh"
        ~/.cc/discard.sh "$WORKTREE_DIR" 2>&1 | tee -a "$LOG"
        ;;
    *)
        log "⚠️  Unknown action: $ACTION. Did safety commit only."
        ;;
esac
log "=== post-session finished ==="
