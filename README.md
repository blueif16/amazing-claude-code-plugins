# Claude Code 插件市场

这是一个包含实用中文插件的 Claude Code 插件市场。

## 包含的插件

### InfiStack (v1.2.0)

自我改进的PRD执行系统，支持渐进式升级和并行处理。通过主协调器拆分PRD，在独立的tmux会话中并行执行，自动修复失败，智能升级到研究员或人工。

**目录结构:**

```
项目根目录/
├── docs/prds/{project}/
│   ├── meta.yaml              # 项目元数据和部分状态
│   └── sections/
│       ├── auth/
│       │   ├── mini-prd.md    # 部分需求文档
│       │   └── .task/
│       │       ├── mini-prd.md
│       │       └── checklist.md
│       └── api/...
│
└── ../worktrees/              # 并行工作区（git worktree）
    ├── auth/                  # 独立分支工作区
    │   └── .task/             # 任务文件
    └── api/...
```

**架构图:**


```
/init
  │
  ▼
┌─────────────────────────────────────────────────┐
│            MAIN COORDINATOR                      │
│                                                  │
│  prd-orchestrator ─→ execution-manager          │
│       │                    │                     │
│       ▼                    ▼                     │
│  [mini-PRDs]         [spawn tmux+worktrees]     │
└─────────────────────────────────────────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ SUB COORDINATOR │ │ SUB COORDINATOR │ │ SUB COORDINATOR │
│                 │ │                 │ │                 │
│   fix-engine    │ │   fix-engine    │ │   fix-engine    │
│       │         │ │       │         │ │       │         │
│       ▼         │ │       ▼         │ │       ▼         │
│   executor ◄──┐ │ │   executor      │ │   executor      │
│       │       │ │ │       │         │ │       │         │
│       ▼       │ │ │       ▼         │ │       ▼         │
│   validator ──┘ │ │   validator     │ │   validator     │
│    (≤3x)        │ │                 │ │                 │
│       │         │ │                 │ │                 │
│       ▼         │ │                 │ │                 │
│ escalation-router│ │                 │ │                 │
│    │       │    │ │                 │ │                 │
│    ▼       ▼    │ │                 │ │                 │
│researcher documenter                 │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

**并行执行机制:**

*Git Worktree 隔离:*
```bash
# 每个部分在独立的 worktree 中执行
git worktree add ../worktrees/auth -b project/auth
git worktree add ../worktrees/api -b project/api

# 避免分支切换冲突，真正并行开发
../worktrees/auth/    # 独立的 git 工作区
../worktrees/api/     # 独立的 git 工作区
```

*Tmux 会话管理:*
```bash
# 创建会话并初始化子协调器
tmux new-session -d -s auth -c ../worktrees/auth \
  claude "You are Sub Coordinator for auth. Read fix-engine skill. Begin."

# 监控会话
tmux ls                                    # 列出所有会话
tmux capture-pane -t auth -p | tail -50   # 查看输出
tmux attach -t auth                        # 附加观察（Ctrl+B D 分离）
tmux send-keys -t auth "Handle edge case" Enter  # 发送指令
```

**功能特点:**
- 🎯 智能拆分：自动分析PRD复杂度，决定整体执行或水平拆分
- ⚡ 并行执行：使用git worktrees和tmux会话实现真正的并行处理
- 🔄 自动修复：executor→validator循环，最多3次自动重试
- 🧠 智能升级：失败后自动决策升级到研究员或人工
- 📊 完整上下文：保留所有尝试历史和代码片段
- 🇨🇳 中文支持：所有交互和文档都使用中文

**使用方法:**

```bash
# 从PRD文件启动
/init ./docs/feature-prd.md

# 监控执行
tmux ls                    # 查看所有会话
tmux attach -t auth        # 附加到特定部分

# 查看完成日志
tail -f ~/.infistack/completion.log
```

### Beautify Commit

美化 Git Commit 消息的中文工具，让你的提交记录更加优雅、规范或可爱！

**功能特点:**
- 🎨 多种风格：支持正常、详细、简洁、可爱四种 commit 风格
- 🇨🇳 中文优先：所有提示和消息都使用中文
- 💾 记住偏好：首次选择风格后自动保存
- 🤖 智能分析：自动分析代码变更，生成合适的 commit 消息
- ✨ 二次元风格：可爱风格使用精选的二次元 emoji 和颜文字

### SkillForge

自管理的插件系统，用于创建、更新和发布 Claude Code 命令。

**功能特点:**
- 🛠️ 创建命令：使用模板快速生成新命令
- ✏️ 更新命令：智能修改现有命令
- 🔄 同步发布：自动提交并推送到 Git
- 📚 知识库：命令编写的最佳实践指南
- 🇨🇳 中文支持：所有操作和文档都使用中文

## 安装方法

### 方法 1: 本地安装（推荐用于测试）

```bash
# 进入 marketplace 目录
cd /path/to/plugin-market-marketplace

# 启动 Claude Code
claude

# 添加本地 marketplace
/plugin marketplace add ./

# 安装插件
/plugin install beautify-commit@plugin-market-marketplace
/plugin install skillforge@plugin-market-marketplace

# 重启 Claude Code 后使用
/beautify-commit
/create-skill
/update-skill
/sync-marketplace
```

### 方法 2: 从 GitHub 安装

```bash
# 添加 GitHub marketplace
/plugin marketplace add yourusername/plugin-market-marketplace

# 安装插件
/plugin install beautify-commit@plugin-market-marketplace
```

## 使用插件

### Beautify Commit

安装完成后，在你的项目中运行：

```bash
/beautify-commit
```

首次使用时会询问你喜欢的 commit 风格，之后会自动记住你的选择。

### SkillForge

创建新命令：

```bash
/create-skill
```

更新现有命令：

```bash
/update-skill
```

同步到 Git：

```bash
/sync-marketplace
```

查看最佳实践：

```bash
/skillforge-knowledge
```

## 目录结构

```
plugin-market-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace 配置文件
├── beautify-commit/               # Beautify Commit 插件
│   ├── .claude-plugin/
│   │   └── plugin.json           # 插件配置
│   ├── commands/
│   │   └── beautify-commit.md    # 命令实现
│   ├── examples/
│   │   └── beautify-commit.local.md  # 配置示例
│   └── README.md                 # 插件文档
├── skillforge/                    # SkillForge 插件
│   ├── .claude-plugin/
│   │   └── plugin.json           # 插件配置
│   ├── commands/
│   │   ├── create-skill.md       # 创建命令
│   │   ├── update-skill.md       # 更新命令
│   │   ├── sync-marketplace.md   # 同步命令
│   │   ├── skillforge-knowledge.md  # 知识库
│   │   └── create-skill/
│   │       ├── scripts/
│   │       │   └── find-marketplace.sh  # 查找脚本
│   │       └── templates/
│   │           └── command-template.md  # 命令模板
│   └── README.md                 # 插件文档
└── README.md                      # 本文件
```

## 发布到 GitHub

如果你想将这个 marketplace 发布到 GitHub：

```bash
cd plugin-market-marketplace
git init
git add .
git commit -m "Initial release of plugin marketplace"
git remote add origin https://github.com/yourusername/plugin-market-marketplace
git push -u origin main
```

然后其他用户可以通过以下方式安装：

```bash
/plugin marketplace add yourusername/plugin-market-marketplace
/plugin install beautify-commit@plugin-market-marketplace
/plugin install skillforge@plugin-market-marketplace
```

## 添加更多插件

要添加更多插件到这个 marketplace：

1. 将新插件目录复制到 `plugin-market-marketplace/` 下
2. 在 `.claude-plugin/marketplace.json` 的 `plugins` 数组中添加新插件信息
3. 更新本 README 文件

示例：

```json
{
  "plugins": [
    {
      "name": "beautify-commit",
      "source": "./beautify-commit",
      "description": "美化 Git Commit 消息的中文工具",
      "version": "0.1.0",
      "category": "git",
      "tags": ["git", "commit", "中文"]
    },
    {
      "name": "your-new-plugin",
      "source": "./your-new-plugin",
      "description": "你的新插件描述",
      "version": "1.0.0",
      "category": "development",
      "tags": ["tag1", "tag2"]
    }
  ]
}
```

## 版本

当前版本：1.0.0

## 许可

MIT License
