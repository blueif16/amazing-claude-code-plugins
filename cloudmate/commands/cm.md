---
name: cm
description: "Start, check, or continue any work. Analyzes intent, plans tasks, and orchestrates execution."
allowed-tools: ["Bash", "Read", "Write", "Task", "Teammate"]
---

# /cm — Single Entry Point

## Routing

Parse what follows `/cm`:

| Input | Action |
|-------|--------|
| `/cm <natural language>` | Plan + execute a task |
| `/cm <path-to-file.md>` | Read file as PRD, plan from it |
| `/cm status` | Show current plan status |
| `/cm continue` | Resume from `.tasks/plan.md` |
| `/cm` (nothing) | Ask "What do you want to do?" |

## Flow: /cm \<description\>

1. Load the `cloudmate` skill
2. Classify intent (Step 1)
3. If codebase context needed: spawn an `Explore` subagent with instructions to write detailed findings to `.tasks/explore-findings.md` (file paths, interfaces, patterns, gotchas) AND return a compact summary. Do NOT read files yourself.
4. Assess complexity (Step 2)
5. **Level 1:** Just do the work. No DAG needed.
6. **Level 2+:** Read `references/operational-efficiency.md`. Generate DAG (Step 3). In each spawn prompt, reference `.tasks/explore-findings.md` for codebase context instead of pasting its contents. Display plan with ASCII tree. Ask `Go? (y / adjust / n)`
   - `y` / `go` / `ok` → Execute (Step 4). Write plan to `$MAIN_DIR/.tasks/$BRANCH.md` (see SKILL.md Step 5 for format).
   - `n` / `cancel` → Abort.
   - Anything else → Treat as adjustment. Revise plan. Ask again.

## Flow: /cm \<path\>

1. Read the file at path
2. Extract requirements, constraints, acceptance criteria from it
3. Skip intent classification — type = `implement`
4. Continue from complexity assessment (Step 2) onward

## Flow: /cm status

1. Find main repo: `MAIN_DIR=$(git worktree list | head -1 | awk '{print $1}')`
2. List all `$MAIN_DIR/.tasks/*.md` files
3. If none: "No active plans. Run `/cm <task>` to start."
4. For each plan file, extract header + task statuses and show overview:
   ```
   📊 CloudMate — [N] active

   ① auth-refactor [L3] 2/5 ██░░░ 40%
     ✅ T1  ✅ T2  🔄 T3  ⏳ T4  ⏳ T5

   ② add-tests [L2] 1/3 █░░░░ 33%
     ✅ T1  🔄 T2  ⏳ T3
   ```
5. If called from within a worktree, highlight that worktree's plan and show its full ASCII tree from the plan file.

## Flow: /cm continue

1. Find main repo: `MAIN_DIR=$(git worktree list | head -1 | awk '{print $1}')`
2. Get current branch: `BRANCH=$(git branch --show-current)`
3. Look for `$MAIN_DIR/.tasks/$BRANCH.md`
4. If not found: list all plans in `.tasks/`, ask user which to continue (or start new)
5. If found: read task statuses from the plan file
6. Display: "Last run: [name]. Done: T1, T2. Remaining: T3, T4."
7. Ask: "Continue? (y / adjust / new)"
   - `y` → Rebuild context from completed task summaries in the plan, resume at next unblocked task
   - `adjust` → Show current plan, let user modify, then continue
   - `new` → Route to bare `/cm`

## Spawn Prompt Convention

When spawning subagents (L2) or generating teammate prompts (L3), always include:

1. **Role and task:** what they are and what they're doing
2. **Scope:** exact files/dirs they may modify, and what they must not touch
3. **Acceptance:** the verification command to run when done
4. **Upstream context:** summaries from completed tasks they depend on
5. **Logging prefix:** `[wt-BRANCH]` where BRANCH = `git branch --show-current`
6. **Commit convention:** `feat:`, `fix:`, `refactor:`, `test:` as appropriate
7. **CLAUDE.md compliance:** "Follow all rules in the project's CLAUDE.md"
8. **API verification:** "Before writing code that uses any library/framework beyond basic builtins, use Context7 (resolve-library-id → get-library-docs) to verify current patterns. Write a brief cheatsheet to the path specified in your task. Do not guess — if you are not absolutely certain, look it up."
9. **Context hygiene:** "Write code directly to files. Do not draft code in your response then also write it to a file. Use cp/mv for file operations, not read-then-write."
10. **Findings handoff:** "Write detailed discoveries (file paths, interface shapes, patterns, gotchas) to the findings file specified in your task. Return only a compact summary to the orchestrator."

## Merge Guidance

After all tasks complete (or when showing status), remind the user of merge strategy based on risk tiers:

- **All routine:** "Ready to merge. `Ctrl+Shift+M` (Merge & Close) when satisfied."
- **Has careful tasks:** "Review the diff before merging. `Ctrl+Shift+K` (Merge & Keep) recommended in case fixes needed."
- **Has critical tasks:** "Consider a review pass before merging. You can ask me to review the changes."

## Session End

When all tasks done:
1. Update the plan file (`$MAIN_DIR/.tasks/$BRANCH.md`):
   - Update all task statuses (both mermaid styles and task detail sections)
   - Add summary section:
   ```markdown
   ## Summary
   Completed: [n]/[n] | Duration: ~[time]
   Files changed: [list]
   All verifications: [passed/failed]
   ```
2. Update Status line in header to `complete` (or `failed`)
3. If L3: clean up Agent Teams (`Teammate({ operation: "cleanup" })`)
4. Report completion to user with merge guidance
