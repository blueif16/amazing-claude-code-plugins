#!/bin/bash
# Squash-merge current worktree branch into main
# Used by both Merge & Close (+ exit) and Merge & Keep (alone)

CURRENT_DIR="${1:-$(pwd)}"
BRANCH=$(git branch --show-current 2>/dev/null)
MAIN_DIR=$(git worktree list | head -1 | awk '{print $1}')
MAIN_BRANCH=$(git -C "$MAIN_DIR" branch --show-current 2>/dev/null || echo "main")

# Safety: don't run from main
if [ "$CURRENT_DIR" = "$MAIN_DIR" ]; then
    echo "❌ You're on the main worktree. Switch to a worktree pane first."
    exit 1
fi

# Commit any uncommitted changes
cd "$CURRENT_DIR"
git add -A
git diff-index --quiet HEAD 2>/dev/null || git commit -m "pre-merge checkpoint" 2>/dev/null || true

# Build squash commit message from branch history
MSG=$(git log "$MAIN_BRANCH".."$BRANCH" --pretty=format:"%s" 2>/dev/null \
    | grep -v "^wip" | grep -v "^checkpoint" | grep -v "^final:" \
    | grep -v "^pre-merge" | grep -v "^session-end" \
    | head -5 | tr '\n' '; ' | sed 's/; $//')
if [ -z "$MSG" ]; then
    MSG="merge from $BRANCH"
fi

# Squash merge into main
cd "$MAIN_DIR"
git merge --squash "$BRANCH" 2>/dev/null

if [ $? -eq 0 ]; then
    git commit -m "merge: $MSG" 2>/dev/null || echo "Nothing new to merge"
    echo "✅ Merged into $MAIN_BRANCH: $MSG"
else
    echo "⚠️  Merge conflict. Resolve in $MAIN_DIR, then clean up manually."
    cd "$CURRENT_DIR"
    exit 1
fi

cd "$CURRENT_DIR"
