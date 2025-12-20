---
name: sync-to-marketplace
description: 将插件发布到marketplace
allowed-tools: Read, Write, Bash, Task
---

# 同步到Marketplace

## 目的
将插件发布到配置的marketplace，包含验证和git自动化。

## 执行逻辑

### 1. 读取配置

1. 读取 `~/.skillforge-config` 获取marketplace路径
2. 如果未找到 → 错误："请先运行global-setup"

### 2. 检查 .claude/ 目录

1. 检查当前目录是否存在 `.claude/` 目录
2. 如果未找到 → 错误："未找到 .claude/ 目录，请先创建组件"

### 3. 创建打包目录

1. 询问："插件名称？"（如果尚未设置）
2. 创建 `{plugin-name}-dev/` 目录结构：
   - .claude-plugin/plugin.json
   - skills/
   - agents/
   - commands/
   - hooks/
   - .gitignore
   - README.md
   - .skillforge-meta

### 4. 复制组件从 .claude/ 到 {plugin-name}-dev/

1. 复制 .claude/skills/* → {plugin-name}-dev/skills/
2. 复制 .claude/agents/* → {plugin-name}-dev/agents/
3. 复制 .claude/commands/* → {plugin-name}-dev/commands/
4. 复制 .claude/hooks/* → {plugin-name}-dev/hooks/

### 5. 调用验证subagent

1. 使用Task工具调用 workspace-validator subagent
2. 传递 {plugin-name}-dev 路径
3. 接收验证报告
4. 如果有错误 → 显示并停止

### 6. 询问版本号

1. 读取当前版本（从 {plugin-name}-dev/.claude-plugin/plugin.json）
2. 询问："当前版本是 X.X.X，新版本应该是？"
3. 验证semver格式
4. 更新 plugin.json 和 .skillforge-meta

### 7. 同步到marketplace

1. 复制 {plugin-name}-dev/* 到 marketplace/plugins/{plugin-name}/
2. 更新版本号

### 8. 调用发布subagent

1. 使用Task工具调用 marketplace-publisher subagent
2. 传递marketplace路径和插件名称
3. Subagent处理所有git操作
4. 接收结果

### 9. 显示成功消息

```
✅ 插件已同步到marketplace
📦 版本: 0.2.0
📁 打包目录: ./{plugin-name}-dev/
📁 Marketplace位置: {marketplace-path}/plugins/{plugin-name}/
🔄 Git commit: abc1234
🚀 已推送到remote

其他人可以这样安装:
  /plugin marketplace add <your-repo-url>
  /plugin install {plugin-name}@<marketplace-name>
```

## 错误处理

- 无marketplace配置 → 引导运行global-setup
- 未找到 .claude/ 目录 → 提示先创建组件
- 验证错误 → 显示详细报告
- Git错误 → 显示并建议修复
- 无变更检测 → 通知用户

## 工作流说明

此skill实现了关键的架构转换：
1. 开发在 .claude/ 进行（立即可用）
2. sync-to-marketplace 创建 {plugin-name}-dev/（打包产物）
3. 从 .claude/* 复制到 {plugin-name}-dev/*
4. 验证 {plugin-name}-dev/ 内容
5. 同步到 marketplace

## Subagent调用示例

```
Task(
  subagent_type="workspace-validator",
  prompt="验证插件: ./{plugin-name}-dev"
)

Task(
  subagent_type="marketplace-publisher",
  prompt="发布插件 {plugin-name} 到 {marketplace-path}"
)
```
