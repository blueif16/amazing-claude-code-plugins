# Worktree PR Workflow

Automated workflow: push → PR (triggers CodeRabbit) → local merge → push main → async review → auto-patch.

## How It Works

1. **Cmd+Shift+W**: Opens a new worktree pane with Claude Code
2. **Work in worktree**: Make commits
3. **Cmd+Shift+P**: Exits Claude → pushes branch → creates PR → **local squash-merge** → pushes main

GitHub sees main updated, auto-closes the PR. CodeRabbit still reviews the closed PR asynchronously. `patch-findings.sh` runs in the background, picks up findings, spawns Claude to fix on main.

## Architecture

### Flow

```
Cmd+Shift+P pressed
  ↓
1. send-exit.sh: capture pwd, send /exit
  ↓
2. post-session.sh: safety commit, dispatch to open_pr.sh (background)
  ↓
3. open_pr.sh:
   ├── git push origin feat-branch        (GitHub has the branch)
   ├── gh pr create --fill                 (triggers CodeRabbit, audit trail)
   ├── git merge --squash (LOCAL)          (instant, no round-trip)
   ├── git push origin main                (GitHub auto-closes PR)
   └── git push origin --delete feat-branch
  ↓
4. [Background] patch-findings.sh --watch
   ├── polls closed PRs every 5 min
   ├── checks for CodeRabbit reviews with actionable findings
   ├── spawns Claude to fix on main, runs tests
   ├── if tests pass: pushes fix commit
   └── if tests fail: reverts, creates GitHub issue
```

### Why local merge instead of gh pr merge?

`gh pr merge` asks GitHub's server to merge, then you `git pull` to get the result locally. That's a round-trip for nothing. You have both branches right there — merge locally, push the result up. One direction instead of two.

### Why create a PR at all?

Two reasons: CodeRabbit only reviews PRs (not direct pushes to main), and the PR preserves the diff + conversation as an audit trail. The PR shows as "closed" not "merged" on GitHub, but the diff and any review comments are preserved.

## Post-Merge Patching

### Background daemon (recommended)

Add to your tmuxinator `work.yml` or run manually:

```bash
~/.cc/patch-findings.sh --watch            # Poll every 5 min
~/.cc/patch-findings.sh --watch --hours 4  # Wider lookback
```

It tracks which PRs it has already handled in `/tmp/.cc-patched-prs` to avoid double-patching.

### One-shot

```bash
~/.cc/patch-findings.sh                # Check last 2 hours
~/.cc/patch-findings.sh --hours 8      # Check last 8 hours
```

## Files

All scripts symlinked to `~/.cc/`:

| Script | Purpose |
|--------|---------|
| `send-exit.sh` | Captures pwd, sends /exit to Claude |
| `post-session.sh` | Reads action, dispatches to open_pr.sh or discard.sh |
| `open_pr.sh` | Push → PR → local merge → push main |
| `patch-findings.sh` | Daemon: watch for CR findings, patch main |
| `discard.sh` | Remove worktree + delete branch |
| `status.sh` | Interactive dashboard |
| `merge.sh` | Legacy local squash-merge (kept for manual use) |

## Setup

### 1. Install Scripts

```bash
mkdir -p ~/.cc

for f in cloudmate/setup/*.sh; do
    ln -sf "$(pwd)/$f" ~/.cc/$(basename "$f")
done

chmod +x ~/.cc/*.sh
```

### 2. Configure iTerm2 Shortcuts

**Cmd+Shift+W** (Open worktree):
- Action: Send Text with "vim" Special Chars
- Text: `split-window -h 'claude -w; ~/.cc/post-session.sh $TMUX_PANE'` + `select-layout main-vertical`

**Cmd+Shift+P** (Ship it):
- Command 1: `run-shell 'echo pr > /tmp/.cc-action-#{pane_id}'`
- Command 2: `run-shell "~/.cc/send-exit.sh #{pane_id}"`

### 3. Start the patch daemon

Add to tmuxinator or run in a dedicated pane:

```bash
~/.cc/patch-findings.sh --watch
```

## Troubleshooting

```bash
# Watch all CloudMate activity
tail -f /tmp/cc-post-session.log

# Check background PR sessions
tmux list-sessions | grep pr-

# Check PR status
cat /tmp/.cc-pr-status

# See which PRs have been patched
cat /tmp/.cc-patched-prs

# Manually trigger a findings check
~/.cc/patch-findings.sh --hours 1

# Reset patched tracking (re-check everything)
rm /tmp/.cc-patched-prs
```
