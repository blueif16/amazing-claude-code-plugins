# GoDag Execution Reference

Load this for Level 2-3 execution. The dashboard server (`serve.js`) owns all state transitions — the orchestrator posts intent via HTTP, never writes state.json.

`$PORT` = dashboard port (default 4567, stored in `state.json dashboard.port`).
`$URL` = `http://localhost:$PORT`

## State API

All endpoints accept `POST` with `Content-Type: application/json`.

| Endpoint | Body | Server handles |
|----------|------|----------------|
| `/state/init` | `{meta:{...}, dag:{...}}` | timestamps, task map (pending/blocked), confidence, `session_start` log |
| `/state/start` | `{task, agent}` | `started_at`, status→in_progress, `task_started` log |
| `/state/done` | `{task, summary, files_changed, decisions, issues, acceptance_passed, acceptance_output}` | `completed_at`, `duration_s`, unblock downstream (hitl-aware), confidence, completeness check, logs |
| `/state/cancel` | `{task}` or `{tasks:[...]}` | status→cancelled (pending/blocked only), unblock downstream, logs |
| `/state/retry` | `{task, reason}` | retry++, reset to in_progress with fresh `started_at`, log |
| `/state/replace` | `{task, title?, type?, scope?, acceptance?, agent_role?, hitl?}` | Replace DAG definition fields, reset runtime to pending, keep all inbound edges, log |
| `/state/append` | `{tasks:[{id, title, type, scope, blocked_by, acceptance, ...}]}` | Add nodes + edges, auto pending/blocked, session→running, logs |
| `/hitl` | `{action:"approve", task_id}` | status→pending, `hitl_approved` log |

Example flow:
```bash
curl -s -X POST $URL/state/start -d '{"task":"T1","agent":"godag:frontend-dev"}'
# ... spawn subagent, parse godag-result, run acceptance ...
curl -s -X POST $URL/state/done -d '{"task":"T1","summary":"...","files_changed":[...],"acceptance_passed":true}'
```

## Spawn Prompt Template

Generate this for each subagent (customized per task). Intent-router Step 4 builds the role/context, this is the structural wrapper:

```
你正在执行 GoDag 任务 {task_id}: {title}

## 任务信息
- 类型: {type} | 范围: {scope} | 验收: {acceptance}
- 角色: {agent_role}

## 上游上下文
{completed upstream task summaries from state.json}
{.godag/context/{task_id}-*.md files if any}

## 返回格式
在最终输出末尾包含：
\`\`\`godag-result
{"task_id":"{task_id}","summary":"做了什么","files_changed":["..."],"decisions":["..."],"issues":[]}
\`\`\`

如果需要外部文档：
\`\`\`json
{"task_id":"{task_id}","status":"needs_context","query":"需要什么"}
\`\`\`
```

## Orchestrator Loop (Level 2)

```
1. POST /state/init
2. For each unblocked task:
   a. POST /state/start
   b. Spawn subagent (Task tool, prompt above)
   c. Parse godag-result from output
   d. Run acceptance, capture stdout+stderr
   e. POST /state/done (with acceptance result)
   f. If failed + retries < 2: POST /state/retry, re-spawn with failure context
3. Repeat until no executable tasks remain
```

Parallel: spawn multiple unblocked tasks in one message. `/state/start` each before, `/state/done` each as they return.

HITL: server auto-sets `awaiting_human` on unblock. Orchestrator shows upstream summaries, waits for user or Dashboard approval, then spawns.

## Browser Verification (tasks with `browser_acceptance`)

Insert between step (d) and (e) of the Orchestrator Loop. Requires Playwright installed and `browser-test` skill loaded.

```
After CLI acceptance passes for a task with browser_acceptance:
  1. Read browser-test skill for script generation template
  2. Generate .godag/tests/{task_id}.spec.ts from browser_acceptance spec
     (generate playwright.config.ts once per run if absent)
  3. Start dev server if not running (check .godag/.devserver.pid)
  4. Run: cd .godag/tests && npx playwright test {task_id}.spec.ts --config=playwright.config.ts
     Orchestrator captures ONLY the exit code (0=pass, non-zero=fail)
  5. Spawn Summarizer subagent (Task tool, disposable):
     - Reads .godag/context/{task_id}-results.json + test-results/ screenshots
     - Writes .godag/context/{task_id}-verdict.md (max 30 lines)
     - Returns godag-result with {acceptance_passed: true/false}
  6. Orchestrator reads ONLY the godag-result (~30 tokens)
  7. If PASS: POST /state/done with browser_verified: true
  8. If FAIL + browser_retries < 2:
     - POST /state/retry with reason from summarizer's one-line summary
     - Re-spawn implementation subagent with FRESH context:
       "Previous summary: {original godag-result summary}.
        Browser test failed. Read .godag/context/{task_id}-verdict.md"
     - After re-implementation, go to step 2 (re-generate test, re-run)
  9. If FAIL + browser_retries >= 2:
     - POST /state/done with browser_verified: false, acceptance_passed: false
     - Issues array includes "browser verification failed after 2 retries"
```

IMPORTANT: The orchestrator NEVER reads results.json, screenshots, or verdict.md directly. All verbose content is processed by disposable subagents in their own context windows. The orchestrator only sees exit codes and godag-result summaries.

### Post-Execution Smoke Test

After all tasks complete, if any had `browser_acceptance`:
1. Re-run ALL browser tests as a regression check (single `npx playwright test` invocation)
2. Spawn one final summarizer for the combined results
3. If any regressed: surface in `/report` as risk, do NOT auto-retry

## DAG Mutation

When user changes direction mid-run, pick the minimal edit:

| Scenario | Operation | Why |
|----------|-----------|-----|
| Pivot at convergence node (multiple inbound edges) | **replace** + append downstream | 0 edge rewrites, all inbound edges preserved |
| Swap a leaf task for different work | **replace** | 1 node, inbound edge kept |
| Redo a failed task with new approach | **replace** | Same ID, fresh runtime |
| Drop unrelated pending tasks | **cancel** | Clean removal, downstream unblocks |
| Extend plan with new work | **append** | New nodes chain off existing |

Replace + append can combine: replace the pivot node, append new downstream in one mutation.

## MCP Mediation

Subagents cannot call MCP. Orchestrator mediates:
- **Pre-spawn:** call MCP, write to `.godag/context/{task_id}-{type}.md`, reference in spawn prompt, `/compact` after.
- **Mid-execution:** subagent returns `needs_context` → orchestrator calls MCP, writes file, resumes subagent.

## Level 3 (Agent Teams)

Same API, team lead calls endpoints. Teammates report via SendMessage with godag-result JSON. Team lead posts `/state/done` on receipt.
