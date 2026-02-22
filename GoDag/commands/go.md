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

1. 检查 `.tasks/backlog.json` 是否存在未完成的任务
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

1. 读取 `.tasks/state.json` 获取上次执行状态
2. 展示上次的进度："上次做到了 X，还剩 Y 和 Z"
3. 问用户 "继续？还是要调整计划？"

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

预计 teammates: N
预计复杂度: [低/中/高]

确认执行？(y/n/调整)
```

- **用户说 y / 好 / 开始 / 确认：** 立即开始执行
- **用户说 n / 不 / 取消：** 终止
- **用户提出调整：** 根据反馈修改 DAG 后再次确认

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

执行开始后，将状态写入项目目录：

**文件：`.tasks/state.json`**
```json
{
  "project": "项目名",
  "started_at": "ISO时间",
  "intent_type": "implement|fix|refactor|review|research",
  "level": 1|2|3,
  "dag": { ... },
  "task_status": {
    "T1": { "status": "done|in_progress|blocked|pending", "completed_at": "...", "agent": "角色名" }
  }
}
```

**文件：`.tasks/backlog.json`** （跨 session 持久化的待办）
```json
{
  "items": [
    {
      "id": "backlog-001",
      "description": "项目描述",
      "created_at": "ISO时间",
      "status": "in_progress|done|pending",
      "state_file": ".tasks/state.json"
    }
  ]
}
```

这些文件 git-tracked，不加到 .gitignore。这样即使 session 崩了，下次 `/go continue` 能恢复。