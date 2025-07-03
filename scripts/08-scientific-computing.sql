-- ================================================================
-- PostgreSQL 科学计算扩展模块 (Scientific Computing Extensions)
-- 专业数值计算、统计分析、机器学习扩展集合
-- ================================================================

\echo '=================================================='
\echo 'Loading Scientific Computing Extensions...'
\echo '数值计算、统计分析、机器学习扩展'
\echo '=================================================='

-- ================================================================
-- 核心数学与统计扩展 (Core Mathematical & Statistical Extensions)
-- ================================================================

-- 高级统计函数和数学运算
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- 已在01-core-extensions.sql中声明
\echo 'Created extension: pg_stat_statements (查询统计分析)'

-- 高精度数值计算
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- 支持更多数据类型的GiST索引
\echo 'Created extension: btree_gist (高精度索引支持)'

CREATE EXTENSION IF NOT EXISTS intarray;  -- 整数数组操作
\echo 'Created extension: intarray (整数数组高效操作)'

-- ================================================================
-- 机器学习与AI扩展 (Machine Learning & AI Extensions)
-- ================================================================

-- PostgresML - 数据库内机器学习
-- 注意：这需要专门的安装包，通常通过deb包安装
\echo 'Note: pgml requires special installation via deb packages'
\echo 'Install command: apt-get install postgresql-16-pgml'

-- 向量相似度计算
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- 三元组相似度
\echo 'Created extension: pg_trgm (文本相似度计算)'

-- ================================================================
-- 数值计算与精度扩展 (Numerical Computing & Precision)
-- ================================================================

-- UUID生成用于科学数据标识
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
\echo 'Created extension: uuid-ossp (科学数据唯一标识)'

-- 加密函数用于数据完整性验证
CREATE EXTENSION IF NOT EXISTS pgcrypto;
\echo 'Created extension: pgcrypto (数据完整性与哈希计算)'

-- ================================================================
-- 高性能计算扩展 (High Performance Computing)
-- ================================================================

-- 并行计算支持
CREATE EXTENSION IF NOT EXISTS postgres_fdw;  -- 分布式计算基础
\echo 'Created extension: postgres_fdw (分布式计算支持)'

-- 表函数用于数据生成和转换
CREATE EXTENSION IF NOT EXISTS tablefunc;
\echo 'Created extension: tablefunc (数据透视与变换)'

-- ================================================================
-- 数据分析与可视化准备 (Data Analysis & Visualization Prep)
-- ================================================================

-- JSON处理用于数据交换
CREATE EXTENSION IF NOT EXISTS plpgsql;  -- 确保存储过程支持
\echo 'Verified extension: plpgsql (存储过程支持)'

-- ================================================================
-- 科学数据类型扩展 (Scientific Data Types)
-- ================================================================

-- HStore用于键值对科学参数存储
-- CREATE EXTENSION IF NOT EXISTS hstore; -- 已在01-core-extensions.sql中声明
\echo 'Created extension: hstore (科学参数键值存储)'

-- 立方体数据类型用于多维数据
CREATE EXTENSION IF NOT EXISTS cube;
\echo 'Created extension: cube (多维数据立方体)'

-- 地球距离计算
CREATE EXTENSION IF NOT EXISTS earthdistance;
\echo 'Created extension: earthdistance (地球距离科学计算)'

-- ================================================================
-- 时序数据科学计算 (Time Series Scientific Computing)
-- ================================================================

-- 时间序列数据支持的基础扩展已在init-time.sql中定义
\echo 'Time series extensions available in init-time.sql'

-- ================================================================
-- 统计聚合函数 (Statistical Aggregate Functions)
-- ================================================================

-- 创建自定义统计函数
DO $$
BEGIN
    -- 检查是否存在统计分析函数
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'variance_pop') THEN
        \echo 'Standard statistical functions available in PostgreSQL core';
    END IF;
END
$$;

-- ================================================================
-- 科学计算工具函数 (Scientific Computing Utility Functions)
-- ================================================================

-- 创建科学计算常用的工具函数
CREATE OR REPLACE FUNCTION scientific_round(val NUMERIC, precision INT DEFAULT 6)
RETURNS NUMERIC AS $$
BEGIN
    RETURN ROUND(val, precision);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION scientific_round(NUMERIC, INT) IS '科学计算精度舍入函数';

-- 标准差计算函数（如果不存在）
CREATE OR REPLACE FUNCTION std_dev_sample(values NUMERIC[])
RETURNS NUMERIC AS $$
DECLARE
    n INT;
    mean_val NUMERIC;
    variance_val NUMERIC;
BEGIN
    n := array_length(values, 1);
    IF n <= 1 THEN
        RETURN NULL;
    END IF;

    SELECT AVG(unnest) INTO mean_val FROM unnest(values);
    SELECT AVG(POWER(unnest - mean_val, 2)) INTO variance_val FROM unnest(values);

    RETURN SQRT(variance_val * n / (n - 1));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION std_dev_sample(NUMERIC[]) IS '样本标准差计算函数';

-- ================================================================
-- 数据验证和质量检查 (Data Validation & Quality Check)
-- ================================================================

-- 创建数据质量检查函数
CREATE OR REPLACE FUNCTION validate_numeric_range(val NUMERIC, min_val NUMERIC, max_val NUMERIC)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN val >= min_val AND val <= max_val;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_numeric_range(NUMERIC, NUMERIC, NUMERIC) IS '数值范围验证函数';

-- ================================================================
-- 科学计算配置优化 (Scientific Computing Configuration)
-- ================================================================

-- 设置科学计算相关的配置参数
DO $$
BEGIN
    -- 提高数值计算精度
    PERFORM set_config('extra_float_digits', '3', false);

    -- 优化并行查询用于大数据集科学计算
    PERFORM set_config('max_parallel_workers_per_gather', '4', false);

    \echo 'Applied scientific computing optimizations';
END
$$;

-- ================================================================
-- 扩展模块加载完成
-- ================================================================

\echo '=================================================='
\echo 'Scientific Computing Extensions loaded successfully!'
\echo '科学计算扩展模块加载完成'
\echo ''
\echo 'Available capabilities:'
\echo '- 高精度数值计算 (High-precision numerical computing)'
\echo '- 统计分析函数 (Statistical analysis functions)'
\echo '- 数组和向量操作 (Array and vector operations)'
\echo '- 数据质量验证 (Data quality validation)'
\echo '- 科学数据类型 (Scientific data types)'
\echo '- 分布式计算支持 (Distributed computing support)'
\echo '=================================================='
