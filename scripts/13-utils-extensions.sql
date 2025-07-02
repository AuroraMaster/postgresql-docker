-- PostgreSQL Pigsty扩展生态补充
-- 基于 https://pigsty.cc/ext/ 的扩展分类
-- ==================================================

-- 创建各类别schema
CREATE SCHEMA IF NOT EXISTS utils;
CREATE SCHEMA IF NOT EXISTS formats;
CREATE SCHEMA IF NOT EXISTS connectors;
CREATE SCHEMA IF NOT EXISTS crypto;
CREATE SCHEMA IF NOT EXISTS indexing;

-- ===========================================
-- 1. UTIL类 - 实用工具扩展
-- ===========================================

-- 字符串实用函数
CREATE OR REPLACE FUNCTION utils.string_entropy(input_text TEXT)
RETURNS DOUBLE PRECISION AS $$
DECLARE
    char_count INTEGER;
    total_chars INTEGER;
    entropy DOUBLE PRECISION := 0;
    char_freq DOUBLE PRECISION;
    rec RECORD;
BEGIN
    total_chars := length(input_text);

    IF total_chars = 0 THEN
        RETURN 0;
    END IF;

    FOR rec IN
        SELECT substr(input_text, i, 1) as char, COUNT(*) as cnt
        FROM generate_series(1, total_chars) i
        GROUP BY substr(input_text, i, 1)
    LOOP
        char_freq := rec.cnt::DOUBLE PRECISION / total_chars;
        entropy := entropy - (char_freq * log(2, char_freq));
    END LOOP;

    RETURN entropy;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Base64编码/解码
CREATE OR REPLACE FUNCTION utils.base64_encode(input_data BYTEA)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(input_data, 'base64');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION utils.base64_decode(input_text TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN decode(input_text, 'base64');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- URL编码/解码模拟
CREATE OR REPLACE FUNCTION utils.url_encode(input_text TEXT)
RETURNS TEXT AS $$
BEGIN
    -- 简化的URL编码实现
    RETURN replace(
        replace(
            replace(input_text, ' ', '%20'),
            '&', '%26'
        ),
        '=', '%3D'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 密码强度检查
CREATE OR REPLACE FUNCTION utils.password_strength(password TEXT)
RETURNS INTEGER AS $$
DECLARE
    score INTEGER := 0;
BEGIN
    -- 长度检查
    IF length(password) >= 8 THEN score := score + 1; END IF;
    IF length(password) >= 12 THEN score := score + 1; END IF;

    -- 复杂度检查
    IF password ~ '[a-z]' THEN score := score + 1; END IF;
    IF password ~ '[A-Z]' THEN score := score + 1; END IF;
    IF password ~ '[0-9]' THEN score := score + 1; END IF;
    IF password ~ '[^a-zA-Z0-9]' THEN score := score + 1; END IF;

    RETURN score;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ===========================================
-- 2. FORMAT类 - 格式转换扩展
-- ===========================================

-- CSV格式处理
CREATE OR REPLACE FUNCTION formats.array_to_csv(arr TEXT[])
RETURNS TEXT AS $$
BEGIN
    RETURN array_to_string(arr, ',');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION formats.csv_to_array(csv_text TEXT)
RETURNS TEXT[] AS $$
BEGIN
    RETURN string_to_array(csv_text, ',');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- XML格式处理（基础）
CREATE OR REPLACE FUNCTION formats.json_to_xml_simple(json_data JSONB)
RETURNS XML AS $$
DECLARE
    result TEXT := '<root>';
    key TEXT;
    value TEXT;
BEGIN
    FOR key, value IN SELECT * FROM jsonb_each_text(json_data) LOOP
        result := result || '<' || key || '>' || value || '</' || key || '>';
    END LOOP;

    result := result || '</root>';
    RETURN result::XML;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- YAML风格输出（简化）
CREATE OR REPLACE FUNCTION formats.jsonb_to_yaml(json_data JSONB)
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    key TEXT;
    value TEXT;
BEGIN
    FOR key, value IN SELECT * FROM jsonb_each_text(json_data) LOOP
        result := result || key || ': ' || value || E'\n';
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ===========================================
-- 3. CONNECT类 - 连接器模拟
-- ===========================================

-- HTTP客户端模拟表
CREATE TABLE IF NOT EXISTS connectors.http_requests (
    id BIGSERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    method TEXT DEFAULT 'GET',
    headers JSONB,
    body TEXT,
    response_status INTEGER,
    response_body TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HTTP请求记录函数
CREATE OR REPLACE FUNCTION connectors.log_http_request(
    url_param TEXT,
    method_param TEXT DEFAULT 'GET',
    headers_param JSONB DEFAULT NULL,
    body_param TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    request_id BIGINT;
BEGIN
    INSERT INTO connectors.http_requests (url, method, headers, body)
    VALUES (url_param, method_param, headers_param, body_param)
    RETURNING id INTO request_id;

    RETURN request_id;
END;
$$ LANGUAGE plpgsql;

-- 数据库连接信息表
CREATE TABLE IF NOT EXISTS connectors.external_databases (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    host TEXT NOT NULL,
    port INTEGER DEFAULT 5432,
    database_name TEXT NOT NULL,
    username TEXT NOT NULL,
    password_hash TEXT, -- 加密存储
    connection_type TEXT DEFAULT 'postgresql',
    status TEXT DEFAULT 'inactive',
    last_connected TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================================
-- 4. CRYPT类 - 加密增强
-- ===========================================

-- 简单哈希函数
CREATE OR REPLACE FUNCTION crypto.simple_hash(input_text TEXT, salt TEXT DEFAULT '')
RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(input_text || salt, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 密码哈希和验证
CREATE OR REPLACE FUNCTION crypto.hash_password(password TEXT)
RETURNS TEXT AS $$
DECLARE
    salt TEXT;
BEGIN
    salt := encode(gen_random_bytes(16), 'hex');
    RETURN salt || ':' || encode(digest(password || salt, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION crypto.verify_password(password TEXT, hash TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    parts TEXT[];
    salt TEXT;
    expected_hash TEXT;
    actual_hash TEXT;
BEGIN
    parts := string_to_array(hash, ':');
    IF array_length(parts, 1) != 2 THEN
        RETURN FALSE;
    END IF;

    salt := parts[1];
    expected_hash := parts[2];
    actual_hash := encode(digest(password || salt, 'sha256'), 'hex');

    RETURN expected_hash = actual_hash;
END;
$$ LANGUAGE plpgsql;

-- 简单数据脱敏
CREATE OR REPLACE FUNCTION crypto.mask_data(
    input_data TEXT,
    mask_type TEXT DEFAULT 'email'
)
RETURNS TEXT AS $$
BEGIN
    CASE mask_type
        WHEN 'email' THEN
            RETURN regexp_replace(input_data, '(.{1,3}).*@', '\1***@');
        WHEN 'phone' THEN
            RETURN regexp_replace(input_data, '(\d{3})\d{4}(\d{4})', '\1****\2');
        WHEN 'name' THEN
            RETURN regexp_replace(input_data, '(.{1}).*(.{1})', '\1***\2');
        ELSE
            RETURN repeat('*', length(input_data));
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ===========================================
-- 5. INDEX类 - 索引增强
-- ===========================================

-- 索引使用情况分析
CREATE OR REPLACE FUNCTION indexing.analyze_index_usage()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    index_name TEXT,
    index_scans BIGINT,
    tuples_read BIGINT,
    tuples_fetched BIGINT,
    usage_ratio DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname::TEXT,
        tablename::TEXT,
        indexrelname::TEXT,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch,
        CASE
            WHEN idx_scan = 0 THEN 0
            ELSE idx_tup_read::DOUBLE PRECISION / idx_scan
        END as usage_ratio
    FROM pg_stat_user_indexes
    ORDER BY idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

-- 建议创建索引的函数
CREATE OR REPLACE FUNCTION indexing.suggest_indexes()
RETURNS TABLE(
    table_name TEXT,
    column_name TEXT,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.tablename::TEXT,
        'id'::TEXT,
        'Primary key should have index'::TEXT
    FROM pg_tables t
    WHERE t.schemaname = 'public'
      AND NOT EXISTS (
          SELECT 1 FROM pg_indexes i
          WHERE i.tablename = t.tablename
            AND i.indexdef LIKE '%id%'
      );
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 6. 性能和监控增强
-- ===========================================

-- 表大小分析
CREATE OR REPLACE FUNCTION utils.table_size_analysis()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    total_size TEXT,
    table_size TEXT,
    index_size TEXT,
    row_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname::TEXT,
        tablename::TEXT,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
        pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size,
        (SELECT n_tup_ins - n_tup_del FROM pg_stat_user_tables WHERE schemaname = t.schemaname AND relname = t.tablename) as row_count
    FROM pg_tables t
    WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql;

-- 慢查询分析
CREATE OR REPLACE FUNCTION utils.slow_query_analysis(min_duration_ms DOUBLE PRECISION DEFAULT 1000)
RETURNS TABLE(
    query_text TEXT,
    calls BIGINT,
    total_time_ms DOUBLE PRECISION,
    mean_time_ms DOUBLE PRECISION,
    max_time_ms DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        LEFT(pss.query, 100) || '...' as query_text,
        pss.calls,
        pss.total_time as total_time_ms,
        pss.mean_time as mean_time_ms,
        pss.max_time as max_time_ms
    FROM pg_stat_statements pss
    WHERE pss.mean_time > min_duration_ms
    ORDER BY pss.total_time DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 7. 配置和维护工具
-- ===========================================

-- 数据库配置检查
CREATE OR REPLACE FUNCTION utils.config_check()
RETURNS TABLE(
    setting_name TEXT,
    current_value TEXT,
    recommended_value TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'shared_buffers'::TEXT,
        current_setting('shared_buffers')::TEXT,
        '25% of RAM'::TEXT,
        'check'::TEXT
    UNION ALL
    SELECT
        'effective_cache_size'::TEXT,
        current_setting('effective_cache_size')::TEXT,
        '75% of RAM'::TEXT,
        'check'::TEXT
    UNION ALL
    SELECT
        'work_mem'::TEXT,
        current_setting('work_mem')::TEXT,
        'RAM/max_connections'::TEXT,
        'check'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 自动VACUUM分析
CREATE OR REPLACE FUNCTION utils.vacuum_analysis()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    last_vacuum TIMESTAMPTZ,
    last_autovacuum TIMESTAMPTZ,
    n_dead_tup BIGINT,
    vacuum_needed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        schemaname::TEXT,
        relname::TEXT,
        last_vacuum,
        last_autovacuum,
        n_dead_tup,
        (n_dead_tup > 1000)::BOOLEAN as vacuum_needed
    FROM pg_stat_user_tables
    ORDER BY n_dead_tup DESC;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 8. 权限和示例数据
-- ===========================================

-- 设置权限
GRANT USAGE ON SCHEMA utils TO PUBLIC;
GRANT USAGE ON SCHEMA formats TO PUBLIC;
GRANT USAGE ON SCHEMA connectors TO PUBLIC;
GRANT USAGE ON SCHEMA crypto TO PUBLIC;
GRANT USAGE ON SCHEMA indexing TO PUBLIC;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA utils TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA formats TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA crypto TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA indexing TO PUBLIC;

GRANT SELECT ON ALL TABLES IN SCHEMA connectors TO PUBLIC;

-- 创建示例配置数据
INSERT INTO connectors.external_databases (name, host, database_name, username, connection_type) VALUES
    ('测试MySQL', 'localhost', 'testdb', 'testuser', 'mysql'),
    ('Redis缓存', 'localhost', '0', 'default', 'redis'),
    ('ElasticSearch', 'localhost', 'logs', 'elastic', 'elasticsearch')
ON CONFLICT (name) DO NOTHING;

-- 输出配置完成信息
\echo '✅ Pigsty扩展生态补充配置完成!'
\echo '🔧 已配置扩展类别:'
\echo '   🛠️  UTIL类 - 实用工具（字符串处理、编码、密码强度）'
\echo '   📄 FORMAT类 - 格式转换（CSV、XML、YAML）'
\echo '   🔗 CONNECT类 - 连接器（HTTP、数据库连接管理）'
\echo '   🔐 CRYPT类 - 加密增强（哈希、密码、数据脱敏）'
\echo '   📊 INDEX类 - 索引分析（使用情况、建议）'
\echo '   ⚡ 性能监控（表大小、慢查询、配置检查）'
\echo ''
\echo '📊 使用示例:'
\echo '   -- 字符串熵值:'
\echo '   SELECT utils.string_entropy(''Hello World'');'
\echo ''
\echo '   -- 密码强度:'
\echo '   SELECT utils.password_strength(''MySecureP@ssw0rd'');'
\echo ''
\echo '   -- 数据脱敏:'
\echo '   SELECT crypto.mask_data(''user@example.com'', ''email'');'
\echo ''
\echo '   -- 性能分析:'
\echo '   SELECT * FROM utils.table_size_analysis();'
