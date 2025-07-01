# 🐘 定制PostgreSQL Docker镜像

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
docker pull ghcr.io/your-username/your-repo/postgres-custom:pg15-latest

# 启动容器
docker run -d \
  --name my-postgres \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  ghcr.io/your-username/your-repo/postgres-custom:pg15-latest
```

### 方法2: 使用Docker Compose（推荐用于开发）

```bash
# 克隆仓库
git clone https://github.com/your-username/your-repo.git
cd your-repo

# 启动完整堆栈
docker-compose up -d

# 仅启动PostgreSQL
docker-compose up -d postgres
```

### 方法3: 本地构建

```bash
# 克隆仓库
git clone https://github.com/your-username/your-repo.git
cd your-repo

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

## 📁 目录结构

```
.
├── Dockerfile                    # Docker镜像构建文件
├── docker-compose.yml           # Docker Compose配置
├── .github/workflows/           # GitHub Actions工作流
│   └── build-postgres.yml      # 自动构建和发布
├── config/                      # 配置文件
│   ├── postgresql.conf          # PostgreSQL主配置
│   └── pg_hba.conf             # 客户端认证配置
├── scripts/                     # 初始化脚本
│   ├── docker-entrypoint.sh    # 自定义启动脚本
│   ├── init-extensions.sql     # 扩展初始化
│   └── init-database.sql       # 数据库初始化
└── README.md                    # 本文档
```

## 🎯 快速开始

### 1. 启动数据库

```bash
docker-compose up -d postgres
```

### 2. 连接数据库

```bash
# 使用psql连接
docker exec -it custom-postgres psql -U postgres

# 或使用外部客户端连接到 localhost:5432
```

### 3. 验证扩展

```sql
-- 查看所有已安装扩展
SELECT * FROM installed_extensions;

-- 检查数据库健康状态
SELECT * FROM database_health_check();

-- 测试PostGIS
SELECT PostGIS_Version();

-- 测试pgvector
SELECT '[1,2,3]'::vector;
```

### 4. 使用pgAdmin管理界面

访问 http://localhost:8080
- 邮箱: admin@example.com
- 密码: admin_password

## 🔄 GitHub Actions自动构建

本项目配置了完整的CI/CD流程：

### 触发条件
- 推送到main/master分支
- 修改Dockerfile或配置文件
- 手动触发
- 每周日定时构建

### 构建流程
1. **多架构构建** - 支持AMD64和ARM64
2. **安全扫描** - 使用Trivy扫描漏洞
3. **自动测试** - 验证镜像功能
4. **自动发布** - 推送到GitHub Container Registry
5. **创建Release** - 自动创建GitHub Release

### 镜像标签
- `pg15-latest` - PostgreSQL 15最新版本
- `pg16-latest` - PostgreSQL 16最新版本
- `pg15-YYYYMMDD` - 按日期标记的版本
- `latest` - 最新稳定版本

## 🛠️ 自定义构建

### 添加新扩展

1. 修改 `Dockerfile`，添加扩展安装命令
2. 更新 `scripts/init-extensions.sql`，添加扩展创建语句
3. 提交到GitHub，自动触发构建

### 修改配置

1. 编辑 `config/postgresql.conf` 或 `config/pg_hba.conf`
2. 提交更改，自动重新构建镜像

### 本地测试

```bash
# 构建测试镜像
docker build -t test-postgres .

# 运行测试
docker run --rm \
  -e POSTGRES_PASSWORD=test \
  test-postgres \
  postgres --version
```

## 📊 监控和管理

### 内置监控视图

```sql
-- 系统统计
SELECT * FROM system_stats;

-- 查询性能统计
SELECT * FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- 数据库活动
SELECT * FROM pg_stat_activity;
```

### 定时任务

```sql
-- 查看定时任务
SELECT * FROM cron.job;

-- 添加新的定时任务
SELECT cron.schedule('job-name', '0 2 * * *', 'VACUUM ANALYZE;');
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
   docker exec custom-postgres pg_dump -U postgres postgres > backup.sql

   # 恢复备份
   docker exec -i custom-postgres psql -U postgres postgres < backup.sql
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

- 🐛 Bug报告: [GitHub Issues](https://github.com/your-username/your-repo/issues)
- 💬 讨论: [GitHub Discussions](https://github.com/your-username/your-repo/discussions)
- 📧 邮件: your-email@example.com

---

**🎉 享受使用这个强大的PostgreSQL Docker镜像！**
