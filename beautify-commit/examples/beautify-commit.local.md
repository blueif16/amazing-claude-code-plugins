---
style: normal
---

# Beautify Commit 配置

当前风格：cute

## 可用风格

- **normal**: 标准的 Conventional Commits 格式
  - 使用 feat/fix/docs/style/refactor/test/chore 等类型前缀
  - 示例：`feat: 添加用户登录功能`

- **detailed**: 详细的多行 commit
  - 包含标题、详细说明和影响范围
  - 适合重要的功能更新或复杂的修改

- **concise**: 简洁的一句话描述
  - 不使用类型前缀，直接描述变更
  - 示例：`添加用户登录功能`

- **cute**: 可爱的二次元风格
  - 使用精选的 emoji 和可爱的颜文字
  - 示例：`✨ 哇！新增了超棒的登录功能呢~ (๑•̀ㅂ•́)و✧`

## 如何更改风格

1. 编辑此文件的 `style` 字段为你想要的风格
2. 或删除此文件，下次运行 `/beautify-commit` 时重新选择
