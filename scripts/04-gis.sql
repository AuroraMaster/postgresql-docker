-- PostgreSQL GIS 功能初始化
-- ===================================

-- 启用核心GIS扩展
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_raster;
CREATE EXTENSION IF NOT EXISTS postgis_sfcgal;

-- 启用地址标准化扩展
CREATE EXTENSION IF NOT EXISTS address_standardizer;
CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;

-- 启用路径分析扩展
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- 启用H3空间索引扩展
CREATE EXTENSION IF NOT EXISTS h3;
CREATE EXTENSION IF NOT EXISTS h3_postgis;

-- 启用点云处理扩展（如果可用）
CREATE EXTENSION IF NOT EXISTS pointcloud;
CREATE EXTENSION IF NOT EXISTS pointcloud_postgis;

-- 创建GIS工作架构
CREATE SCHEMA IF NOT EXISTS gis;

-- ===========================================
-- 1. 示例地理数据表
-- ===========================================

-- 城市点位表
CREATE TABLE IF NOT EXISTS gis.cities (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    country TEXT,
    population INTEGER,
    -- 地理位置 (经纬度)
    location GEOMETRY(POINT, 4326),
    -- H3索引 (多级空间索引)
    h3_index_9 TEXT,   -- ~0.1km² 精度
    h3_index_7 TEXT,   -- ~5km² 精度
    h3_index_5 TEXT,   -- ~250km² 精度
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 道路网络表 (用于路径分析)
CREATE TABLE IF NOT EXISTS gis.roads (
    id SERIAL PRIMARY KEY,
    name TEXT,
    road_type TEXT, -- highway, primary, secondary等
    -- 线几何
    geom GEOMETRY(LINESTRING, 4326),
    -- 路径分析属性
    source INTEGER,
    target INTEGER,
    cost DOUBLE PRECISION,
    reverse_cost DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 区域边界表
CREATE TABLE IF NOT EXISTS gis.regions (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    region_type TEXT, -- country, state, city等
    -- 多边形几何
    boundary GEOMETRY(MULTIPOLYGON, 4326),
    area_km2 DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 轨迹数据表 (移动对象)
CREATE TABLE IF NOT EXISTS gis.trajectories (
    id SERIAL PRIMARY KEY,
    object_id TEXT NOT NULL,
    object_type TEXT, -- vehicle, person, animal等
    -- 轨迹几何 (带时间)
    trajectory GEOMETRY(LINESTRING, 4326),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    -- 轨迹属性
    distance_km DOUBLE PRECISION,
    duration_minutes INTEGER,
    avg_speed_kmh DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===========================================
-- 2. 空间索引
-- ===========================================

-- 为所有几何字段创建空间索引
CREATE INDEX IF NOT EXISTS idx_cities_location ON gis.cities USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_cities_h3_9 ON gis.cities (h3_index_9);
CREATE INDEX IF NOT EXISTS idx_cities_h3_7 ON gis.cities (h3_index_7);

CREATE INDEX IF NOT EXISTS idx_roads_geom ON gis.roads USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_roads_source ON gis.roads (source);
CREATE INDEX IF NOT EXISTS idx_roads_target ON gis.roads (target);

CREATE INDEX IF NOT EXISTS idx_regions_boundary ON gis.regions USING GIST (boundary);
CREATE INDEX IF NOT EXISTS idx_trajectories_geom ON gis.trajectories USING GIST (trajectory);

-- ===========================================
-- 3. 实用GIS函数
-- ===========================================

-- 自动计算H3索引的触发器函数
CREATE OR REPLACE FUNCTION gis.update_h3_indexes()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.location IS NOT NULL THEN
        NEW.h3_index_9 := h3_geo_to_h3(NEW.location, 9);
        NEW.h3_index_7 := h3_geo_to_h3(NEW.location, 7);
        NEW.h3_index_5 := h3_geo_to_h3(NEW.location, 5);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为cities表添加H3自动更新触发器
CREATE TRIGGER cities_h3_trigger
    BEFORE INSERT OR UPDATE ON gis.cities
    FOR EACH ROW EXECUTE FUNCTION gis.update_h3_indexes();

-- 计算两点间距离 (公里)
CREATE OR REPLACE FUNCTION gis.distance_km(
    point1 GEOMETRY,
    point2 GEOMETRY
)
RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN ST_Distance(
        ST_Transform(point1, 3857),  -- 转换为米制投影
        ST_Transform(point2, 3857)
    ) / 1000.0;  -- 转换为公里
END;
$$ LANGUAGE plpgsql;

-- 查找指定点周围的兴趣点
CREATE OR REPLACE FUNCTION gis.find_nearby_cities(
    center_point GEOMETRY,
    radius_km DOUBLE PRECISION DEFAULT 10.0,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE(
    city_id INTEGER,
    city_name TEXT,
    distance_km DOUBLE PRECISION,
    location GEOMETRY
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        gis.distance_km(center_point, c.location) as dist,
        c.location
    FROM gis.cities c
    WHERE ST_DWithin(
        ST_Transform(center_point, 3857),
        ST_Transform(c.location, 3857),
        radius_km * 1000  -- 转换为米
    )
    ORDER BY dist
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 基于H3的邻近搜索 (高性能)
CREATE OR REPLACE FUNCTION gis.find_cities_by_h3(
    h3_index TEXT,
    ring_size INTEGER DEFAULT 1
)
RETURNS TABLE(
    city_id INTEGER,
    city_name TEXT,
    h3_index TEXT,
    location GEOMETRY
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.h3_index_9,
        c.location
    FROM gis.cities c
    WHERE c.h3_index_9 = ANY(
        SELECT h3_k_ring(h3_index, ring_size)
    );
END;
$$ LANGUAGE plpgsql;

-- 路径分析：最短路径查询
CREATE OR REPLACE FUNCTION gis.shortest_path(
    start_point GEOMETRY,
    end_point GEOMETRY
)
RETURNS TABLE(
    seq INTEGER,
    path_seq INTEGER,
    road_id INTEGER,
    cost DOUBLE PRECISION,
    geom GEOMETRY
) AS $$
DECLARE
    start_vertex INTEGER;
    end_vertex INTEGER;
BEGIN
    -- 找到最近的路网节点
    SELECT source INTO start_vertex
    FROM gis.roads
    ORDER BY ST_Distance(geom, start_point)
    LIMIT 1;

    SELECT target INTO end_vertex
    FROM gis.roads
    ORDER BY ST_Distance(geom, end_point)
    LIMIT 1;

    -- 计算最短路径
    RETURN QUERY
    SELECT
        r.seq,
        r.path_seq,
        r.edge as road_id,
        r.cost,
        rd.geom
    FROM pgr_dijkstra(
        'SELECT id, source, target, cost, reverse_cost FROM gis.roads',
        start_vertex,
        end_vertex,
        directed := true
    ) r
    JOIN gis.roads rd ON r.edge = rd.id
    ORDER BY r.seq;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 4. 示例数据插入
-- ===========================================

-- 插入一些示例城市数据
INSERT INTO gis.cities (name, country, population, location) VALUES
('北京', '中国', 21540000, ST_GeomFromText('POINT(116.4074 39.9042)', 4326)),
('上海', '中国', 24280000, ST_GeomFromText('POINT(121.4737 31.2304)', 4326)),
('深圳', '中国', 12530000, ST_GeomFromText('POINT(114.0579 22.5431)', 4326)),
('纽约', '美国', 8400000, ST_GeomFromText('POINT(-74.0060 40.7128)', 4326)),
('伦敦', '英国', 8982000, ST_GeomFromText('POINT(-0.1276 51.5074)', 4326))
ON CONFLICT DO NOTHING;

-- ===========================================
-- 5. 性能优化设置
-- ===========================================

-- 更新表统计信息
ANALYZE gis.cities;
ANALYZE gis.roads;
ANALYZE gis.regions;
ANALYZE gis.trajectories;

-- ===========================================
-- 6. 权限设置
-- ===========================================

-- 创建GIS只读角色
CREATE ROLE IF NOT EXISTS gis_reader;
GRANT USAGE ON SCHEMA gis TO gis_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA gis TO gis_reader;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA gis TO gis_reader;

-- 创建GIS分析师角色 (可读写)
CREATE ROLE IF NOT EXISTS gis_analyst;
GRANT USAGE ON SCHEMA gis TO gis_analyst;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gis TO gis_analyst;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA gis TO gis_analyst;

-- 输出配置完成信息
\echo '✅ GIS功能配置完成!'
\echo '📋 可用扩展:'
\echo '   - PostGIS: 核心地理功能'
\echo '   - pgRouting: 网络路径分析'
\echo '   - H3: 六边形空间索引'
\echo '   - address_standardizer: 地址标准化'
\echo ''
\echo '🗺️ 使用示例:'
\echo '   -- 查找北京周围50公里的城市:'
\echo '   SELECT * FROM gis.find_nearby_cities(ST_GeomFromText(''POINT(116.4074 39.9042)'', 4326), 50);'
\echo ''
\echo '   -- 计算两城市间距离:'
\echo '   SELECT gis.distance_km('
\echo '     (SELECT location FROM gis.cities WHERE name = ''北京''),'
\echo '     (SELECT location FROM gis.cities WHERE name = ''上海'')'
\echo '   );'
