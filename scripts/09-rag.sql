-- PostgreSQL RAG和全文搜索功能初始化
-- ==========================================

-- 启用向量扩展
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vchord;

-- 启用相似度计算扩展
CREATE EXTENSION IF NOT EXISTS pg_similarity;
CREATE EXTENSION IF NOT EXISTS smlar;

-- 启用全文搜索扩展
CREATE EXTENSION IF NOT EXISTS pg_search;
CREATE EXTENSION IF NOT EXISTS zhparser;

-- 创建RAG工作架构
CREATE SCHEMA IF NOT EXISTS rag;

-- ===========================================
-- 1. 文档存储表
-- ===========================================

-- 原始文档表
CREATE TABLE IF NOT EXISTS rag.documents (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    source_type TEXT, -- pdf, txt, web, api等
    source_url TEXT,
    language TEXT DEFAULT 'zh',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- 全文搜索向量
    content_tsvector TSVECTOR,
    -- 文档摘要
    summary TEXT
);

-- 文档分块表 (用于RAG)
CREATE TABLE IF NOT EXISTS rag.document_chunks (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES rag.documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL, -- 在原文档中的顺序
    content TEXT NOT NULL,
    token_count INTEGER,
    -- 向量embeddings (OpenAI: 1536维, BGE: 768维等)
    embedding_openai vector(1536),
    embedding_bge vector(768),
    embedding_custom vector(512),
    -- 元数据
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 查询历史表
CREATE TABLE IF NOT EXISTS rag.query_history (
    id SERIAL PRIMARY KEY,
    query_text TEXT NOT NULL,
    query_embedding vector(1536),
    response_text TEXT,
    retrieved_chunks INTEGER[],
    similarity_scores DOUBLE PRECISION[],
    model_used TEXT,
    execution_time_ms INTEGER,
    user_feedback INTEGER CHECK (user_feedback BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 知识图谱节点表
CREATE TABLE IF NOT EXISTS rag.knowledge_nodes (
    id SERIAL PRIMARY KEY,
    entity_name TEXT NOT NULL,
    entity_type TEXT, -- person, place, concept, etc.
    description TEXT,
    properties JSONB DEFAULT '{}',
    embedding vector(768),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 知识图谱关系表
CREATE TABLE IF NOT EXISTS rag.knowledge_edges (
    id SERIAL PRIMARY KEY,
    source_node_id INTEGER REFERENCES rag.knowledge_nodes(id),
    target_node_id INTEGER REFERENCES rag.knowledge_nodes(id),
    relationship_type TEXT NOT NULL,
    weight DOUBLE PRECISION DEFAULT 1.0,
    properties JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. 索引优化
-- ===========================================

-- 向量相似度索引 (IVFFlat for large datasets)
CREATE INDEX IF NOT EXISTS idx_chunks_embedding_openai ON rag.document_chunks
USING ivfflat (embedding_openai vector_cosine_ops) WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_chunks_embedding_bge ON rag.document_chunks
USING ivfflat (embedding_bge vector_cosine_ops) WITH (lists = 100);

-- HNSW索引 (更好的查询性能)
CREATE INDEX IF NOT EXISTS idx_chunks_embedding_hnsw ON rag.document_chunks
USING hnsw (embedding_openai vector_cosine_ops) WITH (m = 16, ef_construction = 64);

-- 全文搜索索引
CREATE INDEX IF NOT EXISTS idx_documents_content_gin ON rag.documents USING GIN (content_tsvector);
CREATE INDEX IF NOT EXISTS idx_documents_title_gin ON rag.documents USING GIN (to_tsvector('zhparser', title));

-- 常规索引
CREATE INDEX IF NOT EXISTS idx_chunks_document_id ON rag.document_chunks (document_id);
CREATE INDEX IF NOT EXISTS idx_query_history_created_at ON rag.query_history (created_at);
CREATE INDEX IF NOT EXISTS idx_documents_source_type ON rag.documents (source_type);
CREATE INDEX IF NOT EXISTS idx_documents_language ON rag.documents (language);

-- ===========================================
-- 3. RAG核心函数
-- ===========================================

-- 向量相似度搜索
CREATE OR REPLACE FUNCTION rag.search_similar_chunks(
    query_embedding vector(1536),
    similarity_threshold DOUBLE PRECISION DEFAULT 0.7,
    max_results INTEGER DEFAULT 10,
    embedding_model TEXT DEFAULT 'openai'
)
RETURNS TABLE(
    chunk_id INTEGER,
    content TEXT,
    similarity_score DOUBLE PRECISION,
    document_title TEXT,
    metadata JSONB
) AS $$
BEGIN
    IF embedding_model = 'openai' THEN
        RETURN QUERY
        SELECT
            dc.id,
            dc.content,
            1 - (dc.embedding_openai <=> query_embedding) as similarity,
            d.title,
            dc.metadata
        FROM rag.document_chunks dc
        JOIN rag.documents d ON dc.document_id = d.id
        WHERE dc.embedding_openai IS NOT NULL
          AND 1 - (dc.embedding_openai <=> query_embedding) >= similarity_threshold
        ORDER BY similarity DESC
        LIMIT max_results;
    ELSIF embedding_model = 'bge' THEN
        RETURN QUERY
        SELECT
            dc.id,
            dc.content,
            1 - (dc.embedding_bge <=> query_embedding::vector(768)) as similarity,
            d.title,
            dc.metadata
        FROM rag.document_chunks dc
        JOIN rag.documents d ON dc.document_id = d.id
        WHERE dc.embedding_bge IS NOT NULL
          AND 1 - (dc.embedding_bge <=> query_embedding::vector(768)) >= similarity_threshold
        ORDER BY similarity DESC
        LIMIT max_results;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 混合搜索 (向量 + 全文搜索)
CREATE OR REPLACE FUNCTION rag.hybrid_search(
    query_text TEXT,
    query_embedding vector(1536),
    vector_weight DOUBLE PRECISION DEFAULT 0.7,
    text_weight DOUBLE PRECISION DEFAULT 0.3,
    max_results INTEGER DEFAULT 10
)
RETURNS TABLE(
    chunk_id INTEGER,
    content TEXT,
    combined_score DOUBLE PRECISION,
    vector_score DOUBLE PRECISION,
    text_score DOUBLE PRECISION,
    document_title TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH vector_results AS (
        SELECT
            dc.id,
            dc.content,
            1 - (dc.embedding_openai <=> query_embedding) as vec_score,
            d.title
        FROM rag.document_chunks dc
        JOIN rag.documents d ON dc.document_id = d.id
        WHERE dc.embedding_openai IS NOT NULL
    ),
    text_results AS (
        SELECT
            dc.id,
            ts_rank(to_tsvector('zhparser', dc.content), plainto_tsquery('zhparser', query_text)) as txt_score
        FROM rag.document_chunks dc
        WHERE to_tsvector('zhparser', dc.content) @@ plainto_tsquery('zhparser', query_text)
    )
    SELECT
        vr.id,
        vr.content,
        (vector_weight * COALESCE(vr.vec_score, 0) + text_weight * COALESCE(tr.txt_score, 0)) as combined,
        vr.vec_score,
        tr.txt_score,
        vr.title
    FROM vector_results vr
    FULL OUTER JOIN text_results tr ON vr.id = tr.id
    WHERE (vr.vec_score IS NOT NULL OR tr.txt_score IS NOT NULL)
    ORDER BY combined DESC
    LIMIT max_results;
END;
$$ LANGUAGE plpgsql;

-- 智能文档分块
CREATE OR REPLACE FUNCTION rag.create_chunks(
    doc_id INTEGER,
    chunk_size INTEGER DEFAULT 500,
    overlap_size INTEGER DEFAULT 50
)
RETURNS INTEGER AS $$
DECLARE
    doc_content TEXT;
    chunk_text TEXT;
    chunk_start INTEGER := 1;
    chunk_end INTEGER;
    chunk_idx INTEGER := 0;
    total_chunks INTEGER := 0;
BEGIN
    -- 获取文档内容
    SELECT content INTO doc_content FROM rag.documents WHERE id = doc_id;

    IF doc_content IS NULL THEN
        RETURN 0;
    END IF;

    -- 删除现有分块
    DELETE FROM rag.document_chunks WHERE document_id = doc_id;

    -- 创建分块
    WHILE chunk_start <= LENGTH(doc_content) LOOP
        chunk_end := LEAST(chunk_start + chunk_size - 1, LENGTH(doc_content));
        chunk_text := SUBSTRING(doc_content FROM chunk_start FOR chunk_size);

        INSERT INTO rag.document_chunks (document_id, chunk_index, content, token_count)
        VALUES (doc_id, chunk_idx, chunk_text, LENGTH(SPLIT_PART(chunk_text, ' ', -1)));

        chunk_idx := chunk_idx + 1;
        total_chunks := total_chunks + 1;
        chunk_start := chunk_end - overlap_size + 1;
    END LOOP;

    RETURN total_chunks;
END;
$$ LANGUAGE plpgsql;

-- 查询建议 (基于历史查询)
CREATE OR REPLACE FUNCTION rag.suggest_queries(
    partial_query TEXT,
    max_suggestions INTEGER DEFAULT 5
)
RETURNS TABLE(
    suggested_query TEXT,
    usage_count BIGINT,
    avg_feedback DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        qh.query_text,
        COUNT(*) as usage_count,
        AVG(qh.user_feedback) as avg_feedback
    FROM rag.query_history qh
    WHERE qh.query_text ILIKE '%' || partial_query || '%'
      AND qh.user_feedback IS NOT NULL
    GROUP BY qh.query_text
    HAVING COUNT(*) > 1
    ORDER BY usage_count DESC, avg_feedback DESC
    LIMIT max_suggestions;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 4. 触发器和自动化
-- ===========================================

-- 自动更新文档的全文搜索向量
CREATE OR REPLACE FUNCTION rag.update_document_tsvector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.content_tsvector := to_tsvector('zhparser', COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.content, ''));
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_tsvector_trigger
    BEFORE INSERT OR UPDATE ON rag.documents
    FOR EACH ROW EXECUTE FUNCTION rag.update_document_tsvector();

-- ===========================================
-- 5. 示例数据和使用案例
-- ===========================================

-- 插入示例文档
INSERT INTO rag.documents (title, content, source_type, language) VALUES
('机器学习基础', '机器学习是人工智能的一个分支，它使用算法和统计模型来让计算机系统在没有明确编程的情况下学习和改进。', 'manual', 'zh'),
('深度学习概述', '深度学习是机器学习的一个子集，它使用多层神经网络来模拟人脑的工作方式。', 'manual', 'zh'),
('自然语言处理', 'NLP是计算机科学和人工智能的一个分支，专注于计算机和人类语言之间的交互。', 'manual', 'zh')
ON CONFLICT DO NOTHING;

-- 为示例文档创建分块
SELECT rag.create_chunks(id) FROM rag.documents WHERE source_type = 'manual';

-- ===========================================
-- 6. 性能监控视图
-- ===========================================

-- RAG性能监控视图
CREATE OR REPLACE VIEW rag.performance_stats AS
SELECT
    COUNT(*) as total_documents,
    COUNT(DISTINCT language) as languages_count,
    AVG(LENGTH(content)) as avg_document_length,
    (SELECT COUNT(*) FROM rag.document_chunks) as total_chunks,
    (SELECT AVG(token_count) FROM rag.document_chunks) as avg_chunk_tokens,
    (SELECT COUNT(*) FROM rag.query_history) as total_queries,
    (SELECT AVG(execution_time_ms) FROM rag.query_history WHERE execution_time_ms IS NOT NULL) as avg_query_time_ms,
    (SELECT AVG(user_feedback) FROM rag.query_history WHERE user_feedback IS NOT NULL) as avg_user_satisfaction
FROM rag.documents;

-- ===========================================
-- 7. 权限设置
-- ===========================================

-- 创建RAG用户角色
CREATE ROLE IF NOT EXISTS rag_user;
GRANT USAGE ON SCHEMA rag TO rag_user;
GRANT SELECT, INSERT ON rag.query_history TO rag_user;
GRANT SELECT ON rag.documents, rag.document_chunks TO rag_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rag TO rag_user;

-- 创建RAG管理员角色
CREATE ROLE IF NOT EXISTS rag_admin;
GRANT USAGE ON SCHEMA rag TO rag_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA rag TO rag_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA rag TO rag_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rag TO rag_admin;

-- 输出配置完成信息
\echo '✅ RAG和全文搜索功能配置完成!'
\echo '📋 可用功能:'
\echo '   - 向量相似度搜索 (pgvector + vchord)'
\echo '   - 中文全文搜索 (zhparser)'
\echo '   - 混合搜索 (向量+文本)'
\echo '   - 智能文档分块'
\echo '   - 查询历史和建议'
\echo '   - 知识图谱支持'
\echo ''
\echo '🔍 使用示例:'
\echo '   -- 相似度搜索:'
\echo '   SELECT * FROM rag.search_similar_chunks(''[0.1,0.2,...]''::vector(1536));'
\echo ''
\echo '   -- 混合搜索:'
\echo '   SELECT * FROM rag.hybrid_search(''机器学习'', ''[0.1,0.2,...]''::vector(1536));'
\echo ''
\echo '   -- 创建文档分块:'
\echo '   SELECT rag.create_chunks(1, 500, 50);'
