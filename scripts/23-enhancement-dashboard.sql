-- ================================================================
-- 23-enhancement-dashboard.sql
-- 增强控制面板：统一管理和监控所有Rust增强功能
-- ================================================================

-- ================================================================
-- 综合控制面板函数
-- ================================================================

-- 增强功能总览仪表板
CREATE OR REPLACE FUNCTION enhancement_dashboard()
RETURNS TABLE(
    category TEXT,
    feature_name TEXT,
    status TEXT,
    mode TEXT,
    performance_gain TEXT,
    safety_level TEXT,
    usage_last_24h INTEGER,
    avg_performance TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE fe.enhancement_type
            WHEN 'performance' THEN '🚀 Performance'
            WHEN 'feature' THEN '⭐ Feature'
            WHEN 'security' THEN '🛡️ Security'
            ELSE '❓ Other'
        END as category,
        fe.feature_name,
        CASE fe.enhancement_status
            WHEN 'active' THEN '✅ Active'
            WHEN 'testing' THEN '🧪 Testing'
            WHEN 'planning' THEN '📋 Planning'
            WHEN 'deprecated' THEN '❌ Deprecated'
            ELSE '❓ Unknown'
        END as status,
        CASE fe.active_mode
            WHEN 'enhanced' THEN '🔧 Enhanced'
            WHEN 'adaptive' THEN '🧠 Adaptive'
            WHEN 'original' THEN '📝 Original'
            ELSE '❓ Unknown'
        END as mode,
        COALESCE(fe.performance_gain::TEXT || 'x', 'N/A') as performance_gain,
        CASE fe.safety_level
            WHEN 'critical' THEN '🔴 Critical'
            WHEN 'high' THEN '🟠 High'
            WHEN 'medium' THEN '🟡 Medium'
            WHEN 'low' THEN '🟢 Low'
            ELSE '❓ Unknown'
        END as safety_level,
        COALESCE(usage_stats.daily_usage, 0) as usage_last_24h,
        COALESCE(
            ROUND(perf_stats.avg_performance, 2)::TEXT || 'ms',
            'N/A'
        ) as avg_performance
    FROM enhancement_control.feature_enhancements fe
    LEFT JOIN (
        SELECT
            us.feature_name,
            COUNT(*) as daily_usage
        FROM enhancement_control.usage_statistics us
        WHERE us.usage_timestamp > NOW() - INTERVAL '24 hours'
        GROUP BY us.feature_name
    ) usage_stats ON fe.feature_name = usage_stats.feature_name
    LEFT JOIN (
        SELECT
            pc.feature_name,
            AVG(pc.execution_time_ms) as avg_performance
        FROM enhancement_control.performance_comparison pc
        WHERE pc.test_timestamp > NOW() - INTERVAL '24 hours'
        GROUP BY pc.feature_name
    ) perf_stats ON fe.feature_name = perf_stats.feature_name
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

COMMENT ON FUNCTION enhancement_dashboard IS
'增强功能总览仪表板，显示所有功能的状态、性能和使用情况';

-- 实时性能监控仪表板
CREATE OR REPLACE FUNCTION performance_monitor_dashboard(
    time_window INTERVAL DEFAULT '1 hour'
)
RETURNS TABLE(
    feature_name TEXT,
    implementation_type TEXT,
    total_calls INTEGER,
    avg_execution_ms DOUBLE PRECISION,
    min_execution_ms DOUBLE PRECISION,
    max_execution_ms DOUBLE PRECISION,
    success_rate DOUBLE PRECISION,
    throughput_per_sec DOUBLE PRECISION,
    performance_trend TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH performance_data AS (
        SELECT
            pc.feature_name,
            pc.implementation_type,
            COUNT(*) as calls,
            AVG(pc.execution_time_ms) as avg_time,
            MIN(pc.execution_time_ms) as min_time,
            MAX(pc.execution_time_ms) as max_time,
            AVG(CASE WHEN pc.error_count = 0 THEN 1.0 ELSE 0.0 END) as success_rate,
            AVG(pc.throughput_ops_sec) as avg_throughput
        FROM enhancement_control.performance_comparison pc
        WHERE pc.test_timestamp > NOW() - time_window
        GROUP BY pc.feature_name, pc.implementation_type
    ),
    trend_data AS (
        SELECT
            pc.feature_name,
            pc.implementation_type,
            AVG(CASE
                WHEN pc.test_timestamp > NOW() - (time_window / 2) THEN pc.execution_time_ms
            END) as recent_avg,
            AVG(CASE
                WHEN pc.test_timestamp <= NOW() - (time_window / 2) THEN pc.execution_time_ms
            END) as older_avg
        FROM enhancement_control.performance_comparison pc
        WHERE pc.test_timestamp > NOW() - time_window
        GROUP BY pc.feature_name, pc.implementation_type
    )
    SELECT
        pd.feature_name,
        pd.implementation_type,
        pd.calls::INTEGER,
        ROUND(pd.avg_time, 3),
        ROUND(pd.min_time, 3),
        ROUND(pd.max_time, 3),
        ROUND(pd.success_rate * 100, 2),
        ROUND(pd.avg_throughput, 2),
        CASE
            WHEN td.recent_avg < td.older_avg * 0.9 THEN '📈 Improving'
            WHEN td.recent_avg > td.older_avg * 1.1 THEN '📉 Degrading'
            ELSE '➡️ Stable'
        END as trend
    FROM performance_data pd
    LEFT JOIN trend_data td ON pd.feature_name = td.feature_name
                           AND pd.implementation_type = td.implementation_type
    ORDER BY pd.feature_name, pd.implementation_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION performance_monitor_dashboard IS
'实时性能监控仪表板，显示指定时间窗口内的性能统计和趋势';

-- 使用统计分析仪表板
CREATE OR REPLACE FUNCTION usage_analytics_dashboard()
RETURNS TABLE(
    feature_name TEXT,
    total_usage INTEGER,
    original_usage INTEGER,
    enhanced_usage INTEGER,
    enhancement_adoption_rate DOUBLE PRECISION,
    peak_usage_hour INTEGER,
    most_common_context TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH usage_stats AS (
        SELECT
            us.feature_name,
            COUNT(*) as total_calls,
            COUNT(CASE WHEN us.implementation_used = 'original' THEN 1 END) as original_calls,
            COUNT(CASE WHEN us.implementation_used LIKE '%enhanced%' THEN 1 END) as enhanced_calls,
            EXTRACT(HOUR FROM us.usage_timestamp) as usage_hour,
            us.execution_context
        FROM enhancement_control.usage_statistics us
        WHERE us.usage_timestamp > NOW() - INTERVAL '7 days'
        GROUP BY us.feature_name, EXTRACT(HOUR FROM us.usage_timestamp), us.execution_context
    ),
    peak_hours AS (
        SELECT
            feature_name,
            usage_hour,
            SUM(total_calls) as hourly_total,
            ROW_NUMBER() OVER (PARTITION BY feature_name ORDER BY SUM(total_calls) DESC) as rn
        FROM usage_stats
        GROUP BY feature_name, usage_hour
    ),
    common_contexts AS (
        SELECT
            feature_name,
            execution_context,
            SUM(total_calls) as context_total,
            ROW_NUMBER() OVER (PARTITION BY feature_name ORDER BY SUM(total_calls) DESC) as rn
        FROM usage_stats
        GROUP BY feature_name, execution_context
    )
    SELECT
        us.feature_name,
        SUM(us.total_calls)::INTEGER as total_usage,
        SUM(us.original_calls)::INTEGER as original_usage,
        SUM(us.enhanced_calls)::INTEGER as enhanced_usage,
        ROUND(
            CASE
                WHEN SUM(us.total_calls) > 0
                THEN SUM(us.enhanced_calls) * 100.0 / SUM(us.total_calls)
                ELSE 0.0
            END, 2
        ) as enhancement_adoption_rate,
        ph.usage_hour::INTEGER as peak_usage_hour,
        cc.execution_context as most_common_context
    FROM usage_stats us
    LEFT JOIN peak_hours ph ON us.feature_name = ph.feature_name AND ph.rn = 1
    LEFT JOIN common_contexts cc ON us.feature_name = cc.feature_name AND cc.rn = 1
    GROUP BY us.feature_name, ph.usage_hour, cc.execution_context
    ORDER BY SUM(us.total_calls) DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION usage_analytics_dashboard IS
'使用统计分析仪表板，显示功能使用模式和增强功能采用情况';

-- ================================================================
-- 批量管理函数
-- ================================================================

-- 批量启用增强功能
CREATE OR REPLACE FUNCTION enable_all_enhancements(
    enhancement_types TEXT[] DEFAULT ARRAY['performance', 'feature', 'security'],
    safety_levels TEXT[] DEFAULT ARRAY['high', 'critical']
)
RETURNS TABLE(
    feature_name TEXT,
    action_result TEXT
) AS $$
DECLARE
    feature_record RECORD;
BEGIN
    FOR feature_record IN
        SELECT fe.feature_name
        FROM enhancement_control.feature_enhancements fe
        WHERE fe.enhancement_type = ANY(enhancement_types)
          AND fe.safety_level = ANY(safety_levels)
          AND fe.enhancement_status IN ('planning', 'testing')
    LOOP
        RETURN QUERY SELECT
            feature_record.feature_name,
            enhancement_control.control_enhancement(feature_record.feature_name, 'enable_adaptive');
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enable_all_enhancements IS
'批量启用符合条件的增强功能';

-- 系统健康检查
CREATE OR REPLACE FUNCTION system_health_check()
RETURNS TABLE(
    check_category TEXT,
    check_item TEXT,
    status TEXT,
    details TEXT,
    recommendation TEXT
) AS $$
DECLARE
    total_features INTEGER;
    active_features INTEGER;
    error_rate DOUBLE PRECISION;
    avg_performance DOUBLE PRECISION;
BEGIN
    -- 功能状态检查
    SELECT COUNT(*), COUNT(CASE WHEN enhancement_status = 'active' THEN 1 END)
    INTO total_features, active_features
    FROM enhancement_control.feature_enhancements;

    RETURN QUERY SELECT
        'Feature Status'::TEXT,
        'Active Features'::TEXT,
        CASE
            WHEN active_features > 0 THEN '✅ Good'
            ELSE '⚠️ Warning'
        END,
        active_features || ' out of ' || total_features || ' features active',
        CASE
            WHEN active_features = 0 THEN 'Consider enabling some enhancements'
            ELSE 'System is operational'
        END;

    -- 性能检查
    SELECT
        AVG(CASE WHEN error_count > 0 THEN 1.0 ELSE 0.0 END),
        AVG(execution_time_ms)
    INTO error_rate, avg_performance
    FROM enhancement_control.performance_comparison
    WHERE test_timestamp > NOW() - INTERVAL '1 hour';

    RETURN QUERY SELECT
        'Performance'::TEXT,
        'Error Rate'::TEXT,
        CASE
            WHEN COALESCE(error_rate, 0) < 0.01 THEN '✅ Excellent'
            WHEN COALESCE(error_rate, 0) < 0.05 THEN '🟡 Good'
            ELSE '🔴 Poor'
        END,
        COALESCE(ROUND(error_rate * 100, 2)::TEXT || '%', 'No data'),
        CASE
            WHEN COALESCE(error_rate, 0) > 0.05 THEN 'Investigate error sources'
            ELSE 'Error rate within acceptable limits'
        END;

    -- 使用统计检查
    RETURN QUERY SELECT
        'Usage'::TEXT,
        'Recent Activity'::TEXT,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM enhancement_control.usage_statistics
                WHERE usage_timestamp > NOW() - INTERVAL '24 hours'
            ) THEN '✅ Active'
            ELSE '⚠️ Inactive'
        END,
        COALESCE(
            (SELECT COUNT(*)::TEXT FROM enhancement_control.usage_statistics
             WHERE usage_timestamp > NOW() - INTERVAL '24 hours'),
            '0'
        ) || ' operations in last 24h',
        'Monitor usage patterns for optimization opportunities';

    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION system_health_check IS
'系统健康检查，评估增强功能的整体状态';

-- ================================================================
-- 演示和状态显示
-- ================================================================

-- 显示完整的增强控制面板
SELECT '🎛️ PostgreSQL Enhancement Control Dashboard' as title;

-- 主仪表板
SELECT '📊 Enhancement Overview:' as section_title;
SELECT * FROM enhancement_dashboard();

-- 性能监控
SELECT '⚡ Performance Monitor (Last Hour):' as section_title;
SELECT * FROM performance_monitor_dashboard('1 hour');

-- 使用分析
SELECT '📈 Usage Analytics (Last 7 Days):' as section_title;
SELECT * FROM usage_analytics_dashboard();

-- 系统健康
SELECT '🏥 System Health Check:' as section_title;
SELECT * FROM system_health_check();

-- 实时监控视图
SELECT '📺 Live Performance Monitor:' as section_title;
SELECT * FROM enhancement_control.live_performance_monitor;

RAISE NOTICE '🎉 Enhancement Control Dashboard fully operational!';
RAISE NOTICE '   ✅ Comprehensive monitoring and management interface';
RAISE NOTICE '   ✅ Real-time performance tracking';
RAISE NOTICE '   ✅ Usage analytics and trends';
RAISE NOTICE '   ✅ Health checks and recommendations';
