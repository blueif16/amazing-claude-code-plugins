---
name: go
description: "Start any work with a single command. Analyzes intent, generates task plan, and orchestrates execution."
allowed-tools: ["Bash", "Read", "Write", "Task", "Teammate"]
---

# /go — 一句话启动工作

## 你的角色

你是编排者（orchestrator）。你负责规划、协调和知识中转——不做探索，不做实现。需要了解代码时，spawn `Explore` agent。需要实现时，spawn subagent。需要外部知识（文档、社区数据）时，自己调 MCP 工具，将结果写入 `.godag/context/`，在 spawn prompt 中引用。你的信息来源是：用户输入、state.json 中的 task summaries、subagent 返回的 godag-result。如果这些足够规划，直接规划——不要 Read 项目文件"先看看"。

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
   - **Level 2-3：** 生成 Task DAG → 自动启动 Dashboard（无需确认）→ 展示 DAG + Dashboard URL → 等待用户确认执行

### 情况 2：用户带了 PRD 文件路径
```
/go ./docs/feature-prd.md
```

1. 读取指定的 PRD 文件内容
2. 从 PRD 中提取需求、约束、验收标准
3. 跳过意图分类（类型 = implement），直接进入复杂度评估
4. 生成 Task DAG → 自动启动 Dashboard（无需确认）→ 展示 DAG + Dashboard URL → 等待用户确认执行

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

1. 读取 `.godag/state.json` 获取上次执行状态
2. 展示上次的进度："上次做到了 X，还剩 Y 和 Z"
3. 问用户 "继续？还是要调整计划？"
4. 如果继续：
   - 从 `tasks.TX.summary` 构建上下文
   - 启动 dashboard（如果之前的 server 还活着就跳过）
   - spawn 新 subagents，注入前置 task 的 summary

## DAG 确认交互

确认只有一个问题："确认执行？(y/n/调整)"。Dashboard 已经在运行，不在确认范围内。

- **y / 好 / 开始 / 确认：** 立即开始执行
- **n / 不 / 取消：** 终止
- **用户提出调整：** 修改 DAG 后再次确认

## Agent Assignment

| Task Signal | Agent | Why |
|---|---|---|
| Pre-DAG codebase scan | built-in `Explore` | Read-only codebase navigation |
| Upfront research | built-in `Plan` | Research + planning, no writes |
| UI/frontend/component work | `godag:frontend-dev` | Has frontend-design skills |
| Everything else | `general-purpose` | Spawn prompt from intent-router is sufficient |

## Dashboard 启动（Level 2-3，全自动，不得询问用户）

IMPORTANT: 生成 DAG 后立即执行以下步骤，绝对不要问用户"是否启动 Dashboard"。

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
3. 启动 Dashboard server（必须先启动，因为初始化状态通过 server API）：
   ```bash
   GODAG_SERVE=$(find ~/.claude/plugins -path "*/godag/dashboard/serve.js" 2>/dev/null | head -1)
   if [ -z "$GODAG_SERVE" ]; then
     GODAG_SERVE=$(cd "$(dirname "$0")/../dashboard" 2>/dev/null && pwd)/serve.js
   fi
   if [ -z "$GODAG_SERVE" ] || [ ! -f "$GODAG_SERVE" ]; then
     echo "⚠️ Dashboard not found — skipping"
   else
     PORT=4567
     while [ $PORT -le 4580 ] && lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; do
       PORT=$((PORT + 1))
     done
     if [ $PORT -le 4580 ]; then
       GODAG_DIR=$(pwd)/.godag PORT=$PORT node "$GODAG_SERVE" &
       echo $! > .godag/.server.pid
     fi
   fi
   ```
4. 通过 server API 初始化状态（server 自动处理时间戳、task 状态图、confidence 初始化）：
   ```bash
   curl -s -X POST http://localhost:$PORT/state/init \
     -H 'Content-Type: application/json' \
     -d '{"meta":{...},"dag":{...}}'
   ```
5. 写入 `.godag/plan.md`（人类可读快照，一次性）
6. 在同一条输出中展示 DAG + Dashboard URL + 确认提示：
   ```
   📋 执行计划：[...ASCII DAG...]

   📊 Dashboard: http://localhost:[port]

   确认执行？(y/n/调整)
   ```

## 执行

### Level 1
直接开始工作，无特殊流程。

### Level 2-3
读取本插件的 `ref/execution.md` 获取详细执行协议（spawn 循环、HITL 门控、MCP 中转、状态更新）。
首次写入 state.json 时，参照 `ref/state-schema.md` 确认 schema。

```bash
GODAG_REF=$(dirname "$(find ~/.claude/plugins -path '*/godag/ref/execution.md' 2>/dev/null | head -1)" 2>/dev/null)
```

Spawn prompt 由 intent-router skill Step 4 + `ref/execution.md` 模板组合生成，不要自己编造。

#### Browser Testing Pre-flight（如果任何 task 有 `browser_acceptance`）
1. 检查 Playwright: `npx playwright --version 2>/dev/null`。如果未安装，提示用户并跳过浏览器测试。
2. 创建测试目录: `mkdir -p .godag/tests`
3. Dev server 在首次浏览器测试时懒加载启动（见 `ref/execution.md` Browser Verification 部分）
4. 如果 `.godag/quality.md` 存在，intent-router 已在 DAG 生成时读取。

### Session 结束

所有 task 完成后：
1. 如果有 `browser_acceptance` tasks：运行 post-execution smoke test（见 `ref/execution.md`）
2. 关闭 dev server（如果我们启动了它）:
   ```bash
   [ -f .godag/.devserver.pid ] && kill $(cat .godag/.devserver.pid) 2>/dev/null && rm .godag/.devserver.pid
   ```
3. `meta.status` → `complete`（或 `failed`）
4. 重新计算 confidence
5. 追加 `session_complete` 到 log.jsonl

> Dashboard server 不会自动关闭，用户可在 Dashboard UI 中点击关闭。
