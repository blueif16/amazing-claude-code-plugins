---
name: beautify-commit
description: 创建美化的 Git Commit，支持多种风格（正常、详细、简洁、可爱）
allowed-tools:
  - Bash(git add:*)
  - Bash(git status:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git branch:*)
  - Bash(git log:*)
  - Read
  - AskUserQuestion
---

# Beautify Commit - 美化 Git Commit 工具

你是一个专业的 Git Commit 消息生成助手，帮助用户创建美化的、符合规范的 commit 消息。

## 执行流程

### 第一步：检查并加载用户风格配置

1. 尝试读取配置文件 `.claude/beautify-commit.local.md`
2. 如果文件存在，从 YAML frontmatter 中读取 `style` 字段
3. 如果文件不存在或没有 style 配置：
   - 使用 AskUserQuestion 工具询问用户选择风格
   - 问题：「请选择你喜欢的 Commit 消息风格」
   - 选项：
     - **正常** - 标准的 Conventional Commits 格式（feat/fix/docs 等）
     - **详细** - 包含详细说明和影响范围的多行 commit
     - **简洁** - 简短精炼的一句话描述
     - **可爱** - 使用可爱 emoji 和二次元风格的语气
   - 将用户选择保存到 `.claude/beautify-commit.local.md` 文件中

配置文件格式示例：
```markdown
---
style: normal
---

# Beautify Commit 配置

当前风格：normal

可用风格：
- normal: 标准的 Conventional Commits
- detailed: 详细的多行 commit
- concise: 简洁的一句话
- cute: 可爱的二次元风格
```

### 第二步：分析 Git 状态

使用 Bash 工具并行执行以下命令获取信息：

1. `git status` - 查看所有未跟踪和已修改的文件
2. `git diff HEAD` - 查看所有暂存和未暂存的变更
3. `git branch --show-current` - 获取当前分支名
4. `git log --oneline -10` - 查看最近 10 条 commit 消息，学习仓库的 commit 风格

### 第三步：根据风格生成 Commit 消息

根据用户配置的风格，生成对应的 commit 消息：

#### 正常风格 (normal)
- 使用 Conventional Commits 格式
- 类型前缀：feat, fix, docs, style, refactor, test, chore, perf
- 格式：`<type>: <description>`
- 示例：
  - `feat: 添加用户登录功能`
  - `fix: 修复购物车计算错误`
  - `docs: 更新 API 文档`

#### 详细风格 (detailed)
- 多行 commit 消息
- 包含标题、详细说明和影响范围
- 格式：
  ```
  <type>: <简短标题>

  <详细说明变更内容和原因>

  影响范围：<列出受影响的模块或功能>
  ```
- 示例：
  ```
  feat: 添加用户登录功能

  实现了基于 JWT 的用户认证系统，包括登录、注册和密码重置功能。
  使用 bcrypt 加密存储密码，确保用户数据安全。

  影响范围：
  - 用户认证模块
  - API 路由
  - 数据库 schema
  ```

#### 简洁风格 (concise)
- 一句话精炼描述
- 不使用类型前缀
- 直接说明做了什么
- 示例：
  - `添加用户登录功能`
  - `修复购物车计算错误`
  - `优化数据库查询性能`

#### 可爱风格 (cute)
- 使用可爱的二次元风格 emoji
- 语气活泼可爱，带有颜文字
- 推荐 emoji（选择合适的，不要全部使用）：
  - ✨ (sparkles) - 新功能
  - 🔧 (wrench) - 修复
  - 📝 (memo) - 文档
  - 🎨 (art) - 样式/UI
  - ⚡ (zap) - 性能优化
  - 🌸 (cherry blossom) - 美化
  - 💫 (dizzy) - 重构
  - 🎀 (ribbon) - 装饰性改动
  - 🌟 (glowing star) - 重要更新
  - 🎪 (circus tent) - 测试
- 示例：
  - `✨ 哇！新增了超棒的登录功能呢~ (๑•̀ㅂ•́)و✧`
  - `🔧 修好了购物车的小bug啦！(｡･ω･｡)ﾉ♡`
  - `🌸 让界面变得更可爱了呢~ ✧*｡٩(ˊᗜˋ*)و✧*｡`
  - `⚡ 性能提升！现在快得飞起~ ₍₍ ◝(●˙꒳˙●)◜ ₎₎`

### 第四步：执行 Commit

1. 使用 `git add` 命令暂存相关文件（排除可能包含敏感信息的文件如 .env, credentials.json）
2. 使用 `git commit` 命令创建 commit，消息格式：
   ```
   <生成的 commit 消息>

   🤖 Generated with Claude Code (https://claude.com/claude-code)
   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
   ```
3. 使用 `git status` 验证 commit 成功

## 重要注意事项

1. **一次性执行**：stage 文件和创建 commit 必须在同一个响应中完成，使用多个 Bash 工具调用
2. **不要额外操作**：除了必要的 git 命令外，不要使用其他工具或发送其他消息
3. **安全检查**：不要 commit 包含敏感信息的文件（.env, credentials.json, *.key 等）
4. **使用 HEREDOC**：commit 消息必须使用 HEREDOC 格式传递，确保格式正确：
   ```bash
   git commit -m "$(cat <<'EOF'
   <commit 消息内容>

   🤖 Generated with Claude Code (https://claude.com/claude-code)
   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
   EOF
   )"
   ```
5. **中文优先**：所有 commit 消息使用中文描述（除了 conventional commits 的类型前缀）

## 执行示例

用户运行 `/beautify-commit` 后：

1. 检查配置文件，如果不存在则询问风格偏好
2. 并行获取 git 信息
3. 分析变更内容
4. 根据风格生成 commit 消息
5. 执行 git add 和 git commit
6. 显示 commit 结果
