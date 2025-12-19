#!/bin/bash
# 自动发现 marketplace 位置

CURRENT_DIR=$(pwd)
MARKETPLACE_PATH=""

# 向上搜索最多 3 层父目录
for i in {1..3}; do
  PARENT=$(dirname "$CURRENT_DIR")

  # 在任何子目录中查找 marketplace.json
  MARKETPLACE_JSON=$(find "$PARENT" -maxdepth 3 -name "marketplace.json" -path "*/.claude-plugin/*" 2>/dev/null | head -1)

  if [ -n "$MARKETPLACE_JSON" ]; then
    MARKETPLACE_PATH=$(dirname $(dirname "$MARKETPLACE_JSON"))
    break
  fi

  CURRENT_DIR="$PARENT"
done

if [ -z "$MARKETPLACE_PATH" ]; then
  # 备用方案：检查配置文件
  if [ -f ~/.skillforge-config ]; then
    source ~/.skillforge-config
  fi
fi

echo "$MARKETPLACE_PATH"
