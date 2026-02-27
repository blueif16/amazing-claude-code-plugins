---
name: report
description: "Generate a structured progress report for the current or most recent execution."
allowed-tools: ["Bash", "Read", "Task", "Teammate"]
---

# /report — 结构化进度报告

## 执行逻辑

1. 读取 `.godag/state.json`
2. 如果 Agent Teams 正在运行：查询 shared task list 获取实时状态
3. 如果已完成或 session 已结束：从 state.json 读取最终状态
4. 生成报告

## 报告格式

```
═══════════════════════════════════════
📊 GoDag 执行报告
═══════════════════════════════════════

项目: [meta.project]
类型: [meta.intent_type]
启动: [meta.started_at]
耗时: [now - meta.started_at]

─── 任务状态 ──────────────────────────

  ✅ T1: [title]
     完成: [duration_s] | 验证: ✅/❌ [acceptance_output 摘要]

  🔄 T2: [title]
     进行中 | Agent: [agent]

  ⏳ T3: [title]
     等待: [blocked_by 中未完成的 task]

  ⊘ T4: [title]
     已取消

─── 总览 ──────────────────────────────

  完成: X/Y (%) | 进行中: X | 等待中: X | 已取消: X

─── 置信度 ────────────────────────────

  [confidence.level emoji] [confidence.score]%
  依据: [confidence.signals 中非 null 的信号]

─── 风险 ──────────────────────────────

  [超时/重试多/acceptance 失败的 task] 或 "无异常"

═══════════════════════════════════════
```

## 置信度

由 serve.js 自动计算，存储在 `state.json confidence` 中。直接读取：
- 🟢 high (80+) | 🟡 medium (60-79) | 🔴 low (<60)
- 信号明细在 `confidence.signals`

## 快速报告

```
/report short
```

输出：`📊 [项目名]: X/Y done (%) | 🟢 高置信度`

## Dashboard 提示

如果 `dashboard.server_pid` 进程还活着，末尾追加：`📊 Dashboard: http://localhost:[port]`

## 启动 Dashboard 回顾

```
/report --dashboard
```

如果 dashboard 未运行，用 `/go` 相同的 serve.js 查找逻辑启动：
```bash
GODAG_SERVE=$(find ~/.claude/plugins -path "*/godag/dashboard/serve.js" 2>/dev/null | head -1)
```
端口 4567-4580 自动探测。
