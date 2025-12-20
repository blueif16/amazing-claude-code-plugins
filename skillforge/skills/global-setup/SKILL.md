---
name: global-setup
description: 一次性配置SkillForge的marketplace设置
allowed-tools: Write, Read, Bash
---

# SkillForge全局设置

## 目的
配置SkillForge的marketplace路径和作者信息，只需执行一次。

## 执行流程

### 1. 检查是否已有marketplace

询问用户："你是否已经有一个Claude Code插件marketplace？"

**如果回答YES：**
1. 询问："marketplace的完整路径是什么？"
2. 验证目录是否存在
3. 检查是否为git仓库
   - 如果不是：询问"是否初始化为git仓库？(yes/no)"
   - 如果是：继续
4. 检查git配置（user.name, user.email）
   - 如果缺失：显示"请运行: git config --global user.name 'Your Name'"
5. 保存配置

**如果回答NO：**
1. 询问："应该在哪里创建marketplace？" (默认: ~/claude-marketplaces/my-marketplace)
2. 询问："marketplace名称？" (默认: my-marketplace)
3. 询问："作者名称（用于author字段）？"
4. 执行: bash scripts/create-marketplace.sh <路径> <名称> <作者>
5. 初始化git仓库
6. 创建初始commit
7. 显示："Marketplace已创建。要分享，请添加remote: git remote add origin <url>"
8. 保存配置

### 2. 配置文件格式

保存到 `~/.skillforge-config`:
```json
{
  "marketplacePath": "/完整/路径/到/marketplace",
  "author": "用户名称",
  "email": "user@example.com"
}
```

### 3. 错误处理

- 路径无效 → 重新询问
- 未安装git → 引导安装git
- 无写入权限 → 报告错误及权限信息

## 工具使用

- **Read**: 检查现有配置文件
- **Write**: 创建~/.skillforge-config
- **Bash**: 执行git命令和create-marketplace.sh脚本

## 成功输出

```
✅ SkillForge配置完成！
📁 Marketplace路径: ~/projects/my-marketplace
👤 作者: Shiran
🚀 现在可以开始创建插件了
```
