---
name: fix-engine
description: 从验收标准创建检查清单，编排executor→validator循环并带重试逻辑。当子协调器开始实现或收到验证失败时使用。
---

# 修复引擎

**所有者:** 仅子协调器

## 职责

1. 将验收标准转换为可执行检查清单
2. 编排：executor → validator → (失败则重试)
3. 跟踪尝试次数并累积失败上下文
4. 超过最大重试次数时准备详细错误报告

## 检查清单创建

从验收标准生成：
```yaml
checklist:
  - id: check-1
    description: "用户注册创建账户"
    command: "npm test -- --grep 'registration'"
    expected: "exit 0, 用户在数据库中"
  - id: check-2
    description: "无效邮箱被拒绝"
    command: "npm test -- --grep 'validation'"
    expected: "exit 0, 400响应"
```

## 执行循环

```
attempt = 0
max_attempts = 3

while attempt < max_attempts:
    if attempt == 0:
        call executor(task: "implement", prd: mini_prd)
    else:
        call executor(task: "fix", failures: last_failures, previous_attempts: history)

    result = call validator(checklist: checklist)

    if result.passed:
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
