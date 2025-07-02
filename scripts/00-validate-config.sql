-- ================================================================
-- 配置验证脚本 (Configuration Validation Script)
-- 验证Dockerfile配置与scripts脚本的兼容性
-- 此脚本应该在所有其他脚本之前运行
-- ================================================================

\echo '=================================================='
\echo 'Validating PostgreSQL Configuration...'
\echo 'PostgreSQL配置验证中...'
\echo '=================================================='

-- 检查PostgreSQL版本
\echo 'Checking PostgreSQL version...'
SELECT version();

-- 检查shared_preload_libraries配置
\echo 'Checking shared_preload_libraries configuration...'
SHOW shared_preload_libraries;

-- 验证预加载库是否可用
DO $$
DECLARE
    preload_libs TEXT;
    lib_name TEXT;
    lib_array TEXT[];
    i INTEGER;
BEGIN
    -- 获取当前shared_preload_libraries设置
    SELECT setting INTO preload_libs FROM pg_settings WHERE name = 'shared_preload_libraries';

    RAISE NOTICE '当前预加载库: %', preload_libs;

    -- 解析预加载库列表
    IF preload_libs IS NOT NULL AND preload_libs != '' THEN
        lib_array := string_to_array(preload_libs, ',');

        FOR i IN 1..array_length(lib_array, 1) LOOP
            lib_name := trim(lib_array[i]);

            CASE lib_name
                WHEN 'timescaledb' THEN
                    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'timescaledb') THEN
                        RAISE NOTICE '✅ TimescaleDB: 可用';
                    ELSE
                        RAISE WARNING '❌ TimescaleDB: 预加载但扩展不可用';
                    END IF;

                WHEN 'citus' THEN
                    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'citus') THEN
                        RAISE NOTICE '✅ Citus: 可用';
                    ELSE
                        RAISE WARNING '❌ Citus: 预加载但扩展不可用';
                    END IF;

                WHEN 'pg_cron' THEN
                    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
                        RAISE NOTICE '✅ pg_cron: 可用';
                    ELSE
                        RAISE WARNING '❌ pg_cron: 预加载但扩展不可用';
                    END IF;

                WHEN 'pg_stat_statements' THEN
                    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_stat_statements') THEN
                        RAISE NOTICE '✅ pg_stat_statements: 可用';
                    ELSE
                        RAISE WARNING '❌ pg_stat_statements: 预加载但扩展不可用';
                    END IF;

                ELSE
                    RAISE NOTICE '🔍 未知预加载库: %', lib_name;
            END CASE;
        END LOOP;
    END IF;
END
$$;

-- 检查关键扩展是否可用
\echo 'Checking critical extensions availability...'

DO $$
DECLARE
    ext_record RECORD;
    missing_count INTEGER := 0;
    critical_extensions TEXT[] := ARRAY[
        'uuid-ossp', 'pgcrypto', 'hstore', 'ltree', 'citext', 'unaccent',
        'pg_trgm', 'fuzzystrmatch', 'btree_gin', 'btree_gist',
        'intarray', 'cube', 'seg', 'isn', 'tablefunc', 'postgres_fdw',
        'earthdistance', 'postgis', 'pgvector', 'timescaledb', 'citus'
    ];
BEGIN
    RAISE NOTICE '检查关键扩展可用性:';

    FOR i IN 1..array_length(critical_extensions, 1) LOOP
        IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = critical_extensions[i]) THEN
            RAISE NOTICE '✅ %: 可用', critical_extensions[i];
        ELSE
            RAISE WARNING '❌ %: 不可用', critical_extensions[i];
            missing_count := missing_count + 1;
        END IF;
    END LOOP;

    IF missing_count = 0 THEN
        RAISE NOTICE '🎉 所有关键扩展都可用！';
    ELSE
        RAISE WARNING '⚠️  % 个关键扩展不可用', missing_count;
    END IF;
END
$$;

-- 检查数据库配置
\echo 'Checking database configuration...'

-- 显示重要配置参数
SELECT
    name,
    setting,
    unit,
    context,
    boot_val,
    pending_restart
FROM pg_settings
WHERE name IN (
    'max_worker_processes',
    'max_parallel_workers',
    'max_parallel_workers_per_gather',
    'shared_preload_libraries',
    'cron.database_name',
    'timescaledb.telemetry_level'
)
ORDER BY name;

-- 显示内存相关配置
\echo 'Memory configuration:'
SELECT
    name,
    setting,
    unit
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'maintenance_work_mem'
)
ORDER BY name;

-- 创建配置检查函数
CREATE OR REPLACE FUNCTION public.check_config_health()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- 检查预加载库
    RETURN QUERY
    SELECT
        'Shared Preload Libraries'::TEXT,
        CASE WHEN current_setting('shared_preload_libraries') != ''
             THEN 'OK' ELSE 'WARNING' END::TEXT,
        current_setting('shared_preload_libraries')::TEXT;

    -- 检查工作进程
    RETURN QUERY
    SELECT
        'Max Worker Processes'::TEXT,
        CASE WHEN current_setting('max_worker_processes')::INTEGER >= 8
             THEN 'OK' ELSE 'WARNING' END::TEXT,
        current_setting('max_worker_processes')::TEXT;

    -- 检查并行工作进程
    RETURN QUERY
    SELECT
        'Max Parallel Workers'::TEXT,
        CASE WHEN current_setting('max_parallel_workers')::INTEGER >= 4
             THEN 'OK' ELSE 'WARNING' END::TEXT,
        current_setting('max_parallel_workers')::TEXT;

    -- 检查扩展数量
    RETURN QUERY
    SELECT
        'Available Extensions'::TEXT,
        CASE WHEN COUNT(*) >= 50 THEN 'OK' ELSE 'WARNING' END::TEXT,
        'Available: ' || COUNT(*)::TEXT
    FROM pg_available_extensions;
END;
$$ LANGUAGE plpgsql;

-- 运行配置健康检查
\echo 'Configuration health check:'
SELECT * FROM check_config_health();

-- 检查scripts目录挂载
\echo 'Checking scripts directory mount...'
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_stat_file('/docker-entrypoint-initdb.d/01-core-extensions.sql')) THEN
        RAISE NOTICE '✅ Scripts目录正确挂载到 /docker-entrypoint-initdb.d/';
    ELSE
        RAISE WARNING '❌ Scripts目录未找到或未正确挂载';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ 无法检查scripts目录: %', SQLERRM;
END
$$;

-- 验证完成信息
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE '=== PostgreSQL配置验证完成 ===';
    RAISE NOTICE '================================================';
    RAISE NOTICE '如果看到任何❌或WARNING，请检查相关配置';
    RAISE NOTICE '使用 SELECT * FROM check_config_health(); 检查配置健康状态';
    RAISE NOTICE '================================================';
END $$;

\echo '=================================================='
\echo 'Configuration validation completed!'
\echo '配置验证完成！'
\echo '=================================================='
