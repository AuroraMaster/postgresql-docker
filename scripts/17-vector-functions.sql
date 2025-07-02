-- ================================================================
-- 17-vector-functions.sql
-- 向量搜索增强函数实现
-- ================================================================

-- ================================================================
-- 智能向量搜索函数
-- ================================================================

-- 主要的增强向量搜索函数
CREATE OR REPLACE FUNCTION enhanced_vector_search(
    query_vector vector,
    similarity_threshold DOUBLE PRECISION DEFAULT 0.7,
    max_results INTEGER DEFAULT 10,
    search_algorithm TEXT DEFAULT 'auto', -- 'auto', 'ivfflat', 'hnsw', 'rust_optimized'
    performance_mode TEXT DEFAULT 'balanced'
)
RETURNS TABLE(
    id INTEGER,
    similarity DOUBLE PRECISION,
    content TEXT,
    metadata JSONB,
    implementation_used TEXT
) AS $$
DECLARE
    vector_count INTEGER;
    selected_implementation TEXT;
    use_enhanced BOOLEAN := false;
    table_exists BOOLEAN := false;
BEGIN
    -- 检查RAG表是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'rag' AND table_name = 'document_chunks'
    ) INTO table_exists;

    IF NOT table_exists THEN
        RAISE EXCEPTION 'RAG document_chunks table not found. Run 09-rag.sql first.';
    END IF;

    -- 获取向量数据量
    EXECUTE 'SELECT COUNT(*) FROM rag.document_chunks' INTO vector_count;

    -- 智能选择实现
    selected_implementation := enhancement_control.adaptive_performance_selector(
        'vector_search',
        vector_count,
        performance_mode
    );

    -- 检查是否使用增强实现
    use_enhanced := (selected_implementation = 'enhanced')
                    AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vectors');

    -- 记录搜索开始
    INSERT INTO enhancement_control.performance_comparison
    (feature_name, test_scenario, implementation_type, data_size, test_timestamp)
    VALUES (
        'vector_search',
        'similarity_search',
        CASE WHEN use_enhanced THEN 'enhanced' ELSE 'original' END,
        vector_count,
        NOW()
    );

    IF use_enhanced THEN
        -- 使用Rust增强的高性能实现 (pgvecto.rs)
        RETURN QUERY EXECUTE format('
            SELECT
                dc.id,
                1 - (dc.embedding <=> $1) as similarity,
                dc.content,
                dc.metadata,
                $2 as implementation_used
            FROM rag.document_chunks dc
            WHERE 1 - (dc.embedding <=> $1) >= $3
            ORDER BY dc.embedding <=> $1
            LIMIT $4
        ') USING query_vector, 'rust_enhanced', similarity_threshold, max_results;
    ELSE
        -- 使用原有稳定实现 (pgvector)
        RETURN QUERY EXECUTE format('
            SELECT
                dc.id,
                1 - (dc.embedding <-> $1) as similarity,
                dc.content,
                dc.metadata,
                $2 as implementation_used
            FROM rag.document_chunks dc
            WHERE 1 - (dc.embedding <-> $1) >= $3
            ORDER BY dc.embedding <-> $1
            LIMIT $4
        ') USING query_vector, 'original_pgvector', similarity_threshold, max_results;
    END IF;

    -- 记录使用统计
    INSERT INTO enhancement_control.usage_statistics
    (feature_name, implementation_used, query_parameters, execution_context)
    VALUES (
        'vector_search',
        CASE WHEN use_enhanced THEN 'enhanced' ELSE 'original' END,
        jsonb_build_object(
            'vector_count', vector_count,
            'similarity_threshold', similarity_threshold,
            'max_results', max_results,
            'search_algorithm', search_algorithm,
            'performance_mode', performance_mode
        ),
        'enhanced_vector_search'
    );

    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION enhanced_vector_search IS
'增强向量搜索：小数据量用原有pgvector，大数据量自动切换到Rust高性能版本';
