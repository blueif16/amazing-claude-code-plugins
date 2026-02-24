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
3. 扫描当前项目的 CLAUDE.md 和目录结构获取上下文
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
   - spawn 新 teammates，在 spawn prompt 中注入前置 task 的 summary
5. 问用户是否启动 dashboard（如果之前的 server 还活着就跳过）

## DAG 确认交互

当生成了 Level 2-3 的 Task DAG 后，展示给用户的格式：

```
📋 执行计划：[项目名]

任务图：
  T1: [task title] [type] ──┐
  T2: [task title] [type]   ├── T4: [task title] [type]
  T3: [task title] [type] ──┘       │
                                     ↓
                               T5: [task title] [type]

预计 teammates: N | 预计复杂度: [低/中/高]

确认执行？(y/n/调整)
```

- **用户说 y / 好 / 开始 / 确认：** 立即开始执行
- **用户说 n / 不 / 取消：** 终止
- **用户提出调整：** 根据反馈修改 DAG 后再次确认

## Agent Assignment

When spawning subagents (Level 2) or teammates (Level 3), match each DAG task to a shipped agent profile. Use the default general-purpose agent for anything not listed.

| Task Signal | subagent_type | Why specialized |
|-------------|---------------|------------------|
| type=research + tech/docs/library comparison | `researcher` | Has Context7 MCP for official docs |
| type=research + community/market/trends/sentiment | `trend-scout` | Has Reddit MCP for practitioner experience |
| type=implement + UI/frontend/component/layout files | `frontend-dev` | Has frontend-design + interface-design skills, Context7 MCP |
| Everything else (backend, test, review, config) | _(default)_ | Spawn prompt from intent-router is sufficient |

When spawning a specialized agent:
```
Task({
  prompt: "[spawn prompt from intent-router]",
  subagent_type: "researcher"  // or trend-scout, frontend-dev
})
```

The agent's tools, skills, and mcpServers are defined in its agent file and applied automatically. Do not override them in the Task call.

If a required MCP server is not configured, the spawn will still succeed but the agent won't have that capability. Note this in the execution log.

## Dashboard 启动（Level 2-3）

DAG 确认后，如果复杂度 >= Level 2：

```
启动可视化 Dashboard？(y/n)
```

如果用户说 y：
1. `mkdir -p .godag`
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
6. 输出：`📊 Dashboard: http://localhost:4567`
7. 将 server 信息写入 state.json 的 `dashboard` 对象

如果用户说 n，正常执行，无 dashboard。

## 执行启动

确认后，按以下步骤启动：

### Level 1 执行
直接开始工作，无特殊流程。

### Level 2 执行（Subagents）
```
遍历 DAG 中的 task：
  - 对于没有 blocked_by 的 task：立即用 Task tool 创建并执行
  - 对于有 blocked_by 的 task：等待依赖完成后再创建
  - 每个 task 完成后：
    1. 从 subagent 返回值中提取 {"task_id","summary","files_changed"} JSON 块
    2. 由主 agent 执行 state.json 更新（见下方协议）
    3. 运行 acceptance 标准验证，将结果写入 acceptance_passed / acceptance_output
```

### Level 3 执行（Agent Teams）
```
1. 调用 spawnTeam 创建团队
2. 将 DAG 中的所有 task 添加到 shared task list（包含依赖关系）
3. 为每个并行工作流 spawn 一个 teammate（使用 intent-router 生成的 spawn prompt）
4. teammate 自动从 shared task list 中 claim unblocked 的 task
5. teammate 完成后通过 SendMessage 向 team lead 发送结构化 JSON 块
6. team lead 收到消息后执行 state.json 更新（见下方协议）
7. team lead 运行 acceptance 验证，更新结果，unblock 下游 task
```

### State Update Protocol

state.json 的唯一写入者是 orchestrator（Level 2 的主 agent / Level 3 的 team lead）。Teammate 永远不直接写 state.json。

当 orchestrator 收到 teammate 的完成报告后，执行以下原子更新：

```
1. 读取 .godag/state.json
2. 更新 tasks.TX：
   - status → "done"
   - summary → teammate 报告的 summary
   - files_changed → teammate 报告的 files_changed
   - completed_at → 当前 ISO 时间
   - duration_s → completed_at - started_at 的秒数
3. 运行 acceptance 命令，写入：
   - acceptance_passed → true/false
   - acceptance_output → 命令输出
4. 检查下游 task：将所有 blocked_by 包含 TX 且依赖已全部完成的 task 状态从 blocked → pending
5. 重新计算 confidence
6. 更新 meta.updated_at
7. 写回 .godag/state.json
8. 追加 task_done 事件到 log.jsonl
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
        "agent_role": "角色描述"
      }
    ],
    "edges": [["T1", "T2"]]
  },
  "tasks": {
    "T1": {
      "status": "pending|blocked|in_progress|done",
      "agent": null,
      "started_at": null,
      "completed_at": null,
      "duration_s": null,
      "acceptance_passed": null,
      "acceptance_output": null,
      "summary": null,
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
