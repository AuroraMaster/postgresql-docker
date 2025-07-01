#!/bin/bash
# 手动触发GitHub Actions构建脚本

echo "🚀 PostgreSQL Docker Build Trigger"
echo "=================================="

# 检查参数
VERSION=${1:-"both"}
FORCE_REBUILD=${2:-"false"}

echo "📋 Build Configuration:"
echo "   PostgreSQL Version: $VERSION"
echo "   Force Rebuild: $FORCE_REBUILD"
echo ""

# 验证版本参数
if [[ ! "$VERSION" =~ ^(15|16|both)$ ]]; then
    echo "❌ Invalid version. Use: 15, 16, or both"
    echo "Usage: $0 [15|16|both] [true|false]"
    exit 1
fi

# 触发构建工作流
echo "🐘 Triggering PostgreSQL Build workflow..."
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/AuroraMaster/postgresql-docker/actions/workflows/build-postgres.yml/dispatches \
  -d "{\"ref\":\"main\",\"inputs\":{\"postgres_version\":\"$VERSION\",\"force_rebuild\":\"$FORCE_REBUILD\"}}"

echo ""
echo "✅ Build triggered successfully!"
echo ""
echo "📊 Monitor build progress:"
echo "   https://github.com/AuroraMaster/postgresql-docker/actions"
echo ""
echo "🐳 Images will be available at:"
if [[ "$VERSION" == "15" ]] || [[ "$VERSION" == "both" ]]; then
    echo "   ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg15-latest"
fi
if [[ "$VERSION" == "16" ]] || [[ "$VERSION" == "both" ]]; then
    echo "   ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg16-latest"
fi
echo ""
echo "💡 Usage examples:"
echo "   $0 15        # Build PostgreSQL 15 only"
echo "   $0 16 true   # Build PostgreSQL 16 with force rebuild"
echo "   $0 both      # Build both versions"
