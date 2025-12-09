# Beautify Commit

美化 Git Commit 消息的中文工具，让你的提交记录更加优雅、规范或可爱！

## 功能特点

- 🎨 **多种风格**：支持正常、详细、简洁、可爱四种 commit 风格
- 🇨🇳 **中文优先**：所有提示和消息都使用中文
- 💾 **记住偏好**：首次选择风格后自动保存，无需每次重新选择
- 🤖 **智能分析**：自动分析代码变更，生成合适的 commit 消息
- ✨ **二次元风格**：可爱风格使用精选的二次元 emoji 和颜文字

## 安装

将此插件复制到你的 Claude Code 插件目录：

```bash
# 复制到项目的 .claude-plugin 目录
cp -r beautify-commit /path/to/your/project/.claude-plugin/

# 或者安装到全局插件目录
cp -r beautify-commit ~/.claude/plugins/
```

## 使用方法

在你的项目中运行：

```bash
/beautify-commit
```

### 首次使用

首次运行时，会询问你喜欢的 commit 风格：

- **正常** - 标准的 Conventional Commits 格式（feat/fix/docs 等）
- **详细** - 包含详细说明和影响范围的多行 commit
- **简洁** - 简短精炼的一句话描述
- **可爱** - 使用可爱 emoji 和二次元风格的语气

选择后会自动保存到 `.claude/beautify-commit.local.md`，之后每次运行都会使用你选择的风格。

### 风格示例

#### 正常风格
```
feat: 添加用户登录功能
fix: 修复购物车计算错误
docs: 更新 API 文档
```

#### 详细风格
```
feat: 添加用户登录功能

实现了基于 JWT 的用户认证系统，包括登录、注册和密码重置功能。
使用 bcrypt 加密存储密码，确保用户数据安全。

影响范围：
- 用户认证模块
- API 路由
- 数据库 schema
```

#### 简洁风格
```
添加用户登录功能
修复购物车计算错误
优化数据库查询性能
```

#### 可爱风格
```
✨ 哇！新增了超棒的登录功能呢~ (๑•̀ㅂ•́)و✧
🔧 修好了购物车的小bug啦！(｡･ω･｡)ﾉ♡
🌸 让界面变得更可爱了呢~ ✧*｡٩(ˊᗜˋ*)و✧*｡
⚡ 性能提升！现在快得飞起~ ₍₍ ◝(●˙꒳˙●)◜ ₎₎
```

## 配置

插件会在 `.claude/beautify-commit.local.md` 中保存你的风格偏好。

如果想更改风格，可以：
1. 删除配置文件，下次运行时重新选择
2. 或直接编辑配置文件中的 `style` 字段

配置文件格式：
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

## 工作原理

1. 检查并加载用户的风格配置
2. 分析当前 git 状态和变更内容
3. 学习仓库的 commit 历史风格
4. 根据选择的风格生成合适的 commit 消息
5. 自动 stage 文件并创建 commit

## 安全特性

- 自动排除敏感文件（.env, credentials.json 等）
- 不会 commit 包含密钥的文件
- 所有操作都在本地执行

## 版本

当前版本：0.1.0

## 作者

Created with Claude Code

## 许可

MIT License
