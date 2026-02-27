#!/bin/bash
# Discard worktree and clean up — called with && exit to close pane

CURRENT_DIR=$(pwd)
BRANCH=$(git branch --show-current 2>/dev/null)
MAIN_DIR=$(git worktree list | head -1 | awk '{print $1}')

if [ "$CURRENT_DIR" = "$MAIN_DIR" ]; then
    echo "❌ You're on the main worktree. Can't discard main."
    exit 1
fi

cd "$MAIN_DIR"
git worktree remove "$CURRENT_DIR" --force 2>/dev/null || true
git branch -D "$BRANCH" 2>/dev/null || true
echo "🗑️  Discarded: $BRANCH"
