---
name: create-command
description: 创建新的slash command，如果需要会自动初始化插件结构
allowed-tools: Write, Read, Bash, Glob
---

# 创建Command

## 目的
创建新的slash command文件，如果插件结构不存在则自动初始化。

## 执行逻辑

### 1. 检查插件结构

```
检查当前目录是否存在 .claude/ 目录
├─ 找到 → 继续到步骤3
└─ 未找到 → 进入步骤2（同create-skill的自动初始化）
```

### 2. 自动初始化插件（如需要）

与create-skill相同的初始化流程。

### 3. 收集command信息

询问用户：
1. "Command名称？" （验证：小写、字母数字）
2. "描述？"

### 4. 创建command

1. 创建文件: `.claude/commands/{command-name}.md`
2. 从模板生成内容
3. 显示安装说明

## 验证规则

- Command名称格式: `^[a-z0-9-]+$`
- 名称中不能有斜杠
- 不与内置命令冲突

## 成功输出

```
✅ Command已创建: /{command-name}
📁 位置: ./.claude/commands/{command-name}.md

⚠️ Commands需要本地安装才能测试:

1. 添加本地marketplace:
   /plugin marketplace add ./.claude

2. 安装插件:
   /plugin install {plugin-name}@local

3. 测试命令:
   /{command-name}

4. 更新后重新安装:
   /plugin uninstall {plugin-name}@local
   /plugin install {plugin-name}@local
```

## 为什么Commands需要安装？

Commands是slash命令（如 /commit, /help），它们需要注册到Claude Code系统中。
与skills/agents/hooks不同，commands不能直接从文件系统读取使用。

## 示例

用户: "创建一个status command"

执行流程:
1. 检查 .claude/ → 找到
2. 询问command信息:
   - 名称: status
   - 描述: 显示当前插件状态
3. 创建 .claude/commands/status.md
4. 显示安装说明
