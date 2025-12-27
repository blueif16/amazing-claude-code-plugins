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

## 重要约束

**主协调器代码修复规则:**

当需要修复主协调器（当前 agent 所在环境）中的代码时，**必须先询问人工**。

主协调器的职责范围：
- ✅ 协调和生成 tmux 会话
- ✅ 管理 git worktree
- ✅ 检查各部分进度
- ✅ 简洁地调用 skills
- ❌ 不应思考具体执行计划
- ❌ 不应直接修改业务代码

所有具体的执行计划和代码实现应由子协调器在各自的 tmux 会话中完成。

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

## 监控循环 (REQUIRED)

生成所有会话后，**必须继续监控**。不要交给人工处理。

```bash
# 监控状态变量
all_done=false
check_interval=30  # 秒

while [ "$all_done" = false ]; do
  echo "检查所有部分状态..."

  completed_count=0
  blocked_count=0
  in_progress_count=0
  total_sections=$(yq '.sections | length' meta.yaml)

  # 检查每个部分的状态
  for section in $(yq '.sections | keys | .[]' meta.yaml); do
    status=$(yq ".sections.${section}.status" meta.yaml)

    case "$status" in
      completed)
        ((completed_count++))
        echo "✅ $section: COMPLETE"
        ;;
      blocked)
        ((blocked_count++))
        echo "❌ $section: BLOCKED"
        ;;
      in_progress)
        ((in_progress_count++))
        # 检查 tmux 会话是否还在运行
        if ! tmux has-session -t "$section" 2>/dev/null; then
          echo "⚠️ $section: tmux 会话异常退出"
          yq -i ".sections.${section}.status = \"blocked\"" meta.yaml
        else
          # 检查最近输出
          last_output=$(tmux capture-pane -t "$section" -p | tail -20)
          echo "🔄 $section: WORKING"
        fi
        ;;
    esac
  done

  # 检查是否所有部分都完成或阻塞
  if [ $((completed_count + blocked_count)) -eq $total_sections ]; then
    all_done=true
    echo ""
    echo "所有部分已完成或阻塞，准备合并..."
    echo "- 已完成: $completed_count"
    echo "- 已阻塞: $blocked_count"
    echo ""

    # 自动调用 merge-resolver
    if [ $completed_count -gt 0 ]; then
      echo "调用 merge-resolver 处理已完成的部分..."
      # 这里 Claude 会调用 merge-resolver skill
      # 人工只需在 merge-resolver 完成后看到最终报告
    else
      echo "没有已完成的部分可以合并"
      echo "所有部分都被阻塞，需要人工干预"
    fi
  else
    echo ""
    echo "状态摘要: $completed_count 完成, $in_progress_count 进行中, $blocked_count 阻塞"
    echo "等待 ${check_interval} 秒后再次检查..."
    sleep $check_interval
  fi
done
```

### 监控期间的响应策略

**每 30-60 秒检查每个会话：**

1. **WORKING** → 继续监控
2. **COMPLETE** → 更新 meta.yaml，继续监控其他部分
3. **STUCK** → 读取 error-report.md，决定：
   - 通过 `tmux send-keys` 提供额外上下文
   - 或升级到人工（标记为 blocked）
4. **5分钟以上无输出** → 检查是否卡住，发送提示：
   ```bash
   tmux send-keys -t {section-id} "状态更新？" Enter
   ```

**对问题做出反应：**
- 如果 tmux 需要任何权限或询问，通常只需同意并指向正确的选择
- 如果需要外部信息 → 获取并注入：
  ```bash
  tmux send-keys -t {section-id} "额外上下文：..." Enter
  ```

**仅在以下情况停止监控：**
- 所有部分 COMPLETE 或 BLOCKED → 调用 merge-resolver
- merge-resolver 完成 → 向人工报告最终摘要
- 多个部分出现致命错误 → 升级并提供完整报告

不要只是生成后就离开。你负责监控循环直到所有部分完成并调用 merge-resolver。

## 完成触发器

当监控循环检测到所有部分都是 `completed` 或 `blocked` 状态时：

1. **如果有任何 blocked 部分：**
   - 报告阻塞的部分给人工
   - 询问："是否继续合并已完成的部分? (y/n)"
   - 如果 30 秒内无响应，默认为 YES

2. **调用 merge-resolver：**
   - 传递所有 `completed` 部分的列表
   - merge-resolver 会处理合并、冲突解决、测试和报告

3. **merge-resolver 返回后：**
   - 如果所有合并成功且测试通过 → 报告成功
   - 如果有冲突 → 报告冲突文件和解决步骤
   - 如果测试失败 → 报告失败原因

4. **只有在 merge-resolver 完成后才返回控制权给人工**

## 永不提前退出原则

execution-manager 的职责是完整的端到端执行管理：

- ✅ 生成所有 tmux 会话
- ✅ 监控所有部分直到完成
- ✅ 自动调用 merge-resolver
- ✅ 等待 merge-resolver 完成
- ✅ 向人工报告最终结果

**不要：**
- ❌ 生成会话后就返回
- ❌ 部分完成时就返回
- ❌ 让人工手动触发合并
- ❌ 在 merge-resolver 运行时返回

**人工只应看到：**
1. 初始 PRD 输入
2. 最终执行报告（成功或需要处理的冲突）

## 监控状态说明

定期检查 meta.yaml 中各部分的状态：
- `completed` - 部分完成，等待所有部分完成后触发 merge-resolver
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
