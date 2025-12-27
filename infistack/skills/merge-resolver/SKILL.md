---
name: merge-resolver
description: 当部分完成并准备合并时激活。处理git合并和冲突解决。
---

# 合并解决器

**所有者:** 仅主协调器

## 职责

1. 监控 meta.yaml 中的部分完成状态
2. 预览变更并尝试自动合并
3. 分析和解决合并冲突
4. 更新 meta.yaml 的合并状态

## 触发条件

当 meta.yaml 中某个部分的 status 变为 `completed` 时触发。

## 执行流程

```bash
# 1. 获取最新主分支
git fetch origin main

# 2. 预览变更
git diff main..{section-branch} --stat

# 3. 尝试合并（不提交）
git merge {section-branch} --no-commit

# 4. 处理结果
if [冲突]:
    分析冲突文件
    应用解决策略
else:
    提交合并
    更新 meta.yaml
    清理 worktree 和分支
```

## 冲突解决策略

### 自动解决
- **配置文件** (*.json, *.yaml, *.env.example): 优先使用分支版本
- **类型定义** (*.d.ts, types/*): 合并导出项
- **依赖文件** (package.json): 合并依赖列表

### 需要标记
- **业务逻辑** (controllers, services, utils): 标记为冲突
- **测试文件** (*.test.*, *.spec.*): 标记为冲突
- **数据库迁移**: 标记为冲突

## 冲突记录格式

当遇到无法自动解决的冲突时，创建 `sections/{section-id}/merge-conflict.md`:

```markdown
# 合并冲突报告

**分支:** {section-branch}
**时间:** {timestamp}

## 冲突文件

### src/auth/controller.ts
- **冲突类型:** 业务逻辑
- **冲突行:** 45-62
- **原因:** 主分支和功能分支都修改了 login 方法

**主分支版本:**
```typescript
async login(req, res) {
  const user = await UserService.authenticate(req.body);
  return res.json({ token: generateToken(user) });
}
```

**功能分支版本:**
```typescript
async login(req, res) {
  const user = await UserService.authenticate(req.body);
  const token = await TokenService.create(user);
  return res.json({ token, refreshToken: token.refresh });
}
```

**建议:** 需要人工决定是否保留 refreshToken 功能
```

## meta.yaml 更新

```yaml
merge_status:
  completed: [auth, payments]
  pending: [notifications]
  conflicts:
    - section: ui-components
      branch: reddit-bot/ui-components
      files: [src/components/Button.tsx, src/styles/theme.ts]
      report: sections/ui-components/merge-conflict.md
```

## 清理操作

合并成功后：
```bash
# 提交合并
git commit -m "Merge {section-branch}: {section-name}"

# 清理 worktree
git worktree remove ../worktrees/{section-id}

# 删除分支
git branch -d {section-branch}

# 更新 meta.yaml
# 将部分从 pending 移到 completed
```

## 错误处理

- 如果 git merge 失败且无法自动解决，创建冲突报告
- 继续处理其他已完成的部分
- 将有冲突的部分标记在 meta.yaml 中
- 不阻塞其他部分的合并流程
