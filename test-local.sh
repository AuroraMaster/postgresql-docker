#!/bin/bash
# 本地测试定制PostgreSQL Docker镜像的脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 配置
IMAGE_NAME="custom-postgres:test"
CONTAINER_NAME="test-postgres"
TEST_PASSWORD="test_password_123"

# 清理函数
cleanup() {
    log_info "清理测试环境..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
}

# 设置退出时自动清理
trap cleanup EXIT

log_info "=== 开始测试定制PostgreSQL Docker镜像 ==="

# 1. 构建镜像
log_info "1. 构建Docker镜像..."
if docker build -t $IMAGE_NAME .; then
    log_success "镜像构建成功"
else
    log_error "镜像构建失败"
    exit 1
fi

# 2. 启动容器
log_info "2. 启动PostgreSQL容器..."
docker run -d \
    --name $CONTAINER_NAME \
    -e POSTGRES_PASSWORD=$TEST_PASSWORD \
    -e POSTGRES_DB=testdb \
    -p 15432:5432 \
    $IMAGE_NAME

# 3. 等待容器启动
log_info "3. 等待PostgreSQL启动..."
for i in {1..30}; do
    if docker exec $CONTAINER_NAME pg_isready -U postgres >/dev/null 2>&1; then
        log_success "PostgreSQL已启动"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "PostgreSQL启动超时"
        docker logs $CONTAINER_NAME
        exit 1
    fi
    sleep 2
done

# 4. 测试基本连接
log_info "4. 测试数据库连接..."
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT version();" >/dev/null; then
    log_success "数据库连接正常"
else
    log_error "数据库连接失败"
    exit 1
fi

# 5. 测试扩展
log_info "5. 测试PostgreSQL扩展..."

# 测试PostGIS
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT PostGIS_Version();" >/dev/null 2>&1; then
    log_success "PostGIS扩展正常"
else
    log_warning "PostGIS扩展测试失败"
fi

# 测试pgvector
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT '[1,2,3]'::vector;" >/dev/null 2>&1; then
    log_success "pgvector扩展正常"
else
    log_warning "pgvector扩展测试失败"
fi

# 测试pg_cron
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT * FROM cron.job LIMIT 1;" >/dev/null 2>&1; then
    log_success "pg_cron扩展正常"
else
    log_warning "pg_cron扩展测试失败"
fi

# 6. 测试自定义函数和视图
log_info "6. 测试自定义功能..."

# 测试已安装扩展视图
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT COUNT(*) FROM installed_extensions;" >/dev/null; then
    log_success "installed_extensions视图正常"

    # 显示已安装扩展
    log_info "已安装的扩展:"
    docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT extension_name, version FROM installed_extensions ORDER BY extension_name;" 2>/dev/null | grep -E "^\s*[a-z]" || true
else
    log_warning "installed_extensions视图测试失败"
fi

# 测试健康检查函数
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT * FROM database_health_check();" >/dev/null; then
    log_success "database_health_check函数正常"
else
    log_warning "database_health_check函数测试失败"
fi

# 7. 测试示例数据
log_info "7. 测试示例数据..."

# 检查用户表
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT COUNT(*) FROM users;" >/dev/null 2>&1; then
    log_success "示例数据表正常"

    # 显示用户数量
    USER_COUNT=$(docker exec $CONTAINER_NAME psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ')
    log_info "用户表中有 $USER_COUNT 条记录"
else
    log_warning "示例数据表测试失败"
fi

# 8. 测试时间序列数据
log_info "8. 测试TimescaleDB功能..."
if docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "SELECT COUNT(*) FROM sensor_data;" >/dev/null 2>&1; then
    log_success "TimescaleDB hypertable正常"

    SENSOR_COUNT=$(docker exec $CONTAINER_NAME psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM sensor_data;" 2>/dev/null | tr -d ' ')
    log_info "传感器数据表中有 $SENSOR_COUNT 条记录"
else
    log_warning "TimescaleDB功能测试失败"
fi

# 9. 性能测试
log_info "9. 简单性能测试..."
START_TIME=$(date +%s)
docker exec $CONTAINER_NAME psql -U postgres -d testdb -c "
    DO \$\$
    BEGIN
        FOR i IN 1..1000 LOOP
            INSERT INTO users (username, email, password_hash, full_name)
            VALUES ('test_user_' || i, 'test' || i || '@example.com', 'hash', 'Test User ' || i)
            ON CONFLICT (username) DO NOTHING;
        END LOOP;
    END \$\$;
" >/dev/null 2>&1

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
log_success "插入1000条记录耗时 ${DURATION}秒"

# 10. 显示容器信息
log_info "10. 容器资源使用情况..."
docker stats $CONTAINER_NAME --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# 11. 显示日志样本
log_info "11. 容器启动日志:"
docker logs $CONTAINER_NAME 2>&1 | tail -20

log_success "=== 所有测试完成 ==="
log_info "容器将在脚本结束时自动清理"
log_info "如需保留容器进行手动测试，请按Ctrl+C中断脚本"

# 可选：保持容器运行
read -p "是否保持容器运行以便手动测试？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "容器 $CONTAINER_NAME 将继续运行"
    log_info "连接命令: docker exec -it $CONTAINER_NAME psql -U postgres -d testdb"
    log_info "停止命令: docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
    trap - EXIT  # 取消自动清理
fi
