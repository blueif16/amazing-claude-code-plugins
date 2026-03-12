#!/bin/bash
# ~/.claude/statusline.sh — Git status + context usage for Claude Code
# Format: branch | worktree-name ↑ahead ●dirty ✚staged ⇣behind | ctx:N%

set -uo pipefail

# Get git branch
branch=$(git branch --show-current 2>/dev/null || echo "no-git")

# Get worktree directory name (if in worktree)
worktree_name=""
if git worktree list &>/dev/null; then
  cwd=$(pwd)
  main_dir=$(git worktree list | head -1 | awk '{print $1}')
  if [ "$cwd" != "$main_dir" ]; then
    worktree_name=$(basename "$cwd")
  fi
fi

# Git status indicators
ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
dirty=$(git status --porcelain 2>/dev/null | grep '^.[MD]' | wc -l)
staged=$(git status --porcelain 2>/dev/null | grep '^[MADRC]' | wc -l)

# Build status string
status=""
[ "$ahead" != "0" ] && status+=" ↑$ahead"
[ "$dirty" != "0" ] && status+=" ●$dirty"
[ "$staged" != "0" ] && status+=" ✚$staged"
[ "$behind" != "0" ] && status+=" ⇣$behind"

# Context usage (read from Claude Code's internal state if available)
# This is a placeholder - Claude Code may expose this via env var or file
ctx_pct="?"
if [ -n "${CLAUDE_CONTEXT_TOKENS:-}" ] && [ -n "${CLAUDE_CONTEXT_LIMIT:-}" ]; then
  ctx_pct=$((CLAUDE_CONTEXT_TOKENS * 100 / CLAUDE_CONTEXT_LIMIT))
fi

# Output format
output="$branch"
[ -n "$worktree_name" ] && output+=" | $worktree_name"
output+="$status"
output+=" | ctx:$ctx_pct%"

echo "$output"
