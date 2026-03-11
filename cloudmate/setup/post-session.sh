#!/bin/bash
# Post-session wrapper — runs after claude -w exits (via shell semicolon chain).
# Reads action from temp file (set by iTerm shortcut), defaults to "pr".
#
# Flow:
#   Cmd+Shift+P → action=pr → open_pr.sh (push → PR → merge → sync main)
#   Cmd+Shift+D → action=discard → discard.sh (remove worktree + branch)
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
    WORKTREE_DIR=$(pwd)
fi

# ── Read action, default to "pr" ──────────────────────────────
ACTION="pr"
if [ -f "$ACTION_FILE" ]; then
    ACTION=$(cat "$ACTION_FILE")
    rm -f "$ACTION_FILE"
fi
log "ACTION=$ACTION"

# ── Change to worktree directory ──────────────────────────────
cd "$WORKTREE_DIR" || {
    log "ERROR: Cannot cd to $WORKTREE_DIR"
    exit 1
}

log "WORKTREE_DIR=$WORKTREE_DIR"
log "BRANCH=$(git branch --show-current 2>/dev/null)"

# ── Safety commit (always) ────────────────────────────────────
git add -A 2>/dev/null
if ! git diff-index --quiet HEAD 2>/dev/null; then
    log "Uncommitted changes found, doing safety commit"
    git commit -m "session-end checkpoint" 2>/dev/null || true
else
    log "Working tree clean"
fi

# ── Dispatch ──────────────────────────────────────────────────
log "Dispatching action=$ACTION"
case "$ACTION" in
    pr)
        # Run in detached tmux session so the pane can close immediately.
        # open_pr.sh: push → create PR → squash-merge → sync local main.
        # CodeRabbit reviews the merged PR async. Findings patched later.
        SESSION_NAME="pr-$(date +%s)"
        log "Starting PR+merge in background: $SESSION_NAME"

        tmux new-session -d -s "$SESSION_NAME" \
            "cd '$WORKTREE_DIR' && ~/.cc/open_pr.sh '$WORKTREE_DIR' 2>&1 | tee -a '$LOG'"

        log "Background session started. Attach: tmux attach -t $SESSION_NAME"
        log "Watch progress: tail -f $LOG"
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


# ═══════════════════════════════════════════════════════════════
# OLD post-session.sh (commented out for reference)
# Only difference: the pr case previously ran open_pr.sh in foreground
# (blocking) mode. Now it's always background + immediate merge.
# ═══════════════════════════════════════════════════════════════
#
# case "$ACTION" in
#     pr)
#         SESSION_NAME="pr-$(date +%s)"
#         tmux new-session -d -s "$SESSION_NAME" \
#             "cd '$WORKTREE_DIR' && ~/.cc/open_pr.sh '$WORKTREE_DIR' 2>&1 | tee -a '$LOG'"
#         ;;
#     ...
# esac
