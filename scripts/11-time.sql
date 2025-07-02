-- PostgreSQL 时序数据库功能初始化 (TimescaleDB)
-- ==================================================

-- 安装TimescaleDB扩展
-- CREATE EXTENSION IF NOT EXISTS timescaledb; -- 已在03-olap-analytics.sql中声明

-- 创建时序数据schema
CREATE SCHEMA IF NOT EXISTS timeseries;

-- 创建传感器数据表（示例）
CREATE TABLE IF NOT EXISTS timeseries.sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER NOT NULL,
    temperature DOUBLE PRECISION,
    pressure DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 转换为超表（hypertable）
SELECT create_hypertable('timeseries.sensor_data', 'time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor_id
    ON timeseries.sensor_data (sensor_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_data_time
    ON timeseries.sensor_data (time DESC);

-- 设置数据保留策略（保留1年数据）
SELECT add_retention_policy('timeseries.sensor_data', INTERVAL '1 year', if_not_exists => TRUE);

-- 启用压缩
ALTER TABLE timeseries.sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'time DESC',
    timescaledb.compress_segmentby = 'sensor_id'
);

-- 设置压缩策略（压缩7天前的数据）
SELECT add_compression_policy('timeseries.sensor_data', INTERVAL '7 days', if_not_exists => TRUE);

-- 创建连续聚合视图
CREATE MATERIALIZED VIEW IF NOT EXISTS timeseries.sensor_data_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
       sensor_id,
       AVG(temperature) as avg_temperature,
       MAX(temperature) as max_temperature,
       MIN(temperature) as min_temperature,
       AVG(pressure) as avg_pressure,
       AVG(humidity) as avg_humidity,
       COUNT(*) as sample_count
FROM timeseries.sensor_data
GROUP BY bucket, sensor_id;

-- 为连续聚合添加刷新策略
SELECT add_continuous_aggregate_policy('timeseries.sensor_data_hourly',
    start_offset => INTERVAL '2 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '30 minutes',
    if_not_exists => TRUE);

-- 创建日聚合视图
CREATE MATERIALIZED VIEW IF NOT EXISTS timeseries.sensor_data_daily
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', time) AS bucket,
       sensor_id,
       AVG(temperature) as avg_temperature,
       MAX(temperature) as max_temperature,
       MIN(temperature) as min_temperature,
       AVG(pressure) as avg_pressure,
       AVG(humidity) as avg_humidity,
       COUNT(*) as sample_count
FROM timeseries.sensor_data
GROUP BY bucket, sensor_id;

-- 为日聚合添加刷新策略
SELECT add_continuous_aggregate_policy('timeseries.sensor_data_daily',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE);

-- 创建实用函数
CREATE OR REPLACE FUNCTION timeseries.get_latest_readings(sensor_id_param INTEGER)
RETURNS TABLE(
    time TIMESTAMPTZ,
    temperature DOUBLE PRECISION,
    pressure DOUBLE PRECISION,
    humidity DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT sd.time, sd.temperature, sd.pressure, sd.humidity
    FROM timeseries.sensor_data sd
    WHERE sd.sensor_id = sensor_id_param
    ORDER BY sd.time DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 创建温度异常检测函数
CREATE OR REPLACE FUNCTION timeseries.detect_temperature_anomalies(
    sensor_id_param INTEGER,
    hours_back INTEGER DEFAULT 24
)
RETURNS TABLE(
    time TIMESTAMPTZ,
    temperature DOUBLE PRECISION,
    avg_temp DOUBLE PRECISION,
    deviation DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT AVG(temperature) as mean_temp,
               STDDEV(temperature) as std_temp
        FROM timeseries.sensor_data
        WHERE sensor_id = sensor_id_param
          AND time >= NOW() - (hours_back || ' hours')::INTERVAL
    )
    SELECT sd.time,
           sd.temperature,
           s.mean_temp,
           ABS(sd.temperature - s.mean_temp) as deviation
    FROM timeseries.sensor_data sd, stats s
    WHERE sd.sensor_id = sensor_id_param
      AND sd.time >= NOW() - (hours_back || ' hours')::INTERVAL
      AND ABS(sd.temperature - s.mean_temp) > 2 * s.std_temp
    ORDER BY sd.time DESC;
END;
$$ LANGUAGE plpgsql;

-- 创建时序数据统计视图
CREATE OR REPLACE VIEW timeseries.data_summary AS
SELECT
    'sensor_data' as table_name,
    COUNT(*) as total_records,
    MIN(time) as earliest_record,
    MAX(time) as latest_record,
    COUNT(DISTINCT sensor_id) as unique_sensors,
    pg_size_pretty(pg_total_relation_size('timeseries.sensor_data')) as table_size
FROM timeseries.sensor_data;

-- 插入示例数据
INSERT INTO timeseries.sensor_data (time, sensor_id, temperature, pressure, humidity) VALUES
    (NOW() - INTERVAL '1 hour', 1, 25.5, 1013.25, 60.0),
    (NOW() - INTERVAL '2 hours', 1, 24.8, 1012.8, 62.5),
    (NOW() - INTERVAL '3 hours', 1, 26.2, 1014.1, 58.3),
    (NOW() - INTERVAL '1 hour', 2, 22.1, 1015.2, 65.8),
    (NOW() - INTERVAL '2 hours', 2, 21.9, 1014.9, 66.2)
ON CONFLICT DO NOTHING;

-- 设置权限
GRANT USAGE ON SCHEMA timeseries TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA timeseries TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA timeseries TO PUBLIC;

-- 输出配置完成信息
\echo '✅ TimescaleDB时序数据库功能配置完成!'
\echo '🔧 已配置:'
\echo '   - sensor_data超表（按天分区）'
\echo '   - 自动数据保留策略（1年）'
\echo '   - 数据压缩（7天后）'
\echo '   - 小时级连续聚合'
\echo '   - 日级连续聚合'
\echo '   - 异常检测函数'
\echo ''
\echo '📊 使用示例:'
\echo '   -- 查看最新读数:'
\echo '   SELECT * FROM timeseries.get_latest_readings(1);'
\echo ''
\echo '   -- 异常检测:'
\echo '   SELECT * FROM timeseries.detect_temperature_anomalies(1, 24);'
\echo ''
\echo '   -- 数据统计:'
\echo '   SELECT * FROM timeseries.data_summary;'
