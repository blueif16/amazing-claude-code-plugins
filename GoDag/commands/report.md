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
4. 生成以下格式的报告

## 报告格式

```
═══════════════════════════════════════
📊 GoDag 执行报告
═══════════════════════════════════════

项目: [项目名]
类型: [implement/fix/refactor/review/research]
启动: [时间]
耗时: [时长]

─── 任务状态 ──────────────────────────

  ✅ T1: [task title]
     完成时间: Xm Ys
     验证: ✅ 通过 (验证详情)

  🔄 T2: [task title]
     进行中: 当前进度描述
     Agent: [角色名]

  ⏳ T3: [task title]
     状态: 等待 [依赖] 完成
     阻塞: [阻塞的 task]

─── 总览 ──────────────────────────────

  完成: X/Y (百分比%)
  进行中: X/Y
  等待中: X/Y

─── 置信度评估 ────────────────────────

  整体置信度: 🟢/🟡/🔴 高/中/低

  依据:
  - [具体信号]

─── 风险提示 ──────────────────────────

  [如果有风险] ⚠️ 风险描述
  [如果没有风险] 无异常

═══════════════════════════════════════
```

## 置信度计算逻辑

置信度基于以下信号的加权组合：

| 信号 | 权重 | 评分方法 |
|------|------|---------|
| 验证通过率 | 40% | 通过 acceptance 标准的 task 比例 |
| 重试次数 | 20% | 0 次重试 = 满分，3+ 次 = 0 分 |
| 类型检查/Lint | 15% | 无 error = 满分 |
| 测试覆盖 | 15% | 新增代码是否有对应测试 |
| Agent 求助次数 | 10% | 0 次 = 满分，escalation = 扣分 |

综合评分：
- 80-100%: 🟢 高
- 60-79%:  🟡 中
- 0-59%:   🔴 低

## 快速报告

如果用户只是想快速看一眼：

```
/report short
```

输出简化版：
```
📊 [项目名]: X/Y done (百分比%) | 🟢 高置信度
```

## Dashboard 提示

如果 `.godag/state.json` 中 `dashboard.server_pid` 对应的进程还活着，在报告末尾追加：

```
📊 Dashboard running: http://localhost:[port]
```

## 启动 Dashboard 回顾

```
/report --dashboard
```

如果当前没有运行 dashboard server，启动一个并输出 URL：
1. 检查 `.godag/state.json` 是否存在
2. 使用与 `/go` 相同的 serve.js 解析逻辑查找 dashboard：
   ```bash
   GODAG_SERVE=$(find ~/.claude/plugins -path "*/godag/dashboard/serve.js" 2>/dev/null | head -1)
   ```
3. 启动 HTTP server（同 `/go` 的启动逻辑，端口 4567-4580 自动探测）
4. 输出：`📊 Dashboard: http://localhost:[port]`

用于执行已完成后，用户想回顾可视化结果的场景。
