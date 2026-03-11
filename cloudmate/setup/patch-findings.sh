#!/bin/bash
# patch-findings.sh — Background daemon that watches for CodeRabbit findings
# on recently closed/merged PRs and patches main.
#
# How it works:
#   1. Polls GitHub for PRs closed in the last N hours
#      (CloudMate local-merges close PRs as "closed", not "merged" —
#       so we check both states)
#   2. For each PR, checks if CodeRabbit left a review with actionable findings
#   3. If yes, spawns Claude to fix on local main, runs tests, pushes
#   4. If tests fail, reverts and creates a GitHub issue instead
#
# Usage:
#   ~/.cc/patch-findings.sh                # One-shot: check last 2 hours
#   ~/.cc/patch-findings.sh --watch        # Daemon: poll every 5 min
#   ~/.cc/patch-findings.sh --hours 8      # One-shot: check last 8 hours
#
# Background usage (in tmux status pane or tmuxinator):
#   ~/.cc/patch-findings.sh --watch &
#
# ┌─────────────────────────────────────────────────────────────┐
# │ DIRECT-TO-MAIN FIX COMMITS — tradeoffs                     │
# │                                                             │
# │ Pros:                                                       │
# │  - Fully autonomous: findings → fix → pushed, no human      │
# │  - Fast: patch lands minutes after CodeRabbit posts         │
# │  - Clean: fix commit references original PR for traceability│
# │                                                             │
# │ Risks:                                                      │
# │  - Fix commits bypass PR review (only tests gate them)      │
# │  - Claude might misinterpret a CodeRabbit suggestion        │
# │  - If the fix breaks something AND tests don't catch it,    │
# │    main is broken                                           │
# │                                                             │
# │ Mitigations:                                                │
# │  - Only fix real bugs/security, skip style nits (prompt)    │
# │  - Test suite must pass or changes are reverted             │
# │  - On test failure: revert + create issue for human         │
# │  - Tracks patched PRs to avoid double-patching              │
# │                                                             │
# │ When to use:                                                │
# │  - Solo dev with decent test coverage: go for it            │
# │  - Team env: safer to create issues instead of auto-fix     │
# │  - No tests at all: don't. You're flying blind.             │
# └─────────────────────────────────────────────────────────────┘

set -euo pipefail

LOG="/tmp/cc-post-session.log"
log() { echo "[$(date '+%H:%M:%S')] [patch] $*" | tee -a "$LOG"; }

notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
}

# ── Args ──────────────────────────────────────────────────────
HOURS=2
WATCH=false
POLL_INTERVAL=300  # 5 min

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hours) HOURS="$2"; shift 2 ;;
        --watch) WATCH=true; shift ;;
        --interval) POLL_INTERVAL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ── Find repo root ────────────────────────────────────────────
MAIN_DIR=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
if [ -z "$MAIN_DIR" ]; then
    MAIN_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi
cd "$MAIN_DIR"

MAIN_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
    log "❌ Not in a GitHub repo"
    exit 1
fi

# ── Track which PRs we've already patched ─────────────────────
# Avoids re-patching the same PR on every poll cycle.
PATCHED_FILE="/tmp/.cc-patched-prs"
touch "$PATCHED_FILE"

is_already_patched() {
    grep -q "^$1$" "$PATCHED_FILE" 2>/dev/null
}

mark_patched() {
    echo "$1" >> "$PATCHED_FILE"
}

# ── Check one PR for findings ─────────────────────────────────
check_and_patch_pr() {
    local pr_number="$1"
    local pr_title="$2"

    if is_already_patched "$pr_number"; then
        log "  ⏭️  PR #$pr_number: already patched, skipping"
        return 0
    fi

    # Get CodeRabbit reviews on this PR.
    # CodeRabbit posts reviews even after the PR is closed — that's the whole point.
    local findings
    findings=$(gh api "repos/$REPO/pulls/$pr_number/reviews" \
        --jq '[.[] | select(.user.login | test("coderabbit|cr-bot")) | select(.body != "" and .body != null)] | .[0].body // empty' \
        2>/dev/null || echo "")

    if [ -z "$findings" ]; then
        # No CodeRabbit review yet. Could still be pending — we'll catch it next poll.
        return 0
    fi

    # Check for actionable content (not just "looks good" / summary-only reviews)
    local actionable
    actionable=$(echo "$findings" | grep -ciE '(bug|security|error|vulnerability|missing|incorrect|should fix|must fix|critical|race condition|leak|injection|null|undefined|crash)' || true)

    if [ "$actionable" -eq 0 ]; then
        log "  ✅ PR #$pr_number: CodeRabbit reviewed, no actionable findings"
        mark_patched "$pr_number"
        return 0
    fi

    log "  ⚠️  PR #$pr_number ($pr_title): ~$actionable actionable findings"
    notify "CloudMate" "Findings on PR #$pr_number — patching..."

    # Write findings for Claude
    local findings_file="/tmp/.cc-findings-pr${pr_number}"
    echo "$findings" > "$findings_file"

    # ── Ensure main is up to date ─────────────────────────────
    cd "$MAIN_DIR"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    if [ "$current_branch" != "$MAIN_BRANCH" ]; then
        log "  ⚠️  Not on $MAIN_BRANCH (on $current_branch), skipping auto-fix"
        log "  Run manually when on $MAIN_BRANCH"
        return 1
    fi

    git pull --ff-only 2>&1 | tee -a "$LOG" || {
        log "  ⚠️  Could not pull main, skipping"
        return 1
    }

    # ── Spawn Claude to fix ───────────────────────────────────
    log "  🔧 Spawning Claude to patch..."

    local claude_output="/tmp/.cc-patch-output-pr${pr_number}"

    (unset CLAUDECODE && claude -p \
        "You are patching main based on CodeRabbit findings from PR #$pr_number ($pr_title).

Read the findings at $findings_file.

Rules:
- ONLY fix real bugs, security issues, and correctness problems
- SKIP style nits, naming suggestions, and optional improvements
- Keep changes minimal and surgical
- After making changes, run the project's test suite
- If tests FAIL: undo ALL your changes with 'git checkout -- .' and print exactly TESTS_FAILED
- If there are no real issues to fix: print exactly NOTHING_TO_FIX
- If you fixed something and tests pass: commit with 'fix: patch findings from #$pr_number'

Do not over-engineer. Fix only what CodeRabbit flagged as a real problem." \
        2>&1) | tee "$claude_output" >> "$LOG" || true

    local result
    result=$(cat "$claude_output")

    if echo "$result" | grep -q "TESTS_FAILED"; then
        log "  ❌ Tests failed — reverting, creating issue"
        git checkout -- . 2>/dev/null
        git clean -fd 2>/dev/null

        gh issue create \
            --title "fix: address findings from #$pr_number" \
            --body "Auto-patch attempted but tests failed.

PR: https://github.com/$REPO/pull/$pr_number
Title: $pr_title

Manual fix needed. See findings in the PR review comments." \
            --label "auto-fix-failed" 2>&1 | tee -a "$LOG" || true

        notify "CloudMate ❌" "Auto-fix failed for #$pr_number — issue created"

    elif echo "$result" | grep -q "NOTHING_TO_FIX"; then
        log "  ✅ PR #$pr_number: no real issues to fix"

    else
        # Check if Claude actually made commits
        local new_commits
        new_commits=$(git log --oneline -5 2>/dev/null | grep -c "patch findings from #$pr_number" || true)

        if [ "$new_commits" -gt 0 ]; then
            log "  📤 Pushing fix to main..."
            git push 2>&1 | tee -a "$LOG"
            log "  ✅ Patched main from PR #$pr_number"
            notify "CloudMate ✅" "Patched #$pr_number findings"
        else
            log "  ✅ No changes needed for PR #$pr_number"
        fi
    fi

    mark_patched "$pr_number"
    rm -f "$findings_file" "$claude_output"
}

# ── Scan recent PRs ──────────────────────────────────────────
scan_prs() {
    # Calculate "since" timestamp.
    # macOS date uses -v, GNU date uses -d. Try both.
    local since
    since=$(date -u -v-${HOURS}H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
            date -u -d "${HOURS} hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

    log "Scanning PRs since $since..."

    # Check BOTH closed and merged PRs.
    # Local squash-merge + push main → GitHub auto-closes as "closed".
    # gh pr merge → GitHub marks as "merged".
    # We need to catch both patterns.
    local prs
    prs=$(gh pr list --state closed --limit 20 \
        --json number,title,closedAt,mergedAt \
        --jq ".[] | select((.closedAt // .mergedAt // \"1970\") > \"$since\") | \"\(.number)|\(.title)\"" \
        2>/dev/null || echo "")

    if [ -z "$prs" ]; then
        log "No recently closed PRs"
        return 0
    fi

    local count=0
    while IFS='|' read -r pr_number pr_title; do
        [ -z "$pr_number" ] && continue
        count=$((count + 1))
        log "Checking PR #$pr_number: $pr_title"
        check_and_patch_pr "$pr_number" "$pr_title"
    done <<< "$prs"

    log "Scanned $count PRs"
}

# ── Main ──────────────────────────────────────────────────────
if [ "$WATCH" = true ]; then
    log "=== patch-findings daemon started (poll every ${POLL_INTERVAL}s) ==="
    log "Repo: $REPO | Main: $MAIN_BRANCH | Lookback: ${HOURS}h"
    log "Stop with: kill $$ or Ctrl+C"

    while true; do
        scan_prs
        sleep "$POLL_INTERVAL"
    done
else
    log "=== patch-findings one-shot ==="
    scan_prs
    log "=== done ==="
fi
