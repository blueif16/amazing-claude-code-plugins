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

### 2. 调用验证subagent

1. 使用Task工具调用 workspace-validator subagent
2. 传递 plugin-dev 路径
3. 接收验证报告
4. 如果有错误 → 显示并停止

### 3. 询问同步选项

询问："同步全部还是特定组件？"
选项：
- all（全部）
- skills（仅skills）
- agents（仅agents）
- commands（仅commands）
- hooks（仅hooks）

### 4. 询问版本号

1. 读取当前版本（从plugin.json）
2. 询问："当前版本是 X.X.X，新版本应该是？"
3. 验证semver格式

### 5. 复制组件

1. 创建 `marketplace/plugins/{plugin-name}/` （如需要）
2. 复制选定的组件
3. 更新 plugin.json 的版本号

### 6. 调用发布subagent

1. 使用Task工具调用 marketplace-publisher subagent
2. 传递marketplace路径和插件名称
3. Subagent处理所有git操作
4. 接收结果

### 7. 显示成功消息

```
✅ 插件已同步到marketplace
📦 版本: 0.2.0
📁 位置: {marketplace-path}/plugins/{plugin-name}/
🔄 Git commit: abc1234
🚀 已推送到remote

其他人可以这样安装:
  /plugin marketplace add <your-repo-url>
  /plugin install {plugin-name}@<marketplace-name>
```

## 错误处理

- 无marketplace配置 → 引导运行global-setup
- 验证错误 → 显示详细报告
- Git错误 → 显示并建议修复
- 无变更检测 → 通知用户

## Subagent调用示例

```
Task(
  subagent_type="workspace-validator",
  prompt="验证插件: ./reddit-automation-dev"
)

Task(
  subagent_type="marketplace-publisher",
  prompt="发布插件 reddit-automation 到 {marketplace-path}"
)
```
