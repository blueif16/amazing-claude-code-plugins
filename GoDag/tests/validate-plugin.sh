#!/usr/bin/env bash
# GoDag Plugin Structure Validator
# Checks that the plugin follows the official Claude Code plugin spec
#
# Usage: ./tests/validate-plugin.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [[ "$result" == "ok" ]]; then
    PASS=$((PASS + 1))
    printf "  ✅ %s\n" "$desc"
  else
    FAIL=$((FAIL + 1))
    printf "  ❌ %s — %s\n" "$desc" "$result"
  fi
}

echo ""
echo "═══════════════════════════════════════"
echo "🔍 GoDag Plugin Structure Validation"
echo "═══════════════════════════════════════"
echo ""

# --- Manifest ---
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ -f "$MANIFEST" ]]; then
  check "plugin.json exists" "ok"
else
  check "plugin.json exists" "MISSING: $MANIFEST"
fi

if python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null; then
  check "plugin.json is valid JSON" "ok"
else
  check "plugin.json is valid JSON" "parse error"
fi

# Check required manifest fields
for field in name version description; do
  if python3 -c "import json; d=json.load(open('$MANIFEST')); assert '$field' in d" 2>/dev/null; then
    check "manifest has '$field'" "ok"
  else
    check "manifest has '$field'" "MISSING"
  fi
done

# Check skills is a string (directory path), NOT an array
SKILLS_TYPE=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
s = d.get('skills')
if s is None: print('missing')
elif isinstance(s, str): print('ok')
elif isinstance(s, list): print('WRONG: must be string path, got array')
else: print(f'WRONG: unexpected type {type(s).__name__}')
" 2>&1)
check "manifest.skills is string (dir path)" "$SKILLS_TYPE"

# Check commands is an array of strings
CMDS_TYPE=$(python3 -c "
import json
d = json.load(open('$MANIFEST'))
c = d.get('commands')
if c is None: print('ok_autodiscover')
elif isinstance(c, list) and all(isinstance(x, str) for x in c): print('ok')
elif isinstance(c, str): print('WRONG: should be array of file paths')
else: print(f'WRONG: unexpected type')
" 2>&1)
check "manifest.commands is array of paths" "$CMDS_TYPE"

# --- Skills directory structure ---
echo ""
echo "─── Skills ────────────────────────────"

SKILLS_DIR="$PLUGIN_DIR/skills"
if [[ -d "$SKILLS_DIR" ]]; then
  check "skills/ directory exists" "ok"
else
  check "skills/ directory exists" "MISSING"
fi

# Check each skill has SKILL.md in a subdirectory
for skill_dir in "$SKILLS_DIR"/*/; do
  if [[ -d "$skill_dir" ]]; then
    skill_name="$(basename "$skill_dir")"
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      check "skills/$skill_name/SKILL.md" "ok"
    else
      check "skills/$skill_name/SKILL.md" "MISSING (must be SKILL.md, not flat .md)"
    fi
  fi
done

# Warn about flat .md files in skills/ (wrong structure)
for flat_file in "$SKILLS_DIR"/*.md; do
  if [[ -f "$flat_file" ]]; then
    fname="$(basename "$flat_file")"
    check "No flat .md in skills/ ($fname)" "WRONG: should be skills/${fname%.md}/SKILL.md"
  fi
done

# --- Commands ---
echo ""
echo "─── Commands ──────────────────────────"

CMDS_DIR="$PLUGIN_DIR/commands"
if [[ -d "$CMDS_DIR" ]]; then
  check "commands/ directory exists" "ok"
else
  check "commands/ directory exists" "MISSING"
fi

for cmd in "$CMDS_DIR"/*.md; do
  if [[ -f "$cmd" ]]; then
    cmd_name="$(basename "$cmd")"
    # Check frontmatter has required fields
    has_name=$(head -10 "$cmd" | grep -c "^name:" || true)
    has_desc=$(head -10 "$cmd" | grep -c "^description:" || true)
    if [[ $has_name -gt 0 && $has_desc -gt 0 ]]; then
      check "commands/$cmd_name has frontmatter" "ok"
    else
      check "commands/$cmd_name has frontmatter" "missing name or description in YAML frontmatter"
    fi
  fi
done

# --- No agents directory (GoDag doesn't use custom agents) ---
echo ""
echo "─── Agent Policy ──────────────────────"

if [[ -d "$PLUGIN_DIR/agents" ]]; then
  check "No agents/ directory (native-only policy)" "WRONG: agents/ directory exists — GoDag should not define custom agents"
else
  check "No agents/ directory (native-only policy)" "ok"
fi

# Check skill file doesn't reference custom agent types
if grep -rq "infistack:" "$SKILLS_DIR" 2>/dev/null; then
  check "No infistack: agent references in skills" "FOUND: remove all infistack:* agent type references"
else
  check "No infistack: agent references in skills" "ok"
fi

# --- Dashboard ---
echo ""
echo "─── Dashboard ─────────────────────────"

if [[ -f "$PLUGIN_DIR/dashboard/index.html" ]]; then
  check "dashboard/index.html exists" "ok"
else
  check "dashboard/index.html exists" "MISSING"
fi

# --- Results ---
echo ""
echo "─── Results ──────────────────────────"
echo "  Pass: $PASS  Fail: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "⚠️  Fix the failures above before publishing."
  exit 1
else
  echo "✅ Plugin structure is valid!"
fi
