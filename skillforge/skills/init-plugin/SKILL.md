---
name: init-plugin
description: 插件结构知识库（仅供其他skills引用，不直接调用）
allowed-tools:
---

# 插件结构知识库

## 目的
此skill是知识库，供其他skills引用。不应被用户直接调用。

## 插件目录结构

```
{plugin-name}-dev/
├── .claude-plugin/
│   └── plugin.json          # 插件元数据
├── skills/                  # 立即可用的skills
│   └── {skill-name}/
│       └── SKILL.md
├── agents/                  # 立即可用的agents
│   └── {agent-name}.md
├── commands/                # 需要安装才能使用
│   └── {command-name}.md
├── hooks/                   # 立即可用的hooks
│   └── hooks.json
├── .skillforge-meta        # SkillForge元数据
├── .gitignore
└── README.md
```

## plugin.json 结构

```json
{
  "name": "插件名称（小写，连字符）",
  "description": "插件描述",
  "version": "0.1.0",
  "author": {
    "name": "作者名称"
  }
}
```

## SKILL.md 模板

```markdown
---
name: skill-name
description: skill描述
allowed-tools: Tool1, Tool2
---

# Skill标题

## 说明

[你的说明]

## 示例

[你的示例]
```

## Agent .md 模板

```markdown
---
name: agent-name
description: agent描述
tools: Tool1, Tool2
model: sonnet
---

# Agent标题

[你的agent说明]
```

## Command .md 模板

```markdown
---
description: 命令描述
---

# /command-name

[当用户输入 /command-name 时Claude的说明]
```

## hooks.json 模板

```json
{
  "hooks": {
    "PreToolUse": [],
    "PostToolUse": [],
    "PermissionRequest": [],
    "UserPromptSubmit": [],
    "Notification": [],
    "Stop": [],
    "SubagentStop": []
  }
}
```

## .skillforge-meta 模板

```json
{
  "pluginName": "plugin-name",
  "version": "0.1.0",
  "createdAt": "2025-01-15T00:00:00.000Z",
  "lastSync": null
}
```

## .gitignore (项目根目录)

```
{plugin-name}-dev/
.DS_Store
*.log
```

## .gitignore (plugin-dev目录)

```
.DS_Store
*.log
.skillforge-meta
```

## README.md 模板

```markdown
# {plugin-name}

{description}

## 安装

\`\`\`
/plugin marketplace add <marketplace-url>
/plugin install {plugin-name}
\`\`\`

## 使用

[文档]
```

## 验证规则

### 关键验证
- YAML frontmatter: 必须以 --- 开始和结束
- Skill名称: 仅小写字母、数字、连字符
- 必需字段: name, description
- 版本格式: 遵循semver (x.y.z)

### 文件命名
- 仅小写字母
- 无特殊字符（连字符除外）
- 目录名与文件名一致

## 组件类型说明

### 立即可用（无需安装）
- **Skills**: 创建后立即可在当前会话使用
- **Agents**: 创建后立即可在/agents菜单使用
- **Hooks**: 创建后立即生效

### 需要安装
- **Commands**: 必须通过本地marketplace安装后才能使用
  1. `/plugin marketplace add ./{plugin-name}-dev`
  2. `/plugin install {plugin-name}-dev@local`
  3. 测试: `/{command-name}`
