---
name: update-skill
description: 修改现有的skill
allowed-tools: Read, Edit, Glob
---

# 更新Skill

## 目的
修改现有skill的内容。

## 执行逻辑

### 1. 列出所有skills

1. 查找 `.claude/skills/` 目录
2. 列出所有skill（编号列表）
3. 询问："要更新哪个skill？"

### 2. 询问修改内容

询问："你想修改什么？"
选项：
- 描述
- 说明/指令
- 工具列表
- 示例
- 其他

### 3. 执行修改

根据用户选择，使用Edit工具进行精确修改：
- 保持YAML frontmatter完整
- 仅修改指定部分
- 不改变其他内容

### 4. 基本验证

检查：
- YAML frontmatter完整（--- 开始和结束）
- 必需字段存在

## 成功输出

```
✅ Skill已更新: {skill-name}
📁 位置: ./.claude/skills/{skill-name}/SKILL.md
```

## 错误处理

- 未找到 .claude/ → 提示先创建skill
- YAML格式错误 → 报告具体问题
- 无写入权限 → 报告错误

## 示例

用户: "更新reddit-upvote skill"

执行流程:
1. 列出skills:
   1. reddit-upvote
   2. reddit-comment
2. 用户选择: 1
3. 询问修改内容 → "描述"
4. 询问新描述 → "Upvote Reddit posts and comments"
5. 使用Edit工具更新描述字段
6. 输出成功消息
