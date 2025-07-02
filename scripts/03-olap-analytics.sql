-- ================================================================
-- PostgreSQL OLAP和数据分析扩展模块 (OLAP & Analytics Extensions)
-- 整合: 时序数据库、地理信息系统、OLAP、图数据库
-- ================================================================

\echo '=================================================='
\echo 'Loading OLAP & Analytics Extensions...'
\echo 'OLAP和数据分析扩展模块加载中...'
\echo '=================================================='

-- ================================================================
-- 1. 核心OLAP扩展
-- ================================================================

\echo 'Loading core OLAP extensions...'

-- 分布式数据库
CREATE EXTENSION IF NOT EXISTS citus;
CREATE EXTENSION IF NOT EXISTS columnar;

-- 分区管理
CREATE EXTENSION IF NOT EXISTS pg_partman;

-- 图数据库
CREATE EXTENSION IF NOT EXISTS age;

-- 查询优化
CREATE EXTENSION IF NOT EXISTS pg_hint_plan;

-- 假设索引（查询优化）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'hypopg') THEN
        CREATE EXTENSION IF NOT EXISTS hypopg;
        RAISE NOTICE 'hypopg extension loaded successfully';
    ELSE
        RAISE NOTICE 'hypopg extension not available';
    END IF;
END
$$;

-- HyperLogLog（基数估算）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'hll') THEN
        CREATE EXTENSION IF NOT EXISTS hll;
        RAISE NOTICE 'hll extension loaded successfully';
    ELSE
        RAISE NOTICE 'hll extension not available';
    END IF;
END
$$;

-- ================================================================
-- 2. 时序数据库扩展 (TimescaleDB)
-- ================================================================

\echo 'Loading TimescaleDB extensions...'

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 创建schema
CREATE SCHEMA IF NOT EXISTS timeseries;
CREATE SCHEMA IF NOT EXISTS olap;
CREATE SCHEMA IF NOT EXISTS graph;

-- 添加AGE到搜索路径
SELECT set_config('search_path', current_setting('search_path') || ',ag_catalog', false);

-- ================================================================
-- 3. 时序数据表设计
-- ================================================================

\echo 'Creating time series tables...'

-- 传感器数据表（超表）
CREATE TABLE IF NOT EXISTS timeseries.sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER NOT NULL,
    temperature DOUBLE PRECISION,
    pressure DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    voltage DOUBLE PRECISION,
    current_ma DOUBLE PRECISION,
    status TEXT DEFAULT 'active',
    location_id INTEGER,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 转换为超表
SELECT create_hypertable('timeseries.sensor_data', 'time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor_id
    ON timeseries.sensor_data (sensor_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_data_time
    ON timeseries.sensor_data (time DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_data_status
    ON timeseries.sensor_data (status, time DESC);

-- 设置数据保留策略（保留1年数据）
SELECT add_retention_policy('timeseries.sensor_data', INTERVAL '1 year', if_not_exists => TRUE);

-- 启用压缩
ALTER TABLE timeseries.sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_segmentby = 'sensor_id'
);

-- 设置压缩策略
SELECT add_compression_policy('timeseries.sensor_data', INTERVAL '7 days', if_not_exists => TRUE);

-- ================================================================
-- 4. OLAP分析表（列式存储）
-- ================================================================

\echo 'Creating OLAP analysis tables...'

-- 实验数据表
CREATE TABLE IF NOT EXISTS olap.experiment_data (
    id BIGSERIAL,
    experiment_id TEXT NOT NULL,
    shot_number INTEGER,
    timestamp_ms BIGINT,
    -- 物理参数
    plasma_current DOUBLE PRECISION,
    magnetic_field DOUBLE PRECISION,
    electron_temperature DOUBLE PRECISION,
    ion_temperature DOUBLE PRECISION,
    electron_density DOUBLE PRECISION,
    -- 控制参数
    heating_power DOUBLE PRECISION,
    gas_puff_rate DOUBLE PRECISION,
    -- 诊断数据
    diagnostic_signals JSONB,
    -- 元数据
    facility_name TEXT,
    operator_name TEXT,
    configuration JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) USING columnar;

-- 时序分析表
CREATE TABLE IF NOT EXISTS olap.timeseries_analysis (
    id BIGSERIAL,
    experiment_id TEXT NOT NULL,
    parameter_name TEXT NOT NULL,
    time_window_start TIMESTAMP WITH TIME ZONE,
    time_window_end TIMESTAMP WITH TIME ZONE,
    -- 统计指标
    min_value DOUBLE PRECISION,
    max_value DOUBLE PRECISION,
    avg_value DOUBLE PRECISION,
    std_deviation DOUBLE PRECISION,
    -- 高级分析
    fft_coefficients DOUBLE PRECISION[],
    correlation_matrix JSONB,
    anomaly_score DOUBLE PRECISION,
    -- 分类标签
    event_type TEXT,
    quality_flag INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) USING columnar;

-- 数据立方体表
CREATE TABLE IF NOT EXISTS olap.data_cube (
    id BIGSERIAL,
    -- 维度字段
    facility TEXT,
    year_month TEXT,
    experiment_type TEXT,
    configuration_type TEXT,
    -- 度量字段
    total_shots INTEGER,
    successful_shots INTEGER,
    avg_duration_sec DOUBLE PRECISION,
    max_plasma_current DOUBLE PRECISION,
    avg_temperature DOUBLE PRECISION,
    energy_output_mj DOUBLE PRECISION,
    aggregated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
) USING columnar;

-- ================================================================
-- 5. 连续聚合视图
-- ================================================================

\echo 'Creating continuous aggregates...'

-- 小时级聚合视图
CREATE MATERIALIZED VIEW IF NOT EXISTS timeseries.sensor_data_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
       sensor_id,
       location_id,
       AVG(temperature) as avg_temperature,
       MAX(temperature) as max_temperature,
       MIN(temperature) as min_temperature,
       AVG(pressure) as avg_pressure,
       AVG(humidity) as avg_humidity,
       COUNT(*) as sample_count,
       COUNT(*) FILTER (WHERE status = 'active') as active_count
FROM timeseries.sensor_data
GROUP BY bucket, sensor_id, location_id;

-- 添加刷新策略
SELECT add_continuous_aggregate_policy('timeseries.sensor_data_hourly',
    start_offset => INTERVAL '2 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '30 minutes',
    if_not_exists => TRUE);

-- ================================================================
-- 6. 图数据库结构
-- ================================================================

\echo 'Setting up graph database...'

-- 创建图
SELECT * FROM ag_catalog.create_graph('scientific_graph');

-- 创建图数据示例
SELECT * FROM cypher('scientific_graph', $$
    CREATE (:Facility {name: 'research_center', type: 'laboratory', location: 'main_campus'})
$$) AS (a agtype);

SELECT * FROM cypher('scientific_graph', $$
    CREATE (:Experiment {id: 'exp_001', type: 'sensor_monitoring', status: 'active'})
$$) AS (a agtype);

SELECT * FROM cypher('scientific_graph', $$
    CREATE (:Researcher {name: 'system_admin', role: 'data_analyst', expertise: 'time_series'})
$$) AS (a agtype);

-- ================================================================
-- 7. 分区策略
-- ================================================================

\echo 'Setting up partitioning...'

-- 为实验数据表设置分区
SELECT partman.create_parent(
    p_parent_table => 'olap.experiment_data',
    p_control => 'created_at',
    p_type => 'range',
    p_interval => 'monthly',
    p_premake => 3
);

-- ================================================================
-- 8. 分布式表配置（Citus）
-- ================================================================

\echo 'Configuring distributed tables...'

-- 分布式表
SELECT create_distributed_table('olap.experiment_data', 'experiment_id');
SELECT create_distributed_table('olap.timeseries_analysis', 'experiment_id');

-- 引用表
SELECT create_reference_table('olap.data_cube');

-- ================================================================
-- 9. 性能优化索引
-- ================================================================

\echo 'Creating performance indexes...'

-- OLAP表索引
CREATE INDEX IF NOT EXISTS idx_experiment_data_facility_time
    ON olap.experiment_data (facility_name, created_at);
CREATE INDEX IF NOT EXISTS idx_experiment_data_shot
    ON olap.experiment_data (shot_number);
CREATE INDEX IF NOT EXISTS idx_timeseries_exp_param
    ON olap.timeseries_analysis (experiment_id, parameter_name);
CREATE INDEX IF NOT EXISTS idx_data_cube_dimensions
    ON olap.data_cube (facility, year_month, experiment_type);

-- ================================================================
-- 10. 分析函数
-- ================================================================

\echo 'Creating analytics functions...'

-- 获取最新读数
CREATE OR REPLACE FUNCTION timeseries.get_latest_readings(sensor_id_param INTEGER)
RETURNS TABLE(
    time TIMESTAMPTZ,
    temperature DOUBLE PRECISION,
    pressure DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT sd.time, sd.temperature, sd.pressure, sd.humidity, sd.status
    FROM timeseries.sensor_data sd
    WHERE sd.sensor_id = sensor_id_param
    ORDER BY sd.time DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 异常检测函数
CREATE OR REPLACE FUNCTION timeseries.detect_temperature_anomalies(
    sensor_id_param INTEGER,
    hours_back INTEGER DEFAULT 24,
    threshold_multiplier DOUBLE PRECISION DEFAULT 2.0
)
RETURNS TABLE(
    time TIMESTAMPTZ,
    temperature DOUBLE PRECISION,
    avg_temp DOUBLE PRECISION,
    is_anomaly BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT AVG(temperature) as mean_temp,
               STDDEV(temperature) as std_temp
        FROM timeseries.sensor_data
        WHERE sensor_id = sensor_id_param
          AND time >= NOW() - (hours_back || ' hours')::INTERVAL
          AND temperature IS NOT NULL
    )
    SELECT sd.time,
           sd.temperature,
           s.mean_temp,
           (ABS(sd.temperature - s.mean_temp) > threshold_multiplier * s.std_temp) as is_anomaly
    FROM timeseries.sensor_data sd, stats s
    WHERE sd.sensor_id = sensor_id_param
      AND sd.time >= NOW() - (hours_back || ' hours')::INTERVAL
      AND sd.temperature IS NOT NULL
      AND ABS(sd.temperature - s.mean_temp) > threshold_multiplier * s.std_temp
    ORDER BY sd.time DESC;
END;
$$ LANGUAGE plpgsql;

-- OLAP分析函数
CREATE OR REPLACE FUNCTION olap.calculate_experiment_stats(facility_param TEXT)
RETURNS TABLE(
    experiment_type TEXT,
    total_experiments BIGINT,
    avg_duration DOUBLE PRECISION,
    success_rate DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ed.configuration->>'type' as experiment_type,
        COUNT(*) as total_experiments,
        AVG(EXTRACT(EPOCH FROM (ed.created_at - (ed.configuration->>'start_time')::timestamp))) as avg_duration,
        (COUNT(*) FILTER (WHERE ed.configuration->>'status' = 'success'))::DOUBLE PRECISION / COUNT(*) as success_rate
    FROM olap.experiment_data ed
    WHERE ed.facility_name = facility_param
    GROUP BY ed.configuration->>'type';
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- 11. 权限设置
-- ================================================================

\echo 'Setting up permissions...'

-- 授予schema使用权限
GRANT USAGE ON SCHEMA timeseries TO PUBLIC;
GRANT USAGE ON SCHEMA olap TO PUBLIC;
GRANT USAGE ON SCHEMA graph TO PUBLIC;

-- 授予表权限
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA timeseries TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA olap TO PUBLIC;

-- 授予序列权限
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA timeseries TO PUBLIC;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA olap TO PUBLIC;

-- 授予函数执行权限
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA timeseries TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA olap TO PUBLIC;

\echo '=================================================='
\echo 'OLAP & Analytics Extensions loaded successfully!'
\echo 'OLAP和数据分析扩展模块加载完成！'
\echo '=================================================='
\echo 'Available features:'
\echo '- TimescaleDB time series database'
\echo '- Citus distributed computing'
\echo '- Apache AGE graph database'
\echo '- Columnar storage for analytics'
\echo '- Automated partitioning'
\echo '- Continuous aggregates'
\echo '- Performance optimization'
\echo '=================================================='
