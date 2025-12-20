#!/bin/bash
# 创建新的Claude Code插件marketplace

set -e

MARKETPLACE_PATH=$1
MARKETPLACE_NAME=$2
OWNER_NAME=$3

if [ -z "$MARKETPLACE_PATH" ] || [ -z "$MARKETPLACE_NAME" ] || [ -z "$OWNER_NAME" ]; then
    echo "用法: $0 <marketplace路径> <marketplace名称> <所有者名称>"
    exit 1
fi

echo "创建marketplace目录结构..."
mkdir -p "$MARKETPLACE_PATH/.claude-plugin"
mkdir -p "$MARKETPLACE_PATH/plugins"

echo "创建marketplace.json..."
cat > "$MARKETPLACE_PATH/.claude-plugin/marketplace.json" << EOF
{
  "name": "$MARKETPLACE_NAME",
  "owner": {
    "name": "$OWNER_NAME"
  },
  "plugins": []
}
EOF

echo "创建README.md..."
cat > "$MARKETPLACE_PATH/README.md" << EOF
# $MARKETPLACE_NAME

Claude Code插件Marketplace

## 安装

\`\`\`
/plugin marketplace add <repo-url>
\`\`\`

## 插件

查看 plugins/ 目录
EOF

echo "创建.gitignore..."
cat > "$MARKETPLACE_PATH/.gitignore" << EOF
.DS_Store
*.log
EOF

echo "初始化git仓库..."
cd "$MARKETPLACE_PATH"
git init
git add .
git commit -m "Initial marketplace setup"

echo "✅ Marketplace已创建: $MARKETPLACE_PATH"
echo "📝 下一步: 添加remote并push"
echo "   git remote add origin <url>"
echo "   git push -u origin main"
