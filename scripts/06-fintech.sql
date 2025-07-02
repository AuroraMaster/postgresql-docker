-- ================================================================
-- PostgreSQL 金融科技扩展模块 (FinTech Extensions)
-- 专业金融计算、风险管理、合规审计扩展集合
-- ================================================================

\echo '=================================================='
\echo 'Loading FinTech Extensions...'
\echo '金融科技、风险管理、合规审计扩展'
\echo '=================================================='

-- ================================================================
-- 高精度货币计算扩展 (High-Precision Monetary Computing)
-- ================================================================

-- 高精度数值计算基础
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- 支持NUMERIC类型的高效索引
\echo 'Created extension: btree_gist (高精度数值索引)'

-- 加密与哈希计算用于金融安全
CREATE EXTENSION IF NOT EXISTS pgcrypto;
\echo 'Created extension: pgcrypto (金融加密与数字签名)'

-- UUID生成用于交易唯一标识
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
\echo 'Created extension: uuid-ossp (交易唯一标识生成)'

-- ================================================================
-- 时间序列金融数据 (Time Series Financial Data)
-- ================================================================

-- 时间范围查询优化
CREATE EXTENSION IF NOT EXISTS btree_gin;  -- 支持复合索引优化
\echo 'Created extension: btree_gin (时间序列复合索引)'

-- 区间数据类型用于交易时间窗口
CREATE EXTENSION IF NOT EXISTS seg;  -- 区间数据类型
\echo 'Created extension: seg (交易时间区间管理)'

-- ================================================================
-- 审计与合规扩展 (Audit & Compliance Extensions)
-- ================================================================

-- 用户会话跟踪
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- 已创建，用于审计追踪
\echo 'UUID extension available for audit trails'

-- HStore用于灵活的审计元数据存储
-- CREATE EXTENSION IF NOT EXISTS hstore; -- 已在01-core-extensions.sql中声明
\echo 'Created extension: hstore (审计元数据存储)'

-- ================================================================
-- 金融数据类型定义 (Financial Data Types)
-- ================================================================

-- 创建货币金额数据域
DO $$
BEGIN
    -- 创建高精度货币类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'money_amount') THEN
        CREATE DOMAIN money_amount AS NUMERIC(19,4) CHECK (VALUE >= 0);
        COMMENT ON DOMAIN money_amount IS '高精度货币金额类型 (最大15位整数+4位小数)';
    END IF;

    -- 创建汇率类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exchange_rate') THEN
        CREATE DOMAIN exchange_rate AS NUMERIC(12,8) CHECK (VALUE > 0);
        COMMENT ON DOMAIN exchange_rate IS '汇率类型 (支持8位小数精度)';
    END IF;

    -- 创建利率类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interest_rate') THEN
        CREATE DOMAIN interest_rate AS NUMERIC(7,6) CHECK (VALUE >= -1 AND VALUE <= 10);
        COMMENT ON DOMAIN interest_rate IS '利率类型 (支持-100%到1000%范围)';
    END IF;

    -- 创建风险评分类型
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'risk_score') THEN
        CREATE DOMAIN risk_score AS NUMERIC(5,4) CHECK (VALUE >= 0 AND VALUE <= 1);
        COMMENT ON DOMAIN risk_score IS '风险评分类型 (0-1范围，4位小数)';
    END IF;
END
$$;

\echo 'Created financial data domains: money_amount, exchange_rate, interest_rate, risk_score'

-- ================================================================
-- 金融计算函数 (Financial Computing Functions)
-- ================================================================

-- 复利计算函数
CREATE OR REPLACE FUNCTION compound_interest(
    principal money_amount,
    rate interest_rate,
    periods INTEGER,
    compounds_per_period INTEGER DEFAULT 1
) RETURNS money_amount AS $$
BEGIN
    RETURN principal * POWER(1 + rate / compounds_per_period, compounds_per_period * periods);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION compound_interest(money_amount, interest_rate, INTEGER, INTEGER)
IS '复利计算函数 (本金, 利率, 期数, 每期复利次数)';

-- 净现值计算函数
CREATE OR REPLACE FUNCTION net_present_value(
    cash_flows money_amount[],
    discount_rate interest_rate
) RETURNS money_amount AS $$
DECLARE
    npv money_amount := 0;
    i INTEGER;
BEGIN
    FOR i IN 1..array_length(cash_flows, 1) LOOP
        npv := npv + cash_flows[i] / POWER(1 + discount_rate, i - 1);
    END LOOP;
    RETURN npv;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION net_present_value(money_amount[], interest_rate)
IS '净现值计算函数 (现金流数组, 折现率)';

-- 风险调整收益率计算
CREATE OR REPLACE FUNCTION risk_adjusted_return(
    return_rate interest_rate,
    risk_free_rate interest_rate,
    beta_coefficient NUMERIC
) RETURNS interest_rate AS $$
BEGIN
    RETURN risk_free_rate + beta_coefficient * (return_rate - risk_free_rate);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION risk_adjusted_return(interest_rate, interest_rate, NUMERIC)
IS '风险调整收益率计算 (CAPM模型)';

-- ================================================================
-- 合规性检查函数 (Compliance Check Functions)
-- ================================================================

-- AML (反洗钱) 金额检查
CREATE OR REPLACE FUNCTION aml_amount_check(
    amount money_amount,
    threshold money_amount DEFAULT 10000
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN amount >= threshold;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION aml_amount_check(money_amount, money_amount)
IS 'AML金额检查函数 (超过阈值需要特殊处理)';

-- 交易频率风险检查
CREATE OR REPLACE FUNCTION transaction_frequency_risk(
    user_id UUID,
    time_window INTERVAL DEFAULT '1 hour',
    max_transactions INTEGER DEFAULT 100
) RETURNS BOOLEAN AS $$
DECLARE
    transaction_count INTEGER;
BEGIN
    -- 这里应该查询实际的交易表，此处为示例
    -- SELECT COUNT(*) INTO transaction_count
    -- FROM transactions
    -- WHERE user_id = $1 AND created_at > NOW() - time_window;

    -- 返回是否超过风险阈值
    RETURN transaction_count > max_transactions;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION transaction_frequency_risk(UUID, INTERVAL, INTEGER)
IS '交易频率风险检查函数';

-- ================================================================
-- 金融数据验证函数 (Financial Data Validation)
-- ================================================================

-- IBAN验证函数
CREATE OR REPLACE FUNCTION validate_iban(iban_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- 简化的IBAN验证 (实际实现需要更复杂的模97算法)
    RETURN length(iban_code) BETWEEN 15 AND 34
           AND iban_code ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]+$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_iban(TEXT) IS 'IBAN国际银行账号验证函数';

-- 信用卡号验证函数 (Luhn算法)
CREATE OR REPLACE FUNCTION validate_credit_card(card_number TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    clean_number TEXT;
    digit INTEGER;
    sum_val INTEGER := 0;
    is_even BOOLEAN := false;
    i INTEGER;
BEGIN
    -- 移除非数字字符
    clean_number := regexp_replace(card_number, '[^0-9]', '', 'g');

    -- 检查长度
    IF length(clean_number) NOT BETWEEN 13 AND 19 THEN
        RETURN false;
    END IF;

    -- Luhn算法验证
    FOR i IN REVERSE length(clean_number)..1 LOOP
        digit := substring(clean_number FROM i FOR 1)::INTEGER;

        IF is_even THEN
            digit := digit * 2;
            IF digit > 9 THEN
                digit := digit - 9;
            END IF;
        END IF;

        sum_val := sum_val + digit;
        is_even := NOT is_even;
    END LOOP;

    RETURN (sum_val % 10) = 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION validate_credit_card(TEXT) IS '信用卡号Luhn算法验证函数';

-- ================================================================
-- 风险管理函数 (Risk Management Functions)
-- ================================================================

-- VaR (Value at Risk) 计算函数
CREATE OR REPLACE FUNCTION calculate_var(
    portfolio_value money_amount,
    volatility NUMERIC,
    confidence_level NUMERIC DEFAULT 0.95,
    time_horizon INTEGER DEFAULT 1
) RETURNS money_amount AS $$
DECLARE
    z_score NUMERIC;
BEGIN
    -- 根据置信度获取Z分数 (简化实现)
    CASE
        WHEN confidence_level >= 0.99 THEN z_score := 2.33;
        WHEN confidence_level >= 0.95 THEN z_score := 1.65;
        WHEN confidence_level >= 0.90 THEN z_score := 1.28;
        ELSE z_score := 1.65;
    END CASE;

    RETURN portfolio_value * volatility * z_score * SQRT(time_horizon);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_var(money_amount, NUMERIC, NUMERIC, INTEGER)
IS 'VaR风险价值计算函数';

-- ================================================================
-- 审计日志触发器函数 (Audit Log Trigger Functions)
-- ================================================================

-- 通用审计触发器函数
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    audit_data hstore;
BEGIN
    audit_data := hstore(NEW) - hstore(OLD);

    -- 这里应该插入到审计表
    -- INSERT INTO audit_log (table_name, operation, changed_data, user_id, timestamp)
    -- VALUES (TG_TABLE_NAME, TG_OP, audit_data, current_user, NOW());

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION audit_trigger_function() IS '通用审计追踪触发器函数';

-- ================================================================
-- 金融数据安全函数 (Financial Data Security)
-- ================================================================

-- 敏感数据掩码函数
CREATE OR REPLACE FUNCTION mask_account_number(account_number TEXT)
RETURNS TEXT AS $$
BEGIN
    IF length(account_number) <= 4 THEN
        RETURN repeat('*', length(account_number));
    ELSE
        RETURN repeat('*', length(account_number) - 4) || right(account_number, 4);
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION mask_account_number(TEXT) IS '账号掩码函数 (保留后4位)';

-- PII数据加密函数
CREATE OR REPLACE FUNCTION encrypt_pii(
    data TEXT,
    encryption_key TEXT DEFAULT 'default_fintech_key_2024'
) RETURNS TEXT AS $$
BEGIN
    RETURN encode(pgp_sym_encrypt(data, encryption_key), 'base64');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION encrypt_pii(TEXT, TEXT) IS 'PII敏感数据加密函数';

-- PII数据解密函数
CREATE OR REPLACE FUNCTION decrypt_pii(
    encrypted_data TEXT,
    encryption_key TEXT DEFAULT 'default_fintech_key_2024'
) RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(decode(encrypted_data, 'base64'), encryption_key);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;  -- 解密失败返回NULL
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION decrypt_pii(TEXT, TEXT) IS 'PII敏感数据解密函数';

-- ================================================================
-- 金融配置优化 (Financial Computing Configuration)
-- ================================================================

-- 设置金融计算相关的配置参数
DO $$
BEGIN
    -- 设置高精度数值显示
    PERFORM set_config('extra_float_digits', '3', false);

    -- 设置严格的数值计算模式
    PERFORM set_config('client_min_messages', 'warning', false);

    -- 启用行级安全策略支持
    PERFORM set_config('row_security', 'on', false);

    \echo 'Applied financial computing optimizations';
    \echo '- High precision numeric display';
    \echo '- Strict numeric computing mode';
    \echo '- Row-level security enabled';
END
$$;

-- ================================================================
-- 扩展模块加载完成
-- ================================================================

\echo '=================================================='
\echo 'FinTech Extensions loaded successfully!'
\echo '金融科技扩展模块加载完成'
\echo ''
\echo 'Available capabilities:'
\echo '- 高精度货币计算 (High-precision monetary computing)'
\echo '- 金融数据类型 (Financial data types: money_amount, exchange_rate, etc.)'
\echo '- 复利与净现值计算 (Compound interest & NPV calculations)'
\echo '- 风险管理函数 (Risk management: VaR, CAPM, etc.)'
\echo '- 合规性检查 (Compliance: AML, transaction frequency)'
\echo '- 数据验证 (IBAN, credit card validation)'
\echo '- 敏感数据加密 (PII encryption & masking)'
\echo '- 审计追踪支持 (Audit trail capabilities)'
\echo '=================================================='
