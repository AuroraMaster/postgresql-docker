-- PostgreSQL 审计日志和时间旅行功能初始化
-- =====================================================

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS temporal_tables;
CREATE EXTENSION IF NOT EXISTS periods;
-- CREATE EXTENSION IF NOT EXISTS pg_cron; -- 已在Dockerfile中通过postgresql-16-cron安装并在shared_preload_libraries中配置

-- 创建审计日志架构
CREATE SCHEMA IF NOT EXISTS audit;

-- ===========================================
-- 1. 通用审计日志表
-- ===========================================

-- 审计日志主表
CREATE TABLE IF NOT EXISTS audit.audit_log (
    id BIGSERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    operation CHAR(1) NOT NULL CHECK (operation IN ('I','U','D')), -- Insert, Update, Delete
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    user_name TEXT DEFAULT current_user,
    session_user TEXT DEFAULT session_user,
    client_addr INET DEFAULT inet_client_addr(),
    client_port INTEGER DEFAULT inet_client_port(),
    application_name TEXT DEFAULT current_setting('application_name'),
    transaction_id BIGINT DEFAULT txid_current(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    query_text TEXT
);

-- 为审计日志表创建索引
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit.audit_log (created_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_table ON audit.audit_log (schema_name, table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_operation ON audit.audit_log (operation);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit.audit_log (user_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_transaction ON audit.audit_log (transaction_id);

-- ===========================================
-- 2. 审计触发器函数
-- ===========================================

CREATE OR REPLACE FUNCTION audit.audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    old_values JSONB := NULL;
    new_values JSONB := NULL;
    changed_fields TEXT[] := ARRAY[]::TEXT[];
    query_text TEXT;
BEGIN
    -- 获取当前查询文本
    SELECT current_query() INTO query_text;

    -- 处理不同操作类型
    IF TG_OP = 'DELETE' THEN
        old_values := to_jsonb(OLD);
        INSERT INTO audit.audit_log (
            schema_name, table_name, operation, old_values,
            new_values, changed_fields, query_text
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, 'D', old_values,
            NULL, NULL, query_text
        );
        RETURN OLD;

    ELSIF TG_OP = 'INSERT' THEN
        new_values := to_jsonb(NEW);
        INSERT INTO audit.audit_log (
            schema_name, table_name, operation, old_values,
            new_values, changed_fields, query_text
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, 'I', NULL,
            new_values, NULL, query_text
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        old_values := to_jsonb(OLD);
        new_values := to_jsonb(NEW);

        -- 检测变更的字段
        SELECT array_agg(key) INTO changed_fields
        FROM (
            SELECT key FROM jsonb_each_text(old_values)
            EXCEPT
            SELECT key FROM jsonb_each_text(new_values)
            UNION
            SELECT key FROM jsonb_each_text(new_values)
            EXCEPT
            SELECT key FROM jsonb_each_text(old_values)
        ) AS changed_keys;

        INSERT INTO audit.audit_log (
            schema_name, table_name, operation, old_values,
            new_values, changed_fields, query_text
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, 'U', old_values,
            new_values, changed_fields, query_text
        );
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- 3. 时间旅行表示例
-- ===========================================

-- 创建带时间旅行功能的用户表示例
CREATE TABLE IF NOT EXISTS public.users_with_history (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- 时间旅行字段
    sys_period tstzrange NOT NULL DEFAULT tstzrange(current_timestamp, null)
);

-- 创建历史表
CREATE TABLE IF NOT EXISTS public.users_with_history_history (
    LIKE public.users_with_history
);

-- 启用时间旅行
SELECT versioning('public.users_with_history_history', 'public.users_with_history', 'sys_period', 'public.users_with_history_history', true);

-- 为时间旅行表添加审计
CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.users_with_history
    FOR EACH ROW EXECUTE FUNCTION audit.audit_trigger_function();

-- ===========================================
-- 4. 便捷的查询函数
-- ===========================================

-- 查询指定时间点的数据快照
CREATE OR REPLACE FUNCTION audit.get_data_at_time(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_timestamp TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE(record_data JSONB) AS $$
DECLARE
    query_text TEXT;
BEGIN
    -- 构建查询历史表的SQL
    query_text := format(
        'SELECT to_jsonb(t.*) FROM %I.%I_history t WHERE sys_period @> %L::timestamptz',
        p_schema_name, p_table_name, p_timestamp
    );

    RETURN QUERY EXECUTE query_text;
END;
$$ LANGUAGE plpgsql;

-- 查询字段变更历史
CREATE OR REPLACE FUNCTION audit.get_field_changes(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_record_id INTEGER,
    p_field_name TEXT,
    p_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_end_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE(
    operation CHAR(1),
    old_value TEXT,
    new_value TEXT,
    changed_at TIMESTAMP WITH TIME ZONE,
    changed_by TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        al.operation,
        al.old_values->>p_field_name as old_value,
        al.new_values->>p_field_name as new_value,
        al.created_at as changed_at,
        al.user_name as changed_by
    FROM audit.audit_log al
    WHERE al.schema_name = p_schema_name
      AND al.table_name = p_table_name
      AND (al.old_values->>'id')::INTEGER = p_record_id
      AND p_field_name = ANY(al.changed_fields)
      AND al.created_at BETWEEN p_start_time AND p_end_time
    ORDER BY al.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 查询某个时间段内的所有操作
CREATE OR REPLACE FUNCTION audit.get_audit_summary(
    p_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '1 day',
    p_end_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    operation CHAR(1),
    operation_count BIGINT,
    unique_users BIGINT,
    first_operation TIMESTAMP WITH TIME ZONE,
    last_operation TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        al.schema_name,
        al.table_name,
        al.operation,
        COUNT(*) as operation_count,
        COUNT(DISTINCT al.user_name) as unique_users,
        MIN(al.created_at) as first_operation,
        MAX(al.created_at) as last_operation
    FROM audit.audit_log al
    WHERE al.created_at BETWEEN p_start_time AND p_end_time
    GROUP BY al.schema_name, al.table_name, al.operation
    ORDER BY al.schema_name, al.table_name, al.operation;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 5. 自动化清理任务
-- ===========================================

-- 创建审计日志清理函数（保留指定天数）
CREATE OR REPLACE FUNCTION audit.cleanup_old_logs(retention_days INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit.audit_log
    WHERE created_at < NOW() - (retention_days || ' days')::INTERVAL;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RAISE NOTICE '清理了 % 条超过 % 天的审计日志', deleted_count, retention_days;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 设置定时清理任务（每月第一天凌晨2点执行）
SELECT cron.schedule('audit-cleanup', '0 2 1 * *', 'SELECT audit.cleanup_old_logs(90);');

-- ===========================================
-- 6. 权限设置
-- ===========================================

-- 创建审计只读角色
CREATE ROLE IF NOT EXISTS audit_reader;
GRANT USAGE ON SCHEMA audit TO audit_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO audit_reader;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA audit TO audit_reader;

-- 确保future tables也有权限
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT SELECT ON TABLES TO audit_reader;

-- 输出配置完成信息
\echo '✅ 审计日志和时间旅行功能配置完成!'
\echo '📋 使用示例:'
\echo '   -- 查看审计日志: SELECT * FROM audit.audit_log ORDER BY created_at DESC LIMIT 10;'
\echo '   -- 查看变更历史: SELECT * FROM audit.get_field_changes(''public'', ''users_with_history'', 1, ''email'');'
\echo '   -- 查看操作汇总: SELECT * FROM audit.get_audit_summary();'
\echo '   -- 时间旅行查询: SELECT * FROM audit.get_data_at_time(''public'', ''users_with_history'', ''2024-01-01 00:00:00+00'');'
