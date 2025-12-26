---
description: 从PRD初始化InfiStack执行。系统的入口点。
---

# InfiStack 初始化

启动PRD执行管道。

## 使用方法

```
/init [prd文件路径]
```

## 行为

1. 从路径加载PRD（或提示输入）
2. 激活prd-orchestrator skill
3. 交给execution-manager
4. 监控直到完成或等待人工

## 前置条件

- Git仓库已初始化
- PRD文件为markdown格式
- tmux可用

## 示例

```bash
# 使用文件路径
/init ./docs/feature-prd.md

# 或交互式输入
/init
> 请输入PRD内容...
```

## 输出

系统将：
1. 分析并拆分PRD
2. 为每个部分创建并行工作树
3. 在tmux会话中启动子协调器
4. 报告进度和任何需要人工干预的情况

## 监控

检查活动会话：
```bash
tmux ls
```

附加到特定部分：
```bash
tmux attach -t {section-id}
```

查看完成日志：
```bash
tail -f ~/.infistack/completion.log
```
