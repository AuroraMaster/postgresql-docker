#!/bin/bash
# 手动触发GitHub Actions构建脚本

echo "🚀 Triggering GitHub Actions build..."

# 触发测试构建工作流
echo "📋 Triggering Test Build workflow..."
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/AuroraMaster/postgresql-docker/actions/workflows/build-test.yml/dispatches \
  -d '{"ref":"main"}'

echo ""
echo "✅ Test build triggered!"
echo ""

# 等待几秒
sleep 5

# 触发完整构建工作流
echo "🐘 Triggering Full PostgreSQL Build workflow..."
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/AuroraMaster/postgresql-docker/actions/workflows/build-postgres.yml/dispatches \
  -d '{"ref":"main","inputs":{"postgres_version":"15"}}'

echo ""
echo "✅ Full build triggered!"
echo ""
echo "📊 Check build status at:"
echo "   https://github.com/AuroraMaster/postgresql-docker/actions"
echo ""
echo "🐳 Once built, images will be available at:"
echo "   ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg15-latest"
echo "   ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg16-latest"
