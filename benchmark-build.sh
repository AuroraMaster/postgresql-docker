#!/bin/bash

# ================================================================
# Docker构建性能基准测试脚本
# 对比原始和优化版本的构建性能
# ================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message $PURPLE "🏆 PostgreSQL Docker 构建性能基准测试"

# ================================================================
# 配置
# ================================================================

BENCHMARK_RUNS=${BENCHMARK_RUNS:-3}
ORIGINAL_DOCKERFILE="Dockerfile"
OPTIMIZED_DOCKERFILE="Dockerfile.optimized"
TEST_IMAGE_PREFIX="pg-benchmark"
RESULTS_FILE="benchmark-results-$(date +%Y%m%d-%H%M%S).txt"

# 清理函数
cleanup() {
    print_message $YELLOW "🧹 清理测试镜像..."
    docker images | grep "$TEST_IMAGE_PREFIX" | awk '{print $3}' | xargs -r docker rmi -f >/dev/null 2>&1 || true
    docker system prune -f >/dev/null 2>&1 || true
}

# 设置清理陷阱
trap cleanup EXIT

# ================================================================
# 预检查
# ================================================================

print_message $BLUE "🔍 环境检查..."

# 检查必要文件
for dockerfile in "$ORIGINAL_DOCKERFILE" "$OPTIMIZED_DOCKERFILE"; do
    if [ ! -f "$dockerfile" ]; then
        print_message $RED "❌ 文件不存在: $dockerfile"
        exit 1
    fi
done

# 检查Docker和BuildKit
export DOCKER_BUILDKIT=1
print_message $GREEN "✅ 环境检查通过"

# ================================================================
# 基准测试函数
# ================================================================

# 构建测试函数
benchmark_build() {
    local dockerfile=$1
    local tag_suffix=$2
    local test_name=$3
    local run_number=$4

    print_message $YELLOW "🔨 [$test_name] 运行 $run_number/$BENCHMARK_RUNS..."

    # 清理缓存
    docker builder prune -f >/dev/null 2>&1 || true

    # 开始计时
    local start_time=$(date +%s.%N)

    # 执行构建
    if docker build \
        -f "$dockerfile" \
        -t "$TEST_IMAGE_PREFIX-$tag_suffix:run$run_number" \
        --no-cache \
        . >/dev/null 2>&1; then

        # 结束计时
        local end_time=$(date +%s.%N)
        local build_time=$(echo "$end_time - $start_time" | bc)

        # 获取镜像信息
        local image_size=$(docker images "$TEST_IMAGE_PREFIX-$tag_suffix:run$run_number" --format "{{.Size}}")
        local layer_count=$(docker history "$TEST_IMAGE_PREFIX-$tag_suffix:run$run_number" --no-trunc --format "{{.CreatedBy}}" | wc -l)

        echo "$build_time,$image_size,$layer_count"
        return 0
    else
        print_message $RED "❌ 构建失败"
        echo "ERROR,ERROR,ERROR"
        return 1
    fi
}

# 缓存测试函数
benchmark_cache_build() {
    local dockerfile=$1
    local tag_suffix=$2
    local test_name=$3

    print_message $YELLOW "🔄 [$test_name] 缓存构建测试..."

    # 第一次构建（建立缓存）
    docker build -f "$dockerfile" -t "$TEST_IMAGE_PREFIX-$tag_suffix:cache-base" . >/dev/null 2>&1

    # 修改一个文件模拟变更
    echo "# Test change $(date)" >> scripts/README.md

    # 第二次构建（测试缓存效果）
    local start_time=$(date +%s.%N)
    docker build -f "$dockerfile" -t "$TEST_IMAGE_PREFIX-$tag_suffix:cache-test" . >/dev/null 2>&1
    local end_time=$(date +%s.%N)

    # 恢复文件
    git checkout -- scripts/README.md 2>/dev/null || sed -i '$d' scripts/README.md

    local cache_build_time=$(echo "$end_time - $start_time" | bc)
    echo "$cache_build_time"
}

# ================================================================
# 执行基准测试
# ================================================================

print_message $GREEN "🚀 开始基准测试..."
echo "测试配置: $BENCHMARK_RUNS 次运行"
echo "结果保存到: $RESULTS_FILE"
echo ""

# 初始化结果文件
cat > "$RESULTS_FILE" << EOF
PostgreSQL Docker 构建性能基准测试报告
==========================================
测试时间: $(date)
测试配置: $BENCHMARK_RUNS 次运行
Docker版本: $(docker version --format '{{.Server.Version}}' 2>/dev/null)

测试结果:
EOF

# 存储测试结果
original_times=()
original_sizes=()
original_layers=()
optimized_times=()
optimized_sizes=()
optimized_layers=()

# ================================================================
# 原始Dockerfile测试
# ================================================================

print_message $BLUE "📊 测试原始 Dockerfile..."
echo "原始Dockerfile构建测试:" >> "$RESULTS_FILE"

for run in $(seq 1 $BENCHMARK_RUNS); do
    result=$(benchmark_build "$ORIGINAL_DOCKERFILE" "original" "原始版本" "$run")

    if [ "$result" != "ERROR,ERROR,ERROR" ]; then
        build_time=$(echo "$result" | cut -d',' -f1)
        image_size=$(echo "$result" | cut -d',' -f2)
        layer_count=$(echo "$result" | cut -d',' -f3)

        original_times+=("$build_time")
        original_sizes+=("$image_size")
        original_layers+=("$layer_count")

        printf "  运行 %d: %.2f秒, %s, %d层\n" "$run" "$build_time" "$image_size" "$layer_count"
        printf "  运行 %d: %.2f秒, %s, %d层\n" "$run" "$build_time" "$image_size" "$layer_count" >> "$RESULTS_FILE"
    fi
done

# 原始版本缓存测试
original_cache_time=$(benchmark_cache_build "$ORIGINAL_DOCKERFILE" "original" "原始版本缓存")
print_message $BLUE "缓存构建时间: ${original_cache_time}秒"
echo "  缓存构建: ${original_cache_time}秒" >> "$RESULTS_FILE"

echo "" >> "$RESULTS_FILE"

# ================================================================
# 优化Dockerfile测试
# ================================================================

print_message $BLUE "📊 测试优化 Dockerfile..."
echo "优化Dockerfile构建测试:" >> "$RESULTS_FILE"

for run in $(seq 1 $BENCHMARK_RUNS); do
    result=$(benchmark_build "$OPTIMIZED_DOCKERFILE" "optimized" "优化版本" "$run")

    if [ "$result" != "ERROR,ERROR,ERROR" ]; then
        build_time=$(echo "$result" | cut -d',' -f1)
        image_size=$(echo "$result" | cut -d',' -f2)
        layer_count=$(echo "$result" | cut -d',' -f3)

        optimized_times+=("$build_time")
        optimized_sizes+=("$image_size")
        optimized_layers+=("$layer_count")

        printf "  运行 %d: %.2f秒, %s, %d层\n" "$run" "$build_time" "$image_size" "$layer_count"
        printf "  运行 %d: %.2f秒, %s, %d层\n" "$run" "$build_time" "$image_size" "$layer_count" >> "$RESULTS_FILE"
    fi
done

# 优化版本缓存测试
optimized_cache_time=$(benchmark_cache_build "$OPTIMIZED_DOCKERFILE" "optimized" "优化版本缓存")
print_message $BLUE "缓存构建时间: ${optimized_cache_time}秒"
echo "  缓存构建: ${optimized_cache_time}秒" >> "$RESULTS_FILE"

echo "" >> "$RESULTS_FILE"

# ================================================================
# 结果分析
# ================================================================

print_message $GREEN "📈 分析测试结果..."

# 计算平均值
calc_average() {
    local sum=0
    local count=0
    for val in "$@"; do
        sum=$(echo "$sum + $val" | bc)
        count=$((count + 1))
    done
    if [ $count -gt 0 ]; then
        echo "scale=2; $sum / $count" | bc
    else
        echo "0"
    fi
}

# 原始版本平均值
original_avg_time=$(calc_average "${original_times[@]}")
original_avg_layers=$(calc_average "${original_layers[@]}")

# 优化版本平均值
optimized_avg_time=$(calc_average "${optimized_times[@]}")
optimized_avg_layers=$(calc_average "${optimized_layers[@]}")

# 计算改进幅度
if [ $(echo "$original_avg_time > 0" | bc) -eq 1 ] && [ $(echo "$optimized_avg_time > 0" | bc) -eq 1 ]; then
    time_improvement=$(echo "scale=1; ($original_avg_time - $optimized_avg_time) / $original_avg_time * 100" | bc)
    cache_improvement=$(echo "scale=1; ($original_cache_time - $optimized_cache_time) / $original_cache_time * 100" | bc)
else
    time_improvement="计算失败"
    cache_improvement="计算失败"
fi

# ================================================================
# 生成报告
# ================================================================

cat >> "$RESULTS_FILE" << EOF

性能对比分析:
============

构建时间对比:
  原始版本平均: ${original_avg_time}秒
  优化版本平均: ${optimized_avg_time}秒
  改进幅度: ${time_improvement}%

缓存构建对比:
  原始版本: ${original_cache_time}秒
  优化版本: ${optimized_cache_time}秒
  改进幅度: ${cache_improvement}%

镜像层数对比:
  原始版本平均: ${original_avg_layers}层
  优化版本平均: ${optimized_avg_layers}层

镜像大小:
  原始版本: ${original_sizes[0]}
  优化版本: ${optimized_sizes[0]}
EOF

# 控制台输出结果
echo ""
print_message $GREEN "🏆 基准测试完成！"
echo ""
print_message $BLUE "📊 性能对比结果:"
echo "  构建时间: 原始 ${original_avg_time}秒 → 优化 ${optimized_avg_time}秒 (改进 ${time_improvement}%)"
echo "  缓存构建: 原始 ${original_cache_time}秒 → 优化 ${optimized_cache_time}秒 (改进 ${cache_improvement}%)"
echo "  镜像层数: 原始 ${original_avg_layers}层 → 优化 ${optimized_avg_layers}层"
echo "  镜像大小: 原始 ${original_sizes[0]} → 优化 ${optimized_sizes[0]}"

echo ""
print_message $YELLOW "📋 详细报告保存至: $RESULTS_FILE"

# ================================================================
# 建议和总结
# ================================================================

echo ""
print_message $PURPLE "💡 优化建议:"

if [ $(echo "$time_improvement > 30" | bc) -eq 1 ]; then
    print_message $GREEN "✅ 构建时间优化效果显著 (>30%)"
else
    print_message $YELLOW "⚠️  构建时间优化效果一般，建议进一步优化"
fi

if [ $(echo "$cache_improvement > 50" | bc) -eq 1 ]; then
    print_message $GREEN "✅ 缓存构建优化效果优秀 (>50%)"
else
    print_message $YELLOW "⚠️  缓存构建有待优化，检查层级设计"
fi

echo ""
print_message $BLUE "🎯 推荐使用优化版本:"
echo "  ./build-optimized.sh"

print_message $GREEN "✨ 基准测试脚本执行完成！"
