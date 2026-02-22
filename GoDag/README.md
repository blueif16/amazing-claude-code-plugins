# GoDag (InfiStack v2)

从一句话到一个协调好的 agent 团队。

GoDag 建立在 Claude Code Agent Teams 之上的智能编排层。
你说一句话，它帮你规划任务、拆解依赖、启动团队、追踪进度。

## 安装

```bash
/plugin install godag
```

### 前提条件

1. Claude Code v2.1.19+
2. 在 settings.json 或环境变量中开启 Agent Teams：
   ```
   CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
   ```
3. 系统安装 tmux：`brew install tmux`（macOS）或 `apt install tmux`（Linux）

## 使用

```bash
# 说一句话，开始干活
/go 给登录页加上 Google OAuth

# 从 PRD 文件启动
/go ./docs/feature-prd.md

# 继续上次的工作
/go continue

# 不知道做什么？它会问你
/go

# 完整报告
/report

# 简要状态
/report short
```

## 工作原理

1. **理解意图** — 自动判断你要 implement / fix / refactor / review / research
2. **评估复杂度** — 决定单 agent 够了还是需要团队
3. **生成任务图** — 自动拆解任务、声明依赖关系、定义验收标准
4. **启动团队** — 用 Agent Teams 原生能力 spawn teammates
5. **追踪进度** — 结构化报告，置信度评估，风险提示

## 设计哲学

- **不造轮子：** tmux、worktree、task claiming 全用 Agent Teams 原生能力
- **只做判断：** 价值在 "从一句话到一个好的 task DAG" 的转化质量
- **薄而精准：** 整个插件不到 300 行 prompt，不会拖慢 Claude 的指令跟随
- **优雅降级：** Agent Teams 不可用时自动降级到 subagents 或单 session

## 状态文件

GoDag 在项目的 `.tasks/` 目录下维护状态：

- `.tasks/state.json` — 当前执行的任务状态
- `.tasks/backlog.json` — 跨 session 的待办列表

这些文件是 git-tracked 的，session 崩溃后可以用 `/go continue` 恢复。