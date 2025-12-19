---
name: skillforge-knowledge
description: Claude Code 命令编写的最佳实践知识库。在创建或更新命令时参考，以确保质量。
---

# SkillForge 知识库

创建高质量 Claude Code 命令的最佳实践和模式。

## 命令结构

### YAML Frontmatter

```yaml
---
name: command-name              # 必需：小写，仅使用连字符
description: 简短描述           # 必需：说明功能和使用场景
allowed-tools: Read, Write      # 可选：指定工具或省略以使用所有工具
---
```

### 描述最佳实践

描述应包含**功能**和**使用场景**：

- ❌ 不好: "处理文件"
- ✅ 好: "读取和处理 CSV 文件。在处理表格数据时使用。"

包含用户可能使用的触发关键词：
- "点赞"、"投票" 用于 reddit-upvote
- "评论"、"回复" 用于 reddit-comment
- "浏览"、"滚动" 用于 reddit-browse

## 工具选择指南

| 任务类型 | 推荐工具 |
|---------|---------|
| 仅读取文件 | `Read, Grep, Glob` |
| 修改文件 | `Read, Edit, Write` |
| 完全自动化 | 省略 `allowed-tools`（继承所有工具） |
| 搜索代码库 | `Read, Grep, Glob` |
| 运行命令 | `Bash` |
| 询问用户 | `AskUserQuestion` |

## 常见模式

### 模式 1: 文件处理命令

适用于需要读取、处理和写入文件的命令。

```markdown
---
name: process-csv
description: 处理 CSV 文件并生成报告
allowed-tools: Read, Write, Bash
---

## 执行流程

### 第一步：读取输入文件
使用 Read 工具读取 CSV 文件内容

### 第二步：处理数据
解析 CSV 内容并进行必要的转换

### 第三步：生成输出
使用 Write 工具创建处理后的文件
```

### 模式 2: Git 操作命令

适用于需要执行 Git 操作的命令。

```markdown
---
name: git-operation
description: 执行 Git 相关操作
allowed-tools:
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git status:*)
---

## 执行流程

### 第一步：检查 Git 状态
```bash
git status
```

### 第二步：执行操作
根据需求执行相应的 Git 命令

### 第三步：确认结果
验证操作是否成功完成
```

### 模式 3: 交互式命令

适用于需要用户输入的命令。

```markdown
---
name: interactive-command
description: 需要用户选择的交互式命令
allowed-tools: AskUserQuestion, Read, Write
---

## 执行流程

### 第一步：询问用户偏好
使用 AskUserQuestion 工具获取用户选择

### 第二步：根据选择执行
基于用户输入执行相应操作

### 第三步：保存配置（可选）
将用户偏好保存到配置文件
```

## 渐进式披露

对于复杂的命令，创建额外的文件：

```
my-command/
├── my-command.md       # 核心说明
├── reference.md        # 详细文档
└── examples/
    └── advanced.md     # 高级示例
```

Claude 仅在需要时加载额外文件。

## 命名约定

### 命令名称
- 使用小写字母和连字符
- 描述性且简洁
- 反映命令的主要功能

示例：
- ✅ `beautify-commit`
- ✅ `create-skill`
- ✅ `sync-marketplace`
- ❌ `beautifyCommit`（不要使用驼峰命名）
- ❌ `create_skill`（不要使用下划线）

### 文件组织
- 主命令文件：`commands/<command-name>.md`
- 辅助脚本：`commands/<command-name>/scripts/`
- 模板文件：`commands/<command-name>/templates/`
- 参考文档：`commands/<command-name>/reference/`
- 示例：`commands/<command-name>/examples/`

## 错误处理

### 基本原则
- 预见常见错误场景
- 提供清晰的错误消息
- 给出解决方案或下一步建议

### 示例

```markdown
## 错误处理

- **文件不存在** → 提示用户检查文件路径
- **权限不足** → 说明需要的权限并提供解决方法
- **格式错误** → 显示正确的格式示例
```

## 中文支持最佳实践

1. **所有用户可见的文本使用中文**
   - 提示消息
   - 错误信息
   - 帮助文本

2. **保持技术术语的准确性**
   - Git 命令保持英文
   - 工具名称保持英文
   - 技术概念可以中英文混用

3. **示例代码中的注释使用中文**
   ```bash
   # 检查 Git 状态
   git status

   # 暂存所有更改
   git add -A
   ```

## 性能优化

1. **并行执行独立操作**
   ```markdown
   使用多个工具调用并行执行：
   - 读取多个文件
   - 执行多个独立的 Git 命令
   ```

2. **避免不必要的文件读取**
   - 只读取需要的文件
   - 使用 Glob 和 Grep 精确定位

3. **缓存用户配置**
   - 将用户偏好保存到配置文件
   - 避免重复询问相同的问题

## 测试建议

创建命令后，测试以下场景：
1. 正常使用流程
2. 边缘情况（空文件、特殊字符等）
3. 错误场景（文件不存在、权限问题等）
4. 用户取消操作
5. 并发执行（如果适用）
