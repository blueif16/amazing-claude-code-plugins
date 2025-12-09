# Claude Code 插件市场

这是一个包含实用中文插件的 Claude Code 插件市场。

## 包含的插件

### Beautify Commit

美化 Git Commit 消息的中文工具，让你的提交记录更加优雅、规范或可爱！

**功能特点:**
- 🎨 多种风格：支持正常、详细、简洁、可爱四种 commit 风格
- 🇨🇳 中文优先：所有提示和消息都使用中文
- 💾 记住偏好：首次选择风格后自动保存
- 🤖 智能分析：自动分析代码变更，生成合适的 commit 消息
- ✨ 二次元风格：可爱风格使用精选的二次元 emoji 和颜文字

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

# 重启 Claude Code 后使用
/beautify-commit
```

### 方法 2: 从 GitHub 安装

```bash
# 添加 GitHub marketplace
/plugin marketplace add yourusername/plugin-market-marketplace

# 安装插件
/plugin install beautify-commit@plugin-market-marketplace
```

## 使用插件

安装完成后，在你的项目中运行：

```bash
/beautify-commit
```

首次使用时会询问你喜欢的 commit 风格，之后会自动记住你的选择。

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
