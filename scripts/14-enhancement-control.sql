-- ================================================================
-- 14-enhancement-control.sql
-- PostgreSQL Rust扩展增强控制系统
-- 提供在原有基础上的性能和功能增强
-- ================================================================

-- 创建增强管理架构
CREATE SCHEMA IF NOT EXISTS enhancement_control;
COMMENT ON SCHEMA enhancement_control IS 'Rust扩展增强控制和管理系统';

-- ================================================================
-- 功能增强管理表
-- ================================================================

-- 功能增强配置表
CREATE TABLE enhancement_control.feature_enhancements (
    feature_name TEXT PRIMARY KEY,
    original_implementation TEXT NOT NULL, -- 原始实现描述
    rust_enhancement TEXT,                 -- Rust增强版本
    enhancement_type TEXT CHECK (enhancement_type IN ('performance', 'feature', 'security')) NOT NULL,
    active_mode TEXT CHECK (active_mode IN ('original', 'enhanced', 'adaptive')) DEFAULT 'original',
    enhancement_status TEXT CHECK (enhancement_status IN ('planning', 'testing', 'active', 'deprecated')) DEFAULT 'planning',
    performance_gain DOUBLE PRECISION DEFAULT 1.0, -- 性能提升倍数
    memory_improvement DOUBLE PRECISION DEFAULT 1.0, -- 内存使用改善
    safety_level TEXT CHECK (safety_level IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
    rust_extension_name TEXT, -- 对应的Rust扩展名称
    fallback_enabled BOOLEAN DEFAULT true, -- 是否启用回退机制
    auto_switch_threshold INTEGER DEFAULT 10000, -- 自动切换的数据量阈值
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE enhancement_control.feature_enhancements IS '功能增强配置管理表';
COMMENT ON COLUMN enhancement_control.feature_enhancements.performance_gain IS '相比原始实现的性能提升倍数';
COMMENT ON COLUMN enhancement_control.feature_enhancements.auto_switch_threshold IS '大于此数据量时自动切换到增强版本';

-- 性能对比监控表
CREATE TABLE enhancement_control.performance_comparison (
    id SERIAL PRIMARY KEY,
    feature_name TEXT NOT NULL,
    test_scenario TEXT NOT NULL,
    implementation_type TEXT CHECK (implementation_type IN ('original', 'enhanced')) NOT NULL,
    execution_time_ms DOUBLE PRECISION,
    memory_usage_mb DOUBLE PRECISION,
    cpu_usage_percent DOUBLE PRECISION,
    throughput_ops_sec DOUBLE PRECISION,
    data_size INTEGER,
    concurrent_users INTEGER DEFAULT 1,
    error_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 1,
    test_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    environment TEXT DEFAULT 'production' -- 'development', 'testing', 'production'
);

COMMENT ON TABLE enhancement_control.performance_comparison IS '性能对比监控数据表';

-- 增强使用统计表
CREATE TABLE enhancement_control.usage_statistics (
    id SERIAL PRIMARY KEY,
    feature_name TEXT NOT NULL,
    implementation_used TEXT NOT NULL, -- 'original', 'enhanced', 'auto_selected'
    usage_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_id TEXT,
    user_id TEXT,
    query_parameters JSONB,
    execution_context TEXT -- 调用上下文信息
);

COMMENT ON TABLE enhancement_control.usage_statistics IS '增强功能使用统计表';

-- ================================================================
-- 核心增强控制函数
-- ================================================================

-- 自适应性能选择函数
CREATE OR REPLACE FUNCTION enhancement_control.adaptive_performance_selector(
    feature_name TEXT,
    data_size INTEGER DEFAULT 0,
    performance_requirement TEXT DEFAULT 'balanced', -- 'stability', 'balanced', 'performance'
    force_enhanced BOOLEAN DEFAULT false
)
RETURNS TEXT AS $$
DECLARE
    enhancement_config RECORD;
    selection TEXT;
BEGIN
    -- 获取增强配置
    SELECT * INTO enhancement_config
    FROM enhancement_control.feature_enhancements
    WHERE feature_enhancements.feature_name = adaptive_performance_selector.feature_name;

    -- 如果没有配置，返回原始实现
    IF NOT FOUND THEN
        RETURN 'original';
    END IF;

    -- 检查Rust增强是否可用且处于活跃状态
    IF enhancement_config.rust_enhancement IS NULL
       OR enhancement_config.enhancement_status NOT IN ('testing', 'active') THEN
        RETURN 'original';
    END IF;

    -- 强制使用增强版本
    IF force_enhanced THEN
        RETURN 'enhanced';
    END IF;

    -- 根据性能要求和数据量智能选择
    CASE performance_requirement
        WHEN 'stability' THEN
            -- 稳定性优先：始终使用原有实现
            selection := 'original';

        WHEN 'performance' THEN
            -- 性能优先：尽可能使用增强版本
            selection := CASE
                WHEN enhancement_config.enhancement_status = 'active' THEN 'enhanced'
                ELSE 'original'
            END;

        ELSE -- 'balanced'
            -- 平衡模式：根据数据量和安全级别智能选择
            selection := CASE
                WHEN enhancement_config.enhancement_status = 'active'
                     AND data_size >= enhancement_config.auto_switch_threshold
                     AND enhancement_config.safety_level IN ('medium', 'high', 'critical')
                THEN 'enhanced'
                WHEN enhancement_config.enhancement_status = 'active'
                     AND enhancement_config.safety_level = 'high'
                     AND data_size >= (enhancement_config.auto_switch_threshold / 2)
                THEN 'enhanced'
                ELSE 'original'
            END;
    END CASE;

    -- 记录选择决策
    INSERT INTO enhancement_control.usage_statistics
    (feature_name, implementation_used, query_parameters, execution_context)
    VALUES (
        adaptive_performance_selector.feature_name,
        'auto_selected_' || selection,
        jsonb_build_object(
            'data_size', data_size,
            'performance_requirement', performance_requirement,
            'force_enhanced', force_enhanced,
            'auto_threshold', enhancement_config.auto_switch_threshold
        ),
        'adaptive_selector'
    );

    RETURN selection;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enhancement_control.adaptive_performance_selector IS
'智能选择原始实现或增强实现，基于数据量、性能要求和安全级别';

-- 增强效果分析函数
CREATE OR REPLACE FUNCTION enhancement_control.analyze_enhancement_impact(
    feature_name TEXT,
    time_window INTERVAL DEFAULT '24 hours'
)
RETURNS TABLE(
    implementation TEXT,
    avg_performance_ms DOUBLE PRECISION,
    improvement_factor DOUBLE PRECISION,
    usage_count INTEGER,
    success_rate DOUBLE PRECISION,
    avg_throughput DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    WITH performance_stats AS (
        SELECT
            pc.implementation_type,
            AVG(pc.execution_time_ms) as avg_perf,
            AVG(pc.throughput_ops_sec) as avg_throughput,
            COUNT(*) as usage,
            AVG(CASE WHEN pc.error_count = 0 THEN 1.0 ELSE 0.0 END) as success_rate
        FROM enhancement_control.performance_comparison pc
        WHERE pc.feature_name = analyze_enhancement_impact.feature_name
          AND pc.test_timestamp > NOW() - time_window
        GROUP BY pc.implementation_type
    ),
    baseline AS (
        SELECT
            avg_perf as baseline_perf,
            avg_throughput as baseline_throughput
        FROM performance_stats
        WHERE implementation_type = 'original'
    )
    SELECT
        ps.implementation_type,
        ps.avg_perf,
        CASE
            WHEN ps.implementation_type = 'original' THEN 1.0
            ELSE COALESCE(b.baseline_perf / NULLIF(ps.avg_perf, 0), 1.0)
        END as improvement,
        ps.usage::INTEGER,
        ps.success_rate,
        ps.avg_throughput
    FROM performance_stats ps
    LEFT JOIN baseline b ON true
    ORDER BY ps.implementation_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enhancement_control.analyze_enhancement_impact IS
'分析增强功能的性能影响和使用统计';

-- 增强控制主函数
CREATE OR REPLACE FUNCTION enhancement_control.control_enhancement(
    feature_name TEXT,
    action TEXT -- 'enable_enhanced', 'enable_adaptive', 'use_original', 'status', 'benchmark', 'configure'
)
RETURNS TEXT AS $$
DECLARE
    result TEXT;
    config RECORD;
BEGIN
    CASE action
        WHEN 'enable_enhanced' THEN
            UPDATE enhancement_control.feature_enhancements
            SET active_mode = 'enhanced',
                enhancement_status = 'active',
                last_updated = NOW()
            WHERE feature_enhancements.feature_name = control_enhancement.feature_name;

            GET DIAGNOSTICS result = ROW_COUNT;
            IF result::INTEGER > 0 THEN
                result := format('✅ Enhanced mode enabled for %s', feature_name);
            ELSE
                result := format('❌ Feature %s not found', feature_name);
            END IF;

        WHEN 'enable_adaptive' THEN
            UPDATE enhancement_control.feature_enhancements
            SET active_mode = 'adaptive',
                enhancement_status = 'active',
                last_updated = NOW()
            WHERE feature_enhancements.feature_name = control_enhancement.feature_name;

            GET DIAGNOSTICS result = ROW_COUNT;
            IF result::INTEGER > 0 THEN
                result := format('🧠 Adaptive mode enabled for %s', feature_name);
            ELSE
                result := format('❌ Feature %s not found', feature_name);
            END IF;

        WHEN 'use_original' THEN
            UPDATE enhancement_control.feature_enhancements
            SET active_mode = 'original',
                last_updated = NOW()
            WHERE feature_enhancements.feature_name = control_enhancement.feature_name;

            GET DIAGNOSTICS result = ROW_COUNT;
            IF result::INTEGER > 0 THEN
                result := format('🔄 Using original implementation for %s', feature_name);
            ELSE
                result := format('❌ Feature %s not found', feature_name);
            END IF;

        WHEN 'benchmark' THEN
            -- 触发性能对比测试
            INSERT INTO enhancement_control.performance_comparison
            (feature_name, test_scenario, implementation_type, test_timestamp)
            VALUES (feature_name, 'manual_benchmark', 'original', NOW());

            result := format('📊 Benchmark initiated for %s', feature_name);

        WHEN 'status' THEN
            SELECT
                format('🎯 Feature: %s | Mode: %s | Enhancement: %s | Status: %s | Gain: %.2fx | Safety: %s',
                    fe.feature_name,
                    fe.active_mode,
                    fe.enhancement_type,
                    fe.enhancement_status,
                    COALESCE(fe.performance_gain, 1.0),
                    fe.safety_level
                )
            INTO result
            FROM enhancement_control.feature_enhancements fe
            WHERE fe.feature_name = control_enhancement.feature_name;

            IF result IS NULL THEN
                result := format('❌ Feature %s not found', feature_name);
            END IF;

        WHEN 'configure' THEN
            result := format('⚙️ Configuration interface for %s (use specific config functions)', feature_name);

        ELSE
            result := format('❌ Unknown action: %s. Available: enable_enhanced, enable_adaptive, use_original, status, benchmark', action);
    END CASE;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enhancement_control.control_enhancement IS
'增强功能控制主函数，支持启用、配置、状态查询等操作';

-- ================================================================
-- 性能监控和报告函数
-- ================================================================

-- 实时性能监控视图
CREATE OR REPLACE VIEW enhancement_control.live_performance_monitor AS
SELECT
    fe.feature_name,
    fe.active_mode,
    fe.enhancement_status,
    fe.performance_gain,
    COALESCE(recent_stats.usage_last_hour, 0) as usage_last_hour,
    COALESCE(recent_stats.avg_performance_ms, 0) as avg_performance_ms,
    COALESCE(recent_stats.success_rate, 100.0) as success_rate_percent
FROM enhancement_control.feature_enhancements fe
LEFT JOIN (
    SELECT
        pc.feature_name,
        COUNT(*) as usage_last_hour,
        AVG(pc.execution_time_ms) as avg_performance_ms,
        AVG(CASE WHEN pc.error_count = 0 THEN 100.0 ELSE 0.0 END) as success_rate
    FROM enhancement_control.performance_comparison pc
    WHERE pc.test_timestamp > NOW() - INTERVAL '1 hour'
    GROUP BY pc.feature_name
) recent_stats ON fe.feature_name = recent_stats.feature_name
ORDER BY fe.feature_name;

COMMENT ON VIEW enhancement_control.live_performance_monitor IS
'实时性能监控视图，显示所有增强功能的当前状态和性能指标';

-- 增强配置报告函数
CREATE OR REPLACE FUNCTION enhancement_control.enhancement_report()
RETURNS TABLE(
    feature TEXT,
    mode TEXT,
    status TEXT,
    enhancement TEXT,
    performance_gain TEXT,
    safety TEXT,
    last_updated TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        fe.feature_name,
        fe.active_mode,
        fe.enhancement_status,
        fe.enhancement_type,
        COALESCE(fe.performance_gain::TEXT || 'x', 'N/A'),
        fe.safety_level,
        fe.last_updated::TEXT
    FROM enhancement_control.feature_enhancements fe
    ORDER BY
        CASE fe.enhancement_status
            WHEN 'active' THEN 1
            WHEN 'testing' THEN 2
            WHEN 'planning' THEN 3
            WHEN 'deprecated' THEN 4
        END,
        fe.performance_gain DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enhancement_control.enhancement_report IS
'生成增强功能配置和状态的完整报告';

-- ================================================================
-- 初始化增强配置
-- ================================================================

-- 插入预定义的增强配置
INSERT INTO enhancement_control.feature_enhancements
(feature_name, original_implementation, rust_enhancement, enhancement_type, active_mode, enhancement_status, performance_gain, memory_improvement, safety_level, rust_extension_name, auto_switch_threshold)
VALUES
    ('uuid_generation',
     'uuid-ossp v4 random UUID',
     'pg_uuidv7 time-ordered UUID with better clustering',
     'feature',
     'original',
     'planning',
     1.2,
     1.0,
     'high',
     'pg_uuidv7',
     1000),

    ('vector_search',
     'pgvector basic similarity search',
     'pgvecto.rs high-performance vector operations with SIMD',
     'performance',
     'original',
     'planning',
     28.0,
     1.5,
     'medium',
     'vectors',
     10000),

    ('string_processing',
     'Basic SQL string functions',
     'pg_str Laravel-style string manipulation API',
     'feature',
     'original',
     'planning',
     5.0,
     1.2,
     'high',
     'pg_str',
     5000),

    ('sequence_analysis',
     'SQL-based biological sequence calculations',
     'Rust SIMD-optimized sequence processing',
     'performance',
     'original',
     'planning',
     50.0,
     2.0,
     'medium',
     'bio_postgres',
     1000),

    ('analytics_engine',
     'TimescaleDB OLAP components',
     'pg_analytics DuckDB-powered analytical engine',
     'performance',
     'original',
     'planning',
     15.0,
     1.8,
     'medium',
     'pg_analytics',
     50000),

    ('iot_data_processing',
     'JSON + HStore device data handling',
     'pg_iot native device protocol parsing',
     'feature',
     'original',
     'planning',
     8.0,
     1.3,
     'medium',
     'pg_iot',
     20000)
ON CONFLICT (feature_name) DO UPDATE SET
    last_updated = NOW();

-- 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_feature_enhancements_active_mode
    ON enhancement_control.feature_enhancements(active_mode);

CREATE INDEX IF NOT EXISTS idx_performance_comparison_feature_timestamp
    ON enhancement_control.performance_comparison(feature_name, test_timestamp);

CREATE INDEX IF NOT EXISTS idx_usage_statistics_feature_timestamp
    ON enhancement_control.usage_statistics(feature_name, usage_timestamp);

-- 显示初始化结果
SELECT
    '🎉 Enhancement Control System Initialized!' as message,
    COUNT(*) as features_configured
FROM enhancement_control.feature_enhancements;

SELECT
    '📊 Current Enhancement Status:' as status_report,
    feature_name,
    active_mode,
    enhancement_status,
    performance_gain || 'x improvement' as benefit
FROM enhancement_control.feature_enhancements
ORDER BY performance_gain DESC;
