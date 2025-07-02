-- ================================================================
-- 20-sequence-enhancement.sql
-- 生物序列分析增强：SIMD优化的高性能计算
-- 在原有SQL基础上添加Rust高性能实现
-- ================================================================

-- ================================================================
-- 检查和准备Rust增强扩展
-- ================================================================

-- 检查bio_postgres (Rust生物序列处理扩展)
DO $$
DECLARE
    bio_postgres_available BOOLEAN := false;
BEGIN
    -- 检查bio_postgres扩展是否可用
    SELECT COUNT(*) > 0 INTO bio_postgres_available
    FROM pg_available_extensions
    WHERE name = 'bio_postgres';

    IF bio_postgres_available THEN
        BEGIN
            CREATE EXTENSION IF NOT EXISTS bio_postgres;
            RAISE NOTICE '✅ Rust bio_postgres extension installed successfully';

            -- 更新增强控制状态
            UPDATE enhancement_control.feature_enhancements
            SET enhancement_status = 'active',
                last_updated = NOW()
            WHERE feature_name = 'sequence_analysis';

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '⚠️  bio_postgres available but installation failed: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '📝 bio_postgres not available, using SQL sequence functions only';
    END IF;
END $$;
