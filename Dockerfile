# ================================================================
# PostgreSQL 扩展集成镜像 (Debian based)
# 支持科学计算、金融、生物信息学、IoT、GIS、RAG等专业领域
# ================================================================

# 使用官方PostgreSQL 15 Debian镜像作为基础
FROM postgres:15-bullseye

# 设置维护者信息
LABEL maintainer="PostgreSQL Extensions Team"
LABEL description="PostgreSQL with comprehensive extensions for scientific computing, finance, bioinformatics, IoT, GIS, and RAG"

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV POSTGRES_DB=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

# 更新系统并安装基础工具
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    lsb-release \
    ca-certificates \
    software-properties-common \
    build-essential \
    git \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# ================================================================
# 添加各种扩展源
# ================================================================

# 添加PostgreSQL官方APT源
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# 添加TimescaleDB源
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" > /etc/apt/sources.list.d/timescaledb.list \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | apt-key add -

# 添加PostGIS源 (通常包含在PostgreSQL官方源中)
# 添加Citus源
RUN curl https://install.citusdata.com/community/deb.sh | bash

# ================================================================
# 安装核心PostgreSQL扩展
# ================================================================

RUN apt-get update && apt-get install -y \
    # 核心扩展
    postgresql-15-postgis-3 \
    postgresql-15-postgis-3-scripts \
    postgresql-15-pgrouting \
    postgresql-contrib-15 \
    # 时序数据库
    timescaledb-2-postgresql-15 \
    # 分布式数据库
    postgresql-15-citus-11.1 \
    # 全文搜索和中文分词
    postgresql-15-zhparser \
    # 机器学习扩展
    postgresql-15-age \
    # 向量数据库
    postgresql-15-pgvector \
    # 定时任务扩展
    postgresql-15-cron \
    # 分区管理扩展
    postgresql-15-partman \
    # 相似度计算扩展
    postgresql-15-similarity \
    # 机器学习和分析扩展
    postgresql-15-hypopg \
    postgresql-15-hll \
    # JSON查询扩展
    postgresql-15-jsquery \
    # 逻辑复制解码扩展
    postgresql-15-decoderbufs \
    # 数据类型和结构扩展
    postgresql-15-periods \
    postgresql-15-asn1oid \
    postgresql-15-debversion \
    postgresql-15-numeral \
    postgresql-15-ip4r \
    # GIS和空间数据扩展
    postgresql-15-pointcloud \
    postgresql-15-ogr-fdw \
    # 编程语言扩展
    postgresql-15-plr \
    # 连接和复制扩展
    postgresql-15-mysql-fdw \
    postgresql-15-auto-failover \
    postgresql-15-bgw-replstatus \
    postgresql-15-londiste-sql \
    # 数据库管理和优化扩展
    postgresql-15-dirtyread \
    postgresql-15-extra-window-functions \
    postgresql-15-first-last-agg \
    postgresql-15-icu-ext \
    postgresql-15-omnidb \
    # 高级索引和搜索扩展
    postgresql-15-rum \
    postgresql-15-q3c \
    postgresql-15-repack \
    # 数据类型扩展
    postgresql-15-prefix \
    postgresql-15-semver \
    postgresql-15-tdigest \
    && rm -rf /var/lib/apt/lists/*

# ================================================================
# 编译安装特殊扩展
# ================================================================

# 安装编译依赖
RUN apt-get update && apt-get install -y \
    postgresql-server-dev-15 \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libgdal-dev \
    libproj-dev \
    libgeos-dev \
    libjson-c-dev \
    libprotobuf-c-dev \
    protobuf-c-compiler \
    python3-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# pg_similarity, pg_partman, pg_cron 已通过 apt 安装

# 安装pgjwt (JWT处理)
RUN cd /tmp \
    && git clone https://github.com/michelp/pgjwt.git \
    && cd pgjwt \
    && make install \
    && cd / && rm -rf /tmp/pgjwt

# 安装pg_stat_monitor (增强统计)
RUN cd /tmp \
    && git clone https://github.com/percona/pg_stat_monitor.git \
    && cd pg_stat_monitor \
    && make USE_PGXS=1 \
    && make USE_PGXS=1 install \
    && cd / && rm -rf /tmp/pg_stat_monitor

# ================================================================
# Python和机器学习相关
# ================================================================

# 安装Python包用于PL/Python
RUN pip3 install --no-cache-dir \
    numpy \
    pandas \
    scikit-learn \
    matplotlib \
    seaborn \
    requests \
    psycopg2-binary

# ================================================================
# 配置PostgreSQL
# ================================================================

# 修改PostgreSQL配置
RUN echo "shared_preload_libraries = 'timescaledb,citus,pg_cron,pg_stat_statements'" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "cron.database_name = 'postgres'" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "max_worker_processes = 20" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "max_parallel_workers = 8" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "max_parallel_workers_per_gather = 4" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "# Configuration optimized for PostgreSQL Extensions Suite" >> /usr/share/postgresql/postgresql.conf.sample

# 复制初始化脚本
COPY scripts/ /docker-entrypoint-initdb.d/
COPY scripts/docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh

# 设置脚本权限
RUN chmod +x /usr/local/bin/custom-entrypoint.sh \
    && chmod +x /docker-entrypoint-initdb.d/*.sh \
    && chmod 644 /docker-entrypoint-initdb.d/*.sql

# ================================================================
# 健康检查
# ================================================================

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pg_isready -U postgres -d postgres || exit 1

# ================================================================
# 启动配置
# ================================================================

# 设置工作目录
WORKDIR /var/lib/postgresql/data

# 暴露端口
EXPOSE 5432

# 使用自定义启动脚本
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["postgres"]

# ================================================================
# 构建信息
# ================================================================

LABEL org.opencontainers.image.title="PostgreSQL Extensions Suite"
LABEL org.opencontainers.image.description="Comprehensive PostgreSQL with extensions for scientific computing, finance, bioinformatics, IoT, GIS, and RAG"
LABEL org.opencontainers.image.version="15.0"
LABEL org.opencontainers.image.vendor="PostgreSQL Extensions Team"
