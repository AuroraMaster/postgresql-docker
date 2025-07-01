# 定制PostgreSQL Docker镜像
# 基于官方PostgreSQL 15镜像
FROM postgres:15 as postgres

# 维护者信息
LABEL maintainer="your-email@example.com"
LABEL description="Custom PostgreSQL with popular extensions"

# 设置环境变量
ENV POSTGRES_DB=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

# 切换到root用户进行系统级安装
USER root

# 更新包管理器并安装依赖
RUN apt-get update && apt-get install -y \
    # 构建工具
    build-essential \
    git \
    wget \
    curl \
    # PostgreSQL开发包
    postgresql-server-dev-15 \
    # 常用系统库
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libreadline-dev \
    zlib1g-dev \
    libbz2-dev \
    libffi-dev \
    # PostGIS依赖
    libgeos-dev \
    libproj-dev \
    libgdal-dev \
    # 其他有用工具
    vim \
    htop \
    && rm -rf /var/lib/apt/lists/*

# 安装常用PostgreSQL扩展
RUN apt-get update && apt-get install -y \
    # PostGIS - 地理信息系统扩展
    postgresql-15-postgis-3 \
    postgresql-15-postgis-3-scripts \
    # 其他常用扩展
    postgresql-15-contrib \
    postgresql-15-plpython3 \
    postgresql-15-pltcl \
    postgresql-15-plperl \
    # 全文搜索
    postgresql-15-rum \
    # 时间序列
    postgresql-15-timescaledb \
    # 监控扩展
    postgresql-15-pg-stat-kcache \
    postgresql-15-pg-qualstats \
    # 连接池
    postgresql-15-pgbouncer \
    && rm -rf /var/lib/apt/lists/*

# 手动编译安装一些特殊扩展
WORKDIR /tmp

# 安装pg_cron - 定时任务扩展
RUN git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make && make install

# 安装pgvector - 向量数据库扩展（AI/ML场景）
RUN git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make && make install

# 安装pg_partman - 分区管理扩展
RUN git clone https://github.com/pgpartman/pg_partman.git && \
    cd pg_partman && \
    make && make install

# 安装pgjwt - JWT处理扩展
RUN git clone https://github.com/michelp/pgjwt.git && \
    cd pgjwt && \
    make && make install

# 清理临时文件
RUN rm -rf /tmp/*

# 复制自定义配置文件
COPY ./config/postgresql.conf /etc/postgresql/postgresql.conf
COPY ./config/pg_hba.conf /etc/postgresql/pg_hba.conf

# 复制初始化脚本
COPY ./scripts/init-extensions.sql /docker-entrypoint-initdb.d/01-init-extensions.sql
COPY ./scripts/init-database.sql /docker-entrypoint-initdb.d/02-init-database.sql

# 复制自定义启动脚本
COPY ./scripts/docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# 切换回postgres用户
USER postgres

# 暴露端口
EXPOSE 5432

# 设置数据目录
VOLUME ["/var/lib/postgresql/data"]

# 使用自定义启动脚本
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["postgres"]
