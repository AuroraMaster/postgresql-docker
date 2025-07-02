-- ================================================================
-- 16-vector-enhancement.sql
-- 向量搜索性能增强：在原有pgvector基础上添加Rust高性能版本
-- 智能选择最佳实现，保持完全兼容性
-- ================================================================

-- ================================================================
-- 检查和准备Rust增强扩展
-- ================================================================

-- 检查pgvecto.rs (Rust高性能向量扩展)
DO $$
DECLARE
    vectors_available BOOLEAN := false;
    vectorscale_available BOOLEAN := false;
BEGIN
    -- 检查pgvecto.rs (vectors扩展)
    SELECT COUNT(*) > 0 INTO vectors_available
    FROM pg_available_extensions
    WHERE name = 'vectors';

    -- 检查pgvectorscale扩展
    SELECT COUNT(*) > 0 INTO vectorscale_available
    FROM pg_available_extensions
    WHERE name = 'vectorscale';

    IF vectors_available THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS vectors;
            RAISE NOTICE '✅ Rust pgvecto.rs (vectors) installed successfully';

            -- 更新增强控制状态
            UPDATE enhancement_control.feature_enhancements
            SET enhancement_status = 'active',
                last_updated = NOW()
            WHERE feature_name = 'vector_search';

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '⚠️  pgvecto.rs available but installation failed: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '📝 pgvecto.rs not available, using original pgvector only';
    END IF;

    IF vectorscale_available THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS vectorscale;
            RAISE NOTICE '✅ pgvectorscale installed for performance scaling';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '⚠️  pgvectorscale available but installation failed: %', SQLERRM;
        END;
    END IF;
END $$;
