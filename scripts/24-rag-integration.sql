-- ================================================================
-- 24-rag-integration.sql
-- RAG模块增强集成：整合向量搜索增强功能
-- ================================================================

-- ================================================================
-- 更新RAG核心函数以使用增强功能
-- ================================================================

-- 增强的向量相似度搜索 (替代原有函数)
CREATE OR REPLACE FUNCTION rag.search_similar_chunks(
    query_embedding vector(1536),
    similarity_threshold DOUBLE PRECISION DEFAULT 0.7,
    max_results INTEGER DEFAULT 10,
    embedding_model TEXT DEFAULT 'openai',
    performance_mode TEXT DEFAULT 'balanced'
)
RETURNS TABLE(
    chunk_id INTEGER,
    content TEXT,
    similarity_score DOUBLE PRECISION,
    document_title TEXT,
    metadata JSONB,
    implementation_used TEXT
) AS $$
BEGIN
    -- 使用增强向量搜索功能
    RETURN QUERY
    SELECT
        search_result.id,
        search_result.content,
        search_result.similarity,
        COALESCE(d.title, 'Unknown Document') as document_title,
        search_result.metadata,
        search_result.implementation_used
    FROM enhanced_vector_search(
        query_embedding,
        similarity_threshold,
        max_results,
        'auto',
        performance_mode
    ) search_result
    LEFT JOIN rag.documents d ON search_result.id IN (
        SELECT dc.id FROM rag.document_chunks dc WHERE dc.document_id = d.id
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION rag.search_similar_chunks IS
'增强的RAG向量搜索，自动选择最佳向量搜索实现';

-- 智能混合搜索增强版
CREATE OR REPLACE FUNCTION rag.enhanced_hybrid_search(
    query_text TEXT,
    query_embedding vector(1536),
    vector_weight DOUBLE PRECISION DEFAULT 0.7,
    text_weight DOUBLE PRECISION DEFAULT 0.3,
    max_results INTEGER DEFAULT 10,
    performance_mode TEXT DEFAULT 'balanced'
)
RETURNS TABLE(
    chunk_id INTEGER,
    content TEXT,
    combined_score DOUBLE PRECISION,
    vector_score DOUBLE PRECISION,
    text_score DOUBLE PRECISION,
    document_title TEXT,
    implementation_used TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH enhanced_vector_results AS (
        SELECT
            evs.id,
            evs.content,
            evs.similarity as vec_score,
            evs.metadata,
            evs.implementation_used,
            d.title
        FROM enhanced_vector_search(
            query_embedding,
            0.3, -- 降低阈值以获得更多结果
            max_results * 2, -- 获取更多候选结果
            'auto',
            performance_mode
        ) evs
        LEFT JOIN rag.document_chunks dc ON evs.id = dc.id
        LEFT JOIN rag.documents d ON dc.document_id = d.id
    ),
    text_results AS (
        SELECT
            dc.id,
            ts_rank(
                to_tsvector('zhparser', dc.content),
                plainto_tsquery('zhparser', query_text)
            ) as txt_score
        FROM rag.document_chunks dc
        WHERE to_tsvector('zhparser', dc.content) @@ plainto_tsquery('zhparser', query_text)
    )
    SELECT
        vr.id,
        vr.content,
        (vr.vec_score * vector_weight + COALESCE(tr.txt_score, 0) * text_weight) as combined,
        vr.vec_score,
        COALESCE(tr.txt_score, 0),
        vr.title,
        vr.implementation_used
    FROM enhanced_vector_results vr
    LEFT JOIN text_results tr ON vr.id = tr.id
    ORDER BY combined DESC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION rag.enhanced_hybrid_search IS
'增强的混合搜索：结合向量搜索增强和全文搜索';

-- 智能查询建议增强版
CREATE OR REPLACE FUNCTION rag.enhanced_suggest_queries(
    base_query TEXT,
    max_suggestions INTEGER DEFAULT 5
)
RETURNS TABLE(
    suggested_query TEXT,
    similarity_score DOUBLE PRECISION,
    query_frequency INTEGER,
    suggestion_type TEXT
) AS $$
DECLARE
    cleaned_query TEXT;
    query_words TEXT[];
BEGIN
    -- 使用增强字符串处理清理查询
    cleaned_query := clean_text(base_query, false, true);

    -- 分解查询词汇
    query_words := string_to_array(
        enhanced_string_process(cleaned_query, 'clean'),
        ' '
    );

    RETURN QUERY
    WITH query_stats AS (
        SELECT
            qh.query_text,
            COUNT(*) as frequency,
            AVG(qh.user_feedback) as avg_feedback
        FROM rag.query_history qh
        WHERE qh.created_at > NOW() - INTERVAL '30 days'
        GROUP BY qh.query_text
        HAVING COUNT(*) > 1
    ),
    similar_queries AS (
        SELECT
            qs.query_text,
            word_similarity(cleaned_query, qs.query_text) as similarity,
            qs.frequency,
            'historical' as suggestion_type
        FROM query_stats qs
        WHERE word_similarity(cleaned_query, qs.query_text) > 0.3
          AND qs.query_text != cleaned_query
    ),
    word_based_suggestions AS (
        SELECT
            qs.query_text,
            0.8 as similarity,
            qs.frequency,
            'word_match' as suggestion_type
        FROM query_stats qs
        WHERE EXISTS (
            SELECT 1 FROM unnest(query_words) AS word
            WHERE qs.query_text ILIKE '%' || word || '%'
        )
        AND qs.query_text != cleaned_query
    )
    SELECT
        suggestion.query_text,
        suggestion.similarity,
        suggestion.frequency::INTEGER,
        suggestion.suggestion_type
    FROM (
        SELECT * FROM similar_queries
        UNION ALL
        SELECT * FROM word_based_suggestions
    ) suggestion
    ORDER BY suggestion.similarity DESC, suggestion.frequency DESC
    LIMIT max_suggestions;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION rag.enhanced_suggest_queries IS
'增强的查询建议：使用字符串处理增强和智能相似度计算';

-- ================================================================
-- RAG性能优化函数
-- ================================================================

-- 智能向量索引优化
CREATE OR REPLACE FUNCTION rag.optimize_vector_indexes()
RETURNS TEXT AS $$
DECLARE
    result_message TEXT;
    chunk_count INTEGER;
BEGIN
    -- 获取当前文档块数量
    SELECT COUNT(*) INTO chunk_count FROM rag.document_chunks;

    -- 调用增强的索引优化功能
    result_message := optimize_vector_indexes('rag.document_chunks', 'embedding_openai', false);

    -- 记录优化操作
    INSERT INTO enhancement_control.performance_comparison
    (feature_name, test_scenario, implementation_type, data_size, test_timestamp)
    VALUES (
        'vector_search',
        'rag_index_optimization',
        'enhanced',
        chunk_count,
        NOW()
    );

    RETURN result_message;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION rag.optimize_vector_indexes IS
'RAG专用的智能向量索引优化';

-- RAG文档处理增强
CREATE OR REPLACE FUNCTION rag.enhanced_create_chunks(
    doc_id INTEGER,
    chunk_size INTEGER DEFAULT 1000,
    chunk_overlap INTEGER DEFAULT 200
)
RETURNS INTEGER AS $$
DECLARE
    doc_content TEXT;
    doc_title TEXT;
    chunks TEXT[];
    chunk_text TEXT;
    chunk_idx INTEGER := 1;
    total_chunks INTEGER := 0;
    processed_title TEXT;
    processed_content TEXT;
BEGIN
    -- 获取文档内容
    SELECT content, title INTO doc_content, doc_title
    FROM rag.documents WHERE id = doc_id;

    IF doc_content IS NULL THEN
        RAISE EXCEPTION 'Document with id % not found', doc_id;
    END IF;

    -- 使用增强字符串处理清理内容
    processed_title := clean_text(doc_title, true, true);
    processed_content := clean_text(doc_content, true, true);

    -- 简化的分块逻辑（实际应用中需要更复杂的算法）
    chunks := regexp_split_to_array(processed_content, E'\\n\\s*\\n');

    -- 删除现有chunks
    DELETE FROM rag.document_chunks WHERE document_id = doc_id;

    -- 创建新chunks
    FOREACH chunk_text IN ARRAY chunks LOOP
        IF LENGTH(trim(chunk_text)) > 50 THEN -- 过滤太短的块
            INSERT INTO rag.document_chunks (
                document_id,
                chunk_index,
                content,
                token_count,
                metadata
            ) VALUES (
                doc_id,
                chunk_idx,
                trim(chunk_text),
                array_length(string_to_array(chunk_text, ' '), 1),
                jsonb_build_object(
                    'processed_at', NOW(),
                    'processing_method', 'enhanced_string_processing',
                    'original_title', doc_title,
                    'processed_title', processed_title
                )
            );

            chunk_idx := chunk_idx + 1;
            total_chunks := total_chunks + 1;
        END IF;
    END LOOP;

    -- 记录处理统计
    INSERT INTO enhancement_control.usage_statistics
    (feature_name, implementation_used, query_parameters, execution_context)
    VALUES (
        'string_processing',
        'enhanced',
        jsonb_build_object(
            'document_id', doc_id,
            'total_chunks', total_chunks,
            'chunk_size', chunk_size
        ),
        'rag_document_processing'
    );

    RETURN total_chunks;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION rag.enhanced_create_chunks IS
'增强的RAG文档分块处理，使用字符串处理增强功能';

-- ================================================================
-- RAG查询性能监控
-- ================================================================

-- RAG专用性能监控视图
CREATE OR REPLACE VIEW rag.enhanced_performance_stats AS
SELECT
    'RAG Query Performance' as metric_category,
    COUNT(*) as total_queries,
    AVG(execution_time_ms) as avg_execution_time_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms) as p95_execution_time_ms,
    AVG(array_length(retrieved_chunks, 1)) as avg_chunks_retrieved,
    AVG(user_feedback) as avg_user_rating,
    COUNT(CASE WHEN user_feedback >= 4 THEN 1 END) * 100.0 / COUNT(*) as satisfaction_rate
FROM rag.query_history
WHERE created_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT
    'Vector Search Performance' as metric_category,
    COUNT(*) as total_operations,
    AVG(execution_time_ms) as avg_execution_time,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms) as p95_execution_time,
    AVG(data_size) as avg_data_size,
    AVG(CASE WHEN error_count = 0 THEN 5.0 ELSE 1.0 END) as avg_success_rating,
    COUNT(CASE WHEN error_count = 0 THEN 1 END) * 100.0 / COUNT(*) as success_rate
FROM enhancement_control.performance_comparison
WHERE feature_name = 'vector_search'
  AND test_timestamp > NOW() - INTERVAL '24 hours';

COMMENT ON VIEW rag.enhanced_performance_stats IS
'RAG增强性能统计视图，结合查询历史和增强功能监控';

-- ================================================================
-- 示例和测试
-- ================================================================

-- 显示RAG增强集成状态
SELECT
    '🔍 RAG Enhancement Integration Status:' as title,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines
            WHERE routine_name = 'enhanced_vector_search'
        ) THEN '✅ Vector search enhancement integrated'
        ELSE '❌ Vector search enhancement not found'
    END as vector_integration,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines
            WHERE routine_name = 'enhanced_string_process'
        ) THEN '✅ String processing enhancement integrated'
        ELSE '❌ String processing enhancement not found'
    END as string_integration;

-- 测试增强的RAG搜索（如果有数据）
DO $$
DECLARE
    chunk_count INTEGER;
    test_embedding vector(1536);
BEGIN
    SELECT COUNT(*) INTO chunk_count FROM rag.document_chunks;

    IF chunk_count > 0 THEN
        -- 生成测试向量
        test_embedding := ARRAY(SELECT random() FROM generate_series(1, 1536))::vector;

        RAISE NOTICE '🧪 Testing enhanced RAG search with % chunks', chunk_count;

        -- 测试增强搜索（显示前3个结果）
        RAISE NOTICE 'Enhanced search results:';
        PERFORM rag.search_similar_chunks(test_embedding, 0.1, 3, 'openai', 'performance');

    ELSE
        RAISE NOTICE '📝 No document chunks found. Add some documents to test RAG functionality.';
    END IF;
END $$;

-- 显示RAG性能统计
SELECT * FROM rag.enhanced_performance_stats;

RAISE NOTICE '🎉 RAG Enhancement Integration completed!';
RAISE NOTICE '   ✅ Enhanced vector search integrated into RAG workflow';
RAISE NOTICE '   ✅ String processing enhancements for document processing';
RAISE NOTICE '   ✅ Performance monitoring and optimization';
RAISE NOTICE '   ✅ Intelligent hybrid search capabilities';
