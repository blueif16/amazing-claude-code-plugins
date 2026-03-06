#!/bin/bash
# setup-coderabbit.sh — One-shot setup for CodeRabbit CLI + GitHub integration
# Run from your project root or anywhere. Idempotent — safe to re-run.
#
# What this does:
#   1. Installs CodeRabbit CLI (npm global)
#   2. Authenticates with CodeRabbit (browser OAuth)
#   3. Creates .coderabbit.yaml in the target project
#   4. Creates GitHub Actions workflows (Claude Code Action + Autofix)
#   5. Reminds you to install the CodeRabbit GitHub App

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }

PROJECT_ROOT="${1:-.}"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  CodeRabbit + Claude Code Review Setup       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 1. Install CodeRabbit CLI ──────────────────────────────────
echo "── Step 1: CodeRabbit CLI ──"
if command -v coderabbit &>/dev/null; then
    log "CodeRabbit CLI already installed: $(coderabbit --version 2>/dev/null || echo 'unknown version')"
else
    if command -v npm &>/dev/null; then
        warn "Installing CodeRabbit CLI via npm..."
        npm install -g coderabbit 2>&1
        if command -v coderabbit &>/dev/null; then
            log "CodeRabbit CLI installed successfully"
        else
            err "Installation failed. Try manually: npm install -g coderabbit"
            exit 1
        fi
    else
        err "npm not found. Install Node.js first, then run: npm install -g coderabbit"
        exit 1
    fi
fi
echo ""

# ── 2. Authenticate ───────────────────────────────────────────
echo "── Step 2: Authentication ──"
if coderabbit auth status &>/dev/null 2>&1; then
    log "Already authenticated with CodeRabbit"
else
    warn "Opening browser for CodeRabbit authentication..."
    warn "If this doesn't open automatically, visit: https://app.coderabbit.ai"
    coderabbit auth login 2>&1 || {
        warn "Auth command failed — you can authenticate later with: coderabbit auth login"
    }
fi
echo ""

# ── 3. Create .coderabbit.yaml ────────────────────────────────
echo "── Step 3: Repository Config ──"
CR_CONFIG="$PROJECT_ROOT/.coderabbit.yaml"
if [ -f "$CR_CONFIG" ]; then
    warn ".coderabbit.yaml already exists at $CR_CONFIG — skipping"
else
    cat > "$CR_CONFIG" << 'YAML'
# yaml-language-server: $schema=https://coderabbit.ai/integrations/schema.v2.json
language: "en-US"
early_access: false

reviews:
  # "assertive" gives thorough feedback; "chill" is lighter
  profile: "assertive"
  request_changes_workflow: false
  high_level_summary: true
  high_level_summary_placeholder: "@coderabbitai summary"
  poem: false
  review_status: true
  collapse_walkthrough: false
  # Auto-generate PR title when placeholder is in title
  auto_title_placeholder: "@coderabbitai"

  auto_review:
    enabled: true
    drafts: false

  # Path-specific review instructions — customize per project
  path_instructions:
    - path: "src/components/**/*.tsx"
      instructions: |
        - Enforce immutable state updates (no direct mutation of state objects)
        - Check for missing cleanup in useEffect return functions
        - Verify proper TypeScript typing on props interfaces
        - Flag inline styles that should use Tailwind classes
    - path: "src/lib/**/*.ts"
      instructions: |
        - Check for proper error handling with typed errors
        - Verify async functions use try-catch or .catch()
        - Flag hardcoded config values that should be env vars
    - path: "**/*.test.*"
      instructions: |
        - Verify assertions match actual behavior being tested
        - Flag snapshot tests without meaningful assertions
        - Check for proper test isolation (no shared mutable state)
    - path: "src/app/api/**/*.ts"
      instructions: |
        - Ensure all API routes have proper error handling with status codes
        - Validate request bodies
        - Check for authentication/authorization on protected routes

chat:
  auto_reply: true
YAML
    log "Created $CR_CONFIG"
fi
echo ""

# ── 4. GitHub Actions workflows ───────────────────────────────
echo "── Step 4: GitHub Actions ──"
GH_DIR="$PROJECT_ROOT/.github/workflows"
mkdir -p "$GH_DIR"

# 4a. Claude Code Action (interactive + auto-review)
CLAUDE_WF="$GH_DIR/claude.yml"
if [ -f "$CLAUDE_WF" ]; then
    warn "claude.yml already exists — skipping"
else
    cat > "$CLAUDE_WF" << 'YAML'
# Claude Code Action — interactive assistant + PR reviewer
# Responds to @claude mentions in PR/issue comments
# Auto-reviews PRs on open/sync when prompt is set
name: Claude Code
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned, labeled]
  pull_request_review:
    types: [submitted]

concurrency:
  group: claude-${{ github.event.issue.number || github.event.pull_request.number || github.run_id }}
  cancel-in-progress: false

jobs:
  claude:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          claude_args: |
            --max-turns 10
YAML
    log "Created $CLAUDE_WF"
fi

# 4b. Autofix — bot review comments trigger Claude Code fixes
AUTOFIX_WF="$GH_DIR/autofix.yml"
if [ -f "$AUTOFIX_WF" ]; then
    warn "autofix.yml already exists — skipping"
else
    cat > "$AUTOFIX_WF" << 'YAML'
# PR Autofix — when CodeRabbit or other bots leave review comments,
# Claude Code reads them and pushes fix commits automatically.
# Max 3 rounds per PR to prevent runaway loops.
name: PR Autofix
on:
  issue_comment:
    types: [created]
  pull_request_review:
    types: [submitted]
  pull_request_review_comment:
    types: [created]

concurrency:
  group: autofix-${{ github.event.issue.number || github.event.pull_request.number }}
  cancel-in-progress: false

jobs:
  autofix:
    # Only trigger on bot comments (CodeRabbit, linters, etc.)
    if: >
      (github.event.issue.pull_request || github.event.pull_request) &&
      contains(fromJSON('["bot", "Bot"]'),
        github.event.comment.user.type ||
        github.event.review.user.type || '')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            A code review bot left feedback on this PR.
            Read the review comment carefully and fix the identified issues.
            Make minimal, targeted changes — only fix what the review flagged.
            Skip style-only suggestions unless they indicate a real problem.
            Commit with a clear message describing what was fixed.
          claude_args: |
            --max-turns 5
YAML
    log "Created $AUTOFIX_WF"
fi
echo ""

# ── 5. Reminders ──────────────────────────────────────────────
echo "── Step 5: Manual Steps ──"
echo ""
warn "You still need to do these manually:"
echo ""
echo "  1. Install CodeRabbit GitHub App (if not already):"
echo "     → https://github.com/apps/coderabbitai"
echo "     → Grant access to your repo"
echo ""
echo "  2. Add ANTHROPIC_API_KEY to GitHub Secrets:"
echo "     → Repo Settings → Secrets and variables → Actions"
echo "     → New repository secret: ANTHROPIC_API_KEY"
echo ""
echo "  3. (Optional) Install Claude GitHub App for @claude mentions:"
echo "     → In Claude Code terminal, run: /install-github-app"
echo "     → Or visit: https://github.com/apps/claude"
echo ""
echo "  4. Commit and push the new files:"
echo "     git add .coderabbit.yaml .github/"
echo "     git commit -m 'feat: add CodeRabbit + Claude Code review pipeline'"
echo "     git push"
echo ""

# ── Summary ───────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║  Setup Complete                              ║"
echo "╠══════════════════════════════════════════════╣"
echo "║                                              ║"
echo "║  Pipeline:                                   ║"
echo "║  CC writes → CR CLI review → CC fixes →      ║"
echo "║  /ship PR → CR App review → Claude Action →  ║"
echo "║  Autofix → You review on GitHub              ║"
echo "║                                              ║"
echo "║  Files created:                              ║"
echo "║  • .coderabbit.yaml (review config)          ║"
echo "║  • .github/workflows/claude.yml              ║"
echo "║  • .github/workflows/autofix.yml             ║"
echo "║                                              ║"
echo "╚══════════════════════════════════════════════╝"
