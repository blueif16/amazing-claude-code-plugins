#!/bin/bash
# open_pr.sh — Push, create PR (for audit trail + CR), local merge, push main.
#
# Flow:
#   1. Push branch to origin
#   2. Create PR via gh pr create (triggers CodeRabbit, leaves audit trail)
#   3. Local squash-merge to main (instant, no GitHub round-trip)
#   4. Push main to origin
#   5. GitHub auto-closes the PR (detects changes landed in main)
#   6. CodeRabbit reviews the closed PR asynchronously
#   7. patch-findings.sh picks up findings later
#
# Why not gh pr merge?
#   gh pr merge asks GitHub's server to merge, then you git pull to get it.
#   That's a network round-trip for no reason. Local merge is instant.
#   The PR only exists to trigger CodeRabbit and leave an audit trail.
#
# Why not skip the PR entirely?
#   CodeRabbit only reviews PRs, not direct pushes. No PR = no review.
#
# Note: PRs closed this way show as "closed" not "merged" on GitHub.
#   The diff and conversation are still there. patch-findings.sh handles this.
#
# Usage: open_pr.sh [WORKTREE_DIR]

set -euo pipefail

LOG="/tmp/cc-post-session.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
}

STATUS_FILE="/tmp/.cc-pr-status"
update_status() {
    local branch="$1"
    local stage="$2"
    local timestamp=$(date '+%H:%M:%S')
    echo "$branch|$stage|$timestamp" > "$STATUS_FILE"
}

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

COMMITS=$(git log "$MAIN_BRANCH".."$BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
log "Commits ahead of $MAIN_BRANCH: $COMMITS"

if [ "$COMMITS" -eq 0 ]; then
    log "⏭️  No commits ahead of $MAIN_BRANCH, skipping."
    exit 0
fi

if gh pr view "$BRANCH" --json url -q '.url' &>/dev/null; then
    log "ℹ️  PR already exists for $BRANCH"
    exit 0
fi

# ── Push branch ────────────────────────────────────────────────
log "📤 Pushing $BRANCH..."
update_status "$BRANCH" "pushing"
notify "CloudMate" "Pushing $BRANCH..."
git push -u origin "$BRANCH" 2>&1 | tee -a "$LOG"

# ── Create PR (audit trail + CodeRabbit trigger) ──────────────
# gh pr create --fill auto-generates title from branch name and body from commits.
# This is faster than spawning Claude with /ship (~1 sec vs ~15 sec).
# The PR description doesn't need to be perfect — it's an audit record, not a proposal.
log "📝 Creating PR..."
update_status "$BRANCH" "creating_pr"

# Build squash message from commits (same logic as merge.sh)
PR_BODY=$(git log "$MAIN_BRANCH".."$BRANCH" --pretty=format:"- %s" 2>/dev/null \
    | grep -v "^- wip" | grep -v "^- checkpoint" | grep -v "^- pre-merge" \
    | grep -v "^- session-end" | head -20)

PR_URL=$(gh pr create \
    --fill \
    --body "${PR_BODY:-Auto-created by CloudMate}" \
    2>&1 | tail -1) || true

if [ -z "$PR_URL" ] || ! echo "$PR_URL" | grep -q "github.com"; then
    # Fallback: try to get URL if create succeeded but output was noisy
    PR_URL=$(gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null || echo "")
fi

log "PR: ${PR_URL:-failed}"

# ── Local squash-merge to main ────────────────────────────────
# This is instant. No GitHub round-trip. merge.sh handles:
#   - cd to worktree, commit any stragglers
#   - build squash message from branch commits
#   - cd to main dir, git merge --squash, commit
log "🔀 Local squash-merge..."
update_status "$BRANCH" "merging"

cd "$MAIN_DIR"
git merge --squash "$BRANCH" 2>&1 | tee -a "$LOG"

# Build commit message
MSG=$(git log "$MAIN_BRANCH".."$BRANCH" --pretty=format:"%s" 2>/dev/null \
    | grep -v "^wip" | grep -v "^checkpoint" | grep -v "^pre-merge" \
    | grep -v "^session-end" | head -5 | tr '\n' '; ' | sed 's/; $//')
MSG="${MSG:-merge from $BRANCH}"

if git commit -m "merge: $MSG" 2>/dev/null; then
    log "✅ Squash-merged: $MSG"
else
    log "ℹ️  Nothing new to merge (already up to date)"
fi

# ── Push main ─────────────────────────────────────────────────
# This triggers GitHub to auto-close the PR (it detects the changes landed).
log "📤 Pushing $MAIN_BRANCH..."
git push 2>&1 | tee -a "$LOG"

update_status "$BRANCH" "done"
notify "CloudMate ✅" "Merged to $MAIN_BRANCH — CR reviewing async"
log "✅ Done. CR will review the closed PR."

# ── Clean up remote branch ────────────────────────────────────
# The local branch + worktree get cleaned up by discard.sh or manually.
# Remote branch can go now — the PR preserves the diff.
git push origin --delete "$BRANCH" 2>/dev/null || true
log "🗑️  Deleted remote branch $BRANCH"

# ── Update registry if it exists ──────────────────────────────
REGISTRY="$MAIN_DIR/.tasks/registry.json"
if [ -f "$REGISTRY" ] && command -v jq &>/dev/null; then
    WT_NAME=$(basename "$WORKTREE_DIR")
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg wt "$WT_NAME" \
       --arg status "merged" \
       --arg pr "${PR_URL:-}" \
       --arg ts "$TIMESTAMP" \
       '.worktrees[$wt].status = $status |
        .worktrees[$wt].pr = $pr |
        .worktrees[$wt].last_activity = $ts' \
       "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"

    log "Updated registry for $WT_NAME"
fi

log "=== open_pr.sh finished ==="
