# Intent Classification

**User Prompt:** fix the dashboard UX bug: when execution completes, the go.md shutdown logic kills the HTTP server, so the dashboard immediately shows a red "连接已断开" error banner on top of the green completion banner.

## Intent

- **Type:** fix
- **Reasoning:** 这是一个明确的 UX bug 修复。用户描述了一个具体的竞态条件：session 结束时 go.md 的关闭逻辑 kill 掉 HTTP server，导致 dashboard 的 poll 失败，触发红色 "连接已断开" banner 覆盖在绿色 "执行完成" banner 之上。

## Complexity

- **Level:** 1 (低)
- **Reasoning:**
  - 只涉及 2 个文件：`dashboard/index.html` 和 `commands/go.md`
  - 根因清晰：dashboard 的 `poll()` catch 块无法区分 "server 正常关闭" 和 "server 崩溃"
  - 修复方案直接：dashboard 侧追踪 `sessionEnded` 状态，go.md 侧在 kill 前加延迟
  - 无架构变更，无新依赖，无跨模块影响

## Root Cause Analysis

**时序问题：**
1. go.md 写入 `state.json`（status=complete）
2. go.md **立即** kill HTTP server
3. dashboard 的下一次 poll 失败（server 已死）
4. `sessionEnded` 从未被设置（因为 dashboard 没机会读到 complete 状态）
5. catch 块触发 → 红色 "连接已断开" banner 显示

**关键缺陷：**
- `dashboard/index.html:141` — catch 块无条件显示 connLost，不区分断开原因
- `go.md:267` — kill server 前没有给 dashboard 留出最后一次 poll 的时间窗口

## Fix Strategy

**dashboard/index.html（主修复）：**
- 添加 `sessionEnded` 标志
- poll 成功且 status 为 complete/failed 时设置该标志
- catch 块中仅在 `!sessionEnded` 时显示红色 banner

**go.md（辅助修复）：**
- 在 kill server 前加 `sleep 2`，确保 dashboard 有机会完成最后一次 poll 读取到终态
- poll 间隔为 2s，sleep 2s 基本保证 dashboard 能看到 complete 状态
