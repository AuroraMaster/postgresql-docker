#!/bin/bash
# PostgreSQL Docker 启动脚本
set -Eeo pipefail

echo "🐘 Starting PostgreSQL with Extensions..."

# 自动生成密码（如果未设置）
if [ -z "$POSTGRES_PASSWORD" ] && [ -z "$POSTGRES_HOST_AUTH_METHOD" ]; then
    export POSTGRES_PASSWORD=$(openssl rand -base64 32)
    echo "Generated password: $POSTGRES_PASSWORD"
fi

# 复制自定义配置文件
if [ -f "/etc/postgresql/postgresql.conf" ]; then
    mkdir -p "$PGDATA"
    cp /etc/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
fi

if [ -f "/etc/postgresql/pg_hba.conf" ]; then
    mkdir -p "$PGDATA"
    cp /etc/postgresql/pg_hba.conf "$PGDATA/pg_hba.conf"
fi

# 首次启动或重启
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing database..."
    chmod 700 "$PGDATA"
    exec /usr/local/bin/docker-entrypoint.sh "$@"
else
    echo "Starting existing database..."

    # 修复权限
    if [ "$(stat -c %a "$PGDATA")" != "700" ]; then
        chmod 700 "$PGDATA"
    fi

    echo "Extensions: PostGIS, pgvector, TimescaleDB, pg_cron, and more..."
    exec /usr/local/bin/docker-entrypoint.sh "$@"
fi
