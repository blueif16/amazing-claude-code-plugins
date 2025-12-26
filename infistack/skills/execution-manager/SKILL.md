---
name: execution-manager
description: 使用git worktrees为并行子协调器生成和管理tmux会话。当各部分准备好执行时使用。
---

# 执行管理器

**所有者:** 仅主协调器

## 职责

1. 为每个部分创建git worktree
2. 为每个worktree生成tmux会话
3. 在每个会话中初始化子协调器，包含：
   - Mini-PRD
   - 验收标准
   - 分支名称
   - 工作空间路径
4. 监控完成信号
5. 完成/失败时清理

## 生成模式

```bash
# 对每个部分：
git worktree add ../worktrees/{section-id} -b {section-id}
tmux new-session -d -s {section-id} -c ../worktrees/{section-id}
tmux send-keys -t {section-id} "claude --resume" Enter
```

## 监控

轮询每个tmux会话的状态：
- `COMPLETE` - 部分完成，准备合并
- `WAITING` - 已升级到人工，暂停
- `ERROR` - 意外失败，需调查

## 清理

```bash
tmux kill-session -t {section-id}
git worktree remove ../worktrees/{section-id}
git branch -d {section-id}  # 仅在合并后
```
