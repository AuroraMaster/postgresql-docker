# PostgreSQL Docker 项目使用指南

## 🎯 项目优化说明

本项目已经过重大优化，**整合了重复的构建脚本和配置文件**，现在提供更加简洁和高效的使用体验。

### ✅ 优化完成的改进

- **统一构建工具**: 将 3 个独立脚本合并为 1 个多功能 `build.sh`
- **Dockerfile 优化**: 使用性能优化版本作为主要 Dockerfile
- **Docker Compose 统一**: 通过 profiles 机制支持多环境配置
- **减少文件冗余**: 删除重复和过时的文件

## 🚀 快速开始

### 1. 智能构建镜像

```bash
# 自动检测网络环境并构建（推荐）
./build.sh build optimized latest auto

# 国内网络环境（使用清华镜像源）
./build.sh build optimized latest china

# 国际网络环境（使用官方镜像源）
./build.sh build optimized latest international

# 使用标准构建
./build.sh build standard latest auto

# 查看构建帮助
./build.sh help
```

### 2. 测试镜像

```bash
# 快速测试
./build.sh test quick

# 完整测试（包括扩展和性能测试）
./build.sh test full
```

### 3. 性能基准测试

```bash
# 运行 3 次基准测试
./build.sh benchmark 3

# 运行 5 次基准测试
./build.sh benchmark 5
```

### 4. 启动服务

#### 开发环境
```bash
# 仅启动 PostgreSQL 开发版本
docker-compose --profile dev up -d

# 停止
docker-compose --profile dev down
```

#### 生产环境
```bash
# 启动 PostgreSQL 生产版本
docker-compose --profile prod up -d

# 启动完整堆栈（PostgreSQL + 管理工具 + 监控）
docker-compose --profile full up -d
```

#### 特定服务组合
```bash
# PostgreSQL + pgAdmin
docker-compose --profile admin up -d

# PostgreSQL + Redis 缓存
docker-compose --profile cache up -d

# PostgreSQL + 监控
docker-compose --profile monitoring up -d
```

## 📋 可用命令总览

### build.sh 统一构建工具

| 命令 | 参数 | 说明 |
|------|------|------|
| `build` | `[type] [tag] [network]` | 构建 Docker 镜像 |
| `test` | `[quick\|full]` | 测试镜像功能 |
| `benchmark` | `[runs]` | 运行性能基准测试 |
| `trigger` | `<version> [force]` | 触发 GitHub Actions 构建 |
| `status` | - | 检查构建状态 |
| `clean` | - | 清理缓存和临时文件 |
| `help` | - | 显示帮助信息 |

### Docker Compose Profiles

| Profile | 包含服务 | 用途 |
|---------|----------|------|
| `dev` | postgres-dev | 开发环境 |
| `prod` | postgres | 生产环境 |
| `admin` | postgres + pgadmin | 数据库管理 |
| `cache` | postgres + redis | 带缓存的数据库 |
| `monitoring` | postgres + prometheus + grafana | 监控环境 |
| `full` | 所有服务 | 完整堆栈 |

## 🔧 配置说明

### 环境变量

在 `.env` 文件中配置环境变量：

```bash
# PostgreSQL 配置
POSTGRES_VERSION=16
POSTGRES_DB=myapp
POSTGRES_USER=myuser
POSTGRES_PASSWORD=secure_password_123

# 镜像配置
POSTGRES_IMAGE_NAME=custom-postgres
POSTGRES_IMAGE_TAG=latest

# 端口配置
POSTGRES_PORT=5432
PGADMIN_PORT=8080
REDIS_PORT=6379

# 项目配置
PROJECT_NAME=my-postgresql-project
COMPOSE_PROJECT_NAME=my-pg
```

### Dockerfile 版本说明

- **`Dockerfile`** (主版本): 性能优化版本，支持多阶段构建和缓存优化
- **`Dockerfile.legacy`** (备份): 原始版本，保留作为参考

## 📊 性能对比

使用优化后的构建工具，预期性能提升：

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 首次构建时间 | 15-20分钟 | 8-12分钟 | ~40% |
| 增量构建时间 | 10-15分钟 | 2-5分钟 | ~70% |
| 镜像大小 | 1.2-1.5GB | 900MB-1.1GB | ~20% |
| 缓存命中率 | 30% | 80% | ~167% |

## 🛠️ 故障排除

### 常见问题

1. **构建失败**
   ```bash
   # 清理缓存后重试
   ./build.sh clean
   ./build.sh build optimized latest
   ```

2. **端口冲突**
   ```bash
   # 检查端口使用情况
   netstat -tlnp | grep :5432

   # 修改 .env 文件中的端口配置
   POSTGRES_PORT=15432
   ```

3. **权限问题**
   ```bash
   # 确保脚本有执行权限
   chmod +x build.sh

   # 确保 Docker 权限正确
   sudo usermod -aG docker $USER
   ```

### 日志查看

```bash
# 查看构建日志
docker-compose logs postgres

# 查看开发环境日志
docker-compose --profile dev logs postgres-dev

# 实时查看日志
docker-compose --profile prod logs -f postgres
```

## 📚 相关文档

- **BUILD_TRIGGERS.md**: GitHub Actions 触发机制说明
- **docker-optimization-analysis.md**: 详细的优化分析报告
- **scripts/README.md**: 数据库初始化脚本说明

## 🔗 有用链接

- [PostgreSQL 官方文档](https://www.postgresql.org/docs/)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [BuildKit 官方文档](https://docs.docker.com/buildx/)

---

💡 **提示**: 如果您在使用过程中遇到问题，请查看构建状态和日志，或运行 `./build.sh help` 获取更多帮助信息。
