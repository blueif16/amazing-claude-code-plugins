---
name: create-skill
description: 创建新的 Claude Code 命令，包含完整的结构和模板。当用户想要创建、生成或搭建新命令时使用。
allowed-tools:
  - Write
  - Bash
  - Read
  - Glob
  - AskUserQuestion
---

# SkillForge: 创建命令

在 marketplace 中创建新的 Claude Code 命令，遵循最佳实践。

## 工作流程

### 第一步：查找 Marketplace 位置

自动发现 marketplace 的位置：

```bash
# 从当前目录向上搜索，查找 marketplace.json
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
  echo "❌ 未找到 Marketplace。请确保项目和 marketplace 在同一父目录下。"
  exit 1
fi

echo "✅ Marketplace 位置: $MARKETPLACE_PATH"
```

### 第二步：确定目标插件

```bash
# 列出可用插件（排除 skillforge）
PLUGINS=$(find "$MARKETPLACE_PATH" -maxdepth 1 -type d ! -name "amazing-claude-code-plugins" ! -name "skillforge" ! -name ".*" -exec basename {} \;)

# 如果只有一个插件，直接使用；否则询问用户
if [ $(echo "$PLUGINS" | wc -l) -eq 1 ]; then
  TARGET_PLUGIN="$PLUGINS"
else
  echo "可用插件："
  echo "$PLUGINS"
  # 使用 AskUserQuestion 询问用户选择哪个插件
fi
```

### 第三步：验证命令名称

命令名称必须符合以下规则：
- 只能使用小写字母和连字符
- 不能包含下划线、空格或特殊字符
- 最多 64 个字符
- 不能与已存在的命令重名

### 第四步：创建命令结构

```bash
COMMAND_PATH="$MARKETPLACE_PATH/$TARGET_PLUGIN/commands"
mkdir -p "$COMMAND_PATH"
```

### 第五步：从模板生成命令文件

使用内置模板创建 `<command-name>.md` 文件：

```markdown
---
name: {{COMMAND_NAME}}
description: {{DESCRIPTION}}
allowed-tools: {{TOOLS}}
---

# {{COMMAND_TITLE}}

{{SUMMARY}}

## 执行流程

### 第一步：{{STEP_1}}

{{STEP_1_DETAILS}}

### 第二步：{{STEP_2}}

{{STEP_2_DETAILS}}

## 最佳实践

- 使用清晰、描述性的变量名
- 为边缘情况添加错误处理
- 为复杂操作提供示例

## 示例

**示例 1**: 基本用法

输入: {{EXAMPLE_INPUT}}
输出: {{EXAMPLE_OUTPUT}}
```

### 第六步：智能建议

根据命令名称和描述，自动建议：
- 合适的工具（文件操作 → Read/Write，搜索 → Grep/Glob）
- 常见模式（认证、数据处理、浏览器自动化）
- 相关示例

### 第七步：确认创建

```bash
echo "✅ 命令已创建: $COMMAND_PATH/<command-name>.md"
echo ""
echo "📝 后续步骤："
echo "1. 检查并编辑命令文件"
echo "2. 使用 'sync-marketplace' 发布"
echo "3. 重新安装插件进行测试"
```

## 错误处理

- **Marketplace 未找到** → 引导用户检查目录结构
- **命令已存在** → 提供更新选项
- **无效名称** → 说明命名规则

## 智能提示

根据用户输入的命令描述，自动推断：
- 需要的工具权限
- 可能的执行步骤
- 相关的最佳实践

## 中文支持

- 所有提示和错误消息使用中文
- 支持中文命令描述
- 生成的模板包含中文注释
