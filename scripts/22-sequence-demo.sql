-- ================================================================
-- 22-sequence-demo.sql
-- 生物序列分析演示和基准测试
-- ================================================================

-- ================================================================
-- 性能基准测试
-- ================================================================

-- 序列分析性能基准测试
CREATE OR REPLACE FUNCTION benchmark_sequence_analysis(
    test_iterations INTEGER DEFAULT 100,
    sequence_length INTEGER DEFAULT 1000
)
RETURNS TABLE(
    test_name TEXT,
    implementation TEXT,
    avg_time_ms DOUBLE PRECISION,
    analyses_per_second DOUBLE PRECISION,
    sequence_size INTEGER
) AS $$
DECLARE
    start_time TIMESTAMP WITH TIME ZONE;
    end_time TIMESTAMP WITH TIME ZONE;
    duration_ms DOUBLE PRECISION;
    test_sequence TEXT;
    i INTEGER;
    bases TEXT[] := ARRAY['A', 'T', 'G', 'C'];
BEGIN
    -- 生成随机DNA序列用于测试
    test_sequence := (
        SELECT STRING_AGG(
            bases[1 + (RANDOM() * 4)::INTEGER],
            ''
        )
        FROM generate_series(1, sequence_length)
    );

    -- 测试基础分析 - SQL实现
    start_time := clock_timestamp();
    FOR i IN 1..test_iterations LOOP
        PERFORM * FROM enhanced_sequence_analysis(test_sequence, 'basic', 'stability');
    END LOOP;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

    RETURN QUERY SELECT
        'Basic Analysis - SQL',
        'original',
        duration_ms / test_iterations,
        test_iterations / (duration_ms / 1000),
        sequence_length;

    -- 测试高级分析（如果Rust增强可用）
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'bio_postgres') THEN
        start_time := clock_timestamp();
        FOR i IN 1..test_iterations LOOP
            PERFORM * FROM enhanced_sequence_analysis(test_sequence, 'advanced', 'performance');
        END LOOP;
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

        RETURN QUERY SELECT
            'Advanced Analysis - Rust',
            'enhanced',
            duration_ms / test_iterations,
            test_iterations / (duration_ms / 1000),
            sequence_length;

        -- 测试SIMD优化分析
        start_time := clock_timestamp();
        FOR i IN 1..test_iterations LOOP
            PERFORM * FROM enhanced_sequence_analysis(test_sequence, 'simd', 'performance');
        END LOOP;
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

        RETURN QUERY SELECT
            'SIMD Optimized - Rust',
            'simd_enhanced',
            duration_ms / test_iterations,
            test_iterations / (duration_ms / 1000),
            sequence_length;
    END IF;

    -- 测试GC含量计算
    start_time := clock_timestamp();
    FOR i IN 1..test_iterations LOOP
        PERFORM calculate_gc_content(test_sequence, false); -- SQL实现
    END LOOP;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

    RETURN QUERY SELECT
        'GC Content Calculation',
        'optimized',
        duration_ms / test_iterations,
        test_iterations / (duration_ms / 1000),
        sequence_length;

    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION benchmark_sequence_analysis IS
'生物序列分析性能基准测试，对比不同实现的性能';

-- ================================================================
-- 示例和演示
-- ================================================================

-- 显示序列分析增强状态
SELECT
    '🧬 Sequence Analysis Enhancement Status:' as title,
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'bio_postgres')
        THEN '✅ Rust bio_postgres available'
        ELSE '📝 Using SQL sequence analysis only'
    END as rust_status,
    enhancement_control.control_enhancement('sequence_analysis', 'status') as enhancement_config;

-- 生成示例DNA序列用于演示
DO $$
DECLARE
    demo_sequence TEXT;
    bases TEXT[] := ARRAY['A', 'T', 'G', 'C'];
BEGIN
    -- 生成500bp的随机DNA序列
    demo_sequence := (
        SELECT STRING_AGG(
            bases[1 + (RANDOM() * 4)::INTEGER],
            ''
        )
        FROM generate_series(1, 500)
    );

    -- 创建临时表存储演示序列
    DROP TABLE IF EXISTS temp_demo_sequences;
    CREATE TEMP TABLE temp_demo_sequences (
        id SERIAL PRIMARY KEY,
        name TEXT,
        sequence TEXT,
        description TEXT
    );

    INSERT INTO temp_demo_sequences (name, sequence, description) VALUES
    ('Random_DNA_500bp', demo_sequence, '随机生成的500bp DNA序列'),
    ('High_GC_Example', 'GCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGCGC', '高GC含量示例序列'),
    ('Low_GC_Example', 'ATATATATATATATATATATATATATATATATATATAT', '低GC含量示例序列'),
    ('Mixed_Example', 'ATGCATGCATGCATGCATGCATGCATGCATGCATGCATGC', '混合碱基示例序列');

    RAISE NOTICE '✅ Demo sequences created successfully';
END $$;

-- 演示不同序列分析方式
SELECT
    '📋 Sequence Analysis Examples:' as demo_title,
    ds.name,
    LEFT(ds.sequence, 40) || '...' as sequence_preview,
    '' as analysis_result,
    ds.description
FROM temp_demo_sequences ds
WHERE ds.id = 1

UNION ALL

-- 显示基础分析结果
SELECT
    '',
    'Basic Analysis',
    '',
    sa.metric_name || ': ' || sa.value || ' (' || sa.percentage || '%)',
    'SQL实现 - ' || sa.implementation
FROM temp_demo_sequences ds
CROSS JOIN enhanced_sequence_analysis(ds.sequence, 'basic') sa
WHERE ds.id = 1
LIMIT 5

UNION ALL

-- 显示GC含量对比
SELECT
    '',
    'GC Content Comparison',
    '',
    'High GC: ' || calculate_gc_content((SELECT sequence FROM temp_demo_sequences WHERE name = 'High_GC_Example'))::TEXT || '%',
    'vs Low GC: ' || calculate_gc_content((SELECT sequence FROM temp_demo_sequences WHERE name = 'Low_GC_Example'))::TEXT || '%'

UNION ALL

-- 显示复杂度分析预览
SELECT
    '',
    'Complexity Analysis',
    '',
    'Position ' || sc.position || ': Score ' || sc.complexity_score,
    'Window size: 20bp'
FROM temp_demo_sequences ds
CROSS JOIN analyze_sequence_complexity(ds.sequence, 20) sc
WHERE ds.id = 1
LIMIT 3;

-- 演示模式搜索功能
SELECT
    '🔍 Pattern Search Demo:' as search_title,
    'Pattern: ATGC' as pattern_info,
    'Position: ' || sp.match_position as position,
    'Match: ' || sp.matched_sequence as matched_seq,
    'Similarity: ' || sp.similarity_score || '%' as similarity
FROM temp_demo_sequences ds
CROSS JOIN search_sequence_patterns(ds.sequence, 'ATGC', 0) sp
WHERE ds.id = 1
LIMIT 5;

-- 演示批量分析
SELECT
    '📊 Batch Analysis Demo:' as batch_title,
    'Sequence ' || ba.sequence_index as seq_id,
    ba.sequence_preview,
    ba.metric_name || ': ' || ba.value as result,
    ba.implementation
FROM batch_sequence_analysis(
    ARRAY(SELECT sequence FROM temp_demo_sequences LIMIT 3),
    'basic'
) ba
LIMIT 10;

-- 显示性能基准（小规模测试）
SELECT '⚡ Performance Benchmark:' as benchmark_title, *
FROM benchmark_sequence_analysis(50, 200);

RAISE NOTICE '🎉 Sequence Analysis Enhancement successfully demonstrated!';
RAISE NOTICE '   ✅ Basic to SIMD analysis modes available';
RAISE NOTICE '   ✅ GC content and complexity analysis';
RAISE NOTICE '   ✅ Pattern searching with mismatch tolerance';
RAISE NOTICE '   ✅ Batch processing capabilities';
