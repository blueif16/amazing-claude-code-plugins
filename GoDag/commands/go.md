---
name: go
description: "Start any work with a single command. Analyzes intent, generates task plan, and orchestrates execution."
allowed-tools: ["Bash", "Read", "Write", "Task", "Teammate"]
---

# /go — 一句话启动工作

## 执行流程

### 情况 1：用户带了描述
```
/go 给登录页加上 Google OAuth
```

1. 读取 intent-router skill
2. 对用户输入执行意图分类（第一步）
3. 用内置 `Explore` agent 扫描项目的 CLAUDE.md 和目录结构获取上下文
4. 执行复杂度评估（第二步）
5. 根据复杂度决定执行路径：
   - **Level 1：** 直接开始执行，不需要确认
   - **Level 2-3：** 生成 Task DAG，展示给用户，等待确认

### 情况 2：用户带了 PRD 文件路径
```
/go ./docs/feature-prd.md
```

1. 读取指定的 PRD 文件内容
2. 从 PRD 中提取需求、约束、验收标准
3. 跳过意图分类（类型 = implement），直接进入复杂度评估
4. 生成 Task DAG，展示给用户，等待确认

### 情况 3：用户不带参数
```
/go
```

1. 检查 `.godag/backlog.json` 是否存在未完成的任务
2. 如果有：展示未完成任务列表，问用户 "继续哪个？还是做新的？"
3. 如果没有：问用户 "今天想做什么？"

### 情况 4：继续上次的工作
```
/go continue
```
或
```
/go 继续
```

1. 读取 `.godag/state.json` 获取上次执行状态
2. 展示上次的进度："上次做到了 X，还剩 Y 和 Z"
3. 问用户 "继续？还是要调整计划？"
4. 如果继续：
   - 检查哪些 task 还没做完
   - 对已完成的 task，从 `tasks.TX.summary` 构建上下文
   - 启动 dashboard（如果之前的 server 还活着就跳过），输出 URL
   - spawn 新 teammates，在 spawn prompt 中注入前置 task 的 summary

## DAG 确认交互

用户确认时：
- **用户说 y / 好 / 开始 / 确认：** 立即开始执行
- **用户说 n / 不 / 取消：** 终止
- **用户提出调整：** 根据反馈修改 DAG 后再次确认（包括从 Dashboard 调整的 HITL 门控）

## Agent Assignment

Match each DAG task to an agent. Use built-in agents for exploration/planning, `frontend-dev` for UI work, and `general-purpose` for everything else.

| Task Signal | Agent | Why |
|---|---|---|
| Pre-DAG codebase scan (step 3) | built-in `Explore` | Read-only codebase navigation, no writes |
| Complex task needing upfront research | built-in `Plan` | Research + planning without modifying files |
| type=implement + UI/frontend/component/layout | `frontend-dev` | Has frontend-design + interface-design skills |
| Everything else | `general-purpose` | Spawn prompt from intent-router is sufficient |

## MCP Mediation

Custom subagents **cannot call MCP tools** (known Claude Code bug, open since Dec 2025). The main thread mediates all MCP access.

### Pre-spawn context (optional, not aggressive)

If a DAG task clearly needs external data (docs, community sentiment), the orchestrator MAY pre-fetch before spawning:

1. Load the relevant recon skill (e.g. `market-recon` for community research)
2. Call MCP tools per the skill's guidance
3. Write results to `.godag/context/{task_id}-{type}.md`
4. Reference the file in the subagent's spawn prompt
5. `/compact` to shed MCP results from main thread context

Do NOT pre-fetch speculatively. Only fetch when the DAG task explicitly requires external data.

### Mid-execution MCP requests

**Level 2 (subagents):** Subagent finishes early with a context request:
```json
{"task_id":"T2","status":"needs_context","query":"What is the current API for NextAuth v5 session handling?"}
```
Orchestrator receives this, calls MCP, writes to `.godag/context/{task_id}-followup.md`, then resumes the subagent using the `resume` parameter with the returned agent ID.

**Level 3 (Agent Teams):** Teammate sends a `SendMessage` to team lead:
```
[MCP_REQUEST] I need docs on Redis Cluster failover behavior
```
Team lead calls MCP, writes to `.godag/context/{task_id}-followup.md`, replies via `SendMessage`:
```
Read .godag/context/{task_id}-followup.md — contains the Redis Cluster docs you requested.
```

## Dashboard 启动（Level 2-3，DAG 确认前）

生成 DAG 后、展示确认前，自动启动 Dashboard：

1. `mkdir -p .godag/context`
2. 归档上一次运行（如果 state.json 已存在）：
   ```bash
   if [ -f .godag/state.json ]; then
     ts=$(date -r .godag/state.json +%Y%m%d-%H%M%S)
     mkdir -p ".godag/runs/$ts"
     mv .godag/state.json ".godag/runs/$ts/"
     [ -f .godag/log.jsonl ] && mv .godag/log.jsonl ".godag/runs/$ts/"
     [ -f .godag/plan.md ] && mv .godag/plan.md ".godag/runs/$ts/"
   fi
   ```
3. 写入 `.godag/state.json`（初始状态，所有 task pending）
4. 写入 `.godag/plan.md`（人类可读计划快照）
5. 启动 Dashboard server：
   ```bash
   GODAG_DIR=$(pwd)/.godag PORT=4567 node <plugin_dir>/dashboard/serve.js &
   echo $! > .godag/.server.pid
   ```
   - `<plugin_dir>` 是插件安装目录（包含 dashboard/dist/ 构建产物）
   - 默认端口 4567，如果被占用尝试 4568-4580
   - 超过范围跳过 dashboard，不影响执行
6. 将 server 信息写入 state.json 的 `dashboard` 对象

然后展示 DAG 确认，在输出中包含 Dashboard URL：

```
📋 执行计划：[...现有 ASCII DAG...]

📊 Dashboard: http://localhost:4567
确认执行？(y/n/调整) — 可通过 Dashboard 点击节点调整门控位置
```

用户可以在确认前打开 Dashboard 调整 HITL 门控，也可以直接在终端确认。Dashboard 只是可选的可视化，不是必须打开的。

## 执行启动

确认后，按以下步骤启动：

### Level 1 执行
直接开始工作，无特殊流程。

### Level 2 执行（Subagents）

Level 2 使用 Task tool spawn subagent。因为 subagent 运行期间主线程阻塞，需要在 spawn 前后做完整的状态记录。

#### 每个 Task 的执行循环：

```
对于每个可执行的 task TX：

1. PRE-SPAWN（主线程写入）：
   - 读取 state.json
   - tasks.TX.status → "in_progress"
   - tasks.TX.started_at → 当前 ISO 时间
   - tasks.TX.agent → 选定的 agent 类型
   - 写回 state.json
   - 追加 {"event":"task_started","data":{"task":"TX","agent":"..."}} 到 log.jsonl

2. SPAWN（Task tool 调用）：
   - spawn prompt 中注入结构化返回要求（见下方模板）
   - 如果有前置 task 的 summary，注入到 spawn prompt 作为上下文
   - 如果有 .godag/context/{task_id}-*.md 文件，在 prompt 中引用

3. POST-RETURN（主线程处理返回值）：
   - 从返回值中提取 JSON 块（见下方格式）
   - 读取 state.json
   - tasks.TX.status → "done"
   - tasks.TX.completed_at → 当前 ISO 时间
   - tasks.TX.duration_s → completed_at - started_at 秒数
   - tasks.TX.summary → 提取的 summary
   - tasks.TX.files_changed → 提取的 files_changed
   - 运行 acceptance 命令，捕获完整 stdout+stderr：
     - tasks.TX.acceptance_passed → true/false
     - tasks.TX.acceptance_output → 命令完整输出（不截断）
   - 如果 acceptance 失败且 retries < 2：
     - tasks.TX.retries += 1
     - tasks.TX.status → "in_progress"
     - 追加 task_retry 事件到 log.jsonl
     - 重新 spawn，prompt 中注入失败原因和 acceptance_output
   - 检查下游 task，unblock 已满足依赖的 task：
     - hitl: true → awaiting_human
     - 否则 → pending
   - 为每个 files_changed 追加 file_changed 事件到 log.jsonl
   - 追加 task_done 事件到 log.jsonl（包含 summary、duration_s、acceptance 结果）
   - 重新计算 confidence
   - 写回 state.json
```

#### Subagent Spawn Prompt 模板：

```
你正在执行 GoDag 任务 {task_id}: {title}

## 任务信息
- 类型: {type}
- 范围: {scope}
- 验收标准: {acceptance}
- 角色: {agent_role}

## 前置上下文
{前置 task 的 summary，如果有的话}
{.godag/context/ 中的相关文件，如果有的话}

## 执行要求
1. 完成任务后，将推理过程和关键决策写入 .godag/context/{task_id}-log.md
2. 在你的最终输出末尾，必须包含以下 JSON 块（用 ```godag-result 包裹）：

```godag-result
{
  "task_id": "{task_id}",
  "summary": "一句话总结做了什么",
  "files_changed": ["修改的文件路径列表"],
  "decisions": ["关键决策及原因"],
  "issues": ["遇到的问题，如果没有则为空数组"]
}
```
```

#### 并行 Spawn

无依赖的 task 可以并行 spawn（多个 Task tool 调用在同一消息中）。每个返回时立即执行 POST-RETURN 流程更新 state.json，Dashboard 能看到逐个完成。

#### HITL 门控

如果即将 spawn 的 task 有 hitl: true：
1. 将 tasks.TX.status 设为 "awaiting_human"
2. 输出上游 task 的 summary，问用户是否继续
3. Dashboard 也会显示门控状态，用户可从 Dashboard 或终端批准
4. 用户批准后（终端确认或 Dashboard POST /hitl approve），继续 spawn

### Level 3 执行（Agent Teams）
```
1. 调用 spawnTeam 创建团队
2. 将 DAG 中的所有 task 添加到 shared task list（包含依赖关系）
3. 为每个并行工作流 spawn 一个 teammate（使用 intent-router 生成的 spawn prompt）
4. teammate 自动从 shared task list 中 claim unblocked 的 task
5. HITL 门控：当 hitl: true 的 task 被 unblock 后，team lead 将其状态设为 "awaiting_human"，
   展示上游结果，等待用户批准后再允许 teammate claim
6. teammate 完成后通过 SendMessage 向 team lead 发送结构化 JSON 块
7. team lead 收到消息后执行 state.json 更新（见下方协议）
8. team lead 运行 acceptance 验证，更新结果，unblock 下游 task
```

### State Update Protocol

state.json 的唯一写入者是 orchestrator（Level 2 的主 agent / Level 3 的 team lead）。Teammate / Subagent 永远不直接写 state.json。

**Level 2：** 主 agent 在 spawn 前写 in_progress，返回后解析 `godag-result` JSON 块并写入完整结果。

**Level 3：** team lead 收到 teammate 的 SendMessage 后执行更新。

两者共用以下原子更新流程（task 完成时）：

```
1. 读取 .godag/state.json
2. 更新 tasks.TX：
   - status → "done"
   - summary → 报告的 summary
   - files_changed → 报告的 files_changed
   - decisions → 报告的 decisions（Level 2 从 godag-result 提取，Level 3 从 SendMessage 提取）
   - issues → 报告的 issues
   - completed_at → 当前 ISO 时间
   - duration_s → completed_at - started_at 的秒数
3. 运行 acceptance 命令，捕获完整输出：
   - acceptance_passed → true/false
   - acceptance_output → 命令完整 stdout+stderr（不截断，用于调试）
4. 为每个 file_changed 追加 file_changed 事件到 log.jsonl
5. 追加 task_done 事件到 log.jsonl：
   {"event":"task_done","data":{"task":"TX","duration_s":N,"acceptance":"pass|fail","summary":"..."}}
6. 检查下游 task：将所有 blocked_by 包含 TX 且依赖已全部完成的 task：
   - 如果该 task 有 hitl: true → awaiting_human
   - 否则 → pending
7. 重新计算 confidence
8. 更新 meta.updated_at
9. 写回 .godag/state.json
```

这保证了：
- 无并发写入冲突（单一写入者）
- state.json 始终一致（原子读-改-写）
- teammate 无需知道 state.json 的内部结构

## 状态持久化

### .godag/ 目录

首次 `/go` 时自动创建：`mkdir -p .godag`

### 运行历史归档

每次新 `/go`（非 continue）启动时，如果 `.godag/state.json` 已存在，自动归档到 `.godag/runs/{timestamp}/`：

```
.godag/
├── state.json              ← 当前运行（实时更新）
├── log.jsonl               ← 当前运行事件流
├── plan.md                 ← 当前运行计划
├── context/                ← MCP 预取数据（每次运行重置）
├── runs/
│   ├── 20250215-143000/    ← 按 state.json 修改时间命名
│   │   ├── state.json      ← 该次运行的最终状态
│   │   ├── log.jsonl       ← 该次运行的完整事件流
│   │   └── plan.md         ← 该次运行的计划快照
│   └── 20250216-091500/
│       ├── state.json
│       ├── log.jsonl
│       └── plan.md
```

归档数据用于：
- 调试：回溯任务失败原因、查看 acceptance_output
- 优化：对比不同运行的 confidence、duration、retry 数据
- Dashboard 可通过 History 下拉加载历史运行数据

### state.json 写入时机

所有写入均由 orchestrator（Level 2 主 agent / Level 3 team lead）执行。Teammate 不写 state.json。

| 时机 | 写入者 | 写入内容 |
|------|--------|---------|
| DAG 确认后 | orchestrator | 完整的初始 state（meta + dag + tasks 全 pending + confidence 初始值）|
| task 开始时 | orchestrator | tasks.TX.status → in_progress, started_at |
| task 完成时 | orchestrator | 从 teammate 报告中提取 summary, files_changed；运行 acceptance 写入结果；更新 confidence |
| HITL 门控触发 | orchestrator | tasks.TX.status → awaiting_human；追加 hitl_waiting 到 log.jsonl |
| HITL 批准 | orchestrator/dashboard | tasks.TX.status → pending；追加 hitl_approved 到 log.jsonl |
| session 结束时 | orchestrator | meta.status → complete/failed |

### state.json 结构

```json
{
  "$schema": "godag/v2.1",
  "meta": {
    "project": "项目名",
    "intent_type": "implement|fix|refactor|review|research",
    "level": 1|2|3,
    "strategy": "sequential|parallel_fanout|full_team|debate",
    "started_at": "ISO时间",
    "updated_at": "ISO时间",
    "status": "running|complete|failed",
    "user_prompt": "用户原始输入",
    "teammates_max": 5
  },
  "dag": {
    "tasks": [
      {
        "id": "T1",
        "title": "简短描述",
        "type": "implement|test|review|research|config",
        "scope": ["文件/目录"],
        "blocked_by": [],
        "acceptance": "验证命令",
        "estimated_complexity": "small|medium|large",
        "agent_role": "角色描述",
        "hitl": false
      }
    ],
    "edges": [["T1", "T2"]]
  },
  "tasks": {
    "T1": {
      "status": "pending|blocked|in_progress|done|awaiting_human",
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

### plan.md

DAG 确认后、执行开始前写入一次，之后不更新。格式：

```markdown
# GoDag Plan: [project]

**Prompt:** [用户原始输入]
**Type:** [intent_type] | **Level:** [level] | **Strategy:** [strategy]
**Generated:** [ISO时间]

## Task Graph
[ASCII 图]

## Tasks
### T1: [title]
- **Type:** [type] | **Complexity:** [complexity]
- **Scope:** [scope]
- **Acceptance:** `[acceptance]`
- **Role:** [agent_role]
```

### log.jsonl

每个事件发生时追加一行 JSON。事件类型：
- `session_start`, `plan_generated`, `user_confirmed`, `dashboard_started`
- `task_started`, `task_done`, `task_retry`, `task_unblocked`
- `file_changed`, `session_complete`, `dashboard_stopped`
- `hitl_waiting`, `hitl_approved`

格式：`{"ts":"ISO时间","event":"事件类型","data":{...}}`

### backlog.json

跨 session 待办列表，结构不变：

```json
{
  "items": [
    {
      "id": "backlog-001",
      "description": "项目描述",
      "created_at": "ISO时间",
      "status": "in_progress|done|pending",
      "state_file": ".godag/state.json"
    }
  ]
}
```

### Session 结束

所有 task 完成后：
1. 更新 `meta.status` 为 `complete`（或 `failed`）
2. 重新计算 confidence 写入
3. 追加 `session_complete` 到 log.jsonl

> Dashboard server 不会自动关闭，用户可在 Dashboard UI 中点击关闭按钮手动停止。
