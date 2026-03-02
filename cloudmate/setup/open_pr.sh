#!/bin/bash
# Push branch and create PR via Claude /ship command.
# Replaces merge.sh — PRs go to GitHub for review, no local merging.
#
# Usage: open_pr.sh [WORKTREE_DIR]

set -euo pipefail

LOG="/tmp/cc-post-session.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

WORKTREE_DIR="${1:-$(pwd)}"
cd "$WORKTREE_DIR"

BRANCH=$(git branch --show-current 2>/dev/null)
MAIN_DIR=$(git worktree list | head -1 | awk '{print $1}')
MAIN_BRANCH=$(git -C "$MAIN_DIR" branch --show-current 2>/dev/null || echo "main")

log "=== open_pr.sh started ==="
log "WORKTREE_DIR=$WORKTREE_DIR"
log "BRANCH=$BRANCH"
log "MAIN_BRANCH=$MAIN_BRANCH"

# ── Safety checks ──────────────────────────────────────────────
if [ "$BRANCH" = "$MAIN_BRANCH" ]; then
    log "⏭️  On $MAIN_BRANCH, skipping."
    exit 0
fi

# Nothing to ship?
COMMITS=$(git log "$MAIN_BRANCH".."$BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
log "Commits ahead of $MAIN_BRANCH: $COMMITS"

if [ "$COMMITS" -eq 0 ]; then
    log "⏭️  No commits ahead of $MAIN_BRANCH, skipping."
    exit 0
fi

# PR already exists?
if PR_URL=$(gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null); then
    log "ℹ️  PR already exists: $PR_URL"
    exit 0
fi

# ── Push ───────────────────────────────────────────────────────
log "📤 Pushing $BRANCH..."
git push -u origin "$BRANCH" 2>&1 | tee -a "$LOG"

# ── Create PR via /ship ───────────────────────────────────────
log "📝 Creating PR via /ship..."
cd "$WORKTREE_DIR" && unset CLAUDECODE && claude -p "/ship" 2>&1 | tee -a "$LOG"

# Get PR URL
if PR_URL=$(gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null); then
    log "✅ PR created: $PR_URL"
else
    log "⚠️  PR creation completed but URL not found"
fi

# ── Update registry if it exists ──────────────────────────────
REGISTRY="$MAIN_DIR/.tasks/registry.json"
if [ -f "$REGISTRY" ] && command -v jq &>/dev/null; then
    WT_NAME=$(basename "$WORKTREE_DIR")
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg wt "$WT_NAME" \
       --arg status "shipped" \
       --arg pr "${PR_URL:-}" \
       --arg ts "$TIMESTAMP" \
       '.worktrees[$wt].status = $status |
        .worktrees[$wt].pr = $pr |
        .worktrees[$wt].last_activity = $ts' \
       "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

    log "Updated registry for $WT_NAME"
fi

log "=== open_pr.sh finished ==="
