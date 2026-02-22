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

## Dashboard 启动（Level 2-3）

DAG 确认后，如果复杂度 >= Level 2：

```
启动可视化 Dashboard？(y/n)
```

如果用户说 y：
1. `mkdir -p .godag`
2. 写入 `.godag/state.json`（初始状态，所有 task pending）
3. 写入 `.godag/plan.md`（人类可读计划快照）
4. 复制插件的 `dashboard/index.html` → `.godag/dashboard.html`
5. 启动 HTTP server：
   ```bash
   cd .godag && python3 -m http.server 4567 --bind 127.0.0.1 &
   echo $! > .godag/.server.pid
   ```
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
  - 每个 task 完成后：运行 acceptance 标准验证
```

### Level 3 执行（Agent Teams）
```
1. 调用 spawnTeam 创建团队
2. 将 DAG 中的所有 task 添加到 shared task list（包含依赖关系）
3. 为每个并行工作流 spawn 一个 teammate（使用 intent-router 生成的 spawn prompt）
4. teammate 自动从 shared task list 中 claim unblocked 的 task
5. task 完成后自动 unblock 下游 task
```

## 状态持久化

### .godag/ 目录

首次 `/go` 时自动创建：`mkdir -p .godag`

### state.json 写入时机

| 时机 | 写入内容 |
|------|---------|
| DAG 确认后 | 完整的初始 state（meta + dag + tasks 全 pending + confidence 初始值）|
| 每个 task 状态变更时 | 更新对应 tasks.TX 和 confidence |
| task 完成时 | 更新 summary, acceptance_output, files_changed, duration_s |
| session 结束时 | 更新 meta.status 为 complete/failed，关闭 dashboard server |

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
4. 关闭 dashboard server：`kill $(cat .godag/.server.pid) 2>/dev/null && rm -f .godag/.server.pid`
5. 追加 `dashboard_stopped` 到 log.jsonl
