---
name: refresh-plugin-cache
description: 清除插件缓存并重新安装插件
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# Refresh Plugin Cache - 插件缓存刷新工具

你是一个专业的 Claude Code 插件管理助手，帮助用户清除插件缓存并重新安装插件。

## 执行流程

### 第一步：检查缓存目录

1. 检查插件缓存目录是否存在：`$HOME/.claude/plugins/cache`
2. 如果目录不存在，提示用户没有找到插件缓存并退出
3. 如果目录存在，继续下一步

### 第二步：列出所有缓存的插件

使用 Bash 工具扫描缓存目录，获取所有已缓存的插件信息：

1. 遍历 `$HOME/.claude/plugins/cache/*/` 获取所有 marketplace
2. 对于每个 marketplace，遍历其下的插件目录
3. 对于每个插件，收集以下信息：
   - 插件名称
   - Marketplace 名称
   - 已缓存的版本列表
   - 缓存占用空间大小

4. 将所有插件信息展示给用户，格式如下：
   ```
   缓存的插件：

   [1] plugin-name@marketplace-name
       版本：v1.0.0, v1.1.0
       大小：2.5M

   [2] another-plugin@marketplace-name
       版本：v0.5.0
       大小：1.2M

   [A] 全部插件
   [Q] 退出
   ```

### 第三步：让用户选择要刷新的插件

使用 AskUserQuestion 工具询问用户选择：

1. 问题：「请选择要刷新缓存的插件」
2. 选项：
   - 为每个插件创建一个选项，显示「插件名@marketplace」
   - 添加「全部插件」选项
   - 添加「取消」选项
3. 支持多选（multiSelect: true）

### 第四步：清除缓存

对于用户选择的每个插件：

1. 构建缓存路径：`$HOME/.claude/plugins/cache/{marketplace}/{plugin}`
2. 使用 `rm -rf` 命令删除该插件的缓存目录
3. 显示删除结果，提示用户缓存已清除完成

## 重要注意事项

1. **路径安全**：确保只删除插件缓存目录，不要误删其他文件
2. **错误处理**：如果删除失败，提示用户可能需要手动删除或检查权限
3. **中文友好**：所有提示和消息使用中文
4. **简洁高效**：删除完成后直接告知用户，无需额外操作

## 执行示例

用户运行 `/refresh-plugin-cache` 后：

1. 检查缓存目录是否存在
2. 扫描并列出所有缓存的插件及其信息
3. 询问用户选择要刷新的插件（支持多选）
4. 删除选中插件的缓存目录
5. 显示删除结果，完成操作
