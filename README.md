🐘 # 定制PostgreSQL Docker镜像

这是一个功能丰富的PostgreSQL Docker镜像，通过GitHub Actions自动构建，包含了大量常用扩展和优化配置。

## 🚀 特性

### 📦 包含的扩展

- **PostGIS** - 地理信息系统扩展
- **pgvector** - 向量数据库扩展，支持AI/ML应用
- **pg_cron** - 数据库内定时任务
- **pg_partman** - 分区管理
- **pgjwt** - JWT令牌处理
- **TimescaleDB** - 时间序列数据库
- **pgcrypto** - 加密函数
- **hstore** - 键值对存储
- **pg_stat_statements** - 查询统计
- **以及更多标准扩展...**

### ⚙️ 优化配置

- 针对现代硬件优化的PostgreSQL配置
- 适合容器环境的内存和连接设置
- 详细的日志配置用于监控和调试
- 自动清理和维护任务

### 🔒 安全特性

- SCRAM-SHA-256密码加密
- 细粒度的连接控制
- 预配置的用户角色和权限

## 📋 使用方法

### 方法1: 使用预构建镜像（推荐）

```bash
# 拉取镜像
docker pull ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg15-latest

# 启动容器
docker run -d \
  --name my-postgres \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg15-latest
```

### 方法2: 使用Docker Compose（推荐用于开发）

```bash
# 克隆仓库
git clone https://github.com/AuroraMaster/postgresql-docker.git
cd postgresql-docker

# 启动完整堆栈
docker-compose up -d

# 仅启动PostgreSQL
docker-compose up -d postgres
```

### 方法3: 本地构建

```bash
# 克隆仓库
git clone https://github.com/AuroraMaster/postgresql-docker.git
cd postgresql-docker

# 构建镜像
docker build -t custom-postgres:local .

# 运行容器
docker run -d \
  --name my-postgres \
  -e POSTGRES_PASSWORD=your_password \
  -p 5432:5432 \
  custom-postgres:local
```

## 🔧 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `POSTGRES_DB` | `postgres` | 默认数据库名 |
| `POSTGRES_USER` | `postgres` | 超级用户名 |
| `POSTGRES_PASSWORD` | - | 数据库密码（必须设置） |
| `POSTGRES_INITDB_ARGS` | - | 初始化参数 |

## 🎯 快速开始

### 1. 启动数据库

```bash
# 开发环境（仅PostgreSQL）
make dev

# 完整环境（所有服务）
make up
```

### 2. 初始化扩展功能

```bash
# 初始化时序、GIS、AI/RAG、OLAP、图数据库等所有扩展
make db-init
```

### 3. 连接数据库

```bash
# 使用命令行连接
make db-connect

# pgAdmin Web界面: http://localhost:5050
# 用户名: admin@postgres.local / 密码: admin123
```

### 4. 验证扩展功能

```sql
-- 查看所有已安装扩展
\dx

-- 测试时序数据库
SELECT create_hypertable('test_table', 'time') FROM (
    CREATE TABLE test_table (time TIMESTAMPTZ, value DOUBLE PRECISION)
) AS t;

-- 测试向量搜索
SELECT '[1,2,3]'::vector <-> '[1,2,4]'::vector;

-- 测试地理信息
SELECT ST_Distance(
    ST_GeomFromText('POINT(0 0)'),
    ST_GeomFromText('POINT(1 1)')
);

-- 测试图数据库
SELECT * FROM ag_catalog.ag_graph;
```

## 🔄 自动构建

### 📝 提交消息触发构建

通过在Git提交消息中添加特定标签自动触发构建：

```bash
# 基本用法
git commit -m "更新配置 [build] [pg15]"

# 构建两个版本
git commit -m "重要更新 [build] [both]"

# 强制重建
git commit -m "修复问题 [build] [pg16] [force]"

# 自定义标签
git commit -m "发布版本 [build] [both] [tag:v1.0.0]"
```

**支持的标签：**
- 构建触发：`[build]` / `[构建]` / `--build`
- 版本选择：`[pg15]` / `[pg16]` / `[both]`
- 强制重建：`[force]` / `[强制]` / `--force`
- 标签后缀：`[tag:自定义后缀]`

### 🔧 手动触发

```bash
# 构建PostgreSQL 15
./build-helper.sh trigger 15

# 构建PostgreSQL 16
./build-helper.sh trigger 16

# 构建两个版本
./build-helper.sh trigger both

# 强制重建 (无缓存)
./build-helper.sh trigger both true
```

## 📚 详细文档

- 📖 **完整使用指南**: [POSTGRES_GUIDE.md](POSTGRES_GUIDE.md)
- 📊 **扩展分类说明**: [EXTENSION_CATEGORIES.md](EXTENSION_CATEGORIES.md)
- 📋 **Scripts说明**: [scripts/README.md](scripts/README.md)

本数据库集成了以下功能模块：
- 🕐 **时序数据处理** (TimescaleDB)
- 🌍 **地理信息系统** (PostGIS生态)
- 🤖 **AI/RAG应用** (向量数据库)
- 📊 **OLAP分析** (分区表、列式存储)
- 🕸️ **图数据库** (Apache AGE)
- 📋 **审计追踪** (完整变更历史)
- 💼 **金融科技** (风险分析、合规检查)
- 🧬 **生物信息学** (序列分析、基因组学)
- 🏭 **物联网** (设备管理、传感器数据)
- 🔬 **科学计算** (数值分析、统计函数)

## 🛠️ 管理命令

### 数据库管理

```bash
# 连接数据库
make db-connect

# 备份数据库
make db-backup

# 恢复数据库
make db-restore BACKUP_FILE=backup.sql.gz
```

### 服务管理

```bash
# 查看状态
make status

# 查看日志
make logs-postgres

# 健康检查
make health
```

### 测试和维护

```bash
# 本地测试
./build-helper.sh test-local

# 查看构建状态
./build-helper.sh status

# 测试提交消息
./build-helper.sh test-commit "测试消息 [build]"
```

## 🔒 安全建议

### 生产环境配置

1. **修改默认密码**
   ```bash
   docker run -e POSTGRES_PASSWORD=your_secure_password_here ...
   ```

2. **限制网络访问**
   - 修改 `config/pg_hba.conf`
   - 使用防火墙规则
   - 配置SSL证书

3. **定期备份**
   ```bash
   # 创建备份
   make db-backup

   # 恢复备份
   make db-restore BACKUP_FILE=backup_file.sql.gz
   ```

## 🤝 贡献

欢迎提交Issue和Pull Request！

### 开发流程

1. Fork本仓库
2. 创建特性分支: `git checkout -b feature/new-extension`
3. 提交更改: `git commit -am 'Add new extension'`
4. 推送分支: `git push origin feature/new-extension`
5. 创建Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🆘 故障排除

### 常见问题

**Q: 容器启动失败**
```bash
# 查看日志
docker logs custom-postgres

# 检查权限
docker exec custom-postgres ls -la /var/lib/postgresql/data
```

**Q: 扩展加载失败**
```sql
-- 检查扩展状态
SELECT * FROM pg_available_extensions WHERE name = 'postgis';

-- 手动创建扩展
CREATE EXTENSION IF NOT EXISTS postgis;
```

**Q: 性能问题**
```sql
-- 检查慢查询
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC;
```

## 📞 支持

- 🐛 Bug报告: [GitHub Issues](https://github.com/AuroraMaster/postgresql-docker/issues)
- 💬 讨论: [GitHub Discussions](https://github.com/AuroraMaster/postgresql-docker/discussions)
- 📧 邮件: contact@auroramaster.com

---

**🎉 享受使用这个强大的PostgreSQL Docker镜像！**
