-- 初始化PostgreSQL扩展
-- 此脚本在数据库启动时自动执行

-- 创建常用扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";          -- UUID生成
CREATE EXTENSION IF NOT EXISTS "pgcrypto";           -- 加密函数
CREATE EXTENSION IF NOT EXISTS "hstore";             -- 键值对存储
CREATE EXTENSION IF NOT EXISTS "ltree";              -- 层次数据
CREATE EXTENSION IF NOT EXISTS "citext";             -- 大小写不敏感文本
CREATE EXTENSION IF NOT EXISTS "unaccent";           -- 去除重音符号
CREATE EXTENSION IF NOT EXISTS "pg_trgm";            -- 三元组匹配
CREATE EXTENSION IF NOT EXISTS "btree_gin";          -- GIN索引支持
CREATE EXTENSION IF NOT EXISTS "btree_gist";         -- GiST索引支持
CREATE EXTENSION IF NOT EXISTS "intarray";           -- 整数数组函数
CREATE EXTENSION IF NOT EXISTS "tablefunc";          -- 表函数
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";      -- 模糊字符串匹配
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- 查询统计

-- PostGIS扩展（地理信息系统）
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "postgis_topology";
CREATE EXTENSION IF NOT EXISTS "postgis_raster";

-- 向量数据库扩展（AI/ML场景）
CREATE EXTENSION IF NOT EXISTS "vector";

-- 定时任务扩展
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- 分区管理扩展
CREATE EXTENSION IF NOT EXISTS "pg_partman";

-- JWT处理扩展
CREATE EXTENSION IF NOT EXISTS "pgjwt";

-- 时间序列数据库扩展
CREATE EXTENSION IF NOT EXISTS "timescaledb";

-- 创建一些有用的函数
CREATE OR REPLACE FUNCTION public.generate_random_string(length INTEGER)
RETURNS TEXT AS $$
BEGIN
    RETURN array_to_string(
        ARRAY(
            SELECT chr((97 + round(random() * 25))::INTEGER)
            FROM generate_series(1, length)
        ),
        ''
    );
END;
$$ LANGUAGE plpgsql;

-- 创建一个展示所有已安装扩展的视图
CREATE OR REPLACE VIEW public.installed_extensions AS
SELECT
    e.extname AS extension_name,
    e.extversion AS version,
    n.nspname AS schema_name,
    e.extrelocatable AS relocatable,
    e.extowner::regrole AS owner
FROM pg_extension e
LEFT JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY e.extname;

-- 创建一个检查数据库健康状态的函数
CREATE OR REPLACE FUNCTION public.database_health_check()
RETURNS TABLE(
    metric TEXT,
    value TEXT,
    status TEXT
) AS $$
BEGIN
    -- 数据库大小
    RETURN QUERY
    SELECT
        'Database Size'::TEXT,
        pg_size_pretty(pg_database_size(current_database()))::TEXT,
        'INFO'::TEXT;

    -- 连接数
    RETURN QUERY
    SELECT
        'Active Connections'::TEXT,
        count(*)::TEXT,
        CASE WHEN count(*) > 150 THEN 'WARNING' ELSE 'OK' END::TEXT
    FROM pg_stat_activity
    WHERE state = 'active';

    -- 表数量
    RETURN QUERY
    SELECT
        'Total Tables'::TEXT,
        count(*)::TEXT,
        'INFO'::TEXT
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'pg_catalog');

    -- 已安装扩展数量
    RETURN QUERY
    SELECT
        'Installed Extensions'::TEXT,
        count(*)::TEXT,
        'INFO'::TEXT
    FROM pg_extension;
END;
$$ LANGUAGE plpgsql;

-- 输出安装完成信息
DO $$
BEGIN
    RAISE NOTICE '=== PostgreSQL定制扩展安装完成 ===';
    RAISE NOTICE '已安装扩展: %', (
        SELECT string_agg(extname, ', ' ORDER BY extname)
        FROM pg_extension
        WHERE extname != 'plpgsql'
    );
    RAISE NOTICE '使用 SELECT * FROM installed_extensions; 查看所有扩展';
    RAISE NOTICE '使用 SELECT * FROM database_health_check(); 检查数据库状态';
END $$;
