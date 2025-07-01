#!/bin/bash

# GitHub Actions构建状态检查脚本

echo "🔍 检查GitHub Actions构建状态"
echo "================================="

# 获取最新的提交信息
LATEST_COMMIT=$(git rev-parse HEAD)
SHORT_COMMIT=${LATEST_COMMIT:0:7}
COMMIT_MSG=$(git log -1 --pretty=format:"%s")

echo "📋 最新提交信息:"
echo "  提交哈希: $SHORT_COMMIT"
echo "  提交消息: $COMMIT_MSG"
echo

# 检查提交消息是否包含构建触发器
if echo "$COMMIT_MSG" | grep -qE "\[build\]|\[构建\]|--build"; then
    echo "✅ 检测到构建触发器，应该已启动构建"

    # 解析参数
    PG_VERSION="15"
    FORCE_REBUILD="false"
    TAG_SUFFIX=""

    if echo "$COMMIT_MSG" | grep -qE "\[pg15\]|\[postgresql-15\]|--pg15"; then
        PG_VERSION="15"
    elif echo "$COMMIT_MSG" | grep -qE "\[pg16\]|\[postgresql-16\]|--pg16"; then
        PG_VERSION="16"
    elif echo "$COMMIT_MSG" | grep -qE "\[pgboth\]|\[postgresql-both\]|--pgboth|\[both\]"; then
        PG_VERSION="both"
    fi

    if echo "$COMMIT_MSG" | grep -qE "\[force\]|\[强制\]|--force|--no-cache"; then
        FORCE_REBUILD="true"
    fi

    if echo "$COMMIT_MSG" | grep -qE "\[tag:.*\]"; then
        TAG_SUFFIX=$(echo "$COMMIT_MSG" | grep -oE "\[tag:[^]]+\]" | sed 's/\[tag:\([^]]*\)\]/\1/')
    fi

    echo "🔧 解析的构建参数:"
    echo "  PostgreSQL版本: $PG_VERSION"
    echo "  强制重建: $FORCE_REBUILD"
    echo "  标签后缀: ${TAG_SUFFIX:-'none'}"

else
    echo "⏭️ 未检测到构建触发器，不会启动构建"
fi

echo
echo "🌐 查看构建状态:"
echo "  GitHub Actions: https://github.com/AuroraMaster/postgresql-docker/actions"
echo "  最新工作流: https://github.com/AuroraMaster/postgresql-docker/actions/runs"
echo "  提交页面: https://github.com/AuroraMaster/postgresql-docker/commit/$LATEST_COMMIT"

echo
echo "📊 预期的构建流程:"
echo "  1. ⏳ parse-commit job: 解析提交消息参数"
echo "  2. 🐘 build-pg15/16 job: 构建Docker镜像"
echo "  3. 🔍 security-scan job: 安全扫描"
echo "  4. 🧪 test job: 功能测试"
echo "  5. 📦 create-release job: 创建Release"

echo
echo "💡 提示:"
echo "  - 构建过程通常需要5-15分钟"
echo "  - 可以在GitHub Actions页面实时查看进度"
echo "  - 成功后会在Releases页面看到新版本"
