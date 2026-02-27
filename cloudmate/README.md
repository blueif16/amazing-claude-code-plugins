# CloudMate

From one sentence to a coordinated agent team. No dashboards. No servers. Just planning.

CloudMate is a skill + command for Claude Code. You say what you want. It classifies intent, assesses complexity, generates a task DAG with acceptance criteria, and executes at the right level — solo, subagents, or Agent Teams. It integrates with git worktree workflows and the standard merge scripts.

## Install

Copy the skill and command into your project or user-level Claude config:

```bash
# User-level (available across all projects)
cp -r skills/cmoudmate ~/.claude/skills/cmoudmate
mkdir -p ~/.claude/commands && cp commands/cm.md ~/.claude/commands/cm.md

# Project-level (team-shared, checked into git)
cp -r skills/cmoudmate .claude/skills/cmoudmate
mkdir -p .claude/commands && cp commands/cm.md .claude/commands/cm.md
```

### Prerequisites

1. Claude Code v2.1.19+
2. For Level 3 (Agent Teams), add to `~/.claude/settings.json`:
   ```json
   {
     "env": {
       "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
       "CLAUDE_CODE_TEAMMATE_MODE": "tmux"
     }
   }
   ```
3. tmux installed: `brew install tmux` (macOS) or `apt install tmux` (Linux)
4. Pre-approve tools so teammates don't stall on permission prompts:
   ```json
   {
     "permissions": {
       "allow": [
         "Bash(npm:*)", "Bash(npx:*)", "Bash(node:*)",
         "Bash(git add:*)", "Bash(git commit:*)", "Bash(git status:*)",
         "Bash(git diff:*)", "Bash(git log:*)", "Bash(git branch:*)",
         "Bash(grep:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(mkdir:*)",
         "Edit(*)", "Write(*)", "Read(*)"
       ],
       "deny": [
         "Bash(git push --force:*)",
         "Bash(git reset --hard:*)"
       ]
     }
   }
   ```

Without Agent Teams enabled, Level 3 tasks degrade gracefully to sequential subagents.

## Usage

```bash
# Describe what you want
/cm add Google OAuth to the login page

# Plan from a PRD or spec file
/cm ./docs/feature-spec.md

# Check progress
/cm status

# Resume after a crash or new session
/cm continue

# Don't know what to do?
/cm
```

## How It Works

### Level 1 — Solo (1-3 files, simple)
CloudMate classifies and starts working immediately. No plan display, no confirmation. Just does it.

### Level 2 — Subagents (3-8 files, 2 modules)
CloudMate generates a DAG, shows you the plan, and on confirmation uses Claude's Task tool to run subagents within the current session. One pane, one merge.

### Level 3 — Agent Teams (8+ files, 3+ modules)
CloudMate generates a DAG, shows you the plan, and on confirmation spawns an Agent Team. Teammates appear as tmux split panes — leader on the left of the row, workers stacked on the right. Each teammate gets its own worktree, self-claims unblocked tasks, and merges back to the leader's branch automatically.

```
Your CC row before L3:
┌──────────────────────────────┐
│ CC Slot (claude -w)           │
└──────────────────────────────┘

After /cm triggers L3:
┌───────────────┬──────────────┐
│ CC Lead       │ Teammate T1   │
│ (you talk to  │ Teammate T2   │
│  this one)    │ Teammate T3   │
└───────────────┴──────────────┘
```

When the team finishes and cleans up, the row collapses back to a single pane.

## CC Worktree Workflow

你是 PM，不是 coder。你 spawn Claude，划定范围，merge 产出，测试。每个 Claude 都是一次性的——spawn, extract value, merge or discard, repeat。

一个 dev server，一个 localhost，多个隔离的 Claude 在各自 branch 上写代码。你是 merge gatekeeper。

```
main (dev server running, you test here)
  │
  ├── wt/fix-auth/       Claude pane 1, own branch
  ├── wt/add-tests/      Claude pane 2, own branch
  └── wt/refactor-dag/   Claude pane 3, own branch
```

### 5 个快捷键

在 iTerm2 → Settings → Keys → Key Bindings 中配置，Action 选 "Send Text with tmux"。

在 iTerm2 → Settings → Keys → Key Bindings 中配置。Action 选 "Send tmux command"。快捷键 3/5 需要配置为两条命令的 sequence。

| # | 快捷键 | tmux 命令 | 用途 |
|---|--------|----------|------|
| 1 | `Ctrl+Shift+C` | `split-window -h 'claude'` | 需要 dev server 的工作（前端、调试） |
| 2 | `Ctrl+Shift+W` | `split-window -h 'claude -w'` | 其他所有工作（测试、重构、后端） |
| 3 | `Ctrl+Shift+M` | 见下方 | Merge & Close：commit → merge → 关闭 pane |
| 4 | `Ctrl+Shift+K` | `run-shell -b '~/.cc/merge.sh #{pane_current_path}'` | Merge & Keep：后台 merge，Claude 不退出 |
| 5 | `Ctrl+Shift+D` | 见下方 | Discard & Close：commit → discard → 关闭 pane |

**Ctrl+Shift+M** (Merge & Close) — 两条 "Send tmux command" sequence：
1. `run-shell 'echo merge > /tmp/.cc-action-#{pane_id}'`
2. `send-keys '/exit' Enter`

**Ctrl+Shift+D** (Discard & Close) — 两条 "Send tmux command" sequence：
1. `run-shell 'echo discard > /tmp/.cc-action-#{pane_id}'`
2. `send-keys '/exit' Enter`

快捷键 3/4/5 需要点击目标 worktree pane 后再按。非 worktree session 下 merge/discard 脚本会被安全检查拦住，只做 safety commit 后关闭 pane。

### Statusline（Agent 状态追踪）

多 worktree 并发时，一眼看清每个 agent 的状态。在 `~/.claude/settings.json` 中配置：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

脚本安装：

```bash
# 脚本已预装在 ~/.claude/statusline.sh
# 如需重新安装：
cp setup/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

输出格式：

```
feat/jwt-auth | curious-dazzling-pike ↑3 ●2 ✚1 ⇣4 | ctx:34%
```

从左到右：branch 名、worktree 目录名、commits ahead（agent 产出量）、dirty 文件数、staged 文件数、behind remote、context 使用百分比。干净状态只显示核心信息：

```
feat/jwt-auth | curious-dazzling-pike ↑3 | ctx:34%
```

`ctx:%` 是最关键的指标——接近 80% 时 Claude 会自动压缩上下文，可能丢失关键信息。

### Lazygit Popup（tmux 浮窗 Git）

一个快捷键，任何 pane 内弹出浮窗 lazygit。添加到 `~/.tmux.conf`：

```bash
bind g popup -d '#{pane_current_path}' -w 90% -h 90% -E 'lazygit'
```

`prefix + g` 从任何地方——Claude Code、nvim、shell——弹出浮窗。`q` 关闭，回到原位。

安装 lazygit：

```bash
brew install lazygit
```

重载 tmux 配置：

```bash
tmux source ~/.tmux.conf
```

### 脚本安装

```bash
# ~/.cc/merge.sh 和 ~/.cc/discard.sh 已预装
# 如需重新安装：
mkdir -p ~/.cc
cp setup/merge.sh ~/.cc/merge.sh
cp setup/discard.sh ~/.cc/discard.sh
chmod +x ~/.cc/*.sh
```

`merge.sh` 自动从 worktree 的 commit 历史生成 squash commit message，无需手动命名：
```
a]4f2c1 merge: refactor intent router; add edge case handling
b]8e3a7 merge: write integration tests for DAG generation
c]1d9b2 merge: fix OAuth callback for custom domains
```

### Hooks（全局）

`~/.claude/settings.json` 中已配置：

- **SessionEnd** — pane 崩溃或关闭时自动 commit 未保存的工作，可随时恢复
- **Notification** — 任何 Claude session 需要输入时弹出 macOS 通知（多 pane 必备）

### Worktree 日志约定

Worktree Claude 添加的日志自动带 branch 前缀，方便按 worktree 过滤：

```js
// Claude 在 worktree 中自动这样写
console.log("[worktree-fix-auth] OAuth callback received:", data)
```

merge 后出问题时过滤日志定位来源：
```bash
grep "\[worktree-fix-auth\]" logs/server.log
```

如果用了 Merge & Keep（快捷键 4），直接把错误贴回该 Claude 让它修。

### 与 CloudMate 集成

CloudMate 设计为在 `claude -w` session 中运行：

1. 打开工作区：`cd ~/your-project && twork`
2. `Ctrl+Shift+W` 创建新的 CC slot（独立 worktree）
3. 在该 slot 中运行 `/cm <your task>`
4. CloudMate 规划并执行（自动选择 L1/L2/L3）
5. 完成后 merge：
   - `Ctrl+Shift+M` — Merge & Close（routine 任务）
   - `Ctrl+Shift+K` — Merge & Keep（careful 任务，先测试）
   - `Ctrl+Shift+D` — Discard & Close（丢弃）

最多 3 个 CC slot 并发运行独立任务，每个 slot 可独立为 L1、L2 或 L3。

### Risk Tiers → Merge Strategy

CloudMate 为每个任务标记风险等级，对应你的 merge 决策：

| Tier | 含义 | 操作 |
|------|------|------|
| `routine` | 低风险，易回滚 | Merge & Close |
| `careful` | 用户可见变更 | Merge & Keep，先测试 |
| `critical` | 不可逆、安全、数据 | Review diff before merge |

## State & Status

CloudMate writes each plan to the **main repo's** `.tasks/` directory, named by branch:

```
.tasks/
├── auth-refactor.md       ← CC Slot 1's plan
├── add-tests.md           ← CC Slot 2's plan
└── fix-payment-bug.md     ← CC Slot 3's plan
```

All plans visible from one place, regardless of which worktree created them.

### Plan Format

Each plan includes a mermaid DAG (renders on GitHub and in markdown previewers), an ASCII tree (renders in terminal), and detailed task status:

```
# auth-refactor
Branch: wt-auth-refactor | Level: 3 | Type: refactor | Status: in_progress

## DAG (mermaid — renders on GitHub, in VS Code, in Neovim with preview plugin)
## Tree (ASCII — renders in terminal, in status viewer)

✅ T1: Extract interface [routine]
├──→ 🔄 T2: JWT impl [careful]
│    └──→ ⏳ T4: Integration test [routine]
└──→ ⏳ T3: Migrate routes [careful]
     └──→ ⏳ T4: Integration test [routine]

## Tasks (detailed status, scope, verification, summaries)
```

### Status Viewer

The status viewer (`~/.cc/status.sh`) runs in your status pane and gives you an interactive terminal dashboard:

```bash
# Install
cp setup/status.sh ~/.cc/status.sh && chmod +x ~/.cc/status.sh

# Run (auto-refreshes every 3s)
~/.cc/status.sh --watch
```

**Overview** — shows all active plans at a glance:
```
╔══════════════════════════════════════════════╗
║  CloudMate — 3 plan(s)                       ║
╠══════════════════════════════════════════════╣
║                                              ║
║  1) auth-refactor [L3] in_progress           ║
║     2/5 ██████░░░░░░░░░ 40%                 ║
║     ✅T1 ✅T2 🔄T3 ⏳T4 ⏳T5                ║
║                                              ║
║  2) add-tests [L2] in_progress               ║
║     1/3 █████░░░░░░░░░░ 33%                 ║
║     ✅T1 🔄T2 ⏳T3                          ║
║                                              ║
║  [1-3] detail · [r] refresh · [q] quit       ║
╚══════════════════════════════════════════════╝
```

**Drill-down** — press `1` to see the full DAG tree + task details for that plan. Press `b` to go back.

Zoom into the status pane with `Cmd+Shift+Enter` (iTerm2 maximize pane) for a full-screen view. Zoom back out when done.

### Three Ways to View Plans

1. **Status pane** — `~/.cc/status.sh --watch` (interactive, auto-refresh, overview + drill-down)
2. **Neovim** — `<leader>cp` opens plan.md; mermaid renders with a markdown preview plugin
3. **GitHub** — push the branch; mermaid renders natively in the markdown

## Setup Files (Optional)

- `setup/merge.sh` — squash-merge worktree branch 到 main。Copy to `~/.cc/merge.sh`
- `setup/discard.sh` — 丢弃 worktree 并清理 branch。Copy to `~/.cc/discard.sh`
- `setup/status.sh` — interactive terminal status viewer for the status pane. Copy to `~/.cc/status.sh`
- `setup/work.yml` — tmuxinator 模板（仅供参考，推荐用 `twork` 替代）
- `setup/nvim-cloudmate.lua` — minimal Neovim config for watching agent file changes across worktrees

### twork（推荐）

在 `~/.zshrc` 中定义的 shell 函数，替代 tmuxinator。优势：

- 零配置：自动检测当前目录，用目录名作为 session 名
- 不需要为每个项目写 `.yml` 配置文件
- 布局固定：左边 nvim，右上 `claude -w`，右下 `status.sh --watch`
- 右下 pane 留空可按项目需要自定义（dev server、测试等）
- 重复运行 `twork` 会 attach 回已有 session

```bash
cd ~/your-project
twork
```

tmuxinator 的 `setup/work.yml` 保留作为参考，但日常使用 `twork` 即可。

### nvim-cloudmate.lua 安装状态

已安装。安装步骤：

```bash
cp setup/nvim-cloudmate.lua ~/.config/nvim/lua/cmoudmate.lua
# 然后在 init.lua 末尾添加: require("cloudmate")
```

依赖情况：
- telescope.nvim + telescope-fzf-native — 已安装
- gitsigns.nvim — 已安装，已添加 `watch_gitdir` 配置
- fugitive.vim — 已安装，在 nvim 内执行 git 命令

提供的快捷键：
- `<leader>fw` — 跨 worktree 搜索文件
- `<leader>gw` — 跨 worktree 内容搜索
- `<leader>cp` — 快速打开 `.tasks/plan.md`

查看 Agent 文件变更：
- 文件自动刷新：agent 修改文件后 nvim 自动重载内容（autoread + checktime）
- 行内 diff：gitsigns 配合 `watch_gitdir` 实时标记变更行
- 查看变更文件列表：`:Git status` 或 `:Git diff --stat`（fugitive）

## Design Philosophy

- **No runtime.** CloudMate is pure planning. Agent Teams handles execution. Your merge scripts handle integration.
- **No dashboard server.** `status.sh` reads markdown files. That's it.
- **No custom orchestration.** Agent Teams' native task list, self-claim, and teammate messaging are used directly.
- **Complexity gating.** Most work is L1-2. CloudMate prevents token waste on unnecessary Agent Teams.
- **Acceptance criteria on every task.** Agents without verification solve the wrong problem.
- **~390 lines of prompt across 4 files.** Lean enough that Claude's instruction-following stays sharp.
