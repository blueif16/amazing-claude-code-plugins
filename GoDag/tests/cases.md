# GoDag Behavior Tests

Three real tasks, run in order. Each tests a different aspect of `/go`'s decision-making.

---

## How to run

**CC Session 1** (the GoDag project dir): paste the prompt from each test case.  
**CC Session 2** (same dir): paste the judge prompt after each test.

Between tests, run: `rm -rf .godag` to reset state.

---

## Test 1: Trivial fix → should NOT produce a DAG

**What it tests:** Does `/go` correctly identify a 1-file, 5-minute fix as Level 1 and just do it — no DAG, no confirmation, no teammates?

### CC1 prompt:
```
/go fix inconsistent path references in commands/go.md — some lines say .tasks/ but should say .godag/ everywhere. Before you start, write your intent classification, complexity level, and reasoning to .godag/reasoning.md
```

### Expected behavior:
- Creates `.godag/reasoning.md` with its thinking
- Intent: `fix`
- Level: 1
- Does NOT create `state.json` with a DAG
- Directly edits `commands/go.md`
- All `.tasks/` references become `.godag/`

### CC2 judge prompt:
```
You are judging whether GoDag's /go command behaved correctly. Read these files:
- .godag/reasoning.md (if exists)
- .godag/state.json (if exists — it should NOT for this test)
- commands/go.md

Test case: User asked to fix .tasks/ → .godag/ path references in go.md. This is a single-file typo fix.

Pass criteria:
1. It classified intent as "fix" — PASS/FAIL?
2. It assessed complexity as Level 1 (single agent, no DAG) — PASS/FAIL? If it created a DAG with tasks and teammates for this, that's a FAIL (over-engineering).
3. go.md no longer contains any ".tasks/" references (only ".godag/") — PASS/FAIL?
4. It didn't touch files outside commands/go.md — PASS/FAIL?

Give a verdict with one line per criterion.
```

---

## Test 2: Single-file refactor → should still be Level 1

**What it tests:** Can `/go` recognize that trimming a markdown file is a solo task, even though "refactor" sounds complex?

### CC1 prompt:
```
/go refactor skills/intent-router/SKILL.md — remove the "CRITICAL: Agent Type Policy" section (just add one line under 第一步 saying "Only use native Claude Code agent types: general-purpose, Bash, Explore, Plan"), compress the 典型 DAG 模式 examples into a single compact block, and tighten the DAG 生成规则 to remove redundancy. Target: under 180 lines total. Before you start, write your intent classification, complexity level, and reasoning to .godag/reasoning.md
```

### Expected behavior:
- Intent: `refactor`
- Level: 1
- No DAG — this is one file
- SKILL.md gets shorter, not longer
- The native-agent-only rule is preserved as a single line, not a section

### CC2 judge prompt:
```
You are judging whether GoDag's /go command behaved correctly. Read these files:
- .godag/reasoning.md (if exists)
- .godag/state.json (if exists — should NOT exist)
- skills/intent-router/SKILL.md

Test case: User asked to refactor SKILL.md to be more concise — remove a bloated section, compress examples, target under 180 lines.

Pass criteria:
1. Intent classified as "refactor" — PASS/FAIL?
2. Level 1 (no DAG, no teammates) — PASS/FAIL?
3. SKILL.md is now under 180 lines — PASS/FAIL? (run: wc -l skills/intent-router/SKILL.md)
4. The file still contains all 6 intent types (implement/fix/refactor/review/research/continue) — PASS/FAIL?
5. The file still contains DAG format JSON example — PASS/FAIL?
6. The file mentions native agent types only (no custom agents) somewhere concisely — PASS/FAIL?
7. No other files were modified — PASS/FAIL?

Give a verdict with one line per criterion.
```

---

## Test 3: Multi-file bug → should produce a DAG

**What it tests:** Does `/go` correctly identify a cross-file bug (dashboard HTML + go.md shutdown logic) as Level 2, produce a clean DAG with proper dependencies, and show the task graph?

### CC1 prompt:
```
/go fix the dashboard UX bug: when execution completes, the go.md shutdown logic kills the HTTP server, so the dashboard immediately shows a red "连接已断开" error banner on top of the green completion banner. The dashboard needs to distinguish between "server shut down cleanly after completion" vs "server crashed." This involves dashboard/index.html and commands/go.md. Before generating the DAG, write your intent classification, complexity level, and reasoning to .godag/reasoning.md. Then show me the plan but do NOT execute — I want to review first.
```

### Expected behavior:
- Intent: `fix`
- Level: 2 (two files, clear dependency)
- Generates a DAG with 2-3 tasks + integration task
- The DAG should show dashboard HTML changes and go.md shutdown logic changes
- Task edges make sense (can't test integration before both fixes land)
- Acceptance criteria are real commands, not vague descriptions
- Does NOT actually execute (user said don't execute)

### CC2 judge prompt:
```
You are judging whether GoDag's /go command behaved correctly. Read these files:
- .godag/reasoning.md
- .godag/state.json
- .godag/plan.md (if exists)

Test case: User reported a multi-file bug — dashboard shows disconnect error when /go cleanly shuts down the server after completion. Involves dashboard/index.html and commands/go.md.

Pass criteria:
1. Intent classified as "fix" — PASS/FAIL?
2. Level 2 or 3 (NOT Level 1 — this crosses multiple files) — PASS/FAIL?
3. DAG has 2+ tasks with at least one dependency edge — PASS/FAIL?
4. Tasks have scopes that reference actual files (dashboard/index.html, commands/go.md) — PASS/FAIL?
5. Acceptance criteria are runnable commands, not vague descriptions like "works correctly" — PASS/FAIL?
6. There's a final integration/review task that depends on the others — PASS/FAIL?
7. No tasks reference custom agent types (no infistack:anything) — PASS/FAIL?
8. It did NOT execute — only planned — PASS/FAIL?

Give a verdict with one line per criterion. Then give an overall assessment: is this a DAG you'd actually want to execute?
```

---

## Scoring

- Test 1 checks: **restraint** — does it avoid over-engineering?
- Test 2 checks: **single-file awareness** — refactor ≠ always complex
- Test 3 checks: **DAG quality** — real dependencies, real acceptance, real scopes

All 3 pass = `/go`'s intent router is working. Any fail = fix the SKILL.md or go.md logic accordingly.
