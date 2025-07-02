# PostgreSQL 多功能数据库使用指南

## 概述

本PostgreSQL数据库集成了多个先进的扩展和功能模块，支持：
- 🕐 **时序数据处理** (TimescaleDB)
- 🌍 **地理信息系统** (PostGIS生态)
- 🤖 **AI/RAG应用** (向量数据库)
- 📊 **OLAP分析** (列式存储、分布式)
- 🕸️ **图数据库** (Apache AGE)
- 📋 **审计追踪** (完整的变更历史)

特别适合科学研究、核聚变装置数据管理等应用场景。

## 快速开始

### 1. 启动服务

```bash
# 开发环境（仅PostgreSQL）
make dev

# 完整环境（所有服务）
make up

# 管理环境（数据库+pgAdmin）
make up-admin
```

### 2. 初始化扩展

```bash
# 初始化所有扩展功能
make db-init
```

### 3. 连接数据库

```bash
# 命令行连接
make db-connect

# pgAdmin Web界面
# http://localhost:5050
# 用户名: admin@postgres.local
# 密码: admin123
```

## 功能模块详解

### 🕐 时序数据 (TimescaleDB)

#### 核心特性
- 超表(Hypertables)自动分区
- 连续聚合(Continuous Aggregates)
- 数据保留策略(Retention Policies)
- 压缩存储(Compression)

#### 使用示例

```sql
-- 创建传感器数据表
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER,
    temperature DOUBLE PRECISION,
    pressure DOUBLE PRECISION
);

-- 转换为时序超表
SELECT create_hypertable('sensor_data', 'time', chunk_time_interval => INTERVAL '1 day');

-- 插入数据
INSERT INTO sensor_data VALUES
    (NOW(), 1, 25.5, 1013.25),
    (NOW() - INTERVAL '1 hour', 1, 24.8, 1012.8);

-- 时序查询
SELECT time_bucket('1 hour', time) AS hour,
       AVG(temperature) as avg_temp
FROM sensor_data
WHERE time >= NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;
```

### 🌍 地理信息系统 (PostGIS)

#### 核心特性
- 几何/地理数据类型
- 空间索引(GIST)
- 路径规划(pgRouting)
- 地址标准化
- H3地理网格系统

#### 使用示例

```sql
-- 创建地理位置表
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT,
    location GEOMETRY(POINT, 4326)
);

-- 插入地理数据
INSERT INTO locations (name, location) VALUES
    ('北京', ST_GeomFromText('POINT(116.4074 39.9042)', 4326)),
    ('上海', ST_GeomFromText('POINT(121.4737 31.2304)', 4326));

-- 空间查询
SELECT name, ST_AsText(location)
FROM locations
WHERE ST_DWithin(location, ST_GeomFromText('POINT(116.4074 39.9042)', 4326), 1000000);

-- 距离计算
SELECT
    a.name as from_city,
    b.name as to_city,
    ST_Distance(a.location::geography, b.location::geography) / 1000 as distance_km
FROM locations a, locations b
WHERE a.id != b.id;
```

### 🤖 AI/RAG应用 (向量数据库)

#### 核心特性
- 向量相似度搜索(pgvector)
- 文档分块和嵌入
- 混合搜索(向量+全文)
- 知识图谱构建
- 多语言分词(zhparser)

#### 使用示例

```sql
-- 创建文档向量表
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 添加向量索引
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops);

-- 向量相似度搜索
SELECT title, content,
       1 - (embedding <=> '[0.1,0.2,0.3,...]'::vector) as similarity
FROM documents
ORDER BY embedding <=> '[0.1,0.2,0.3,...]'::vector
LIMIT 5;

-- 混合搜索（向量+全文）
SELECT d.title,
       ts_rank(to_tsvector('chinese', d.content), query) as text_score,
       1 - (d.embedding <=> search_vector) as vector_score
FROM documents d,
     to_tsquery('chinese', '核聚变') as query,
     '[0.1,0.2,0.3,...]'::vector as search_vector
WHERE to_tsvector('chinese', d.content) @@ query
   OR d.embedding <=> search_vector < 0.3
ORDER BY (ts_rank(to_tsvector('chinese', d.content), query) * 0.3 +
          (1 - (d.embedding <=> search_vector)) * 0.7) DESC;
```

### 📊 OLAP分析 (托卡马克实验数据)

#### 核心特性
- 分区表(Partitioning)
- 列式存储(Columnar)
- 并行查询
- 物化视图
- 数据立方体(Data Cube)

#### 使用示例

```sql
-- 托卡马克实验性能分析
SELECT * FROM olap.analyze_experiment_performance('TOKAMAK-1');

-- 异常检测
SELECT * FROM olap.detect_anomalies('exp_001', 'plasma_current', 2.5);

-- 多维分析
SELECT * FROM olap.drill_down_analysis('facility_name', 'total_shots', 2024);

-- 数据质量检查
SELECT * FROM olap.data_quality_check();

-- 性能监控
SELECT * FROM olap.performance_dashboard;
```

### 🕸️ 图数据库 (Apache AGE)

#### 核心特性
- Cypher查询语言
- 图遍历算法
- 节点关系分析
- 路径查找
- 社交网络分析

#### 使用示例

```sql
-- 查找研究者协作网络
SELECT * FROM graph.find_collaboration_network('张三', 3);

-- 实验上下文查询
SELECT * FROM graph.get_experiment_context('exp_001');

-- 原生Cypher查询
SELECT * FROM cypher('scientific_graph', $$
    MATCH (r:Researcher)-[c:COLLABORATED_WITH]-(other:Researcher)
    WHERE r.name = '张三'
    RETURN other.name, c.project, c.start_date
$$) AS (name agtype, project agtype, start_date agtype);
```

### 📋 审计追踪 (变更历史)

#### 核心特性
- 自动变更记录
- 字段级审计
- 时间点查询
- 变更回滚
- 自动化清理

#### 使用示例

```sql
-- 查看表的变更历史
SELECT * FROM audit.view_table_history('users');

-- 时间点查询
SELECT * FROM audit.query_at_time('users', '2024-01-01 10:00:00');

-- 字段变更追踪
SELECT * FROM audit.field_change_history('users', 'email');

-- 用户操作审计
SELECT * FROM audit.user_activity_log('admin_user');
```

## 实际应用场景

### 托卡马克核聚变装置数据管理

这个数据库系统特别适合托卡马克装置的科学数据管理：

1. **实时数据采集**: 使用TimescaleDB处理高频传感器数据
2. **空间定位**: 用PostGIS管理装置内部组件的3D位置关系
3. **智能分析**: 利用AI/RAG进行实验数据的智能问答和知识发现
4. **多维分析**: 通过OLAP功能进行实验参数的多维度分析
5. **关系网络**: 用图数据库分析研究团队协作和实验依赖关系
6. **变更追踪**: 完整记录装置配置和实验参数的变更历史

### 示例：完整的实验数据分析流程

```sql
-- 1. 插入传感器数据
INSERT INTO olap.experiment_data (
    experiment_id, facility_name, plasma_current,
    electron_temperature, ion_temperature, heating_power
) VALUES
    ('exp_2024_001', 'TOKAMAK-1', 2.5, 15000, 12000, 25.5);

-- 2. 空间位置记录
INSERT INTO gis.device_locations (device_id, location_3d) VALUES
    ('sensor_001', ST_GeomFromText('POINT Z(1.5 2.3 0.8)'));

-- 3. 实验报告向量化存储
INSERT INTO rag.documents (title, content, embedding) VALUES
    ('实验报告_exp_2024_001', '本次实验成功达到预期等离子体电流...',
     rag.generate_embedding('实验报告内容'));

-- 4. 研究网络关系
SELECT * FROM cypher('scientific_graph', $$
    CREATE (exp:Experiment {id: 'exp_2024_001', date: '2024-01-15'})
    CREATE (researcher:Researcher {name: '李博士'})
    CREATE (researcher)-[:CONDUCTED]->(exp)
$$) AS (result agtype);

-- 5. 综合分析查询
WITH experiment_perf AS (
    SELECT * FROM olap.analyze_experiment_performance('TOKAMAK-1')
),
spatial_context AS (
    SELECT COUNT(*) as device_count
    FROM gis.device_locations
    WHERE ST_3DDistance(location_3d, ST_GeomFromText('POINT Z(0 0 0)')) < 5
),
knowledge_base AS (
    SELECT COUNT(*) as related_docs
    FROM rag.documents
    WHERE content LIKE '%等离子体%'
)
SELECT
    ep.total_shots,
    ep.avg_plasma_current,
    sc.device_count,
    kb.related_docs
FROM experiment_perf ep, spatial_context sc, knowledge_base kb;
```

## 监控和维护

### 性能监控

```bash
# 查看服务状态
make status

# 查看PostgreSQL日志
make logs-postgres

# 健康检查
make health
```

### 数据备份

```bash
# 创建备份
make db-backup

# 恢复备份
make db-restore BACKUP_FILE=backup_20240115_143022.sql.gz
```

### 自动化维护

系统已配置自动化任务：
- 每天凌晨2点：分区维护和清理
- 每周日凌晨3点：统计信息更新
- 定期数据质量检查

## 扩展和定制

### 添加新的时序表

```sql
-- 创建新的传感器表
CREATE TABLE new_sensor_data (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT,
    measurement JSONB
);

-- 转换为超表
SELECT create_hypertable('new_sensor_data', 'time');

-- 添加数据保留策略
SELECT add_retention_policy('new_sensor_data', INTERVAL '1 year');
```

### 自定义向量搜索

```sql
-- 添加新的向量维度
ALTER TABLE documents ADD COLUMN custom_embedding vector(768);

-- 创建专用索引
CREATE INDEX ON documents USING ivfflat (custom_embedding vector_l2_ops);
```

### 扩展图模型

```sql
-- 添加新的节点类型
SELECT * FROM cypher('scientific_graph', $$
    CREATE (device:Device {id: 'tokamak_coil_01', type: 'magnetic_coil'})
    CREATE (exp:Experiment {id: 'exp_2024_001'})
    CREATE (device)-[:USED_IN]->(exp)
$$) AS (result agtype);
```

## 故障排除

### 常见问题

1. **向量搜索慢**：检查是否创建了向量索引
2. **时序查询慢**：确认超表分区设置正确
3. **空间查询慢**：验证GIST索引是否存在
4. **图查询失败**：检查Apache AGE扩展安装状态

### 性能优化

```sql
-- 查看索引使用情况
SELECT * FROM olap.query_performance;

-- 检查表统计信息
ANALYZE;

-- 查看慢查询
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

## 总结

这个PostgreSQL多功能数据库系统为科学研究提供了完整的数据管理解决方案，结合了现代数据库的最佳实践和先进技术，特别适合：

- 核聚变/托卡马克装置数据管理
- 科学研究数据分析
- IoT时序数据处理
- 地理空间分析
- AI/ML应用开发
- 企业级数据仓库

通过统一的PostgreSQL平台，避免了多系统集成的复杂性，符合奥卡姆剃刀原理的简洁性要求。
