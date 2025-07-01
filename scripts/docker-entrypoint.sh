#!/bin/bash
# 自定义PostgreSQL Docker启动脚本
set -Eeo pipefail

# 定义颜色输出函数
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

echo "$(blue '🐘 启动定制PostgreSQL Docker容器...')"

# 检查环境变量
echo "$(yellow '📋 检查环境变量...')"
echo "POSTGRES_DB: ${POSTGRES_DB:-默认}"
echo "POSTGRES_USER: ${POSTGRES_USER:-默认}"
echo "数据目录: ${PGDATA:-/var/lib/postgresql/data}"

# 如果没有设置密码且不是信任模式，生成随机密码
if [ -z "$POSTGRES_PASSWORD" ] && [ -z "$POSTGRES_HOST_AUTH_METHOD" ]; then
    export POSTGRES_PASSWORD=$(openssl rand -base64 32)
    echo "$(yellow '🔐 自动生成数据库密码:') $POSTGRES_PASSWORD"
fi

# 复制自定义配置文件（如果存在）
if [ -f "/etc/postgresql/postgresql.conf" ]; then
    echo "$(green '⚙️  使用自定义postgresql.conf配置文件')"
    mkdir -p "$PGDATA"
    cp /etc/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
fi

if [ -f "/etc/postgresql/pg_hba.conf" ]; then
    echo "$(green '🔒 使用自定义pg_hba.conf认证配置文件')"
    mkdir -p "$PGDATA"
    cp /etc/postgresql/pg_hba.conf "$PGDATA/pg_hba.conf"
fi

# 检查是否是首次启动
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "$(blue '🆕 首次启动，正在初始化数据库...')"

    # 设置权限
    chmod 700 "$PGDATA"

    # 调用原始的docker-entrypoint.sh进行初始化
    exec /usr/local/bin/docker-entrypoint.sh "$@"
else
    echo "$(green '🔄 数据库已存在，正在启动...')"

    # 检查数据目录权限
    if [ "$(stat -c %a "$PGDATA")" != "700" ]; then
        echo "$(yellow '🔧 修复数据目录权限...')"
        chmod 700 "$PGDATA"
    fi

    # 启动前检查
    echo "$(blue '🔍 启动前检查...')"

    # 检查配置文件
    if [ -f "$PGDATA/postgresql.conf" ]; then
        echo "✅ postgresql.conf 存在"
    else
        echo "$(yellow '⚠️  postgresql.conf 不存在，使用默认配置')"
    fi

    if [ -f "$PGDATA/pg_hba.conf" ]; then
        echo "✅ pg_hba.conf 存在"
    else
        echo "$(yellow '⚠️  pg_hba.conf 不存在，使用默认配置')"
    fi

    # 输出扩展信息
    echo "$(green '📦 已安装的PostgreSQL扩展:')"
    echo "  • PostGIS (地理信息系统)"
    echo "  • pgvector (向量数据库/AI)"
    echo "  • pg_cron (定时任务)"
    echo "  • pg_partman (分区管理)"
    echo "  • pgjwt (JWT处理)"
    echo "  • TimescaleDB (时间序列)"
    echo "  • 以及更多标准扩展..."

    # 启动PostgreSQL
    echo "$(blue '🚀 启动PostgreSQL服务器...')"
    exec /usr/local/bin/docker-entrypoint.sh "$@"
fi
