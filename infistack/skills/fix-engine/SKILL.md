---
name: fix-engine
description: 从验收标准创建检查清单，编排executor→validator循环并带重试逻辑。当子协调器开始实现或收到验证失败时使用。
---

# 修复引擎

**所有者:** 仅子协调器

## 职责

1. 读取 section_path 中的 mini-prd.md
2. 将验收标准转换为 checklist.md（markdown 复选框格式）
3. 编排：executor → validator → (失败则重试)
4. 每次验证后更新 checklist.md 的复选框状态
5. 更新 meta.yaml 中的进度摘要
6. 跟踪尝试次数并累积失败上下文
7. 超过最大重试次数时准备详细错误报告

## 检查清单创建

从 mini-prd.md 的验收标准生成 checklist.md（markdown 格式）：

```markdown
## 认证模块检查清单

- [ ] 用户可以使用邮箱/密码注册
- [ ] 登录时签发 JWT 令牌
- [ ] 受保护路由拒绝无效令牌
- [ ] 刷新令牌轮换正常工作

**进度: 0/4**
```

每次 validator 返回结果后，更新对应的复选框：
- 通过的检查项：`- [x]`
- 失败的检查项：`- [ ]`

同时更新底部的进度摘要。

## 执行循环

```
attempt = 0
max_attempts = 3

while attempt < max_attempts:
    if attempt == 0:
        # 使用 executor agent 实现 .task/mini-prd.md
        call executor agent to implement .task/mini-prd.md
    else:
        call executor(task: "fix", failures: last_failures, previous_attempts: history)

    # 使用 validator agent 检查 .task/checklist.md
    result = call validator agent to check against .task/checklist.md

    # 更新 checklist.md
    update_checklist(result.checkbox_states)

    # 更新 meta.yaml 进度
    progress = f"{result.passed_count}/{result.total_count}"
    update_meta_yaml(section_id, progress: progress)

    if result.all_passed:
        update_meta_yaml(section_id, status: "completed")
        return SUCCESS

    history.append({
        attempt: attempt,
        failures: result.failures,
        executor_notes: executor.notes,
        code_snippets: result.relevant_code
    })

    attempt++

return ESCALATE(error_report: history)
```

## 错误报告格式

```yaml
error_report:
  section_id: "auth-module"
  attempts: 3
  final_failures:
    - check_id: check-2
      expected: "400响应"
      actual: "500响应"
      code_snippet: |
        // src/auth/validate.ts:45-62
        function validateEmail(email) { ... }
      tested_methods:
        - validateEmail()
        - UserService.create()
        - AuthController.register()
  history:
    - attempt: 1
      approach: "初始实现"
      failures: [...]
    - attempt: 2
      approach: "添加try-catch"
      failures: [...]
    - attempt: 3
      approach: "重构验证"
      failures: [...]
```

将error_report交给escalation-router。
