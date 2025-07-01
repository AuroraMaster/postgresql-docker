-- 数据库初始化脚本
-- 创建示例用户、数据库和演示数据

-- 创建应用用户
DO $$
BEGIN
    -- 创建只读用户
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'readonly_user') THEN
        CREATE ROLE readonly_user WITH LOGIN PASSWORD 'readonly_pass';
    END IF;

    -- 创建应用用户
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user WITH LOGIN PASSWORD 'app_pass';
    END IF;

    -- 创建管理用户
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'admin_user') THEN
        CREATE ROLE admin_user WITH LOGIN PASSWORD 'admin_pass' CREATEDB CREATEROLE;
    END IF;
END $$;

-- 创建示例数据库（如果不存在）
SELECT 'CREATE DATABASE demo_db OWNER app_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'demo_db')\gexec

-- 授权
GRANT CONNECT ON DATABASE postgres TO readonly_user, app_user;
GRANT USAGE ON SCHEMA public TO readonly_user, app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- 设置默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;

-- 创建示例表结构
CREATE TABLE IF NOT EXISTS public.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb,
    search_vector tsvector
);

-- 创建GIS示例表（PostGIS）
CREATE TABLE IF NOT EXISTS public.locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    coordinates GEOMETRY(POINT, 4326),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建向量数据示例表（pgvector）
CREATE TABLE IF NOT EXISTS public.documents (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536), -- OpenAI embedding维度
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建时间序列示例表（TimescaleDB）
CREATE TABLE IF NOT EXISTS public.sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    pressure DOUBLE PRECISION
);

-- 将sensor_data转换为TimescaleDB hypertable
SELECT create_hypertable('public.sensor_data', 'time', if_not_exists => TRUE);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_search ON public.users USING gin(search_vector);
CREATE INDEX IF NOT EXISTS idx_users_metadata ON public.users USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_locations_coordinates ON public.locations USING gist(coordinates);
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON public.documents USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_sensor_data_sensor_time ON public.sensor_data(sensor_id, time DESC);

-- 创建触发器函数用于更新updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器用于搜索向量更新
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english',
        COALESCE(NEW.username, '') || ' ' ||
        COALESCE(NEW.email, '') || ' ' ||
        COALESCE(NEW.full_name, '')
    );
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 添加触发器
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_search_vector ON public.users;
CREATE TRIGGER update_users_search_vector
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_search_vector();

-- 插入示例数据
INSERT INTO public.users (username, email, password_hash, full_name, metadata) VALUES
    ('admin', 'admin@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz', 'Administrator', '{"role": "admin", "department": "IT"}'),
    ('john_doe', 'john@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz', 'John Doe', '{"role": "user", "department": "Sales"}'),
    ('jane_smith', 'jane@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz', 'Jane Smith', '{"role": "manager", "department": "Marketing"}')
ON CONFLICT (username) DO NOTHING;

-- 插入地理位置示例数据
INSERT INTO public.locations (name, description, coordinates) VALUES
    ('北京天安门', '中华人民共和国首都北京市的城市地标', ST_GeomFromText('POINT(116.3974 39.9093)', 4326)),
    ('上海外滩', '上海市黄浦区的著名景点', ST_GeomFromText('POINT(121.4944 31.2371)', 4326)),
    ('深圳市民中心', '深圳市政府所在地', ST_GeomFromText('POINT(114.0579 22.5597)', 4326))
ON CONFLICT DO NOTHING;

-- 插入传感器示例数据
INSERT INTO public.sensor_data (time, sensor_id, temperature, humidity, pressure) VALUES
    (NOW() - INTERVAL '1 hour', 1, 23.5, 45.2, 1013.25),
    (NOW() - INTERVAL '2 hours', 1, 23.8, 44.8, 1013.30),
    (NOW() - INTERVAL '3 hours', 1, 24.1, 44.5, 1013.35),
    (NOW() - INTERVAL '1 hour', 2, 22.8, 48.1, 1012.95),
    (NOW() - INTERVAL '2 hours', 2, 22.5, 48.5, 1012.88),
    (NOW() - INTERVAL '3 hours', 2, 22.2, 49.0, 1012.80)
ON CONFLICT DO NOTHING;

-- 设置定时任务示例（pg_cron）
-- 每天凌晨2点清理旧日志
SELECT cron.schedule('cleanup-old-logs', '0 2 * * *', 'DELETE FROM pg_stat_statements WHERE query LIKE ''%temp%'' AND calls < 10;');

-- 创建监控视图
CREATE OR REPLACE VIEW public.system_stats AS
SELECT
    'Database Connections' as metric,
    count(*) as value,
    'current' as type
FROM pg_stat_activity
UNION ALL
SELECT
    'Database Size' as metric,
    pg_database_size(current_database()) as value,
    'bytes' as type
UNION ALL
SELECT
    'Tables Count' as metric,
    count(*) as value,
    'current' as type
FROM information_schema.tables
WHERE table_schema = 'public';

-- 输出初始化完成信息
DO $$
BEGIN
    RAISE NOTICE '=== 数据库初始化完成 ===';
    RAISE NOTICE '创建用户: readonly_user, app_user, admin_user';
    RAISE NOTICE '创建表: users, locations, documents, sensor_data';
    RAISE NOTICE '插入示例数据完成';
    RAISE NOTICE '使用 SELECT * FROM system_stats; 查看系统状态';
    RAISE NOTICE '使用 SELECT * FROM cron.job; 查看定时任务';
END $$;
