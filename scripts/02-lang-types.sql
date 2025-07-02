-- ================================================================
-- PostgreSQL 语言和类型扩展模块 (Language & Types Extensions) - 整合版
-- 合并了 init-lang-types.sql, init-lang-types-part1.sql, init-lang-types-part2.sql
-- 基于 Pigsty 扩展生态分类: https://pigsty.cc/ext/
-- 包含 LANG类(编程语言) 和 TYPE类(数据类型) 扩展
-- ================================================================

\echo '=================================================='
\echo 'Loading Language & Types Extensions (Consolidated)...'
\echo '语言和类型扩展模块加载中 (整合版)...'
\echo '=================================================='

-- 创建专用schema
CREATE SCHEMA IF NOT EXISTS lang;
CREATE SCHEMA IF NOT EXISTS types;

-- ================================================================
-- LANG类 - 编程语言扩展 (Programming Language Extensions)
-- ================================================================

\echo 'Loading programming language extensions...'

-- PL/pgSQL (默认已安装，确保启用)
CREATE EXTENSION IF NOT EXISTS plpgsql;  -- 确保存储过程支持

-- Python语言支持
-- 注意：需要先安装python3-postgresql-plpython3u包
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'plpython3u') THEN
        CREATE EXTENSION IF NOT EXISTS plpython3u;
        RAISE NOTICE 'PL/Python3U extension loaded successfully';
    ELSE
        RAISE NOTICE 'PL/Python3U extension not available - install python3-postgresql-plpython3u package';
    END IF;
END
$$;

-- Perl语言支持
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'plperl') THEN
        CREATE EXTENSION IF NOT EXISTS plperl;
        RAISE NOTICE 'PL/Perl extension loaded successfully';
    ELSE
        RAISE NOTICE 'PL/Perl extension not available - install postgresql-plperl package';
    END IF;
END
$$;

-- R语言支持 (统计分析)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'plr') THEN
        CREATE EXTENSION IF NOT EXISTS plr;
        RAISE NOTICE 'PL/R extension loaded successfully';
    ELSE
        RAISE NOTICE 'PL/R extension not available - install postgresql-plr package';
    END IF;
END
$$;

-- TCL语言支持
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pltcl') THEN
        CREATE EXTENSION IF NOT EXISTS pltcl;
        RAISE NOTICE 'PL/TCL extension loaded successfully';
    ELSE
        RAISE NOTICE 'PL/TCL extension not available - install postgresql-pltcl package';
    END IF;
END
$$;

-- ================================================================
-- TYPE类 - 数据类型扩展 (Data Type Extensions)
-- ================================================================

\echo 'Loading data type extensions...'

-- 基础数据类型扩展 (已在01-core-extensions.sql中声明)
-- hstore, citext, ltree, cube, earthdistance, isn, seg 等已在核心扩展中加载

-- UUID生成 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- 已在核心扩展中加载

-- 加密相关 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS pgcrypto; -- 已在核心扩展中加载

-- 国际化 (已在01-core-extensions.sql中声明)
-- CREATE EXTENSION IF NOT EXISTS unaccent; -- 已在核心扩展中加载

-- 数值和科学计算 (已在01-core-extensions.sql中声明)
-- cube, earthdistance 已在核心扩展中加载

-- 高级数据类型 (已在01-core-extensions.sql中声明)
-- isn, seg 已在核心扩展中加载

-- JSON增强
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'jsquery') THEN
        CREATE EXTENSION IF NOT EXISTS jsquery;
        RAISE NOTICE 'jsquery extension loaded successfully';
    ELSE
        RAISE NOTICE 'jsquery extension not available';
    END IF;
END
$$;

-- IP地址类型增强
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'ip4r') THEN
        CREATE EXTENSION IF NOT EXISTS ip4r;
        RAISE NOTICE 'ip4r extension loaded successfully';
    ELSE
        RAISE NOTICE 'ip4r extension not available';
    END IF;
END
$$;

-- 版本比较
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'semver') THEN
        CREATE EXTENSION IF NOT EXISTS semver;
        RAISE NOTICE 'semver extension loaded successfully';
    ELSE
        RAISE NOTICE 'semver extension not available';
    END IF;
END
$$;

-- 时间段数据类型
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'periods') THEN
        CREATE EXTENSION IF NOT EXISTS periods;
        RAISE NOTICE 'periods extension loaded successfully';
    ELSE
        RAISE NOTICE 'periods extension not available';
    END IF;
END
$$;

-- 数字类型增强
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'numeral') THEN
        CREATE EXTENSION IF NOT EXISTS numeral;
        RAISE NOTICE 'numeral extension loaded successfully';
    ELSE
        RAISE NOTICE 'numeral extension not available';
    END IF;
END
$$;

-- 前缀匹配类型
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'prefix') THEN
        CREATE EXTENSION IF NOT EXISTS prefix;
        RAISE NOTICE 'prefix extension loaded successfully';
    ELSE
        RAISE NOTICE 'prefix extension not available';
    END IF;
END
$$;

-- ASN.1 OID类型
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'asn1oid') THEN
        CREATE EXTENSION IF NOT EXISTS asn1oid;
        RAISE NOTICE 'asn1oid extension loaded successfully';
    ELSE
        RAISE NOTICE 'asn1oid extension not available';
    END IF;
END
$$;

-- Debian版本比较
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'debversion') THEN
        CREATE EXTENSION IF NOT EXISTS debversion;
        RAISE NOTICE 'debversion extension loaded successfully';
    ELSE
        RAISE NOTICE 'debversion extension not available';
    END IF;
END
$$;

-- ================================================================
-- 创建示例表和函数
-- ================================================================

\echo 'Creating language and types demo tables...'

-- 在types schema中创建示例表展示各种数据类型
CREATE TABLE IF NOT EXISTS types.data_types_demo (
    id SERIAL PRIMARY KEY,

    -- 基础类型
    text_field TEXT,
    citext_field CITEXT,

    -- UUID类型
    uuid_field UUID DEFAULT uuid_generate_v4(),

    -- 加密相关
    encrypted_field BYTEA,

    -- 几何类型
    cube_field CUBE,
    segment_field SEG,

    -- 国际标准号码
    isbn_field ISBN,

    -- JSON增强 (如果可用)
    json_field JSON,

    -- 时间戳
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- 层次路径
    path_field LTREE
);

-- 创建一些示例函数展示编程语言扩展
CREATE OR REPLACE FUNCTION lang.demo_plpgsql_function(input_text TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'PL/pgSQL processed: ' || UPPER(input_text);
END;
$$ LANGUAGE plpgsql;

-- Python函数示例 (如果可用)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'plpython3u') THEN
        EXECUTE $func$
            CREATE OR REPLACE FUNCTION lang.demo_python_function(input_text TEXT)
            RETURNS TEXT AS $py$
                import re
                return f"Python processed: {input_text.lower()}"
            $py$ LANGUAGE plpython3u;
        $func$;
        RAISE NOTICE 'Python demo function created';
    ELSE
        RAISE NOTICE 'Python demo function skipped - extension not available';
    END IF;
END
$$;

-- R函数示例 (如果可用)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'plr') THEN
        EXECUTE $func$
            CREATE OR REPLACE FUNCTION lang.demo_r_function(input_numbers FLOAT[])
            RETURNS FLOAT AS $r$
                numbers <- arg1
                return(mean(numbers))
            $r$ LANGUAGE plr;
        $func$;
        RAISE NOTICE 'R demo function created';
    ELSE
        RAISE NOTICE 'R demo function skipped - extension not available';
    END IF;
END
$$;

-- ================================================================
-- 权限设置
-- ================================================================

\echo 'Setting up permissions for language and types schemas...'

-- 为普通用户授予使用权限
GRANT USAGE ON SCHEMA lang TO PUBLIC;
GRANT USAGE ON SCHEMA types TO PUBLIC;

-- 为表授予权限
GRANT SELECT, INSERT, UPDATE, DELETE ON types.data_types_demo TO PUBLIC;
GRANT USAGE, SELECT ON SEQUENCE types.data_types_demo_id_seq TO PUBLIC;

-- 为函数授予执行权限
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lang TO PUBLIC;

\echo '=================================================='
\echo 'Language & Types Extensions loaded successfully!'
\echo '语言和类型扩展模块加载完成！'
\echo '=================================================='
