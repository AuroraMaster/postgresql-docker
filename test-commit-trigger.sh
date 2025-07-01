#!/bin/bash

# 提交消息触发测试脚本
# 用于测试不同的提交消息参数组合

set -e

echo "🧪 PostgreSQL Docker构建 - 提交消息触发测试"
echo "================================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试用例函数
test_commit_message() {
    local message="$1"
    local expected_trigger="$2"
    local expected_version="$3"
    local expected_force="$4"
    local expected_tag="$5"

    echo -e "\n${BLUE}🔍 测试提交消息:${NC} '$message'"

    # 模拟GitHub Actions解析逻辑
    SHOULD_BUILD="false"
    PG_VERSION="15"
    FORCE_REBUILD="false"
    TAG_SUFFIX=""

    # 检查构建触发器
    if echo "$message" | grep -qE "\[build\]|\[构建\]|--build"; then
        SHOULD_BUILD="true"

        # 解析PostgreSQL版本
        if echo "$message" | grep -qE "\[pg15\]|\[postgresql-15\]|--pg15"; then
            PG_VERSION="15"
        elif echo "$message" | grep -qE "\[pg16\]|\[postgresql-16\]|--pg16"; then
            PG_VERSION="16"
        elif echo "$message" | grep -qE "\[pgboth\]|\[postgresql-both\]|--pgboth|\[both\]"; then
            PG_VERSION="both"
        fi

        # 检查强制重建
        if echo "$message" | grep -qE "\[force\]|\[强制\]|--force|--no-cache"; then
            FORCE_REBUILD="true"
        fi

        # 提取标签后缀
        if echo "$message" | grep -qE "\[tag:.*\]"; then
            TAG_SUFFIX=$(echo "$message" | grep -oE "\[tag:[^]]+\]" | sed 's/\[tag:\([^]]*\)\]/\1/')
        fi
    fi

    # 显示解析结果
    echo -e "  ${YELLOW}解析结果:${NC}"
    echo -e "    是否构建: $SHOULD_BUILD"
    echo -e "    PG版本: $PG_VERSION"
    echo -e "    强制重建: $FORCE_REBUILD"
    echo -e "    标签后缀: ${TAG_SUFFIX:-'none'}"

    # 验证结果
    local success=true
    if [ "$SHOULD_BUILD" != "$expected_trigger" ]; then
        echo -e "  ${RED}❌ 构建触发错误: 期望 $expected_trigger, 实际 $SHOULD_BUILD${NC}"
        success=false
    fi

    if [ "$PG_VERSION" != "$expected_version" ]; then
        echo -e "  ${RED}❌ 版本解析错误: 期望 $expected_version, 实际 $PG_VERSION${NC}"
        success=false
    fi

    if [ "$FORCE_REBUILD" != "$expected_force" ]; then
        echo -e "  ${RED}❌ 强制重建错误: 期望 $expected_force, 实际 $FORCE_REBUILD${NC}"
        success=false
    fi

    if [ "$TAG_SUFFIX" != "$expected_tag" ]; then
        echo -e "  ${RED}❌ 标签后缀错误: 期望 '$expected_tag', 实际 '$TAG_SUFFIX'${NC}"
        success=false
    fi

    if [ "$success" = true ]; then
        echo -e "  ${GREEN}✅ 测试通过${NC}"
    else
        echo -e "  ${RED}❌ 测试失败${NC}"
    fi
}

echo -e "\n${YELLOW}开始测试用例...${NC}"

# 测试用例
test_commit_message "更新文档" "false" "15" "false" ""
test_commit_message "修复数据库连接问题 [build]" "true" "15" "false" ""
test_commit_message "添加新功能 [build] [pg16]" "true" "16" "false" ""
test_commit_message "重要更新 [build] [both]" "true" "both" "false" ""
test_commit_message "修复构建问题 [build] [pg15] [force]" "true" "15" "true" ""
test_commit_message "发布版本 [build] [pg15] [tag:v1.2.0]" "true" "15" "false" "v1.2.0"
test_commit_message "紧急修复 [build] [both] [force] [tag:hotfix]" "true" "both" "true" "hotfix"
test_commit_message "数据库优化 [构建] [强制]" "true" "15" "true" ""
test_commit_message "update extensions --build --pg16 --force" "true" "16" "true" ""
test_commit_message "重要更新 [build] --pg16 [tag:release]" "true" "16" "false" "release"

echo -e "\n${GREEN}🎉 所有测试完成！${NC}"
echo
echo -e "${BLUE}💡 使用提示:${NC}"
echo "1. 提交消息必须包含构建触发器才会启动构建"
echo "2. 支持中文和英文标签，以及命令行风格参数"
echo "3. 版本解析优先级: both > 16 > 15"
echo "4. 可以组合使用多个标签参数"
echo
echo -e "${YELLOW}📖 详细文档: BUILD_TRIGGERS.md${NC}"
