---
name: prd-orchestrator
description: 解析PRD，决定水平拆分策略，生成带验收标准的mini-PRD。当主协调器收到初始PRD或需要重新拆分工作时使用。
---

# PRD编排器

**所有者:** 仅主协调器

## 职责

1. 接收 PRD 文件路径（如 `docs/prds/reddit-bot.md`）
2. 创建项目文件夹结构
3. 移动原始 PRD 到项目文件夹
4. 分析 PRD 复杂度并决策拆分策略
5. 生成 meta.yaml 和各部分的 mini-PRD
6. 为每个部分生成验收标准和上下文边界

## 项目文件夹结构

当接收到 PRD 时，创建以下结构：

```
docs/prds/reddit-bot/
├── original.md          # 移动的原始 PRD（非复制）
├── meta.yaml           # 项目元数据和进度跟踪
└── sections/           # 各部分的详细信息
    ├── auth/
    │   ├── mini-prd.md
    │   └── checklist.md
    └── payments/
        ├── mini-prd.md
        └── checklist.md
```

**重要：** 原始 PRD 文件必须被移动（mv）而非复制，确保单一数据源。

## 拆分标准

**默认行为：始终拆分并使用 tmux + worktree**

**例外情况（保持整体）：**
- PRD 少于 50 行
- 单一关注点（如修复一个 bug）
- 无外部依赖
- 以上三个条件必须同时满足

## 输出格式

### meta.yaml

```yaml
project: reddit-bot
created: 2025-01-15T10:00:00Z
original_prd: ./original.md
status: in_progress  # in_progress | completed | blocked

sections:
  auth:
    status: pending  # pending | in_progress | completed | blocked
    branch: reddit-bot/auth
    progress: "0/4"
    files_created: []

  payments:
    status: pending
    branch: reddit-bot/payments
    progress: "0/5"
    files_created: []

merge_status:
  completed: []
  pending: []
  conflicts: []
```

### sections/{section-id}/mini-prd.md

```markdown
# 认证模块

## 范围
实现用户注册、登录和令牌管理功能。

## 验收标准
- 用户可以使用邮箱/密码注册
- 登录时签发 JWT 令牌
- 受保护路由拒绝无效令牌
- 刷新令牌轮换正常工作

## 上下文边界
**拥有:** src/auth/*, src/middleware/auth.ts
**读取:** src/config/*, src/types/*
**禁止:** src/payments/*, src/ui/*
```

编排完成后交给execution-manager。
