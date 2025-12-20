# SkillForge 2.0

完整的Claude Code插件开发生命周期管理系统

## 概述

SkillForge是一个元插件，用于创建、管理和发布Claude Code插件。它提供自动初始化、即时测试和一键发布功能。

## 核心特性

### 零摩擦开发
- 自然语言命令创建完整插件结构
- 自动初始化，无需手动设置
- 90%组件立即可测试（skills/agents/hooks）
- 10%组件需要安装（commands）

### 自动脚手架
- 首次创建组件时自动初始化插件结构
- 从init-plugin知识库读取标准结构
- 一次性询问插件名称
- 创建完整的目录和配置文件

### 简化发布
- 一条命令同步到marketplace
- 自动验证插件结构
- 自动化git操作（commit + push）
- 智能生成commit消息

## 安装

```bash
# 添加marketplace
/plugin marketplace add <marketplace-url>

# 安装SkillForge
/plugin install skillforge
```

## 快速开始

### 1. 首次设置

```
用户: "设置SkillForge"
```

SkillForge会询问：
- 是否已有marketplace？
- Marketplace路径
- 作者信息

配置保存到 `~/.skillforge-config`

### 2. 创建第一个Skill

```
用户: "创建一个reddit-upvote skill"
```

SkillForge会：
1. 检测无插件结构
2. 询问插件名称
3. 创建 .claude/ 目录结构
4. 创建skill文件在 .claude/skills/
5. Skill立即可用

### 3. 添加更多组件

```
用户: "创建reddit-comment skill"
用户: "创建git-helper agent"
用户: "添加auto-format hook"
```

所有组件立即可用，无需安装。

### 4. 创建Command（需要安装）

```
用户: "创建status command"
```

SkillForge会显示安装步骤：
```
/plugin marketplace add ./.claude
/plugin install {plugin-name}@local
/{command-name}
```

### 5. 发布到Marketplace

```
用户: "同步到marketplace"
```

SkillForge会：
1. 检查 .claude/ 目录
2. 创建 {plugin-name}-dev/ 打包目录
3. 从 .claude/* 复制到 {plugin-name}-dev/*
4. 验证插件结构
5. 询问版本号
6. 复制到marketplace
7. 自动commit和push

## 组件说明

### Skills (9个)

| Skill | 描述 | 用户调用 |
|-------|------|---------|
| global-setup | 配置marketplace | 是 |
| init-plugin | 插件结构知识库 | 否（仅供引用） |
| create-skill | 创建skill | 是 |
| create-agent | 创建agent | 是 |
| create-command | 创建command | 是 |
| create-hook | 创建hook | 是 |
| update-skill | 更新skill | 是 |
| update-agent | 更新agent | 是 |
| sync-to-marketplace | 发布插件 | 是 |

### Agents (2个)

| Agent | 描述 | 调用方式 |
|-------|------|---------|
| workspace-validator | 验证插件结构 | 由sync-to-marketplace调用 |
| marketplace-publisher | 执行git操作 | 由sync-to-marketplace调用 |

## 插件结构

### 开发工作目录（.claude/）
开发时所有组件都创建在这里，可立即测试：

```
.claude/
├── skills/                  # 立即可用
│   └── {skill-name}/
│       └── SKILL.md
├── agents/                  # 立即可用
│   └── {agent-name}.md
├── commands/                # 需要本地安装
│   └── {command-name}.md
└── hooks/                   # 立即可用
    └── hooks.json
```

### 发布打包目录（{plugin-name}-dev/）
sync-to-marketplace 时创建，用于发布：

```
{plugin-name}-dev/
├── .claude-plugin/
│   └── plugin.json          # 插件元数据
├── skills/                  # 从 .claude/skills/ 复制
│   └── {skill-name}/
│       └── SKILL.md
├── agents/                  # 从 .claude/agents/ 复制
│   └── {agent-name}.md
├── commands/                # 从 .claude/commands/ 复制
│   └── {command-name}.md
├── hooks/                   # 从 .claude/hooks/ 复制
│   └── hooks.json
├── .skillforge-meta        # SkillForge元数据
├── .gitignore
└── README.md
```

## 工作流程示例

### 完整工作流：从零到发布

```
# 步骤1: 设置SkillForge
用户: "设置SkillForge"
→ 配置marketplace路径和作者信息

# 步骤2: 创建第一个skill（自动初始化插件）
用户: "创建reddit-upvote skill"
→ 询问插件名称: reddit-automation
→ 创建 .claude/ 目录结构
→ 创建skill文件在 .claude/skills/
→ ✅ Skill立即可用

# 步骤3: 添加更多组件
用户: "创建reddit-comment skill"
→ ✅ 立即可用

用户: "创建git-helper agent"
→ ✅ 立即可用

用户: "添加PostToolUse hook"
→ ✅ 立即生效

# 步骤4: 创建command（需要安装测试）
用户: "创建status command"
→ 显示安装步骤
→ 用户手动安装测试

# 步骤5: 发布
用户: "同步到marketplace"
→ 创建 {plugin-name}-dev/ 打包目录
→ 从 .claude/* 复制到 {plugin-name}-dev/*
→ 验证结构
→ 询问版本号
→ 复制到marketplace
→ Git commit + push
→ ✅ 发布完成
```

## 设计原则

### 1. 用户输入是神圣的
- 完全按用户提供的内容使用
- 不做自动修正或建议
- 不添加"智能"或假设
- 仅验证关键错误

### 2. 自动脚手架
- 用户永远不需要手动初始化
- 需要时自动创建插件结构
- 从init-plugin知识库引用
- 对用户透明

### 3. 即时反馈
- Skills/agents/hooks: 立即工作
- Commands: 清晰的安装说明
- 验证: 详细的错误报告
- Git操作: 显示commit hash

### 4. 关注点分离
- Skills: 用户面向的命令
- Subagents: 复杂的隔离操作
- Knowledge skills: 仅供引用
- Scripts: 外部自动化

### 5. 渐进式披露
- 从简单开始（一个skill）
- 自然增长（添加组件）
- 准备好时发布（一条命令）
- 无需前期承诺

## 模板

SkillForge包含以下模板：

- `plugin.json` - 插件配置
- `SKILL.md` - Skill模板
- `agent.md` - Agent模板
- `command.md` - Command模板
- `hooks.json` - Hooks配置
- `skillforge-meta.json` - 元数据
- `gitignore-root` - 项目根.gitignore
- `gitignore-plugin` - 插件.gitignore
- `README.md` - 插件README

## 脚本

### create-marketplace.sh

创建新的Claude Code插件marketplace。

用法：
```bash
./scripts/create-marketplace.sh <路径> <名称> <所有者>
```

功能：
- 创建marketplace目录结构
- 初始化git仓库
- 创建初始commit
- 提供后续步骤指导

## 故障排除

### 未找到marketplace配置

错误: "请先运行global-setup"

解决:
```
用户: "设置SkillForge"
```

### 验证失败

SkillForge会显示详细的错误报告，包括：
- 文件路径
- 行号
- 具体问题

修复错误后重新同步。

### Git推送失败

常见原因：
- 未配置git凭据
- 无remote
- 认证失败
- 非快进推送

SkillForge会显示具体错误和解决方案。

### 未找到插件结构

如果在错误的目录：
```
错误: "未找到 .claude/ 目录。创建一个skill开始。"
```

解决: 创建任何组件，SkillForge会自动初始化。

## 版本历史

### 2.0.0 (当前)
- 完全重构为skills架构
- 添加自动脚手架
- 添加subagents用于验证和发布
- 改进模板系统
- 添加全面的文档

### 1.0.0
- 初始版本
- 基于commands的架构

## 许可

MIT License
