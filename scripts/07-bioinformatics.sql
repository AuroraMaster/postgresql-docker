-- ================================================================
-- PostgreSQL 生物信息学扩展模块 (Bioinformatics Extensions)
-- 专业生物序列分析、基因组学、蛋白质组学扩展集合
-- ================================================================

\echo '=================================================='
\echo 'Loading Bioinformatics Extensions...'
\echo '生物信息学、基因组学、蛋白质组学扩展'
\echo '=================================================='

-- ================================================================
-- 基础扩展 (Core Extensions)
-- ================================================================

-- 文本处理和模式匹配
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- 序列相似性搜索
\echo 'Created extension: pg_trgm (序列相似性搜索)'

-- 数组处理用于序列数据
CREATE EXTENSION IF NOT EXISTS intarray;  -- 整数数组操作
\echo 'Created extension: intarray (序列数组操作)'

-- 高精度数值计算
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- 支持复杂数据类型索引
\echo 'Created extension: btree_gist (复杂数据类型索引)'

-- UUID生成用于生物样本标识
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
\echo 'Created extension: uuid-ossp (生物样本唯一标识)'

-- 加密函数用于基因数据保护
CREATE EXTENSION IF NOT EXISTS pgcrypto;
\echo 'Created extension: pgcrypto (基因数据加密保护)'

-- HStore用于生物注释元数据
-- CREATE EXTENSION IF NOT EXISTS hstore; -- 已在01-core-extensions.sql中声明
\echo 'Created extension: hstore (生物注释元数据存储)'

-- ================================================================
-- 生物数据类型定义 (Biological Data Types)
-- ================================================================

-- 创建DNA序列类型
DO $$
BEGIN
    -- DNA序列类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dna_sequence') THEN
        CREATE DOMAIN dna_sequence AS TEXT CHECK (VALUE ~ '^[ATCG]*$');
        COMMENT ON DOMAIN dna_sequence IS 'DNA序列类型 (仅包含A,T,C,G)';
    END IF;

    -- RNA序列类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rna_sequence') THEN
        CREATE DOMAIN rna_sequence AS TEXT CHECK (VALUE ~ '^[AUCG]*$');
        COMMENT ON DOMAIN rna_sequence IS 'RNA序列类型 (仅包含A,U,C,G)';
    END IF;

    -- 蛋白质序列类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'protein_sequence') THEN
        CREATE DOMAIN protein_sequence AS TEXT CHECK (VALUE ~ '^[ACDEFGHIKLMNPQRSTVWY]*$');
        COMMENT ON DOMAIN protein_sequence IS '蛋白质序列类型 (标准20种氨基酸)';
    END IF;

    -- 质量分数类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quality_score') THEN
        CREATE DOMAIN quality_score AS INTEGER CHECK (VALUE >= 0 AND VALUE <= 93);
        COMMENT ON DOMAIN quality_score IS '测序质量分数类型 (Phred质量分数0-93)';
    END IF;
END
$$;

\echo 'Created biological data domains: dna_sequence, rna_sequence, protein_sequence, quality_score'

-- ================================================================
-- 序列分析函数 (Sequence Analysis Functions)
-- ================================================================

-- DNA序列互补函数
CREATE OR REPLACE FUNCTION dna_complement(seq dna_sequence)
RETURNS dna_sequence AS $$
BEGIN
    RETURN translate(seq, 'ATCG', 'TAGC');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION dna_complement(dna_sequence) IS 'DNA序列互补函数';

-- DNA序列反向互补函数
CREATE OR REPLACE FUNCTION dna_reverse_complement(seq dna_sequence)
RETURNS dna_sequence AS $$
BEGIN
    RETURN reverse(translate(seq, 'ATCG', 'TAGC'));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION dna_reverse_complement(dna_sequence) IS 'DNA序列反向互补函数';

-- DNA转录为RNA函数
CREATE OR REPLACE FUNCTION dna_transcribe(seq dna_sequence)
RETURNS rna_sequence AS $$
BEGIN
    RETURN translate(seq, 'T', 'U')::rna_sequence;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION dna_transcribe(dna_sequence) IS 'DNA转录为RNA函数';

-- GC含量计算函数
CREATE OR REPLACE FUNCTION gc_content(seq TEXT)
RETURNS NUMERIC AS $$
DECLARE
    gc_count INTEGER;
    total_count INTEGER;
BEGIN
    gc_count := length(seq) - length(translate(seq, 'GC', ''));
    total_count := length(seq);

    IF total_count = 0 THEN
        RETURN 0;
    END IF;

    RETURN ROUND((gc_count::NUMERIC / total_count) * 100, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION gc_content(TEXT) IS 'GC含量计算函数 (返回百分比)';

-- 序列长度统计函数
CREATE OR REPLACE FUNCTION sequence_stats(seq TEXT)
RETURNS TABLE(
    length INTEGER,
    gc_content NUMERIC,
    a_count INTEGER,
    t_count INTEGER,
    c_count INTEGER,
    g_count INTEGER
) AS $$
BEGIN
    RETURN QUERY SELECT
        length(seq) as length,
        gc_content(seq) as gc_content,
        length(seq) - length(translate(seq, 'A', '')) as a_count,
        length(seq) - length(translate(seq, 'T', '')) as t_count,
        length(seq) - length(translate(seq, 'C', '')) as c_count,
        length(seq) - length(translate(seq, 'G', '')) as g_count;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION sequence_stats(TEXT) IS '序列统计分析函数';

-- ================================================================
-- 基因组学函数 (Genomics Functions)
-- ================================================================

-- 开放阅读框查找函数
CREATE OR REPLACE FUNCTION find_orfs(seq dna_sequence, min_length INTEGER DEFAULT 100)
RETURNS TABLE(
    start_pos INTEGER,
    end_pos INTEGER,
    length INTEGER,
    frame INTEGER,
    sequence TEXT
) AS $$
DECLARE
    i INTEGER;
    frame_num INTEGER;
    current_seq TEXT;
    orf_start INTEGER;
    orf_end INTEGER;
BEGIN
    -- 检查三个阅读框
    FOR frame_num IN 1..3 LOOP
        current_seq := substring(seq FROM frame_num);
        orf_start := 1;

        -- 查找起始密码子ATG
        FOR i IN 1..length(current_seq)-2 BY 3 LOOP
            IF substring(current_seq FROM i FOR 3) = 'ATG' THEN
                orf_start := i;

                -- 查找终止密码子
                FOR orf_end IN orf_start+3..length(current_seq)-2 BY 3 LOOP
                    IF substring(current_seq FROM orf_end FOR 3) IN ('TAA', 'TAG', 'TGA') THEN
                        IF orf_end - orf_start + 3 >= min_length THEN
                            RETURN QUERY SELECT
                                orf_start + frame_num - 1 as start_pos,
                                orf_end + frame_num + 1 as end_pos,
                                orf_end - orf_start + 3 as length,
                                frame_num as frame,
                                substring(current_seq FROM orf_start FOR orf_end - orf_start + 3) as sequence;
                        END IF;
                        EXIT;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION find_orfs(dna_sequence, INTEGER) IS '开放阅读框查找函数';

-- 密码子使用频率分析
CREATE OR REPLACE FUNCTION codon_usage(seq dna_sequence)
RETURNS TABLE(
    codon TEXT,
    count INTEGER,
    frequency NUMERIC
) AS $$
DECLARE
    total_codons INTEGER;
    i INTEGER;
    current_codon TEXT;
BEGIN
    total_codons := length(seq) / 3;

    -- 创建临时表存储密码子计数
    CREATE TEMP TABLE IF NOT EXISTS temp_codon_counts (
        codon TEXT,
        count INTEGER DEFAULT 0
    );

    -- 统计密码子
    FOR i IN 1..length(seq)-2 BY 3 LOOP
        current_codon := substring(seq FROM i FOR 3);

        INSERT INTO temp_codon_counts (codon, count)
        VALUES (current_codon, 1)
        ON CONFLICT (codon) DO UPDATE SET count = temp_codon_counts.count + 1;
    END LOOP;

    -- 返回结果
    RETURN QUERY
    SELECT
        t.codon,
        t.count,
        ROUND((t.count::NUMERIC / total_codons) * 100, 2) as frequency
    FROM temp_codon_counts t
    ORDER BY t.count DESC;

    DROP TABLE temp_codon_counts;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION codon_usage(dna_sequence) IS '密码子使用频率分析函数';

-- ================================================================
-- 序列比对和相似性 (Sequence Alignment & Similarity)
-- ================================================================

-- 简单的汉明距离计算
CREATE OR REPLACE FUNCTION hamming_distance(seq1 TEXT, seq2 TEXT)
RETURNS INTEGER AS $$
DECLARE
    distance INTEGER := 0;
    i INTEGER;
BEGIN
    IF length(seq1) != length(seq2) THEN
        RETURN -1;  -- 长度不同返回-1
    END IF;

    FOR i IN 1..length(seq1) LOOP
        IF substring(seq1 FROM i FOR 1) != substring(seq2 FROM i FOR 1) THEN
            distance := distance + 1;
        END IF;
    END LOOP;

    RETURN distance;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION hamming_distance(TEXT, TEXT) IS '汉明距离计算函数';

-- 序列相似度百分比
CREATE OR REPLACE FUNCTION sequence_similarity(seq1 TEXT, seq2 TEXT)
RETURNS NUMERIC AS $$
DECLARE
    distance INTEGER;
    max_length INTEGER;
BEGIN
    max_length := GREATEST(length(seq1), length(seq2));

    IF max_length = 0 THEN
        RETURN 100.0;
    END IF;

    distance := hamming_distance(seq1, seq2);

    IF distance = -1 THEN
        -- 长度不同，使用编辑距离的简化版本
        RETURN ROUND((1.0 - ABS(length(seq1) - length(seq2))::NUMERIC / max_length) * 100, 2);
    ELSE
        RETURN ROUND((1.0 - distance::NUMERIC / max_length) * 100, 2);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION sequence_similarity(TEXT, TEXT) IS '序列相似度百分比计算';

-- ================================================================
-- 扩展模块加载完成
-- ================================================================

\echo '=================================================='
\echo 'Bioinformatics Extensions loaded successfully!'
\echo '生物信息学扩展模块加载完成'
\echo ''
\echo 'Available capabilities:'
\echo '- DNA/RNA/蛋白质序列类型 (Biological sequence data types)'
\echo '- 序列分析函数 (Sequence analysis functions)'
\echo '- GC含量计算 (GC content calculation)'
\echo '- 开放阅读框查找 (ORF finding)'
\echo '- 密码子使用分析 (Codon usage analysis)'
\echo '- 序列比对和相似性 (Sequence alignment & similarity)'
\echo '- 基因数据加密保护 (Genetic data encryption)'
\echo '=================================================='
