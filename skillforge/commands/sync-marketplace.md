---
name: sync-marketplace
description: 将 marketplace 更改提交并推送到 Git。当用户想要发布、同步、推送或保存 marketplace 更改时使用。
allowed-tools:
  - Bash
  - Read
  - Glob
---

# SkillForge: 同步 Marketplace

通过 Git 发布 marketplace 的更改。

## 工作流程

### 第一步：查找 Marketplace

```bash
# 自动发现 marketplace 位置
CURRENT_DIR=$(pwd)
MARKETPLACE_PATH=""

for i in {1..3}; do
  PARENT=$(dirname "$CURRENT_DIR")
  MARKETPLACE_JSON=$(find "$PARENT" -maxdepth 3 -name "marketplace.json" -path "*/.claude-plugin/*" 2>/dev/null | head -1)

  if [ -n "$MARKETPLACE_JSON" ]; then
    MARKETPLACE_PATH=$(dirname $(dirname "$MARKETPLACE_JSON"))
    break
  fi

  CURRENT_DIR="$PARENT"
done

if [ -z "$MARKETPLACE_PATH" ]; then
  echo "❌ 未找到 Marketplace"
  exit 1
fi

cd "$MARKETPLACE_PATH"
```

### 第二步：检查 Git 状态

```bash
if [ ! -d .git ]; then
  echo "❌ 不是 Git 仓库。使用以下命令初始化: git init"
  exit 1
fi

echo "📊 Git 状态："
git status --short
```

### 第三步：暂存更改

```bash
# 暂存所有更改
git add -A

# 显示将要提交的更改
echo ""
echo "📝 将要提交的更改："
git diff --cached --name-status
```

### 第四步：生成提交消息

分析更改并创建语义化的提交消息：

```bash
CHANGES=$(git diff --cached --name-status)

if [[ "$CHANGES" == *"commands/"* ]]; then
  if [[ "$CHANGES" == *"A	"* ]]; then
    # 新增命令
    NEW_COMMAND=$(basename $(git diff --cached --name-only | grep "commands/.*\.md" | head -1) .md)
    COMMIT_MSG="feat: 添加 $NEW_COMMAND 命令"
  elif [[ "$CHANGES" == *"M	"* ]]; then
    # 修改命令
    MODIFIED_COUNT=$(git diff --cached --name-only | grep "commands/.*\.md" | wc -l | tr -d ' ')
    COMMIT_MSG="update: 修改 $MODIFIED_COUNT 个命令"
  elif [[ "$CHANGES" == *"D	"* ]]; then
    # 删除命令
    COMMIT_MSG="remove: 删除命令"
  fi
else
  COMMIT_MSG="chore: 更新 marketplace"
fi
```

### 第五步：提交更改

```bash
git commit -m "$COMMIT_MSG

🤖 Generated with Claude Code (https://claude.com/claude-code)
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

### 第六步：推送到远程

```bash
CURRENT_BRANCH=$(git branch --show-current)
git push origin "$CURRENT_BRANCH"
```

### 第七步：处理错误

**合并冲突**：
```bash
if [ $? -ne 0 ]; then
  echo "⚠️ 推送被拒绝，正在拉取更改..."
  git pull --rebase
  git push origin "$CURRENT_BRANCH"
fi
```

**认证失败**：
如果推送因认证错误失败：
```bash
echo "❌ 认证失败"
echo "💡 配置 Git 凭据："
echo "   SSH: ssh-add ~/.ssh/id_rsa"
echo "   HTTPS: git config --global credential.helper store"
```

### 第八步：确认同步

```bash
echo "✅ Marketplace 同步成功"
echo "🌐 已推送到: $(git remote get-url origin)"
echo "📦 分支: $CURRENT_BRANCH"
echo ""
echo "📝 使用更新的命令："
echo "   /plugin marketplace update"
echo "   /plugin uninstall <插件名>"
echo "   /plugin install <插件名>"
```

## 智能提交消息

根据更改类型自动生成合适的提交消息：

- **新增命令** → `feat: 添加 <命令名> 命令`
- **修改命令** → `update: 修改 <数量> 个命令`
- **删除命令** → `remove: 删除 <命令名> 命令`
- **插件配置** → `config: 更新插件配置`
- **文档更新** → `docs: 更新文档`
- **其他更改** → `chore: 更新 marketplace`

## 错误处理

- **未初始化 Git** → 提供初始化指导
- **无更改** → 提示没有需要提交的内容
- **推送冲突** → 自动尝试 rebase 并重新推送
- **认证问题** → 提供配置凭据的帮助

## 中文支持

- 所有提示和错误消息使用中文
- 提交消息使用中文描述
- 保持 Git 操作的标准格式
