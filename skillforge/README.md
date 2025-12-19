# SkillForge - 命令创建工具

自管理的 Claude Code 插件，用于命令的创建、更新和发布。

## 功能特点

- **create-skill** - 使用模板生成新命令
- **update-skill** - 智能修改现有命令
- **sync-marketplace** - 通过 Git 发布更改
- **skillforge-knowledge** - 最佳实践知识库

## 安装方法

```bash
# 添加本地 marketplace
/plugin marketplace add /path/to/amazing-claude-code-plugins

# 安装 skillforge 插件
/plugin install skillforge@plugin-market-marketplace
```

## 使用方法

只需描述你的需求：

- "创建一个名为 reddit-upvote 的新命令"
- "更新 reddit-comment 命令，添加延迟功能"
- "同步我的更改到 marketplace"

SkillForge 会自动处理所有操作。

## 命令说明

### /create-skill

创建新的 Claude Code 命令。

**使用场景**：
- 需要添加新功能到插件
- 想要快速搭建命令框架
- 需要遵循最佳实践

**工作流程**：
1. 自动查找 marketplace 位置
2. 选择目标插件
3. 验证命令名称
4. 从模板生成命令文件
5. 提供后续步骤指导

### /update-skill

修改现有命令。

**使用场景**：
- 需要添加新功能
- 修复错误或改进逻辑
- 更新文档或示例

**支持的更新类型**：
- 添加执行步骤
- 修改描述和配置
- 更新工具权限
- 添加示例和最佳实践

### /sync-marketplace

将更改发布到 Git。

**使用场景**：
- 完成命令开发后发布
- 需要备份更改
- 与团队共享更新

**自动处理**：
- 智能生成提交消息
- 处理合并冲突
- 推送到远程仓库

### /skillforge-knowledge

查看命令编写的最佳实践。

**包含内容**：
- 命令结构规范
- 工具选择指南
- 常见模式和示例
- 错误处理建议
- 性能优化技巧

## 目录结构

```
skillforge/
├── .claude-plugin/
│   └── plugin.json                    # 插件配置
├── commands/
│   ├── create-skill.md                # 创建命令
│   ├── update-skill.md                # 更新命令
│   ├── sync-marketplace.md            # 同步命令
│   ├── skillforge-knowledge.md        # 知识库
│   └── create-skill/
│       ├── scripts/
│       │   └── find-marketplace.sh    # 查找 marketplace 脚本
│       └── templates/
│           └── command-template.md    # 命令模板
└── README.md                          # 本文件
```

## 要求

- 项目和 marketplace 必须在同一父目录下
- Marketplace 必须是 Git 仓库
- 需要配置 Git 凭据以推送更改

## 最佳实践

1. **命名规范**
   - 使用小写字母和连字符
   - 描述性且简洁
   - 反映主要功能

2. **描述编写**
   - 说明功能和使用场景
   - 包含触发关键词
   - 保持简洁明了

3. **工具选择**
   - 只请求必需的工具
   - 考虑安全性
   - 参考知识库指南

4. **中文支持**
   - 所有用户可见文本使用中文
   - 保持技术术语准确性
   - 代码注释使用中文

## 示例工作流

### 创建新命令

```bash
# 1. 运行创建命令
/create-skill

# 2. 按提示输入信息
命令名称: my-awesome-command
描述: 执行某个很棒的功能
工具: Read, Write, Bash

# 3. 编辑生成的命令文件
# 4. 测试命令
# 5. 同步到 marketplace
/sync-marketplace
```

### 更新现有命令

```bash
# 1. 运行更新命令
/update-skill

# 2. 指定要更新的命令
命令名称: my-awesome-command

# 3. 描述需要的更改
添加错误处理和新的示例

# 4. 同步更改
/sync-marketplace
```

## 故障排除

### Marketplace 未找到

确保：
- 项目和 marketplace 在同一父目录下
- Marketplace 包含 `.claude-plugin/marketplace.json`
- 目录结构正确

### Git 推送失败

检查：
- Git 凭据是否配置
- 远程仓库是否可访问
- 是否有推送权限

### 命令未生效

尝试：
```bash
/plugin marketplace update
/plugin uninstall skillforge
/plugin install skillforge@plugin-market-marketplace
```

## 版本

当前版本：1.0.0

## 许可

MIT License
