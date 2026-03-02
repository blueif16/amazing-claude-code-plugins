---
name: slice
description: "Divide a PRD/spec into ordered, dependency-aware slices. Each slice is a copy-paste-ready /cm block. Creates .env.example and config.py pattern for worktree env resolution."
allowed-tools: Bash(git:*), Bash(cat:*), Bash(ls:*), Bash(grep:*), Read, Write
---

# /slice — PRD to Execution Slices

## Routing

| Input | Action |
|-------|--------|
| `/slice <path-to-spec.md>` | Read spec, generate slices |
| `/slice` (nothing) | Ask for spec file path |

---

## Step 1: Read + Analyze the Spec

Read the spec file. Extract:

- **Phases/components:** Distinct functional units (discovery, pipeline, analysis, output, etc.)
- **Shared types:** Data models/interfaces multiple components depend on
- **External dependencies:** APIs, services, libraries requiring keys or config
- **Data flow:** What each phase produces → what consumes it
- **Tech stack:** Language, framework, package manager

---

## Step 2: Detect Environment Keys

Scan the spec for any mention of API keys, secrets, service credentials, or environment variables.

Create `.env.example` in the project root immediately:
```
# Required environment variables — copy to .env and fill in values
# KEY_NAME=
```

One line per detected key, commented with what service it's for. Commit-safe (no values).

---

## Step 3: Slice the Spec

Divide into slices following these rules:

### Slice 1 is ALWAYS scaffold
Slice 1 runs on main branch (not a worktree). It delivers:
- Project structure (package config, directory layout, entrypoint stub)
- All shared types/models/enums that downstream slices import
- `config.py` with worktree-aware env loading (see Step 4)
- `.env.example` (already created in Step 2)
- `.gitignore`
- Empty module stubs so later slices have import targets
- Tests for pure logic only (scoring, sorting, validation — no external calls)

### Slicing principles
- **One functional vertical per slice.** Each slice delivers one working capability end-to-end within its scope. Not horizontal layers ("all models", "all routes").
- **3-8 files per slice.** Fewer = merge into adjacent slice. More = split further.
- **Explicit data dependencies.** If Slice B needs output from Slice A, say exactly which types/files. No implicit coupling.
- **Fixtures flow forward.** No slice depends on test fixtures that haven't been produced yet by a prior slice. Early slices test with hand-written mocks. The first slice that produces real data (e.g. captures screenshots, calls APIs) commits its output as `tests/fixtures/` for all downstream slices.
- **Acceptance criteria are runnable.** Every slice ends with commands you can execute: `pytest tests/test_X.py`, `python -m app --help`, etc. Not vibes.
- **Two test tiers.** Tier 1 = mocked, no API calls, runs during `/cm`. Tier 2 = hits real APIs, run manually after merge. Mark which is which.

### Dependency ordering
- Map the dependency graph. Identify which slices can run in parallel (no shared deps).
- Linear chains are fine. Don't force parallelism where it doesn't exist.
- The graph must be a DAG — no cycles.

---

## Step 4: Generate config.py Spec

Every Slice 1 must include a `config.py` that resolves `.env` from the main worktree. This is the standard pattern — include it verbatim in Slice 1's deliverables:

```python
import subprocess, os
from pathlib import Path
from dotenv import load_dotenv

def _find_main_worktree() -> Path:
    result = subprocess.run(
        ["git", "worktree", "list", "--porcelain"],
        capture_output=True, text=True
    )
    first_line = result.stdout.splitlines()[0]
    return Path(first_line.split(" ", 1)[1])

_main_env = _find_main_worktree() / ".env"
if _main_env.exists():
    load_dotenv(_main_env)

# --- project-specific keys below ---
```

This works from main AND any linked worktree. No hooks, no copying, no shell env vars.

---

## Step 5: Write the Output

Write a single file: `.tasks/slices.md`

### Format

```markdown
# [Project Name] — Slice Plan

> Run `/cm` with any slice block below. Slices are ordered by dependency.
> After Slice 1 merges: `cp .env.example .env` and fill in keys. All worktrees resolve from main.

## Environment
| Key | Service | First needed |
|-----|---------|-------------|
| ... | ...     | Slice N     |

## Slice Index
| # | Name | Spec sections | Depends on | Est. Level |
|---|------|--------------|------------|------------|
| 1 | ... | ... | — | L1 |
| 2 | ... | ... | 1 | L2 |

## Dependency Graph
(ASCII art showing parallel opportunities)

---

### Slice 1 — [Name]

**Read:** [which sections of the spec to reference]

**Deliver:**
- [file]: [what it does, one line]
- ...

**Fixtures produced:** [what test data this slice creates, or "none — hand-written mocks"]
**Fixtures required:** [what test data from prior slices, or "none"]

**Acceptance:**
- `command to run` — what it proves
- ...

---

### Slice 2 — [Name]
...
```

### Rules for the output
- Each slice section must be **self-contained enough to paste into `/cm`**. The `/cm` agent reads the spec file for detail — the slice block tells it scope, deliverables, and acceptance.
- Keep each slice block under 40 lines. Concise deliverable lists, not essays.
- Acceptance criteria: max 5 items per slice. Each is a command + expected outcome.
- Always note which spec sections to read — the `/cm` agent needs to know where to look.

---

## Step 6: Confirm with User

Print summary:
```
✅ Sliced [spec file] into [N] slices
📄 .tasks/slices.md — ready for /cm
📋 .env.example — created with [N] keys

Slice 1 (scaffold) runs on main branch.
After merge: cp .env.example .env, fill in keys.
Then Ctrl+Shift+W per slice, paste the block into /cm.

Parallel opportunities: Slices [X] and [Y] have no shared deps.
```

Do NOT auto-execute any slice. The user decides when and how to run them.
