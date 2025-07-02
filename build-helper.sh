#!/bin/bash

# PostgreSQL Docker 构建辅助工具
# 整合所有构建相关功能的统一脚本

set -e

# 加载环境变量文件
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

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
    echo "  test-local [mode]          - 本地构建和测试Docker镜像"
    echo "  test-commit <message>      - 测试提交消息解析逻辑"
    echo "  status                     - 检查最近的构建状态"
    echo "  help                       - 显示此帮助信息"
    echo
    echo "📖 示例:"
    echo "  $0 trigger 15              # 触发PG15构建"
    echo "  $0 trigger both true       # 强制构建两个版本"
    echo "  $0 test-local              # 完整本地测试"
    echo "  $0 test-local quick        # 快速本地测试"
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
    local mode="${1:-full}"  # full, quick

    echo -e "${BLUE}🧪 本地Docker构建和测试${NC}"
    echo "========================="

    local image_name="custom-postgres:test"
    local container_name="test-postgres"
    local test_password="test_password_123"

    # 清理函数
    cleanup_test() {
        echo -e "${YELLOW}🧹 清理测试环境...${NC}"
        docker stop $container_name 2>/dev/null || true
        docker rm $container_name 2>/dev/null || true
    }

    # 设置退出时自动清理
    trap cleanup_test EXIT

    # 1. 构建镜像
    echo "🔨 构建Docker镜像..."
    if docker build -t $image_name .; then
        echo -e "${GREEN}✅ 镜像构建成功${NC}"
    else
        echo -e "${RED}❌ 镜像构建失败${NC}"
        return 1
    fi

    if [ "$mode" = "quick" ]; then
        echo "🚀 快速版本测试..."
        docker run --rm \
            -e POSTGRES_PASSWORD=$test_password \
            $image_name \
            postgres --version
        echo -e "${GREEN}🎉 快速测试完成！${NC}"
        return 0
    fi

    # 完整测试模式
    echo "🚀 启动PostgreSQL容器..."
    docker run -d \
        --name $container_name \
        -e POSTGRES_PASSWORD=$test_password \
        -e POSTGRES_DB=testdb \
        -p 15432:5432 \
        $image_name

    # 等待容器启动
    echo "⏳ 等待PostgreSQL启动..."
    for i in {1..30}; do
        if docker exec $container_name pg_isready -U postgres >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL已启动${NC}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo -e "${RED}❌ PostgreSQL启动超时${NC}"
            docker logs $container_name
            return 1
        fi
        sleep 2
    done

    # 测试基本连接
    echo "🔍 测试数据库连接..."
    if docker exec $container_name psql -U postgres -d testdb -c "SELECT version();" >/dev/null; then
        echo -e "${GREEN}✅ 数据库连接正常${NC}"
    else
        echo -e "${RED}❌ 数据库连接失败${NC}"
        return 1
    fi

    # 测试扩展
    echo "🧩 测试PostgreSQL扩展..."

    # 测试PostGIS
    if docker exec $container_name psql -U postgres -d testdb -c "SELECT PostGIS_Version();" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostGIS扩展正常${NC}"
    else
        echo -e "${YELLOW}⚠️  PostGIS扩展测试失败${NC}"
    fi

    # 测试pgvector
    if docker exec $container_name psql -U postgres -d testdb -c "SELECT '[1,2,3]'::vector;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ pgvector扩展正常${NC}"
    else
        echo -e "${YELLOW}⚠️  pgvector扩展测试失败${NC}"
    fi

    # 测试自定义功能
    echo "🔧 测试自定义功能..."

    # 测试已安装扩展视图
    if docker exec $container_name psql -U postgres -d testdb -c "SELECT COUNT(*) FROM installed_extensions;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ 自定义视图正常${NC}"

        # 显示已安装扩展数量
        local ext_count=$(docker exec $container_name psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM installed_extensions;" 2>/dev/null | tr -d ' ')
        echo "📦 已安装 $ext_count 个扩展"
    else
        echo -e "${YELLOW}⚠️  自定义视图测试失败${NC}"
    fi

    # 简单性能测试
    echo "⚡ 简单性能测试..."
    local start_time=$(date +%s)
    docker exec $container_name psql -U postgres -d testdb -c "
        DO \$\$
        BEGIN
            FOR i IN 1..1000 LOOP
                INSERT INTO users (username, email, password_hash, full_name)
                VALUES ('test_user_' || i, 'test' || i || '@example.com', 'hash', 'Test User ' || i)
                ON CONFLICT (username) DO NOTHING;
            END LOOP;
        END \$\$;
    " >/dev/null 2>&1

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo -e "${GREEN}✅ 插入1000条记录耗时 ${duration}秒${NC}"

    # 显示容器资源使用
    echo "📊 容器资源使用:"
    docker stats $container_name --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null || echo "无法获取资源统计"

    echo -e "${GREEN}🎉 完整测试完成！${NC}"

    # 询问是否保留容器
    echo
    read -p "是否保留容器进行手动测试？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}容器 $container_name 将继续运行${NC}"
        echo "连接: docker exec -it $container_name psql -U postgres -d testdb"
        echo "停止: docker stop $container_name && docker rm $container_name"
        trap - EXIT  # 取消自动清理
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
