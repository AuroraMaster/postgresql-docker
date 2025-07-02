-- ================================================================
-- PostgreSQL 物联网扩展模块 (IoT Extensions)
-- 专业物联网设备管理、传感器数据、边缘计算扩展集合
-- ================================================================

\echo '=================================================='
\echo 'Loading IoT Extensions...'
\echo '物联网、传感器数据、边缘计算扩展'
\echo '=================================================='

-- ================================================================
-- 基础扩展 (Core Extensions)
-- ================================================================

-- 时间序列数据支持
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- 时间范围索引
\echo 'Created extension: btree_gist (时间序列索引)'

-- JSON数据处理
CREATE EXTENSION IF NOT EXISTS plpgsql;  -- 确保存储过程支持
\echo 'Verified extension: plpgsql (存储过程支持)'

-- UUID生成用于设备标识 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- 已在核心扩展中加载
\echo 'Using extension: uuid-ossp (设备唯一标识)'

-- HStore用于设备属性存储 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS hstore; -- 已在01-core-extensions.sql中声明
\echo 'Using extension: hstore (设备属性键值存储)'

-- 加密函数用于设备通信安全 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS pgcrypto; -- 已在核心扩展中加载
\echo 'Using extension: pgcrypto (设备通信加密)'

-- 立方体数据类型用于多维传感器数据 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS cube; -- 已在核心扩展中加载
\echo 'Using extension: cube (多维传感器数据)'

-- ================================================================
-- IoT数据类型定义 (IoT Data Types)
-- ================================================================

-- 创建IoT相关数据类型
DO $$
BEGIN
    -- 设备状态类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'device_status') THEN
        CREATE TYPE device_status AS ENUM ('online', 'offline', 'maintenance', 'error', 'unknown');
        COMMENT ON TYPE device_status IS '设备状态枚举类型';
    END IF;

    -- 传感器数据类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sensor_value') THEN
        CREATE DOMAIN sensor_value AS NUMERIC(12,4);
        COMMENT ON DOMAIN sensor_value IS '传感器数值类型 (高精度)';
    END IF;

    -- 信号强度类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'signal_strength') THEN
        CREATE DOMAIN signal_strength AS INTEGER CHECK (VALUE >= -120 AND VALUE <= 0);
        COMMENT ON DOMAIN signal_strength IS '信号强度类型 (dBm, -120到0)';
    END IF;

    -- 电池电量类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'battery_level') THEN
        CREATE DOMAIN battery_level AS INTEGER CHECK (VALUE >= 0 AND VALUE <= 100);
        COMMENT ON DOMAIN battery_level IS '电池电量类型 (0-100%)';
    END IF;

    -- MAC地址类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mac_address') THEN
        CREATE DOMAIN mac_address AS TEXT CHECK (VALUE ~ '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
        COMMENT ON DOMAIN mac_address IS 'MAC地址类型';
    END IF;
END
$$;

\echo 'Created IoT data types: device_status, sensor_value, signal_strength, battery_level, mac_address'

-- ================================================================
-- 设备管理函数 (Device Management Functions)
-- ================================================================

-- 设备心跳检查函数
CREATE OR REPLACE FUNCTION check_device_heartbeat(
    device_id UUID,
    heartbeat_interval INTERVAL DEFAULT '5 minutes'
) RETURNS device_status AS $$
DECLARE
    last_seen TIMESTAMP;
    status device_status;
BEGIN
    -- 这里应该查询实际的设备心跳表
    -- SELECT last_heartbeat INTO last_seen FROM device_heartbeats WHERE device_id = $1;

    -- 模拟逻辑
    IF last_seen IS NULL THEN
        RETURN 'unknown'::device_status;
    ELSIF last_seen < NOW() - heartbeat_interval THEN
        RETURN 'offline'::device_status;
    ELSE
        RETURN 'online'::device_status;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_device_heartbeat(UUID, INTERVAL) IS '设备心跳检查函数';

-- 设备电池状态评估
CREATE OR REPLACE FUNCTION evaluate_battery_status(
    current_level battery_level,
    voltage NUMERIC DEFAULT NULL
) RETURNS TEXT AS $$
BEGIN
    CASE
        WHEN current_level >= 80 THEN RETURN 'excellent';
        WHEN current_level >= 60 THEN RETURN 'good';
        WHEN current_level >= 40 THEN RETURN 'fair';
        WHEN current_level >= 20 THEN RETURN 'low';
        WHEN current_level >= 10 THEN RETURN 'critical';
        ELSE RETURN 'replace_soon';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION evaluate_battery_status(battery_level, NUMERIC) IS '设备电池状态评估函数';

-- 信号强度分级函数
CREATE OR REPLACE FUNCTION signal_quality(rssi signal_strength)
RETURNS TEXT AS $$
BEGIN
    CASE
        WHEN rssi >= -30 THEN RETURN 'excellent';
        WHEN rssi >= -50 THEN RETURN 'good';
        WHEN rssi >= -70 THEN RETURN 'fair';
        WHEN rssi >= -90 THEN RETURN 'poor';
        ELSE RETURN 'no_signal';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION signal_quality(signal_strength) IS '信号强度分级函数';

-- ================================================================
-- 传感器数据处理函数 (Sensor Data Processing Functions)
-- ================================================================

-- 传感器数据异常检测
CREATE OR REPLACE FUNCTION detect_sensor_anomaly(
    current_value sensor_value,
    historical_avg sensor_value,
    threshold_multiplier NUMERIC DEFAULT 2.0
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN ABS(current_value - historical_avg) > (historical_avg * threshold_multiplier);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION detect_sensor_anomaly(sensor_value, sensor_value, NUMERIC) IS '传感器数据异常检测函数';

-- 温度单位转换函数
CREATE OR REPLACE FUNCTION convert_temperature(
    value sensor_value,
    from_unit TEXT,
    to_unit TEXT
) RETURNS sensor_value AS $$
BEGIN
    -- 先转换为摄氏度
    CASE LOWER(from_unit)
        WHEN 'f', 'fahrenheit' THEN
            value := (value - 32) * 5.0 / 9.0;
        WHEN 'k', 'kelvin' THEN
            value := value - 273.15;
        WHEN 'c', 'celsius' THEN
            -- 已经是摄氏度，无需转换
            NULL;
        ELSE
            RAISE EXCEPTION 'Unsupported temperature unit: %', from_unit;
    END CASE;

    -- 从摄氏度转换为目标单位
    CASE LOWER(to_unit)
        WHEN 'f', 'fahrenheit' THEN
            RETURN (value * 9.0 / 5.0) + 32;
        WHEN 'k', 'kelvin' THEN
            RETURN value + 273.15;
        WHEN 'c', 'celsius' THEN
            RETURN value;
        ELSE
            RAISE EXCEPTION 'Unsupported temperature unit: %', to_unit;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION convert_temperature(sensor_value, TEXT, TEXT) IS '温度单位转换函数';

-- 传感器数据平滑处理 (移动平均)
CREATE OR REPLACE FUNCTION moving_average(
    values sensor_value[],
    window_size INTEGER DEFAULT 5
) RETURNS sensor_value AS $$
DECLARE
    total sensor_value := 0;
    count INTEGER := 0;
    i INTEGER;
BEGIN
    -- 取最后window_size个值计算平均
    FOR i IN GREATEST(1, array_length(values, 1) - window_size + 1)..array_length(values, 1) LOOP
        total := total + values[i];
        count := count + 1;
    END LOOP;

    IF count = 0 THEN
        RETURN NULL;
    END IF;

    RETURN total / count;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION moving_average(sensor_value[], INTEGER) IS '传感器数据移动平均函数';

-- ================================================================
-- 设备安全与加密 (Device Security & Encryption)
-- ================================================================

-- 设备令牌生成函数
CREATE OR REPLACE FUNCTION generate_device_token(device_id UUID)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(
        pgp_sym_encrypt(
            device_id::TEXT || '|' || extract(epoch from now())::TEXT,
            'iot_device_secret_2024'
        ),
        'base64'
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_device_token(UUID) IS '设备认证令牌生成函数';

-- 设备令牌验证函数
CREATE OR REPLACE FUNCTION validate_device_token(
    device_id UUID,
    token TEXT,
    validity_hours INTEGER DEFAULT 24
) RETURNS BOOLEAN AS $$
DECLARE
    decoded_data TEXT;
    token_device_id UUID;
    token_timestamp NUMERIC;
BEGIN
    BEGIN
        decoded_data := pgp_sym_decrypt(
            decode(token, 'base64'),
            'iot_device_secret_2024'
        );

        -- 解析设备ID和时间戳
        token_device_id := split_part(decoded_data, '|', 1)::UUID;
        token_timestamp := split_part(decoded_data, '|', 2)::NUMERIC;

        -- 验证设备ID和时间戳
        RETURN token_device_id = device_id
               AND (extract(epoch from now()) - token_timestamp) < (validity_hours * 3600);

    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_device_token(UUID, TEXT, INTEGER) IS '设备认证令牌验证函数';

-- MAC地址标准化函数
CREATE OR REPLACE FUNCTION normalize_mac_address(mac TEXT)
RETURNS mac_address AS $$
BEGIN
    -- 移除所有分隔符并转为大写
    mac := UPPER(regexp_replace(mac, '[:-]', '', 'g'));

    -- 验证长度
    IF length(mac) != 12 THEN
        RAISE EXCEPTION 'Invalid MAC address length: %', mac;
    END IF;

    -- 格式化为标准格式 (XX:XX:XX:XX:XX:XX)
    RETURN substring(mac FROM 1 FOR 2) || ':' ||
           substring(mac FROM 3 FOR 2) || ':' ||
           substring(mac FROM 5 FOR 2) || ':' ||
           substring(mac FROM 7 FOR 2) || ':' ||
           substring(mac FROM 9 FOR 2) || ':' ||
           substring(mac FROM 11 FOR 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION normalize_mac_address(TEXT) IS 'MAC地址标准化函数';

-- ================================================================
-- 扩展模块加载完成
-- ================================================================

\echo '=================================================='
\echo 'IoT Extensions loaded successfully!'
\echo '物联网扩展模块加载完成'
\echo ''
\echo 'Available capabilities:'
\echo '- IoT设备数据类型 (IoT device data types)'
\echo '- 设备状态管理 (Device status management)'
\echo '- 传感器数据处理 (Sensor data processing)'
\echo '- 异常检测算法 (Anomaly detection algorithms)'
\echo '- 温度单位转换 (Temperature unit conversion)'
\echo '- 信号强度分析 (Signal strength analysis)'
\echo '- 设备安全认证 (Device security & authentication)'
\echo '- MAC地址处理 (MAC address processing)'
\echo '=================================================='
