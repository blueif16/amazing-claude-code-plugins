---
name: update-skill
description: 修改现有的 Claude Code 命令。当用户想要编辑、更新、修改或改进命令时使用。
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Glob
  - AskUserQuestion
---

# SkillForge: 更新命令

智能更新现有的 Claude Code 命令。

## 工作流程

### 第一步：定位命令

```bash
# 查找 marketplace 位置
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

# 查找命令文件
COMMAND_PATH=$(find "$MARKETPLACE_PATH" -type f -name "$COMMAND_NAME.md" -path "*/commands/*")

if [ -z "$COMMAND_PATH" ]; then
  echo "❌ 未找到命令: $COMMAND_NAME"
  exit 1
fi

echo "✅ 找到命令: $COMMAND_PATH"
```

### 第二步：读取当前内容

使用 Read 工具获取当前命令文件的内容。

### 第三步：应用更新

根据用户请求进行相应的更新：

- **添加说明** → 追加到 ## 执行流程 部分
- **更新描述** → 修改 YAML frontmatter
- **添加工具** → 更新 allowed-tools 字段
- **添加示例** → 追加到 ## 示例 部分
- **修改步骤** → 编辑相应的步骤内容

使用 Edit 工具进行精确修改，或使用 Write 工具完全重写。

### 第四步：验证 YAML

确保编辑后的 frontmatter 仍然有效：
- name 字段存在且有效
- description 字段存在
- allowed-tools 格式正确（如果存在）

### 第五步：确认更新

```bash
echo "✅ 命令已更新: $COMMAND_NAME"
echo "📝 已应用更改"
echo ""
echo "使用 'sync-marketplace' 发布更改"
```

## 智能更新模式

根据用户的更新请求，自动识别更新类型：

1. **功能增强** - 添加新的执行步骤或功能
2. **错误修复** - 修正现有逻辑或说明
3. **文档改进** - 更新示例或最佳实践
4. **工具调整** - 添加或移除所需工具

## 错误处理

- **命令未找到** → 提供创建新命令的选项
- **YAML 格式错误** → 自动修复或提示用户
- **冲突的更改** → 询问用户如何处理

## 中文支持

- 所有操作提示使用中文
- 支持中文内容的编辑
- 保持原有的中文格式和风格
