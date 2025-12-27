---
style: normal
---

# Beautify Commit 配置

当前风格：normal

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

- **custom**: 自定义风格
  - 使用你自己定义的风格描述和示例
  - 需要在配置文件中添加 `customStyle` 字段

## 如何更改风格

1. 编辑此文件的 `style` 字段为你想要的风格
2. 或删除此文件，下次运行 `/beautify-commit` 时重新选择

## 自定义风格示例

如果你想使用自定义风格，可以这样配置：

```markdown
---
style: custom
customStyle: |
  我喜欢使用简短的英文动词开头，然后用中文描述。
  格式：<英文动词> <中文描述>

  示例：
  - Add 用户登录功能
  - Fix 购物车计算bug
  - Update API文档
  - Refactor 认证模块
---
```
