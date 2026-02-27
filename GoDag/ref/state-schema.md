# GoDag State Schema Reference

Read this on first state.json write or when you need to verify structure.

## .godag/ directory

```
.godag/
├── state.json              ← current run (live updates)
├── log.jsonl               ← current run event stream
├── plan.md                 ← current run plan snapshot
├── context/                ← MCP pre-fetched data + verdict files (reset per run)
├── tests/                  ← generated Playwright specs + config (reset per run)
├── .server.pid             ← dashboard process ID
├── .devserver.pid          ← dev server process ID (browser testing)
└── runs/
    └── 20250215-143000/    ← archived by state.json mtime
        ├── state.json
        ├── log.jsonl
        └── plan.md
```

First `/go` auto-creates: `mkdir -p .godag/context`

## state.json

```json
{
  "$schema": "godag/v2.1",
  "meta": {
    "project": "project name",
    "intent_type": "implement|fix|refactor|review|research",
    "level": 1|2|3,
    "strategy": "sequential|parallel_fanout|full_team|debate",
    "started_at": "ISO",
    "updated_at": "ISO",
    "status": "running|complete|failed",
    "user_prompt": "original input",
    "teammates_max": 5
  },
  "dag": {
    "tasks": [
      {
        "id": "T1",
        "title": "short description",
        "type": "implement|test|review|research|config",
        "scope": ["files/dirs"],
        "blocked_by": [],
        "acceptance": "verification command",
        "estimated_complexity": "small|medium|large",
        "agent_role": "role description",
        "hitl": false,
        "browser_acceptance": null
      }
    ],
    "edges": [["T1", "T2"]]
  },
  "tasks": {
    "T1": {
      "status": "pending|blocked|in_progress|done|awaiting_human|cancelled",
      "agent": null,
      "started_at": null,
      "completed_at": null,
      "duration_s": null,
      "acceptance_passed": null,
      "acceptance_output": null,
      "summary": null,
      "decisions": [],
      "issues": [],
      "retries": 0,
      "browser_retries": 0,
      "browser_verified": null,
      "files_changed": []
    }
  },
  "confidence": {
    "score": 0,
    "level": "low",
    "signals": {
      "acceptance_pass_rate": 0,
      "retry_count": 0,
      "lint_clean": null,
      "has_tests": null,
      "escalation_count": 0
    }
  },
  "dashboard": {
    "server_pid": null,
    "port": null,
    "url": null
  }
}
```

### Write timing

All writes go through `serve.js` state API. The orchestrator never writes state.json directly.

| Endpoint | Trigger | Server handles |
|----------|---------|----------------|
| `POST /state/init` | DAG confirmed | timestamps, task map, confidence init, session_start log |
| `POST /state/start` | Before spawning task | started_at, in_progress, task_started log |
| `POST /state/done` | Subagent returns | completed_at, duration_s, unblock downstream, confidence, task_done log |
| `POST /state/cancel` | User pivots | cancelled status, unblock downstream, task_cancelled log |
| `POST /state/retry` | Acceptance failed | retry counter, fresh started_at, task_retry log |
| `POST /state/replace` | Convergence pivot | replace DAG definition in-place, reset runtime, keep inbound edges, task_replaced log |
| `POST /state/append` | DAG mutation | new tasks + edges, auto pending/blocked, task_appended log |
| `POST /hitl` (approve) | User approves gate | status → pending, hitl_approved log |

## plan.md

Written once after DAG confirmed, never updated:

```markdown
# GoDag Plan: [project]

**Prompt:** [user input]
**Type:** [intent_type] | **Level:** [level] | **Strategy:** [strategy]
**Generated:** [ISO]

## Task Graph
[ASCII diagram]

## Tasks
### T1: [title]
- **Type:** [type] | **Complexity:** [complexity]
- **Scope:** [scope]
- **Acceptance:** `[command]`
- **Role:** [role]
```

## log.jsonl

One JSON line per event: `{"ts":"ISO","event":"type","data":{...}}`

Events: `session_start`, `plan_generated`, `user_confirmed`, `dashboard_started`, `task_started`, `task_done`, `task_retry`, `task_unblocked`, `task_cancelled`, `task_replaced`, `task_appended`, `file_changed`, `session_complete`, `dashboard_stopped`, `hitl_waiting`, `hitl_approved`, `browser_test_started`, `browser_test_done`, `browser_test_failed`, `smoke_test_done`

`browser_acceptance` field on dag tasks: see `skills/browser-test/SKILL.md` for full format. Value is `null` for tasks without browser testing, or an object with `{dev_server, base_url, tests}`.

## backlog.json

```json
{
  "items": [
    {
      "id": "backlog-001",
      "description": "project description",
      "created_at": "ISO",
      "status": "in_progress|done|pending",
      "state_file": ".godag/state.json"
    }
  ]
}
```
