---
name: prd-orchestrator
description: 解析PRD，决定水平拆分策略，生成带验收标准的mini-PRD。当主协调器收到初始PRD或需要重新拆分工作时使用。
---

# PRD编排器

**所有者:** 仅主协调器

## 职责

1. 分析传入PRD的复杂度
2. 决策：整体执行 或 水平拆分
3. 为每个部分生成：
   - Mini-PRD（自包含的范围）
   - 验收标准（成功的标准，而非如何测试）
   - 上下文边界（该部分可以/不可以触及的内容）

## 拆分标准

**需要拆分的情况：**
- 存在独立模块（认证、支付、UI）
- 各部分之间无循环依赖
- 每个部分可独立测试

**保持整体的情况：**
- 全局紧密耦合
- 顺序依赖关系
- 足够简单可单次执行

## 输出格式

```yaml
sections:
  - id: section-1
    name: "认证模块"
    mini_prd: |
      [提取的范围]
    acceptance_criteria:
      - 用户可以使用邮箱/密码注册
      - 登录时签发JWT令牌
      - 受保护路由拒绝无效令牌
    boundaries:
      owns: [src/auth/*, src/middleware/auth.ts]
      reads: [src/config/*, src/types/*]
      forbidden: [src/payments/*, src/ui/*]
```

编排完成后交给execution-manager。
