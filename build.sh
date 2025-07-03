#!/bin/bash

# ================================================================
# PostgreSQL Docker 统一构建工具
# 整合构建、测试、基准测试、辅助功能的一体化脚本
# ================================================================

set -e

# 加载环境变量文件
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 网络环境检测函数
detect_network_environment() {
    print_message $BLUE "🌐 检测网络环境..."

    # 检测是否能访问国际网站
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
        echo "international"
        print_message $GREEN "✅ 检测到国际网络环境"
    elif curl -s --connect-timeout 5 https://www.baidu.com > /dev/null 2>&1; then
        echo "china"
        print_message $YELLOW "🇨🇳 检测到中国网络环境"
    else
        echo "auto"
        print_message $YELLOW "⚠️ 网络检测失败，使用自动配置"
    fi
}

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示帮助信息
show_help() {
    echo "🐘 PostgreSQL Docker 统一构建工具"
    echo "=================================="
    echo
    echo "用法: $0 <命令> [参数]"
    echo
    echo "📋 可用命令:"
    echo "  build [type] [tag] [network]     - 构建Docker镜像"
    echo "  test [quick|full]                - 本地测试Docker镜像"
    echo "  benchmark [runs]                 - 运行性能基准测试"
    echo "  trigger <version> [force]        - 触发GitHub Actions构建"
    echo "  status                          - 检查构建状态"
    echo "  clean                           - 清理构建缓存和临时文件"
    echo "  help                            - 显示此帮助信息"
    echo
    echo "📖 构建选项:"
    echo "  type: optimized|standard         - 构建类型"
    echo "  tag: latest|自定义标签           - 镜像标签"
    echo "  network: auto|international|china - 网络环境"
    echo
    echo "📖 示例:"
    echo "  $0 build optimized latest auto   # 自动检测网络环境构建"
    echo "  $0 build optimized latest china  # 强制使用国内镜像源"
    echo "  $0 build optimized latest international # 强制使用国际镜像源"
    echo "  $0 test quick                    # 快速测试"
    echo "  $0 benchmark 3                   # 运行3次基准测试"
    echo "  $0 trigger 16 true               # 强制触发PG16构建"
    echo "  $0 clean                         # 清理缓存"
    echo
    echo "🔗 相关链接:"
    echo "  GitHub Actions: https://github.com/AuroraMaster/postgresql-docker/actions"
    echo "  详细文档: BUILD_TRIGGERS.md"
}

# ================================================================
# 构建功能
# ================================================================

build_image() {
    local build_type="${1:-optimized}"  # optimized, standard
    local tag="${2:-latest}"
    local network_env="${3:-auto}"  # auto, international, china

    print_message $BLUE "🔨 构建PostgreSQL Docker镜像"
    echo "================================="
    echo "构建类型: $build_type"
    echo "镜像标签: $tag"
    echo

    # 网络环境检测
    if [ "$network_env" = "auto" ]; then
        network_env=$(detect_network_environment)
    fi

    print_message $CYAN "🌐 网络环境: $network_env"

    # 确定使用的Dockerfile
    local dockerfile="Dockerfile"
    if [ "$build_type" = "optimized" ]; then
        # 检查是否存在专用的优化版本Dockerfile
        if [ -f "Dockerfile.optimized" ]; then
            dockerfile="Dockerfile.optimized"
        else
            # 使用主Dockerfile（已包含优化）
            dockerfile="Dockerfile"
        fi

        # 启用BuildKit
        export DOCKER_BUILDKIT=1
        export BUILDKIT_PROGRESS=plain

        print_message $GREEN "✅ 启用BuildKit优化构建"
    fi

    # 检查Dockerfile存在
    if [ ! -f "$dockerfile" ]; then
        print_message $RED "❌ Dockerfile不存在: $dockerfile"
        exit 1
    fi

    # 构建配置
    local image_name="${POSTGRES_IMAGE_NAME:-custom-postgres}"
    local context="${CONTEXT:-.}"

    # 构建参数
    local build_args="--build-arg NETWORK_ENVIRONMENT=$network_env"

    # 根据网络环境设置镜像源
    if [ "$network_env" = "international" ]; then
        build_args="$build_args --build-arg DEBIAN_MIRROR=international --build-arg PIP_INDEX_URL=https://pypi.org/simple"
        print_message $GREEN "✅ 使用国际镜像源"
    elif [ "$network_env" = "china" ]; then
        build_args="$build_args --build-arg DEBIAN_MIRROR=china --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple"
        build_args="$build_args --build-arg SKIP_GIT_EXTENSIONS=true"
        print_message $YELLOW "🇨🇳 使用国内镜像源，跳过Git扩展编译"
    fi

    # 加载.env文件中的其他参数
    if [ -f ".env" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[^#]*= ]]; then
                key=$(echo "$line" | cut -d'=' -f1)
                value=$(echo "$line" | cut -d'=' -f2-)
                build_args="$build_args --build-arg $key=$value"
            fi
        done < .env
    fi

    # 记录开始时间
    local start_time=$(date +%s)

    print_message $YELLOW "🚀 开始构建..."

    if [ "$build_type" = "optimized" ] && command -v docker &>/dev/null && docker buildx version >/dev/null 2>&1; then
        # 使用BuildKit优化构建
        local cache_from="type=local,src=/tmp/buildkit-cache"
        local cache_to="type=local,dest=/tmp/buildkit-cache,mode=max"

        # 创建缓存目录
        mkdir -p /tmp/buildkit-cache

        docker buildx build \
            --file "$dockerfile" \
            --tag "$image_name:$tag" \
            --cache-from "$cache_from" \
            --cache-to "$cache_to" \
            --progress=plain \
            --load \
            $build_args \
            "$context"
    else
        # 传统构建
        docker build \
            --file "$dockerfile" \
            --tag "$image_name:$tag" \
            $build_args \
            "$context"
    fi

    # 记录结束时间和分析结果
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local minutes=$((build_time / 60))
    local seconds=$((build_time % 60))

    print_message $GREEN "🎉 构建完成！"
    echo "构建耗时: ${minutes}分${seconds}秒"

    # 镜像信息
    local image_size=$(docker images "$image_name:$tag" --format "{{.Size}}" | head -1)
    local layer_count=$(docker history "$image_name:$tag" --no-trunc --format "{{.CreatedBy}}" | wc -l)

    echo "镜像大小: $image_size"
    echo "镜像层数: $layer_count"
}

# ================================================================
# 测试功能
# ================================================================

test_image() {
    local mode="${1:-full}"  # quick, full

    print_message $BLUE "🧪 测试PostgreSQL Docker镜像"
    echo "========================="
    echo "测试模式: $mode"
    echo

    local image_name="${POSTGRES_IMAGE_NAME:-custom-postgres}"
    local image_tag="${POSTGRES_IMAGE_TAG:-latest}"
    local container_name="test-postgres-$$"
    local test_password="test_password_123"

    # 清理函数
    cleanup_test() {
        print_message $YELLOW "🧹 清理测试环境..."
        docker stop $container_name 2>/dev/null || true
        docker rm $container_name 2>/dev/null || true
    }

    # 设置退出时自动清理
    trap cleanup_test EXIT

    # 检查镜像存在
    if ! docker image inspect "$image_name:$image_tag" >/dev/null 2>&1; then
        print_message $RED "❌ 镜像不存在: $image_name:$image_tag"
        print_message $YELLOW "请先运行: $0 build"
        exit 1
    fi

    if [ "$mode" = "quick" ]; then
        print_message $BLUE "🚀 快速版本测试..."
        if docker run --rm \
            -e POSTGRES_PASSWORD=$test_password \
            "$image_name:$image_tag" \
            postgres --version; then
            print_message $GREEN "✅ 快速测试通过！"
        else
            print_message $RED "❌ 快速测试失败"
            exit 1
        fi
        return 0
    fi

    # 完整测试模式
    print_message $BLUE "🚀 启动PostgreSQL容器..."
    docker run -d \
        --name $container_name \
        -e POSTGRES_PASSWORD=$test_password \
        -e POSTGRES_DB=testdb \
        -p 15432:5432 \
        "$image_name:$image_tag"

    # 等待容器启动
    print_message $YELLOW "⏳ 等待PostgreSQL启动..."
    for i in {1..30}; do
        if docker exec $container_name pg_isready -U postgres >/dev/null 2>&1; then
            print_message $GREEN "✅ PostgreSQL已启动"
            break
        fi
        if [ $i -eq 30 ]; then
            print_message $RED "❌ PostgreSQL启动超时"
            docker logs $container_name
            exit 1
        fi
        sleep 2
    done

    # 测试数据库连接
    print_message $BLUE "🔍 测试数据库连接..."
    if docker exec $container_name psql -U postgres -d testdb -c "SELECT version();" >/dev/null; then
        print_message $GREEN "✅ 数据库连接正常"
    else
        print_message $RED "❌ 数据库连接失败"
        exit 1
    fi

    # 测试扩展
    print_message $BLUE "🧩 测试PostgreSQL扩展..."

    local extensions_tested=0
    local extensions_passed=0

    # 测试PostGIS
    extensions_tested=$((extensions_tested + 1))
    if docker exec $container_name psql -U postgres -d testdb -c "CREATE EXTENSION IF NOT EXISTS postgis;" >/dev/null 2>&1; then
        extensions_passed=$((extensions_passed + 1))
        print_message $GREEN "✅ PostGIS扩展正常"
    else
        print_message $YELLOW "⚠️  PostGIS扩展测试失败"
    fi

    # 测试pgvector
    extensions_tested=$((extensions_tested + 1))
    if docker exec $container_name psql -U postgres -d testdb -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1; then
        extensions_passed=$((extensions_passed + 1))
        print_message $GREEN "✅ pgvector扩展正常"
    else
        print_message $YELLOW "⚠️  pgvector扩展测试失败"
    fi

    # 测试TimescaleDB
    extensions_tested=$((extensions_tested + 1))
    if docker exec $container_name psql -U postgres -d testdb -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" >/dev/null 2>&1; then
        extensions_passed=$((extensions_passed + 1))
        print_message $GREEN "✅ TimescaleDB扩展正常"
    else
        print_message $YELLOW "⚠️  TimescaleDB扩展测试失败"
    fi

    print_message $BLUE "📊 扩展测试结果: $extensions_passed/$extensions_tested 通过"

    # 简单性能测试
    print_message $BLUE "⚡ 简单性能测试..."
    local start_time=$(date +%s)
    docker exec $container_name psql -U postgres -d testdb -c "
        CREATE TABLE IF NOT EXISTS test_performance (
            id SERIAL PRIMARY KEY,
            data TEXT,
            created_at TIMESTAMP DEFAULT NOW()
        );
        INSERT INTO test_performance (data)
        SELECT 'test_data_' || generate_series(1, 1000);
        SELECT COUNT(*) FROM test_performance;
        DROP TABLE test_performance;
    " >/dev/null 2>&1
    local end_time=$(date +%s)
    local perf_time=$((end_time - start_time))

    print_message $GREEN "✅ 性能测试完成 (${perf_time}秒)"
    print_message $GREEN "🎉 完整测试通过！"
}

# ================================================================
# 基准测试功能
# ================================================================

benchmark_builds() {
    local runs="${1:-3}"

    print_message $PURPLE "🏆 PostgreSQL Docker 构建性能基准测试"
    echo "====================================="
    echo "测试运行次数: $runs"
    echo

    local results_file="benchmark-results-$(date +%Y%m%d-%H%M%S).txt"
    local original_dockerfile="Dockerfile"
    local optimized_dockerfile="Dockerfile.optimized"
    local test_image_prefix="pg-benchmark"

    # 清理函数
    cleanup_benchmark() {
        print_message $YELLOW "🧹 清理基准测试环境..."
        docker images | grep "$test_image_prefix" | awk '{print $3}' | xargs -r docker rmi -f >/dev/null 2>&1 || true
        docker system prune -f >/dev/null 2>&1 || true
    }

    trap cleanup_benchmark EXIT

    # 初始化结果文件
    cat > "$results_file" << EOF
PostgreSQL Docker 构建性能基准测试报告
==========================================
测试时间: $(date)
测试运行次数: $runs
Docker版本: $(docker version --format '{{.Server.Version}}' 2>/dev/null)

测试结果:
EOF

    # 存储测试结果
    local original_times=()
    local optimized_times=()

    # 测试函数
    benchmark_single_build() {
        local dockerfile=$1
        local tag_suffix=$2
        local run_number=$3

        print_message $YELLOW "🔨 [$tag_suffix] 运行 $run_number/$runs..."

        # 清理缓存
        docker builder prune -f >/dev/null 2>&1 || true

        # 开始计时
        local start_time=$(date +%s.%N)

        # 执行构建
        if docker build \
            -f "$dockerfile" \
            -t "$test_image_prefix-$tag_suffix:run$run_number" \
            --no-cache \
            . >/dev/null 2>&1; then

            local end_time=$(date +%s.%N)
            local build_time=$(echo "$end_time - $start_time" | bc)
            echo "$build_time"
            return 0
        else
            print_message $RED "❌ 构建失败"
            echo "ERROR"
            return 1
        fi
    }

    # 测试标准版本（如果存在）
    if [ -f "$original_dockerfile" ]; then
        print_message $BLUE "📊 测试标准 Dockerfile..."
        echo "标准Dockerfile构建测试:" >> "$results_file"

        for run in $(seq 1 $runs); do
            result=$(benchmark_single_build "$original_dockerfile" "standard" "$run")
            if [ "$result" != "ERROR" ]; then
                original_times+=("$result")
                printf "  运行 %d: %.2f秒\n" "$run" "$result"
                printf "  运行 %d: %.2f秒\n" "$run" "$result" >> "$results_file"
            fi
        done
        echo "" >> "$results_file"
    fi

    # 测试优化版本
    if [ -f "$optimized_dockerfile" ]; then
        print_message $BLUE "📊 测试优化 Dockerfile..."
        echo "优化Dockerfile构建测试:" >> "$results_file"

        for run in $(seq 1 $runs); do
            result=$(benchmark_single_build "$optimized_dockerfile" "optimized" "$run")
            if [ "$result" != "ERROR" ]; then
                optimized_times+=("$result")
                printf "  运行 %d: %.2f秒\n" "$run" "$result"
                printf "  运行 %d: %.2f秒\n" "$run" "$result" >> "$results_file"
            fi
        done
        echo "" >> "$results_file"
    fi

    # 计算平均值和对比
    if [ ${#original_times[@]} -gt 0 ] && [ ${#optimized_times[@]} -gt 0 ]; then
        local original_avg=$(printf '%s\n' "${original_times[@]}" | awk '{sum+=$1} END {print sum/NR}')
        local optimized_avg=$(printf '%s\n' "${optimized_times[@]}" | awk '{sum+=$1} END {print sum/NR}')
        local improvement=$(echo "scale=2; ($original_avg - $optimized_avg) / $original_avg * 100" | bc)

        print_message $GREEN "📈 基准测试结果总结:"
        printf "标准版本平均: %.2f秒\n" "$original_avg"
        printf "优化版本平均: %.2f秒\n" "$optimized_avg"
        printf "性能提升: %.1f%%\n" "$improvement"

        echo "" >> "$results_file"
        echo "测试结果总结:" >> "$results_file"
        printf "标准版本平均: %.2f秒\n" "$original_avg" >> "$results_file"
        printf "优化版本平均: %.2f秒\n" "$optimized_avg" >> "$results_file"
        printf "性能提升: %.1f%%\n" "$improvement" >> "$results_file"
    fi

    print_message $GREEN "📋 基准测试完成，结果保存到: $results_file"
}

# ================================================================
# GitHub Actions触发功能
# ================================================================

trigger_github_build() {
    local version="${1:-16}"
    local force_rebuild="${2:-false}"

    print_message $BLUE "🚀 触发GitHub Actions构建"
    echo "========================="
    echo "PostgreSQL版本: $version"
    echo "强制重建: $force_rebuild"
    echo

    if command -v gh &> /dev/null; then
        print_message $BLUE "📤 使用GitHub CLI触发构建..."
        gh workflow run build-postgres.yml \
            -f postgres_version="$version" \
            -f force_rebuild="$force_rebuild"

        print_message $GREEN "✅ 构建请求已发送！"
        print_message $CYAN "🔍 查看状态: gh run list --workflow=build-postgres.yml"
    else
        print_message $YELLOW "⚠️  GitHub CLI (gh) 未安装"
        print_message $CYAN "💡 请手动前往GitHub Actions页面触发构建:"
        echo "https://github.com/AuroraMaster/postgresql-docker/actions/workflows/build-postgres.yml"
        echo
        echo "参数设置:"
        echo "- postgres_version: $version"
        echo "- force_rebuild: $force_rebuild"
    fi
}

# ================================================================
# 状态检查功能
# ================================================================

check_status() {
    print_message $BLUE "📊 构建状态检查"
    echo "==============="

    # 检查本地镜像
    print_message $YELLOW "🐳 本地Docker镜像:"
    local image_name="${POSTGRES_IMAGE_NAME:-custom-postgres}"
    if docker images | grep -q "$image_name"; then
        docker images | grep "$image_name" | while read line; do
            echo "  $line"
        done
    else
        echo "  (无)"
    fi
    echo

    # 检查GitHub Actions状态（如果可用）
    if command -v gh &> /dev/null; then
        print_message $YELLOW "🔄 GitHub Actions状态:"
        if gh run list --workflow=build-postgres.yml --limit=5 2>/dev/null; then
            :
        else
            echo "  无法获取GitHub Actions状态"
        fi
    else
        print_message $YELLOW "⚠️  GitHub CLI未安装，无法检查远程构建状态"
    fi
}

# ================================================================
# 清理功能
# ================================================================

clean_cache() {
    print_message $BLUE "🧹 清理构建缓存和临时文件"
    echo "========================"

    # 清理Docker构建缓存
    print_message $YELLOW "🗑️  清理Docker构建缓存..."
    docker builder prune -f || true
    docker system prune -f || true

    # 清理BuildKit缓存
    if [ -d "/tmp/buildkit-cache" ]; then
        print_message $YELLOW "🗑️  清理BuildKit缓存..."
        rm -rf /tmp/buildkit-cache
    fi

    # 清理测试镜像
    print_message $YELLOW "🗑️  清理测试镜像..."
    docker images | grep -E "(pg-benchmark|test-postgres)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

    # 清理基准测试结果文件（可选）
    local benchmark_files=$(ls benchmark-results-*.txt 2>/dev/null | wc -l)
    if [ "$benchmark_files" -gt 0 ]; then
        print_message $CYAN "📋 发现 $benchmark_files 个基准测试结果文件"
        echo "删除？[y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            rm -f benchmark-results-*.txt
            print_message $GREEN "✅ 已删除基准测试结果文件"
        fi
    fi

    print_message $GREEN "✅ 清理完成"
}

# ================================================================
# 主程序
# ================================================================

main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    case "$1" in
        "build")
            build_image "${2:-optimized}" "${3:-latest}" "${4:-auto}"
            ;;
        "test")
            test_image "$2"
            ;;
        "benchmark")
            benchmark_builds "$2"
            ;;
        "trigger")
            trigger_github_build "$2" "$3"
            ;;
        "status")
            check_status
            ;;
        "clean")
            clean_cache
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_message $RED "❌ 未知命令: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"
