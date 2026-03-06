#!/bin/bash
# fix-cr.sh — Pull CodeRabbit review comments from a PR, feed to local CC, push fixes.
# Runs entirely locally. No cloud API keys needed.
#
# Usage:
#   ~/.cc/fix-cr.sh                  # auto-detect PR from current branch
#   ~/.cc/fix-cr.sh 5                # fix PR #5
#   ~/.cc/fix-cr.sh --dry-run        # show what CC would receive, don't fix

set -euo pipefail

LOG="/tmp/cc-post-session.log"
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

DRY_RUN=false
PR_NUMBER=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        [0-9]*) PR_NUMBER="$arg" ;;
    esac
done

# Auto-detect PR from current branch
if [ -z "$PR_NUMBER" ]; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    PR_NUMBER=$(gh pr view "$BRANCH" --json number -q '.number' 2>/dev/null || true)
    if [ -z "$PR_NUMBER" ]; then
        echo "No PR found for branch $BRANCH. Pass PR number: fix-cr.sh 5"
        exit 1
    fi
fi

log "=== fix-cr.sh started for PR #$PR_NUMBER ==="

# ── Pull CodeRabbit review comments ──────────────────────────
# Get all review comments, filter to coderabbit bot
CR_COMMENTS=$(gh api \
    "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" \
    --paginate \
    --jq '.[] | select(.user.login == "coderabbitai[bot]") | {
        path: .path,
        line: .line,
        body: .body
    }' 2>/dev/null)

if [ -z "$CR_COMMENTS" ]; then
    log "No CodeRabbit comments found on PR #$PR_NUMBER"
    exit 0
fi

COMMENT_COUNT=$(echo "$CR_COMMENTS" | jq -s 'length')
log "Found $COMMENT_COUNT CodeRabbit comments"

# ── Also grab the walkthrough comment for the AI prompts block ─
# The walkthrough has the combined "Prompt for all review comments" 
WALKTHROUGH=$(gh api \
    "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
    --paginate \
    --jq '.[] | select(.user.login == "coderabbitai[bot]") | .body' 2>/dev/null | head -1)

# Extract the "Prompt for AI Agents" blocks from review comments
AI_PROMPTS=$(echo "$CR_COMMENTS" | jq -r '.body' | \
    sed -n '/Prompt for AI Agents/,/```$/p' | \
    grep -v '```' | \
    grep -v 'Prompt for AI Agents' || true)

# Build a consolidated prompt for CC
CR_FILE="/tmp/.cc-cr-pr-${PR_NUMBER}"
cat > "$CR_FILE" << PROMPT
You are fixing CodeRabbit review findings on PR #$PR_NUMBER.

Here are the review comments from CodeRabbit, organized by file:

$(echo "$CR_COMMENTS" | jq -rs '.[] | "## \(.path) (line \(.line))\n\(.body)\n---\n"')

Instructions:
1. Fix each actionable issue (bugs, security, correctness, missing error handling)
2. Skip pure style nits unless they indicate a real problem  
3. Make minimal, targeted changes per issue
4. Commit with: 'fix: address CR review on PR #$PR_NUMBER'
PROMPT

log "Wrote consolidated prompt to $CR_FILE"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "══════ DRY RUN — CC would receive: ══════"
    cat "$CR_FILE"
    echo "══════════════════════════════════════════"
    rm -f "$CR_FILE"
    exit 0
fi

# ── Spawn CC to fix ──────────────────────────────────────────
log "🔧 Spawning CC to fix $COMMENT_COUNT issues..."
unset CLAUDECODE && claude -p "$(cat "$CR_FILE")" 2>&1 | tee -a "$LOG"

# ── Push fixes ───────────────────────────────────────────────
if ! git diff-index --quiet HEAD 2>/dev/null; then
    git add -A
    git commit -m "fix: address CodeRabbit review on PR #$PR_NUMBER"
fi

git push 2>&1 | tee -a "$LOG"
log "📤 Pushed fixes for PR #$PR_NUMBER"

rm -f "$CR_FILE"
log "=== fix-cr.sh finished ==="
