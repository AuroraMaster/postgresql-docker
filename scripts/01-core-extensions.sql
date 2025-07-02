-- ================================================================
-- PostgreSQL 核心扩展初始化 (Core Extensions Initialization)
-- 此脚本包含所有基础扩展，必须首先加载
-- ================================================================

\echo '=================================================='
\echo 'Initializing PostgreSQL Core Extensions...'
\echo 'PostgreSQL 核心扩展系统初始化中...'
\echo '=================================================='

-- ================================================================
-- 核心基础扩展 (Core Foundation Extensions)
-- ================================================================

\echo 'Loading core foundation extensions...'

-- 基础功能扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";          -- UUID生成
CREATE EXTENSION IF NOT EXISTS "pgcrypto";           -- 加密函数
CREATE EXTENSION IF NOT EXISTS "hstore";             -- 键值对存储
CREATE EXTENSION IF NOT EXISTS "ltree";              -- 层次数据
CREATE EXTENSION IF NOT EXISTS "citext";             -- 大小写不敏感文本
CREATE EXTENSION IF NOT EXISTS "unaccent";           -- 去除重音符号

-- 搜索和匹配扩展
CREATE EXTENSION IF NOT EXISTS "pg_trgm";            -- 三元组匹配
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";      -- 模糊字符串匹配

-- 索引和性能扩展
CREATE EXTENSION IF NOT EXISTS "btree_gin";          -- GIN索引支持
CREATE EXTENSION IF NOT EXISTS "btree_gist";         -- GiST索引支持
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- 查询统计

-- 数组和数值扩展
CREATE EXTENSION IF NOT EXISTS "intarray";           -- 整数数组函数
CREATE EXTENSION IF NOT EXISTS "cube";               -- 多维立方体类型
CREATE EXTENSION IF NOT EXISTS "seg";                -- 线段类型
CREATE EXTENSION IF NOT EXISTS "isn";                -- 国际标准号码类型

-- 表函数和工具
CREATE EXTENSION IF NOT EXISTS "tablefunc";          -- 表函数
CREATE EXTENSION IF NOT EXISTS "postgres_fdw";       -- 外部数据包装器
CREATE EXTENSION IF NOT EXISTS "earthdistance";      -- 地球距离计算

-- 预加载扩展（这些扩展在shared_preload_libraries中配置）
CREATE EXTENSION IF NOT EXISTS "pg_cron";            -- 定时任务调度器

\echo 'Core foundation extensions loaded successfully'

-- ================================================================
-- 实用函数创建 (Utility Functions)
-- ================================================================

-- 生成随机字符串函数
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

COMMENT ON FUNCTION public.generate_random_string(INTEGER) IS '生成指定长度的随机字符串';

-- 数据库健康检查函数
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

COMMENT ON FUNCTION public.database_health_check() IS '数据库健康状态检查函数';

-- ================================================================
-- 系统视图创建 (System Views)
-- ================================================================

-- 已安装扩展视图
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

COMMENT ON VIEW public.installed_extensions IS '显示所有已安装扩展的信息';

-- 表大小分析视图
CREATE OR REPLACE VIEW public.table_sizes AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(
        pg_total_relation_size(schemaname||'.'||tablename) -
        pg_relation_size(schemaname||'.'||tablename)
    ) AS index_size,
    CASE
        WHEN pg_relation_size(schemaname||'.'||tablename) = 0 THEN 0
        ELSE ROUND(
            (pg_total_relation_size(schemaname||'.'||tablename) -
             pg_relation_size(schemaname||'.'||tablename))::NUMERIC /
            pg_relation_size(schemaname||'.'||tablename) * 100, 2
        )
    END AS index_ratio_pct
FROM pg_tables
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

COMMENT ON VIEW public.table_sizes IS '显示所有表的大小信息';

-- ================================================================
-- 配置优化 (Configuration Optimization)
-- ================================================================

-- 设置基础配置参数
DO $$
BEGIN
    -- 提高数值计算精度
    PERFORM set_config('extra_float_digits', '3', false);

    -- 启用行级安全策略支持
    PERFORM set_config('row_security', 'on', false);

    \echo 'Applied core configuration optimizations';
END
$$;

-- ================================================================
-- 完成信息输出
-- ================================================================

-- 输出安装完成信息
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE '=== PostgreSQL 核心扩展系统初始化完成 ===';
    RAISE NOTICE '================================================';
    RAISE NOTICE '已安装核心扩展: %', (
        SELECT string_agg(extname, ', ' ORDER BY extname)
        FROM pg_extension
        WHERE extname != 'plpgsql'
    );
    RAISE NOTICE '';
    RAISE NOTICE '实用命令:';
    RAISE NOTICE '- 查看所有扩展: SELECT * FROM installed_extensions;';
    RAISE NOTICE '- 检查数据库状态: SELECT * FROM database_health_check();';
    RAISE NOTICE '- 查看表大小: SELECT * FROM table_sizes;';
    RAISE NOTICE '================================================';
END $$;

\echo '=================================================='
\echo 'PostgreSQL Core Extensions System Ready!'
\echo 'PostgreSQL 核心扩展系统就绪！'
\echo '=================================================='
