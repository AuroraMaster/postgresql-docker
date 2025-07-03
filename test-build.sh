#!/bin/bash

# PostgreSQL Docker 统一构建测试脚本
# 整合网络环境检测和增强构建功能
# 替代原有的独立测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔧 PostgreSQL Docker 统一构建测试${NC}"
echo "=================================="

# 检查build.sh是否存在
if [ ! -f "build.sh" ]; then
    echo -e "${RED}❌ build.sh 文件不存在${NC}"
    echo -e "${YELLOW}💡 请确保在项目根目录运行此脚本${NC}"
    exit 1
fi

# 使用统一的build.sh进行构建测试
echo -e "${BLUE}🚀 使用 build.sh 进行统一构建测试...${NC}"

# 检测网络环境
echo -e "${CYAN}🌐 检测网络环境...${NC}"
if curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
    NETWORK_ENV="international"
    echo -e "${GREEN}✅ 检测到国际网络环境${NC}"
elif curl -s --connect-timeout 5 https://www.baidu.com > /dev/null 2>&1; then
    NETWORK_ENV="china"
    echo -e "${YELLOW}🇨🇳 检测到中国网络环境${NC}"
else
    NETWORK_ENV="auto"
    echo -e "${YELLOW}⚠️ 网络检测失败，使用自动配置${NC}"
fi

# 清理旧镜像
echo -e "${YELLOW}🧹 清理旧的测试镜像...${NC}"
docker rmi custom-postgres:test 2>/dev/null || true

# 使用build.sh进行构建
echo -e "${BLUE}🔨 开始优化构建 (网络环境: $NETWORK_ENV)...${NC}"
if ./build.sh build optimized test $NETWORK_ENV; then
    echo -e "${GREEN}✅ Docker 镜像构建成功！${NC}"

    # 运行快速测试
    echo -e "${BLUE}🧪 运行快速功能测试...${NC}"
    if ./build.sh test quick; then
        echo -e "${GREEN}✅ 快速测试通过！${NC}"

        # 显示镜像信息
        echo -e "${BLUE}📊 镜像信息:${NC}"
        docker images custom-postgres:test --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

        # 可选：运行完整测试
        echo -e "${CYAN}🔍 是否运行完整测试? (需要更多时间) [y/N]:${NC}"
        read -r -t 10 response || response="n"
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}🧪 运行完整测试...${NC}"
            ./build.sh test full
        fi

        echo -e "${GREEN}🎉 所有测试完成！${NC}"
    else
        echo -e "${RED}❌ 功能测试失败${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Docker 镜像构建失败${NC}"
    echo -e "${YELLOW}💡 提示：检查构建日志获取详细错误信息${NC}"
    echo -e "${YELLOW}💡 可以尝试：./build.sh clean 然后重新构建${NC}"
    exit 1
fi

echo
echo -e "${BLUE}📋 测试完成 - 使用说明：${NC}"
echo "- 构建成功的镜像: custom-postgres:test"
echo "- 启动容器: docker run -d --name test-pg -e POSTGRES_PASSWORD=test123 custom-postgres:test"
echo "- 连接数据库: docker exec -it test-pg psql -U postgres"
echo "- 查看状态: ./build.sh status"
echo "- 清理环境: ./build.sh clean"
echo -e "${CYAN}- 性能基准: ./build.sh benchmark 3${NC}"
