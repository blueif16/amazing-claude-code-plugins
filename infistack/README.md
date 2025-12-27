# InfiStack

自我改进的 PRD 执行系统，支持渐进式升级和并行处理。

## 架构概览

```
项目根目录/
├── docs/prds/{project}/
│   ├── meta.yaml              # 项目元数据和部分状态
│   └── sections/
│       ├── auth/
│       │   ├── mini-prd.md    # 部分需求文档
│       │   └── .task/
│       │       ├── mini-prd.md
│       │       └── checklist.md
│       └── api/...
│
└── ../worktrees/              # 并行工作区（git worktree）
    ├── auth/                  # 独立分支工作区
    │   └── .task/             # 任务文件
    └── api/...
```

## 并行执行机制

### Git Worktree 隔离
每个部分在独立的 worktree 中执行，避免分支切换冲突：

```bash
# 主协调器创建 worktree
git worktree add ../worktrees/auth -b project/auth

# 每个 worktree 是独立的工作目录
../worktrees/auth/          # 独立的 git 工作区
├── src/                    # 可以独立修改代码
└── .task/                  # 任务文件
```

### Tmux 会话管理
每个部分在独立的 tmux 会话中运行子协调器：

```bash
# 创建会话并初始化子协调器
tmux new-session -d -s auth -c ../worktrees/auth \
  claude "You are Sub Coordinator for auth. Read fix-engine skill. Begin."

# 监控会话
tmux ls                                    # 列出所有会话
tmux capture-pane -t auth -p | tail -50   # 查看输出
tmux attach -t auth                        # 附加观察（Ctrl+B D 分离）
```

## 工作流程

1. **主协调器** 读取 PRD，调用 `prd-orchestrator` 拆分为多个部分
2. **execution-manager** 为每个部分创建 worktree + tmux 会话
3. **子协调器** 在各自会话中独立执行，调用 `fix-engine`
4. **fix-engine** 编排 executor → validator 循环，最多重试 3 次
5. 完成后 **merge-resolver** 合并各部分，失败则 **escalation-router** 升级
