#!/bin/bash

# PostgreSQL Docker 构建辅助工具
# 整合所有构建相关功能的统一脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "🐘 PostgreSQL Docker 构建辅助工具"
    echo "=================================="
    echo
    echo "用法: $0 <命令> [参数]"
    echo
    echo "📋 可用命令:"
    echo "  trigger <version> [force]  - 手动触发GitHub Actions构建"
    echo "  test-local                 - 本地构建和测试Docker镜像"
    echo "  test-commit <message>      - 测试提交消息解析逻辑"
    echo "  status                     - 检查最近的构建状态"
    echo "  help                       - 显示此帮助信息"
    echo
    echo "📖 示例:"
    echo "  $0 trigger 15              # 触发PG15构建"
    echo "  $0 trigger both true       # 强制构建两个版本"
    echo "  $0 test-local              # 本地测试构建"
    echo "  $0 test-commit \"修复问题 [build] [pg15]\""
    echo "  $0 status                  # 查看构建状态"
    echo
    echo "🔗 相关链接:"
    echo "  GitHub Actions: https://github.com/AuroraMaster/postgresql-docker/actions"
    echo "  详细文档: BUILD_TRIGGERS.md"
}

# 手动触发构建
trigger_build() {
    local version="${1:-15}"
    local force_rebuild="${2:-false}"

    echo -e "${BLUE}🚀 手动触发GitHub Actions构建${NC}"
    echo "================================="
    echo "PostgreSQL版本: $version"
    echo "强制重建: $force_rebuild"
    echo

    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI (gh) 未安装，使用curl触发...${NC}"

        # 构建请求数据
        local request_data="{
            \"ref\": \"main\",
            \"inputs\": {
                \"postgres_version\": \"$version\",
                \"force_rebuild\": \"$force_rebuild\"
            }
        }"

        echo "📤 发送构建请求..."
        echo "$request_data"
        echo
        echo -e "${CYAN}💡 请手动前往GitHub Actions页面触发构建:${NC}"
        echo "https://github.com/AuroraMaster/postgresql-docker/actions/workflows/build-postgres.yml"
        echo
        echo "参数设置:"
        echo "- postgres_version: $version"
        echo "- force_rebuild: $force_rebuild"
    else
        echo "📤 使用GitHub CLI触发构建..."
        gh workflow run build-postgres.yml \
            -f postgres_version="$version" \
            -f force_rebuild="$force_rebuild"

        echo -e "${GREEN}✅ 构建请求已发送！${NC}"
        echo "🔍 查看状态: gh run list --workflow=build-postgres.yml"
    fi
}

# 本地测试构建
test_local() {
    echo -e "${BLUE}🧪 本地Docker构建和测试${NC}"
    echo "========================="

    if [ -f "./test-local.sh" ]; then
        echo "📋 运行详细的本地测试脚本..."
        ./test-local.sh
    else
        echo -e "${YELLOW}⚠️  详细测试脚本不存在，执行简单测试...${NC}"

        local test_tag="postgres-custom:test"

        echo "🔨 构建测试镜像..."
        if docker build -t "$test_tag" .; then
            echo -e "${GREEN}✅ 镜像构建成功${NC}"
        else
            echo -e "${RED}❌ 镜像构建失败${NC}"
            return 1
        fi

        echo "🧪 快速功能测试..."
        docker run --rm \
            -e POSTGRES_PASSWORD=testpass \
            "$test_tag" \
            postgres --version

        echo -e "${GREEN}🎉 简单测试完成！${NC}"
        echo "💡 运行完整测试请执行: ./test-local.sh"
    fi
}

# 测试提交消息解析
test_commit_message() {
    local message="$1"

    if [ -z "$message" ]; then
        echo -e "${RED}❌ 请提供要测试的提交消息${NC}"
        echo "示例: $0 test-commit \"修复问题 [build] [pg15]\""
        return 1
    fi

    echo -e "${BLUE}🧪 测试提交消息解析${NC}"
    echo "======================="
    echo -e "${YELLOW}测试消息:${NC} '$message'"
    echo

    # 解析逻辑（与GitHub Actions保持一致）
    SHOULD_BUILD="false"
    PG_VERSION="15"
    FORCE_REBUILD="false"
    TAG_SUFFIX=""

    if echo "$message" | grep -qE "\[build\]|\[构建\]|--build"; then
        SHOULD_BUILD="true"

        if echo "$message" | grep -qE "\[pg15\]|\[postgresql-15\]|--pg15"; then
            PG_VERSION="15"
        elif echo "$message" | grep -qE "\[pg16\]|\[postgresql-16\]|--pg16"; then
            PG_VERSION="16"
        elif echo "$message" | grep -qE "\[pgboth\]|\[postgresql-both\]|--pgboth|\[both\]"; then
            PG_VERSION="both"
        fi

        if echo "$message" | grep -qE "\[force\]|\[强制\]|--force|--no-cache"; then
            FORCE_REBUILD="true"
        fi

        if echo "$message" | grep -qE "\[tag:.*\]"; then
            TAG_SUFFIX=$(echo "$message" | grep -oE "\[tag:[^]]+\]" | sed 's/\[tag:\([^]]*\)\]/\1/')
        fi
    fi

    echo -e "${YELLOW}解析结果:${NC}"
    echo "  🚀 触发构建: $SHOULD_BUILD"
    echo "  📦 PG版本: $PG_VERSION"
    echo "  🔥 强制重建: $FORCE_REBUILD"
    echo "  🏷️  标签后缀: ${TAG_SUFFIX:-'none'}"

    if [ "$SHOULD_BUILD" = "true" ]; then
        echo -e "${GREEN}✅ 此提交消息会触发构建${NC}"
    else
        echo -e "${YELLOW}⏭️  此提交消息不会触发构建${NC}"
    fi
}

# 检查构建状态
check_status() {
    echo -e "${BLUE}🔍 GitHub Actions构建状态${NC}"
    echo "=========================="

    # 获取最新提交信息
    local latest_commit=$(git rev-parse HEAD)
    local short_commit=${latest_commit:0:7}
    local commit_msg=$(git log -1 --pretty=format:"%s")

    echo -e "${YELLOW}最新提交:${NC}"
    echo "  哈希: $short_commit"
    echo "  消息: $commit_msg"
    echo

    # 检查是否应该触发构建
    if echo "$commit_msg" | grep -qE "\[build\]|\[构建\]|--build"; then
        echo -e "${GREEN}✅ 检测到构建触发器${NC}"

        # 快速解析关键参数
        local pg_version="15"
        if echo "$commit_msg" | grep -qE "\[pg16\]|\[postgresql-16\]|--pg16"; then
            pg_version="16"
        elif echo "$commit_msg" | grep -qE "\[pgboth\]|\[postgresql-both\]|--pgboth|\[both\]"; then
            pg_version="both"
        fi

        echo "  📦 构建版本: $pg_version"
    else
        echo -e "${YELLOW}⏭️  未检测到构建触发器${NC}"
    fi

    echo
    echo -e "${CYAN}🌐 查看详细状态:${NC}"
    echo "  GitHub Actions: https://github.com/AuroraMaster/postgresql-docker/actions"
    echo "  最新工作流: https://github.com/AuroraMaster/postgresql-docker/actions/runs"
    echo "  提交页面: https://github.com/AuroraMaster/postgresql-docker/commit/$latest_commit"

    if command -v gh &> /dev/null; then
        echo
        echo -e "${CYAN}📊 最近的工作流运行:${NC}"
        gh run list --workflow=build-postgres.yml --limit=3
    fi
}

# 主函数
main() {
    local command="$1"
    shift

    case "$command" in
        "trigger")
            trigger_build "$@"
            ;;
        "test-local")
            test_local
            ;;
        "test-commit")
            test_commit_message "$@"
            ;;
        "status")
            check_status
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $command${NC}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
