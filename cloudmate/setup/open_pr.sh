#!/bin/bash
# Push branch and create PR via Claude /ship command.
# Replaces merge.sh — PRs go to GitHub for review, no local merging.
#
# Usage: open_pr.sh [WORKTREE_DIR]

set -euo pipefail

LOG="/tmp/cc-post-session.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

# Notification helper
notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
}

# Status file for monitoring
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
update_status "$BRANCH" "pushing"
notify "CloudMate" "Pushing branch..."
git push -u origin "$BRANCH" 2>&1 | tee -a "$LOG"

# ── CodeRabbit pre-PR review + autofix ─────────────────────────
MAX_CR_ROUNDS=2
CR_ROUND=0

if command -v coderabbit &>/dev/null; then
    while [ $CR_ROUND -lt $MAX_CR_ROUNDS ]; do
        CR_ROUND=$((CR_ROUND + 1))
        log "🐇 CodeRabbit review round $CR_ROUND/$MAX_CR_ROUNDS..."
        update_status "$BRANCH" "coderabbit_review_round_${CR_ROUND}"
        notify "CloudMate" "CodeRabbit reviewing (round $CR_ROUND/$MAX_CR_ROUNDS)..."

        CR_OUTPUT=$(coderabbit review --base "$MAIN_BRANCH" --prompt-only 2>&1)
        CR_EXIT=$?

        if [ $CR_EXIT -ne 0 ]; then
            log "⚠️  CodeRabbit failed (exit $CR_EXIT), skipping"
            break
        fi

        # Check if CR found actionable issues (non-empty, not just whitespace/headers)
        ISSUE_COUNT=$(echo "$CR_OUTPUT" | grep -cE '(bug|error|vulnerability|missing|incorrect|should|must|critical|warning)' || true)

        if [ "$ISSUE_COUNT" -eq 0 ]; then
            log "✅ CodeRabbit clean — no actionable issues"
            break
        fi

        log "🔧 CodeRabbit found ~$ISSUE_COUNT issues, spawning CC to fix..."
        update_status "$BRANCH" "claude_fixing_issues_round_${CR_ROUND}"
        notify "CloudMate" "Claude fixing $ISSUE_COUNT issues..."

        # Write CR output to temp file for CC to read
        CR_FILE="/tmp/.cc-cr-review-${BRANCH}"
        echo "$CR_OUTPUT" > "$CR_FILE"

        # Spawn CC to fix issues (non-interactive, bounded)
        cd "$WORKTREE_DIR" && unset CLAUDECODE && claude -p \
            "Read the CodeRabbit review at $CR_FILE and fix the actionable issues. Only fix real bugs, security issues, and correctness problems — skip style nits. Commit with message: 'fix: address CodeRabbit review (round $CR_ROUND)'" \
            2>&1 | tee -a "$LOG"

        # Push fixes
        git push 2>&1 | tee -a "$LOG"
        log "📤 Pushed fixes from round $CR_ROUND"

        rm -f "$CR_FILE"
    done
else
    log "ℹ️  CodeRabbit CLI not installed, skipping pre-PR review"
fi

# ── Create PR via /ship ───────────────────────────────────────
log "📝 Creating PR via /ship..."
update_status "$BRANCH" "creating_pr"
notify "CloudMate" "Creating PR with /ship..."
cd "$WORKTREE_DIR" && unset CLAUDECODE && claude -p "/ship" 2>&1 | tee -a "$LOG"

# Get PR URL
if PR_URL=$(gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null); then
    log "✅ PR created: $PR_URL"
    update_status "$BRANCH" "done"
    notify "CloudMate ✅" "PR created: $PR_URL"
else
    log "⚠️  PR creation completed but URL not found"
    update_status "$BRANCH" "error"
    notify "CloudMate ⚠️" "PR creation completed but URL not found"
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
