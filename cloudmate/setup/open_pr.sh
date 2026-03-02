#!/bin/bash
# Push branch and create PR via Claude /ship command.
# Replaces merge.sh — PRs go to GitHub for review, no local merging.
#
# Usage: open_pr.sh [WORKTREE_DIR]

set -euo pipefail

WORKTREE_DIR="${1:-$(pwd)}"
cd "$WORKTREE_DIR"

BRANCH=$(git branch --show-current 2>/dev/null)
MAIN_DIR=$(git worktree list | head -1 | awk '{print $1}')
MAIN_BRANCH=$(git -C "$MAIN_DIR" branch --show-current 2>/dev/null || echo "main")

# ── Safety checks ──────────────────────────────────────────────
if [ "$BRANCH" = "$MAIN_BRANCH" ]; then
    echo "⏭️  On $MAIN_BRANCH, skipping."
    exit 0
fi

# Nothing to ship?
if ! git log "$MAIN_BRANCH".."$BRANCH" --oneline 2>/dev/null | grep -q .; then
    echo "⏭️  No commits ahead of $MAIN_BRANCH, skipping."
    exit 0
fi

# PR already exists?
if gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null; then
    echo "ℹ️  PR already exists for $BRANCH."
    exit 0
fi

# ── Push ───────────────────────────────────────────────────────
echo "📤 Pushing $BRANCH..."
git push -u origin "$BRANCH" 2>/dev/null

# ── Create PR via /ship ───────────────────────────────────────
# /ship reads .tasks/BRANCH.md if available, falls back to git log + diff.
# Must cd to worktree so /ship's git commands read the right repo.
echo "📝 Creating PR..."
cd "$WORKTREE_DIR" && unset CLAUDECODE && claude -p "/ship"

# ── Update registry if it exists ──────────────────────────────
REGISTRY="$MAIN_DIR/.tasks/registry.json"
if [ -f "$REGISTRY" ] && command -v jq &>/dev/null; then
    WT_NAME=$(basename "$WORKTREE_DIR")
    PR_URL=$(gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null || echo "")
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq --arg wt "$WT_NAME" \
       --arg status "shipped" \
       --arg pr "$PR_URL" \
       --arg ts "$TIMESTAMP" \
       '.worktrees[$wt].status = $status |
        .worktrees[$wt].pr = $pr |
        .worktrees[$wt].last_activity = $ts' \
       "$REGISTRY" > "${REGISTRY}.tmp" && mv "${REGISTRY}.tmp" "$REGISTRY"
fi
