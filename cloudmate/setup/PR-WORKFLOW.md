# Worktree PR Workflow

Automated workflow to create GitHub PRs from git worktrees using iTerm2 shortcuts.

## How It Works

1. **Cmd+Shift+W**: Opens a new worktree pane with Claude Code
2. **Work in worktree**: Make commits in the worktree
3. **Cmd+Shift+P**: Captures directory, exits Claude, and creates PR

## Architecture

### Flow

```
Cmd+Shift+P pressed
  ↓
1. Write action to /tmp/.cc-action-$PANE_ID
  ↓
2. send-exit.sh runs:
   - Send !pwd | tee /tmp/.cc-dir-$PANE_ID (capture worktree path)
   - Send /exit (close Claude Code)
  ↓
3. Shell chain runs: post-session.sh $TMUX_PANE
  ↓
4. post-session.sh:
   - Read directory from /tmp/.cc-dir-$PANE_ID
   - Read action from /tmp/.cc-action-$PANE_ID
   - cd to worktree directory
   - Detect branch
   - Call open_pr.sh
  ↓
5. open_pr.sh:
   - Push branch to GitHub
   - Create PR via claude -p "/ship"
```

### Why This Approach?

**Problem**: After Claude Code exits, the shell returns to the parent directory. `pwd` in post-session.sh would return the wrong path.

**Solution**: Before exiting, Claude Code runs `!pwd` to save its current directory to a temp file. post-session.sh reads this file to know which worktree to work in.

**Key insight**: Only Claude Code knows the worktree path while it's running. We must capture it before exit.

## Files

All scripts are symlinked to `~/.cc/` for easy access:

- `~/.cc/send-exit.sh` - Captures pwd and sends /exit to Claude
- `~/.cc/post-session.sh` - Reads directory, handles PR workflow
- `~/.cc/open_pr.sh` - Pushes branch and creates PR

## Setup

### 1. Install Scripts

```bash
# Create ~/.cc directory
mkdir -p ~/.cc

# Symlink scripts (run from amazing-claude-code-plugins repo)
ln -sf "$(pwd)/cloudmate/setup/send-exit.sh" ~/.cc/send-exit.sh
ln -sf "$(pwd)/cloudmate/setup/post-session.sh" ~/.cc/post-session.sh
ln -sf "$(pwd)/cloudmate/setup/open_pr.sh" ~/.cc/open_pr.sh

# Make executable
chmod +x ~/.cc/*.sh
```

### 2. Configure iTerm2 Shortcuts

**Cmd+Shift+W** (Open worktree):
- Action: Send Text with "vim" Special Chars
- Text:
```
[{"Version":2,"Apply Mode":0,"Action":65,"Text":" split-window -h 'claude -w; ~/.cc/post-session.sh $TMUX_PANE'","Escaping":2},{"Version":2,"Apply Mode":0,"Action":65,"Text":"select-layout main-vertical","Escaping":2}]
```

**Cmd+Shift+P** (Create PR):
- Command 1: `run-shell 'echo pr > /tmp/.cc-action-#{pane_id}'`
- Command 2: `run-shell "~/.cc/send-exit.sh #{pane_id}"`

### 3. Configure Claude Code SessionEnd Hook

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '{session_id, cwd} | \"\\(.session_id)=\\(.cwd)\"' >> /tmp/.cc-sessions.log"
          }
        ]
      }
    ]
  }
}
```

## Usage

1. Open a worktree: **Cmd+Shift+W**
2. Make commits in Claude Code
3. Ship it: **Cmd+Shift+P**
4. PR is created automatically

## Background Mode (Optional)

To run PR creation in the background (non-blocking):

### Modify post-session.sh

Change the PR dispatch section:

```bash
# ── Dispatch ──────────────────────────────────────────────────
log "Dispatching action=$ACTION"
case "$ACTION" in
    pr)
        log "Calling open_pr.sh in background"
        # Run in detached tmux session
        tmux new-session -d -s "pr-$(date +%s)" \
            "cd '$WORKTREE_DIR' && ~/.cc/open_pr.sh '$WORKTREE_DIR' 2>&1 | tee -a '$LOG'"
        log "PR creation started in background"
        ;;
    discard)
        log "Calling discard.sh"
        ~/.cc/discard.sh "$WORKTREE_DIR" 2>&1 | tee -a "$LOG"
        ;;
    *)
        log "⚠️  Unknown action: $ACTION. Did safety commit only."
        ;;
esac
```

**Pros:**
- Pane closes immediately
- Non-blocking workflow
- Cleaner UX

**Cons:**
- Can't see PR creation progress
- Harder to debug failures
- Must check logs or GitHub to confirm

## Troubleshooting

### Check logs

```bash
tail -f /tmp/cc-post-session.log
```

### Verify directory capture

```bash
# After pressing Cmd+Shift+P, check if directory was captured
cat /tmp/.cc-dir-$(echo $TMUX_PANE | tr -d '%')
```

### Common issues

1. **"No commits ahead of main"**: The worktree has no new commits, or PR already exists
2. **"Cannot cd to directory"**: Directory file wasn't created - check send-exit.sh timing
3. **Empty directory file**: The `!pwd` command didn't execute - check tmux send-keys timing

## Race Conditions

The workflow uses `$PANE_ID` in temp filenames to avoid race conditions. If you press Cmd+Shift+P in multiple panes within ~5 seconds, each gets its own temp files.

**Single-file alternative**: If you never do concurrent PRs, you could use `/tmp/.cc-action` and `/tmp/.cc-dir` (no pane_id suffix) for simplicity. But the current approach is safer.
