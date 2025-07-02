-- ================================================================
-- 19-string-enhancement.sql
-- 字符串处理增强：在原有SQL基础上添加Laravel风格API
-- 提供现代化字符串操作功能
-- ================================================================

-- ================================================================
-- 检查和准备Rust增强扩展
-- ================================================================

-- 检查pg_str (Rust字符串处理扩展)
DO $$
DECLARE
    pg_str_available BOOLEAN := false;
BEGIN
    -- 检查pg_str扩展是否可用
    SELECT COUNT(*) > 0 INTO pg_str_available
    FROM pg_available_extensions
    WHERE name = 'pg_str';

    IF pg_str_available THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS pg_str;
            RAISE NOTICE '✅ Rust pg_str extension installed successfully';

            -- 更新增强控制状态
            UPDATE enhancement_control.feature_enhancements
            SET enhancement_status = 'active',
                last_updated = NOW()
            WHERE feature_name = 'string_processing';

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '⚠️  pg_str available but installation failed: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '📝 pg_str not available, using SQL string functions only';
    END IF;
END $$;

-- ================================================================
-- 增强字符串处理函数
-- ================================================================

-- 主要的增强字符串处理函数
CREATE OR REPLACE FUNCTION enhanced_string_process(
    input_text TEXT,
    operation TEXT, -- 'slug', 'camel', 'snake', 'title', 'clean', 'truncate'
    options JSONB DEFAULT '{}',
    performance_mode TEXT DEFAULT 'balanced'
)
RETURNS TEXT AS $$
DECLARE
    selected_implementation TEXT;
    result_text TEXT;
    max_length INTEGER;
    separator TEXT;
BEGIN
    -- 智能选择实现
    selected_implementation := enhancement_control.adaptive_performance_selector(
        'string_processing',
        LENGTH(input_text),
        performance_mode
    );

    -- 提取选项
    max_length := COALESCE((options->>'max_length')::INTEGER, 255);
    separator := COALESCE(options->>'separator', '-');

    CASE operation
        WHEN 'slug' THEN
            IF selected_implementation = 'enhanced'
               AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_str') THEN
                -- 使用Rust增强的slug生成
                result_text := str_slug(input_text);
            ELSE
                -- SQL实现的slug生成
                result_text := LOWER(
                    TRIM(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(input_text, '[^a-zA-Z0-9\s-]', '', 'g'),
                            '\s+', separator, 'g'
                        )
                    )
                );
            END IF;

        WHEN 'camel' THEN
            IF selected_implementation = 'enhanced'
               AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_str') THEN
                result_text := str_camel(input_text);
            ELSE
                -- SQL实现的驼峰命名
                result_text := (
                    SELECT STRING_AGG(
                        CASE
                            WHEN i = 1 THEN LOWER(word)
                            ELSE INITCAP(LOWER(word))
                        END,
                        ''
                    )
                    FROM (
                        SELECT
                            REGEXP_SPLIT_TO_TABLE(input_text, '\s+') as word,
                            ROW_NUMBER() OVER() as i
                    ) words
                );
            END IF;

        WHEN 'snake' THEN
            IF selected_implementation = 'enhanced'
               AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_str') THEN
                result_text := str_snake(input_text);
            ELSE
                -- SQL实现的蛇形命名
                result_text := LOWER(
                    REGEXP_REPLACE(
                        TRIM(input_text),
                        '\s+', '_', 'g'
                    )
                );
            END IF;

        WHEN 'title' THEN
            -- 标题格式化
            result_text := INITCAP(LOWER(input_text));

        WHEN 'clean' THEN
            -- 清理字符串（移除多余空白和特殊字符）
            result_text := TRIM(REGEXP_REPLACE(input_text, '\s+', ' ', 'g'));

        WHEN 'truncate' THEN
            -- 截断字符串
            IF LENGTH(input_text) > max_length THEN
                result_text := SUBSTRING(input_text FROM 1 FOR max_length - 3) || '...';
            ELSE
                result_text := input_text;
            END IF;

        ELSE
            RAISE EXCEPTION 'Unknown string operation: %', operation;
    END CASE;

    -- 记录使用统计
    INSERT INTO enhancement_control.usage_statistics
    (feature_name, implementation_used, query_parameters, execution_context)
    VALUES (
        'string_processing',
        selected_implementation,
        jsonb_build_object(
            'operation', operation,
            'input_length', LENGTH(input_text),
            'options', options,
            'performance_mode', performance_mode
        ),
        'enhanced_string_process'
    );

    RETURN result_text;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enhanced_string_process IS
'增强字符串处理：提供Laravel风格的字符串操作，智能选择实现';

-- ================================================================
-- 便捷包装函数
-- ================================================================

-- URL友好的slug生成
CREATE OR REPLACE FUNCTION generate_slug(input_text TEXT, max_length INTEGER DEFAULT 100)
RETURNS TEXT AS $$
BEGIN
    RETURN enhanced_string_process(
        input_text,
        'slug',
        jsonb_build_object('max_length', max_length),
        'performance'
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_slug IS '生成URL友好的slug字符串';

-- 驼峰命名转换
CREATE OR REPLACE FUNCTION to_camel_case(input_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN enhanced_string_process(input_text, 'camel', '{}', 'performance');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION to_camel_case IS '转换为驼峰命名格式';

-- 蛇形命名转换
CREATE OR REPLACE FUNCTION to_snake_case(input_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN enhanced_string_process(input_text, 'snake', '{}', 'performance');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION to_snake_case IS '转换为蛇形命名格式';

-- 智能文本清理
CREATE OR REPLACE FUNCTION clean_text(
    input_text TEXT,
    remove_html BOOLEAN DEFAULT false,
    normalize_spaces BOOLEAN DEFAULT true
)
RETURNS TEXT AS $$
DECLARE
    cleaned_text TEXT;
BEGIN
    cleaned_text := input_text;

    -- 移除HTML标签
    IF remove_html THEN
        cleaned_text := REGEXP_REPLACE(cleaned_text, '<[^>]*>', '', 'g');
    END IF;

    -- 标准化空白字符
    IF normalize_spaces THEN
        cleaned_text := enhanced_string_process(cleaned_text, 'clean');
    END IF;

    RETURN cleaned_text;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION clean_text IS '智能文本清理，支持HTML标签移除和空白标准化';

-- 批量字符串处理
CREATE OR REPLACE FUNCTION batch_string_process(
    input_texts TEXT[],
    operation TEXT,
    options JSONB DEFAULT '{}'
)
RETURNS TEXT[] AS $$
DECLARE
    result_array TEXT[];
    input_text TEXT;
    start_time TIMESTAMP WITH TIME ZONE;
    end_time TIMESTAMP WITH TIME ZONE;
BEGIN
    start_time := clock_timestamp();
    result_array := ARRAY[]::TEXT[];

    FOREACH input_text IN ARRAY input_texts LOOP
        result_array := array_append(
            result_array,
            enhanced_string_process(input_text, operation, options, 'performance')
        );
    END LOOP;

    end_time := clock_timestamp();

    -- 记录批量处理性能
    INSERT INTO enhancement_control.performance_comparison
    (feature_name, test_scenario, implementation_type, data_size, execution_time_ms)
    VALUES (
        'string_processing',
        'batch_processing',
        'enhanced',
        array_length(input_texts, 1),
        EXTRACT(EPOCH FROM (end_time - start_time)) * 1000
    );

    RETURN result_array;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION batch_string_process IS '批量字符串处理，支持数组输入';

-- ================================================================
-- 字符串分析和工具函数
-- ================================================================

-- 字符串复杂度分析
CREATE OR REPLACE FUNCTION analyze_string_complexity(input_text TEXT)
RETURNS TABLE(
    text_length INTEGER,
    word_count INTEGER,
    unique_chars INTEGER,
    special_chars INTEGER,
    complexity_score DOUBLE PRECISION,
    suggested_operation TEXT
) AS $$
DECLARE
    words INTEGER;
    unique_count INTEGER;
    special_count INTEGER;
    score DOUBLE PRECISION;
    suggestion TEXT;
BEGIN
    -- 计算各项指标
    words := array_length(string_to_array(TRIM(input_text), ' '), 1);
    unique_count := LENGTH(input_text) - LENGTH(REPLACE(REPLACE(REPLACE(
        LOWER(input_text), 'a', ''), 'e', ''), 'i', ''));
    special_count := LENGTH(input_text) - LENGTH(REGEXP_REPLACE(input_text, '[^a-zA-Z0-9\s]', '', 'g'));

    -- 计算复杂度分数
    score := (LENGTH(input_text) * 0.1) + (words * 0.5) + (special_count * 2.0);

    -- 建议操作
    IF score > 50 THEN
        suggestion := 'truncate or clean';
    ELSIF special_count > 5 THEN
        suggestion := 'slug generation';
    ELSIF words > 3 THEN
        suggestion := 'snake_case for identifiers';
    ELSE
        suggestion := 'camel_case for variables';
    END IF;

    RETURN QUERY SELECT
        LENGTH(input_text),
        COALESCE(words, 0),
        unique_count,
        special_count,
        score,
        suggestion;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION analyze_string_complexity IS '分析字符串复杂度并提供处理建议';

-- ================================================================
-- 性能基准测试
-- ================================================================

-- 字符串处理性能基准测试
CREATE OR REPLACE FUNCTION benchmark_string_processing(
    test_iterations INTEGER DEFAULT 1000,
    test_string_length INTEGER DEFAULT 100
)
RETURNS TABLE(
    test_name TEXT,
    implementation TEXT,
    avg_time_ms DOUBLE PRECISION,
    operations_per_second DOUBLE PRECISION
) AS $$
DECLARE
    start_time TIMESTAMP WITH TIME ZONE;
    end_time TIMESTAMP WITH TIME ZONE;
    duration_ms DOUBLE PRECISION;
    test_string TEXT;
    i INTEGER;
BEGIN
    -- 生成测试字符串
    test_string := REPEAT('Hello World Test String ', test_string_length / 25);

    -- 测试slug生成 - SQL实现
    start_time := clock_timestamp();
    FOR i IN 1..test_iterations LOOP
        PERFORM enhanced_string_process(test_string, 'slug', '{}', 'stability');
    END LOOP;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

    RETURN QUERY SELECT
        'Slug Generation - SQL',
        'original',
        duration_ms / test_iterations,
        test_iterations / (duration_ms / 1000);

    -- 测试slug生成 - Rust增强（如果可用）
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_str') THEN
        start_time := clock_timestamp();
        FOR i IN 1..test_iterations LOOP
            PERFORM enhanced_string_process(test_string, 'slug', '{}', 'performance');
        END LOOP;
        end_time := clock_timestamp();
        duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

        RETURN QUERY SELECT
            'Slug Generation - Rust',
            'enhanced',
            duration_ms / test_iterations,
            test_iterations / (duration_ms / 1000);
    END IF;

    -- 测试驼峰命名转换
    start_time := clock_timestamp();
    FOR i IN 1..test_iterations LOOP
        PERFORM to_camel_case(test_string);
    END LOOP;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

    RETURN QUERY SELECT
        'Camel Case Conversion',
        'wrapper',
        duration_ms / test_iterations,
        test_iterations / (duration_ms / 1000);

    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION benchmark_string_processing IS
'字符串处理性能基准测试，对比不同实现的性能';

-- ================================================================
-- 示例和测试
-- ================================================================

-- 显示字符串增强功能状态
SELECT
    '📝 String Processing Enhancement Status:' as title,
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_str')
        THEN '✅ Rust pg_str available'
        ELSE '📝 Using SQL string functions only'
    END as rust_status,
    enhancement_control.control_enhancement('string_processing', 'status') as enhancement_config;

-- 演示不同字符串处理方式
SELECT
    '📋 String Processing Examples:' as demo_title,
    'Original' as type,
    'Hello World! This is a Test String.' as input,
    '' as output,
    'Input text' as note
UNION ALL
SELECT
    '',
    'Slug',
    '',
    generate_slug('Hello World! This is a Test String.'),
    'URL-friendly slug'
UNION ALL
SELECT
    '',
    'Camel Case',
    '',
    to_camel_case('hello world test string'),
    'camelCase format'
UNION ALL
SELECT
    '',
    'Snake Case',
    '',
    to_snake_case('Hello World Test String'),
    'snake_case format'
UNION ALL
SELECT
    '',
    'Cleaned',
    '',
    clean_text('  Hello   World!   <script>alert("test")</script>  ', true, true),
    'HTML removed, spaces normalized';

-- 显示性能基准（小规模测试）
SELECT * FROM benchmark_string_processing(100, 50);

RAISE NOTICE '🎉 String Processing Enhancement successfully implemented!';
RAISE NOTICE '   ✅ Laravel-style string manipulation API';
RAISE NOTICE '   ✅ Intelligent implementation selection';
RAISE NOTICE '   ✅ Batch processing support';
RAISE NOTICE '   ✅ Performance monitoring and analysis';
