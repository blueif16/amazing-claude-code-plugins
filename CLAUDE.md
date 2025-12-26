# Claude Code 插件市场管理规则

## 新增插件到 marketplace.json 的标准流程

当创建新插件时，必须按照以下步骤将其添加到 marketplace.json：

### 1. 读取插件配置
从插件目录的 `.claude-plugin/plugin.json` 文件中读取以下信息：
- `name`: 插件名称
- `description`: 插件描述
- `version`: 版本号
- `keywords`: 关键词数组

### 2. 添加到 marketplace.json
在 `plugins` 数组中添加新条目，包含以下字段：

```json
{
  "name": "插件名称",
  "source": "./插件目录名",
  "description": "插件描述",
  "version": "版本号",
  "category": "分类",
  "tags": ["标签1", "标签2", ...]
}
```

### 3. 字段映射规则
- `name`: 直接使用 plugin.json 中的 name
- `source`: 格式为 `./插件目录名`
- `description`: 直接使用 plugin.json 中的 description
- `version`: 直接使用 plugin.json 中的 version
- `category`: 根据插件功能选择合适的分类（如 git、development、automation 等）
- `tags`: 使用 plugin.json 中的 keywords，可适当补充

### 4. 分类参考
- `git`: Git 相关工具
- `development`: 开发工具
- `automation`: 自动化工具
- `utility`: 实用工具
- `documentation`: 文档工具

### 5. 注意事项
- 新插件添加到 plugins 数组末尾
- 确保 JSON 格式正确，最后一个条目后不加逗号
- tags 中建议包含"中文"标签（如果插件支持中文）
- 保持与现有插件条目的格式一致
