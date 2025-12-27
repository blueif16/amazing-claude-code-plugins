---
name: execution-manager
description: 使用git worktrees为并行子协调器生成和管理tmux会话。当各部分准备好执行时使用。
---

# 执行管理器

**所有者:** 仅主协调器

## 职责

1. 读取 meta.yaml 获取所有待执行部分
2. 为每个部分创建 git worktree
3. 为每个 worktree 生成 tmux 会话
4. 在每个会话中初始化子协调器，传递：
   - section_path（部分目录路径，如 `docs/prds/reddit-bot/sections/auth`）
   - 分支名称
   - 工作空间路径
5. 生成后立即更新 meta.yaml 中的部分状态
6. 监控完成信号
7. 完成/失败时清理

## 生成模式

```bash
# 读取 meta.yaml 获取项目信息
project_name=$(yq '.project' meta.yaml)
sections=$(yq '.sections | keys' meta.yaml)

# 对每个部分：
for section in $sections; do
  branch="${project_name}/${section}"
  section_path="docs/prds/${project_name}/sections/${section}"

  # 创建 worktree
  git worktree add ../worktrees/${section} -b ${branch}

  # 创建 tmux 会话并初始化子协调器
  tmux new-session -d -s ${section} -c ../worktrees/${section} \
    claude "You are Sub Coordinator for ${section}. Read fix-engine skill. Task files in .task/ directory. Begin."

  # 更新 meta.yaml 状态
  yq -i ".sections.${section}.status = \"in_progress\"" meta.yaml
done
```

## 监控

定期检查 meta.yaml 中各部分的状态：
- `completed` - 部分完成，触发 merge-resolver
- `blocked` - 已升级到人工，暂停该部分
- `in_progress` - 继续监控

同时监控 tmux 会话是否异常退出。

## 清理

```bash
tmux kill-session -t {section-id}
git worktree remove ../worktrees/{section-id}
git branch -d {section-id}  # 仅在合并后
```

## 主协调器必备命令

### tmux 会话管理

```bash
# 列出所有工作会话
tmux ls

# 查看工作输出（最后50行，非阻塞）
tmux capture-pane -t {section-id} -p | tail -50

# 向工作会话发送后续指令
tmux send-keys -t {section-id} "Also handle edge case X" Enter

# 附加到会话实时观察（Ctrl+B D 分离）
tmux attach -t {section-id}

# 终止卡住的工作会话
tmux kill-session -t {section-id}
```

### git worktree 管理

```bash
# 创建带新分支的 worktree
git worktree add ../worktrees/{section-id} -b {section-id}

# 列出所有 worktrees
git worktree list

# 删除 worktree（合并后）
git worktree remove ../worktrees/{section-id}

# 清理过期的 worktree 引用
git worktree prune

# 从主分支合并完成的部分
git merge {section-id} --no-ff -m "Merge {section-id}"
```
