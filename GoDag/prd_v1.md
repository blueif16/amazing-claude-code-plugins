# GoDag (InfiStack v2) — 实施规范

> **给实施者的话：** 这份文档是完整的实施蓝图。你的任务是将它变成一个 Claude Code 插件。
> 不需要猜测任何东西——每个文件的路径、内容、逻辑全部在这里。按照顺序执行即可。

---

## 0. 核心原则（读完再动手）

**InfiStack v2 不是 framework，不是 orchestrator，不是 Gas Town 的复制品。**

它是三个写得极好的文件——一个 Skill 和两个 Command——建立在 Claude Code 原生 Agent Teams 能力之上。

### 设计哲学

1. **Anthropic 能做的事，永远不要自己做。** tmux 管理、worktree 创建、teammate 通信、task claiming——全部用原生 Agent Teams。我们不造编排层。
2. **我们只做 Anthropic 不做的事。** 意图识别、自动 task DAG 生成、执行记忆、结构化报告——这是我们的价值。
3. **用户是 PM，不是 coder。** 入口是一句自然语言，不是格式化的 PRD 文件。PRD 是可选的高端输入。
4. **薄而精准。** 整个插件的 prompt 内容加起来不超过 300 行。臃肿的 skill 文件会导致 Claude 指令跟随能力下降（Boris Cherny 的经验）。

### 核心依赖

- Claude Code v2.1.19+
- Agent Teams 功能开启：`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- 系统已安装 tmux（Agent Teams split pane 模式需要）
- 系统已安装 git（worktree 隔离需要）

---

## 1. 插件目录结构

```
infistack/
├── .claude-plugin/
│   └── plugin.json              # 插件元数据
├── skills/
│   └── intent-router.md         # 核心：意图识别 + DAG 生成
├── commands/
│   ├── go.md                    # /go 命令：一句话启动
│   └── report.md                # /report 命令：结构化汇报
└── README.md                    # 用户文档
```

---

## 2. 文件 1：plugin.json

**路径：** `infistack/.claude-plugin/plugin.json`

```json
{
  "name": "infistack",
  "version": "2.0.0",
  "description": "Intent-driven agent orchestration. Say what you want, get a coordinated team.",
  "skills": ["skills/intent-router.md"],
  "commands": [
    "commands/go.md",
    "commands/report.md"
  ]
}
```

---

## 3. 文件 2：Intent Router Skill（核心中的核心）

**路径：** `infistack/skills/intent-router.md`

**这个 skill 的职责：** 教会 Claude 从自然语言推导出结构化的执行计划。它不执行任何代码，只做判断和规划。

### 完整内容如下：

```markdown
---
name: intent-router
description: "Analyze user intent, classify work type, assess complexity, and generate task DAGs for Agent Teams orchestration. This skill activates whenever the user uses /go or describes work they want done."
---

# Intent Router — 从意图到执行计划

## 你的角色

你是一个 Staff Engineer 级别的技术 PM。用户会用自然语言告诉你他们想做什么。你的工作是：
1. 理解他们到底要什么
2. 判断这个工作的性质和复杂度
3. 决定最优的执行策略
4. 如果需要多 agent 协作，生成一个精确的 Task DAG

你不写代码。你做的是规划和判断。

## 第一步：意图分类

将用户输入归类为以下六种之一：

| 类型 | 信号词 | 示例 |
|------|--------|------|
| `implement` | 加、做、建、创建、实现 | "给登录页加上 Google OAuth" |
| `fix` | 修、改、bug、问题、报错、崩溃 | "checkout API 间歇性超时" |
| `refactor` | 重构、优化、整理、清理、拆分 | "把 UserService 拆成独立模块" |
| `review` | 审查、检查、review、看看 | "review 一下昨天的 PR" |
| `research` | 调查、研究、了解、比较、评估 | "调查一下用 Redis 还是 Memcached" |
| `continue` | 继续、接着、上次、还没做完 | "继续做昨天的 payment 模块" |

如果无法判断，直接问用户一个问题，不要猜。

## 第二步：复杂度评估

根据以下标准判断复杂度等级：

### Level 1 — 单 Agent 足够
- 改动范围：1-3 个文件
- 估计时间：< 30 分钟
- 无跨模块依赖
- **决策：直接执行，不需要 Agent Teams**

### Level 2 — 需要 Subagents
- 改动范围：3-8 个文件
- 涉及 2 个模块但依赖关系清晰
- 需要一些并行但不需要 agent 间通信
- **决策：用原生 subagents（Task tool），不启动 Agent Teams**

### Level 3 — 需要 Agent Teams
- 改动范围：8+ 个文件
- 跨 3+ 个模块
- agent 之间需要共享发现、互相挑战结论、协调接口
- **决策：启动 Agent Teams**

IMPORTANT: 大多数日常工作是 Level 1-2。不要过度工程化。Agent Teams 的 token 消耗是单 session 的 5-10 倍。只在真正需要并行协作时使用。

## 第三步：生成 Task DAG（仅 Level 2-3）

### DAG 格式

输出一个 JSON 结构的 Task DAG。每个 task 必须包含：

```json
{
  "dag": {
    "project": "简短项目名",
    "tasks": [
      {
        "id": "T1",
        "title": "简短描述",
        "type": "implement|test|review|research|config",
        "scope": "涉及的文件/模块",
        "blocked_by": [],
        "acceptance": "怎么验证这个 task 做对了（具体的命令或检查）",
        "estimated_complexity": "small|medium|large",
        "agent_role": "这个 agent 的专业角色描述"
      },
      {
        "id": "T2",
        "title": "写集成测试",
        "type": "test",
        "scope": "tests/integration/auth/",
        "blocked_by": ["T1"],
        "acceptance": "npm test -- --grep 'auth' 全部通过",
        "estimated_complexity": "medium",
        "agent_role": "Test Engineer，专注于边界情况和错误路径"
      }
    ]
  }
}
```

### DAG 生成规则

1. **每个 task 必须有 acceptance 标准。** 这是从 Anthropic C 编译器项目学到的最重要的教训：没有明确验证方法的 task，agent 会解决错误的问题。acceptance 必须是可执行的（一个命令、一个检查），不是模糊的描述。

2. **依赖关系必须显式声明。** `blocked_by` 数组里列出所有前置 task 的 ID。Agent Teams 的原生 Task 系统支持 DAG 依赖，teammate 不会尝试做被 block 的 task。

3. **尽量减少依赖。** 更多的独立 task = 更多的并行 = 更快完成。只在真正有数据/逻辑依赖时才添加 blocked_by。

4. **每个 task 应该是一个 teammate 能独立完成的。** 如果一个 task 需要两个 teammate 协作才能完成，说明拆得不对。

5. **总是包含一个 integration/review task 在最后。** 这个 task blocked_by 所有其他 task，负责验证整体集成。

### 典型 DAG 模式

**模式 A：Feature Implementation（最常见）**
```
T1: DB Schema/Migration ──┐
T2: Backend API ──────────┤── T4: Integration Test ── T5: Review
T3: Frontend Component ───┘
```

**模式 B：Bug Investigation**
```
T1: Log Analysis ─────────┐
T2: Code Archaeology ──────┤── T4: Root Cause Synthesis ── T5: Fix
T3: Reproduce in Test ────┘
```

**模式 C：Refactor**
```
T1: Extract Interface ─── T2: Migrate Callers ─── T3: Remove Old Code ─── T4: Test
```

**模式 D：Research/Debate**
```
T1: Approach A Research ──┐
T2: Approach B Research ──┤── T3: Compare & Recommend
T3: Approach C Research ──┘
```

## 第四步：编排策略选择

根据 DAG 的形状自动选择策略：

| DAG 形状 | 策略 | Agent Teams 用法 |
|----------|------|-----------------|
| 线性链（A→B→C） | Sequential | 单 session，不需要 team |
| 扇出（A,B,C→D） | Parallel Fan-out | spawn N teammates + 1 integration reviewer |
| 复杂图（混合依赖） | Full Team | team lead 协调，teammates 用 shared task list |
| 对等辩论（A,B,C→合议） | Debate | spawn teammates 并在 prompt 里要求互相挑战 |

## 第五步：生成 Spawn Prompts

为每个 teammate 生成精确的 spawn prompt。格式：

```
你是 [角色名]，负责 [具体职责]。

## 你的任务
[task title]

## 范围
只修改这些文件/目录：[scope]
不要碰这些文件/目录之外的任何东西。

## 完成标准
当以下条件全部满足时，标记任务完成：
[acceptance criteria]

## 依赖
[如果有 blocked_by] 等待以下任务完成后再开始：[blocked tasks]
[如果没有] 你可以立即开始。

## 约束
- 遵循项目的 CLAUDE.md 中的所有规则
- 每完成一个关键步骤，在 shared task list 里更新状态
- 如果遇到阻塞，通过 teammate messaging 通知 team lead
- 不要修改其他 teammate 正在处理的文件
```

## 降级策略

如果 Agent Teams 不可用（未开启、tmux 未安装、或用户选择不使用）：

- Level 3 任务降级为：单 session + subagents（Task tool），按 DAG 顺序执行
- Level 2 任务正常用 subagents
- Level 1 任务直接执行

在降级时告知用户："Agent Teams 不可用，我将用单 session 顺序执行。开启方法：在 settings.json 中添加 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
```

---

## 4. 文件 3：/go Command

**路径：** `infistack/commands/go.md`

### 完整内容如下：

```markdown
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
📋 执行计划：给登录页加上 Google OAuth

任务图：
  T1: 配置 Google OAuth credentials [config] ──┐
  T2: 后端 OAuth callback 路由 [implement]     ├── T4: 集成测试 [test]
  T3: 前端登录按钮组件 [implement] ────────────┘       │
                                                        ↓
                                                  T5: Code Review [review]

预计 teammates: 3（后端 + 前端 + 测试）
预计复杂度: 中等

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
  "project": "google-oauth",
  "started_at": "2026-02-22T10:30:00Z",
  "intent_type": "implement",
  "level": 3,
  "dag": { ... },
  "task_status": {
    "T1": { "status": "done", "completed_at": "...", "agent": "config-specialist" },
    "T2": { "status": "in_progress", "agent": "backend-dev" },
    "T3": { "status": "in_progress", "agent": "frontend-dev" },
    "T4": { "status": "blocked", "blocked_by": ["T2", "T3"] },
    "T5": { "status": "pending" }
  }
}
```

**文件：`.tasks/backlog.json`** （跨 session 持久化的待办）
```json
{
  "items": [
    {
      "id": "backlog-001",
      "description": "Google OAuth 登录",
      "created_at": "2026-02-22T10:30:00Z",
      "status": "in_progress",
      "state_file": ".tasks/state.json"
    }
  ]
}
```

这些文件 git-tracked，不加到 .gitignore。这样即使 session 崩了，下次 `/go continue` 能恢复。
```

---

## 5. 文件 4：/report Command

**路径：** `infistack/commands/report.md`

### 完整内容如下：

```markdown
---
name: report
description: "Generate a structured progress report for the current or most recent execution."
allowed-tools: ["Bash", "Read", "Task", "Teammate"]
---

# /report — 结构化进度报告

## 执行逻辑

1. 读取 `.tasks/state.json`
2. 如果 Agent Teams 正在运行：查询 shared task list 获取实时状态
3. 如果已完成或 session 已结束：从 state.json 读取最终状态
4. 生成以下格式的报告

## 报告格式

```
═══════════════════════════════════════
📊 InfiStack 执行报告
═══════════════════════════════════════

项目: [项目名]
类型: [implement/fix/refactor/review/research]
启动: [时间]
耗时: [时长]

─── 任务状态 ──────────────────────────

  ✅ T1: 配置 Google OAuth credentials
     完成时间: 3m 22s
     验证: ✅ 通过 (env vars set, OAuth client created)

  ✅ T2: 后端 OAuth callback 路由
     完成时间: 12m 45s
     验证: ✅ 通过 (npm test -- --grep 'oauth' 8/8 passed)

  🔄 T3: 前端登录按钮组件
     进行中: 已完成 UI，正在接入 API
     Agent: frontend-dev

  ⏳ T4: 集成测试
     状态: 等待 T2, T3 完成
     阻塞: T3

  ⏳ T5: Code Review
     状态: 等待 T4 完成

─── 总览 ──────────────────────────────

  完成: 2/5 (40%)
  进行中: 1/5
  等待中: 2/5

─── 置信度评估 ────────────────────────

  整体置信度: 🟢 高

  依据:
  - 已完成的 task 全部通过验证
  - 无 task 进入失败重试
  - 无 agent 报告阻塞或求助

─── 风险提示 ──────────────────────────

  [如果有风险] ⚠️ T3 耗时超出预期，可能影响整体进度
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
📊 google-oauth: 2/5 done (40%) | 🟢 高置信度 | 预计还需 ~15min
```
```

---

## 6. README.md（用户文档）

**路径：** `infistack/README.md`

```markdown
# InfiStack v2

从一句话到一个协调好的 agent 团队。

InfiStack 是建立在 Claude Code Agent Teams 之上的智能编排层。
你说一句话，它帮你规划任务、拆解依赖、启动团队、追踪进度。

## 安装

```bash
# 在你的 Claude Code 项目中
/plugin install infistack
```

### 前提条件

1. Claude Code v2.1.19+
2. 在 settings.json 或环境变量中开启 Agent Teams：
   ```
   CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
   ```
3. 系统安装 tmux：`brew install tmux`（macOS）或 `apt install tmux`（Linux）

## 使用

### 基础用法

```bash
# 说一句话，开始干活
/go 给登录页加上 Google OAuth

# 从 PRD 文件启动
/go ./docs/feature-prd.md

# 继续上次的工作
/go continue

# 不知道做什么？它会问你
/go
```

### 查看进度

```bash
# 完整报告
/report

# 简要状态
/report short
```

## 它做了什么

1. **理解意图** — 自动判断你要 implement / fix / refactor / review / research
2. **评估复杂度** — 决定单 agent 够了还是需要团队
3. **生成任务图** — 自动拆解任务、声明依赖关系、定义验收标准
4. **启动团队** — 用 Agent Teams 原生能力 spawn teammates
5. **追踪进度** — 结构化报告，置信度评估，风险提示

## 设计哲学

- **不造轮子：** tmux、worktree、task claiming 全用 Agent Teams 原生能力
- **只做判断：** 我们的价值在 "从一句话到一个好的 task DAG" 的转化质量
- **薄而精准：** 整个插件不到 300 行 prompt，不会拖慢 Claude 的指令跟随
- **优雅降级：** Agent Teams 不可用时自动降级到 subagents 或单 session

## 状态文件

InfiStack 在项目的 `.tasks/` 目录下维护状态：

- `.tasks/state.json` — 当前执行的任务状态
- `.tasks/backlog.json` — 跨 session 的待办列表

这些文件是 git-tracked 的，session 崩溃后可以用 `/go continue` 恢复。
```

---

## 7. 实施注意事项（给实施 LLM 的提醒）

### 关键决策

1. **不要在 skill 文件里写代码。** Intent Router 是纯 prompt/instruction，教 Claude 怎么思考和决策。不是 Python 脚本。

2. **不要在 command 文件里重复 skill 内容。** `/go` command 调用 intent-router skill，不要复制粘贴 skill 的逻辑。Command 只定义流程和交互格式。

3. **Task DAG 的 JSON 格式不是给人看的。** 它是 Claude 内部推理用的中间表示。给用户看的是那个 ASCII 任务图。

4. **`.tasks/` 目录要在首次 `/go` 时自动创建。** 不需要用户手动 init。

5. **state.json 要在每个 task 状态变更时更新。** 不是最后一次性写入。这样 `/report` 随时能给出实时状态。

### Agent Teams 集成的具体调用方式

实施时需要使用以下 Agent Teams 原语（这些是 Claude Code 内置的，不需要额外安装）：

```
# 创建团队
Teammate({ operation: "spawnTeam", team_name: "项目名" })

# Spawn 一个 teammate
Teammate({ 
  operation: "spawn", 
  team_name: "项目名",
  name: "backend-dev",
  prompt: "你的完整 spawn prompt..."
})

# 创建有依赖的 task
Task({
  team_name: "项目名",
  name: "T1: 配置 OAuth",
  description: "...",
  blocked_by: []  // 或 ["task-id-1", "task-id-2"]
})

# 发送消息给 teammate
Teammate({
  operation: "write",
  team_name: "项目名",
  to: "backend-dev",
  text: "T2 完成了，你可以开始集成了"
})

# 查询团队状态
Teammate({ operation: "list", team_name: "项目名" })
```

### 测试插件

安装后，用以下场景验证：

**场景 1：简单任务（应该 Level 1，直接执行）**
```
/go 把 README 里的 typo 修一下
```
预期：不启动 Agent Teams，直接修。

**场景 2：中等任务（应该 Level 2，用 subagents）**
```
/go 给 User model 加一个 email verification 功能
```
预期：生成 DAG，用 subagents 执行。

**场景 3：复杂任务（应该 Level 3，用 Agent Teams）**
```
/go 重构整个认证系统，从 session-based 切换到 JWT，包括后端、前端、测试
```
预期：生成 DAG，确认后 spawn Agent Teams。

**场景 4：继续工作**
```
/go continue
```
预期：读取 `.tasks/state.json`，展示进度，继续执行。

**场景 5：报告**
```
/report
```
预期：输出结构化报告。

---

## 8. 融合的最佳实践来源

本设计综合了以下来源的经验，实施者不需要重新调研：

| 来源 | 提炼出的核心教训 | 在哪里体现 |
|------|-----------------|-----------|
| **Boris Cherny (Claude Code 创始人)** | Plan mode 先行；CLAUDE.md 要精简；并行用 worktree | Intent Router 的 plan-first 设计；整个插件 < 300 行 |
| **Anthropic C 编译器实验** | 测试验证器必须近乎完美；不需要中央调度者；每个 agent 自己挑下一个任务 | 每个 task 强制定义 acceptance 标准；用 Agent Teams 的 self-claim 机制 |
| **Steve Yegge (Gas Town)** | 用户是 PM 不是 coder；工作单元要持久化；优雅降级 | /go 一句话入口；.tasks/ git-tracked 状态；fallback 到 subagents |
| **VentureBeat Tasks 报道** | Tasks 支持 DAG 依赖；blocked_by 防止跳过依赖执行 | Task DAG 的 blocked_by 字段 |
| **Reddit 社区 (r/ClaudeAI)** | Context 管理是第一大失败原因；CLAUDE.md 过长导致指令跟随下降 | Skill 文件精简；每个 teammate 有独立 context |
| **Cursor 社区 (r/cursor)** | "AI gaslighting loop" 来自 context 污染；需要结构化的工作流来防止 | /report 的置信度评估；失败 task 的独立重试不影响其他 agent |

---

## 9. 未来扩展（v2.1+，现在不做）

以下是明确的 "现在不做" 列表，避免实施者过度工程化：

- ❌ 自定义 agent 角色模板系统
- ❌ Web dashboard / UI
- ❌ 跨项目的统一 backlog
- ❌ 成本追踪和 token 预算
- ❌ 与 Jira / Linear / GitHub Issues 集成
- ❌ 多模型支持（Codex、Gemini CLI）
- ❌ 自动从 git history 学习项目模式

这些都是好想法，但 v2.0 的目标是：**三个文件，做好一件事——从一句话到一个协调好的 agent 团队。**