# GoDag Test Suite

## Quick Start

```bash
cd /path/to/GoDag

# Make scripts executable
chmod +x tests/*.sh

# 1. Validate plugin structure matches Claude Code spec
./tests/validate-plugin.sh

# 2. Validate state.json fixtures against schema
./tests/validate-state.sh

# 3. Launch dashboard with mock data (opens browser)
./tests/test-dashboard.sh fanout-running
```

## Test Scripts

| Script | What it checks |
|--------|---------------|
| `validate-plugin.sh` | Manifest schema, skills dir structure (`SKILL.md` in subdirs), command frontmatter, no custom agents |
| `validate-state.sh` | All fixture `.json` files have correct schema: meta, dag, tasks, confidence, dashboard, edges↔blocked_by consistency |
| `test-dashboard.sh` | Copies fixture + dashboard to temp dir, starts HTTP server, opens browser |

## Fixtures

| Fixture | DAG Shape | Status | Tests |
|---------|-----------|--------|-------|
| `fanout-running` | Fan-out (T1→T2,T3→T4→T5) | Mid-execution, T2+T3 in_progress | Dashboard renders parallel nodes, activity feed, blocked tasks |
| `fanout-complete` | Same shape | All done, 95% confidence | Completion banner, all green nodes |
| `linear-running` | Linear chain (T1→T2→T3→T4→T5) | T3 in_progress, 1 retry on T2 | Sequential layout, retry counter, medium confidence |

## Testing in Claude Code

After fixing the plugin, test these scenarios:

```bash
# Scenario 1: Simple task (should be Level 1, no DAG)
/go fix the typo in README.md

# Scenario 2: Medium task (should be Level 2, subagents)
/go add email verification to the User model

# Scenario 3: Complex task (should be Level 3, Agent Teams)
/go refactor auth from session-based to JWT, including backend, frontend, and tests

# Scenario 4: Continue previous work
/go continue

# Scenario 5: Report
/report
/report short
```

## What to verify

1. **Plugin loads** — no manifest errors in `claude --debug`
2. **Skill activates** — `/go` triggers intent classification
3. **DAG generation** — Level 2+ shows task graph with edges
4. **No custom agents** — teammates are `general-purpose`, `Bash`, `Explore`, or `Plan` only
5. **Dashboard renders** — `test-dashboard.sh` shows nodes, edges, activity feed
6. **State persistence** — `.godag/state.json` created on first `/go`
