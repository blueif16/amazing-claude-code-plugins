#!/usr/bin/env bash
# GoDag Schema Validator — checks state.json files for structural correctness
#
# Usage:
#   ./tests/validate-state.sh                        # validate all fixtures
#   ./tests/validate-state.sh tests/fixtures/X.json   # validate one file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
ERRORS=""

validate_file() {
  local file="$1"
  local name="$(basename "$file" .json)"
  local errs=""

  # --- Is it valid JSON? ---
  if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
    errs+="  ❌ Invalid JSON\n"
    FAIL=$((FAIL + 1))
    ERRORS+="$name: Invalid JSON\n"
    printf "  ❌ %-30s Invalid JSON\n" "$name"
    return
  fi

  # --- Run structural checks ---
  result=$(python3 -c "
import json, sys

with open('$file') as f:
    s = json.load(f)

errors = []

# Top-level keys
for k in ['\$schema', 'meta', 'dag', 'tasks', 'confidence', 'dashboard']:
    if k not in s:
        errors.append(f'Missing top-level key: {k}')

# Meta fields
meta = s.get('meta', {})
for k in ['project', 'intent_type', 'level', 'strategy', 'started_at', 'status', 'user_prompt']:
    if k not in meta:
        errors.append(f'meta missing: {k}')

if meta.get('intent_type') not in ('implement', 'fix', 'refactor', 'review', 'research', 'continue'):
    errors.append(f'meta.intent_type invalid: {meta.get(\"intent_type\")}')

if meta.get('level') not in (1, 2, 3):
    errors.append(f'meta.level invalid: {meta.get(\"level\")}')

if meta.get('status') not in ('running', 'complete', 'failed'):
    errors.append(f'meta.status invalid: {meta.get(\"status\")}')

# DAG structure
dag = s.get('dag', {})
dag_tasks = dag.get('tasks', [])
edges = dag.get('edges', [])

if not dag_tasks:
    errors.append('dag.tasks is empty')

task_ids = set()
for t in dag_tasks:
    tid = t.get('id')
    task_ids.add(tid)
    for k in ['id', 'title', 'type', 'scope', 'blocked_by', 'acceptance', 'estimated_complexity', 'agent_role']:
        if k not in t:
            errors.append(f'dag task {tid} missing: {k}')
    if not isinstance(t.get('scope', []), list):
        errors.append(f'dag task {tid}: scope must be array')
    if not isinstance(t.get('blocked_by', []), list):
        errors.append(f'dag task {tid}: blocked_by must be array')
    for dep in t.get('blocked_by', []):
        if dep not in task_ids and dep not in [tt.get('id') for tt in dag_tasks]:
            errors.append(f'dag task {tid}: blocked_by references unknown task {dep}')

# Edges consistency
for edge in edges:
    if len(edge) != 2:
        errors.append(f'edge must be [from, to], got: {edge}')
    elif edge[0] not in task_ids or edge[1] not in task_ids:
        errors.append(f'edge references unknown task: {edge}')

# blocked_by ↔ edges consistency
for t in dag_tasks:
    for dep in t.get('blocked_by', []):
        if [dep, t['id']] not in edges:
            errors.append(f'blocked_by [{dep} → {t[\"id\"]}] missing from edges')

# Tasks runtime state
tasks_state = s.get('tasks', {})
for tid in task_ids:
    if tid not in tasks_state:
        errors.append(f'tasks state missing for {tid}')
    else:
        ts = tasks_state[tid]
        if ts.get('status') not in ('pending', 'blocked', 'in_progress', 'done'):
            errors.append(f'tasks.{tid}.status invalid: {ts.get(\"status\")}')
        if ts.get('status') == 'done' and ts.get('acceptance_passed') is None:
            errors.append(f'tasks.{tid}: done but acceptance_passed is null')
        if ts.get('retries') is None:
            errors.append(f'tasks.{tid}: retries is null')

# Confidence
conf = s.get('confidence', {})
for k in ['score', 'level', 'signals']:
    if k not in conf:
        errors.append(f'confidence missing: {k}')

if conf.get('level') not in ('low', 'medium', 'high'):
    errors.append(f'confidence.level invalid: {conf.get(\"level\")}')

if errors:
    print('\\n'.join(errors))
    sys.exit(1)
else:
    sys.exit(0)
" 2>&1)

  if [[ $? -eq 0 ]]; then
    PASS=$((PASS + 1))
    printf "  ✅ %-30s OK\n" "$name"
  else
    FAIL=$((FAIL + 1))
    printf "  ❌ %-30s FAIL\n" "$name"
    echo "$result" | sed 's/^/     /'
    ERRORS+="$name:\n$result\n"
  fi
}

echo ""
echo "═══════════════════════════════════════"
echo "🔍 GoDag State Schema Validation"
echo "═══════════════════════════════════════"
echo ""

if [[ $# -gt 0 ]]; then
  validate_file "$1"
else
  for f in "$SCRIPT_DIR/fixtures/"*.json; do
    validate_file "$f"
  done
fi

echo ""
echo "─── Results ──────────────────────────"
echo "  Pass: $PASS  Fail: $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
