# PostgreSQL Docker 项目 Makefile
# 使用方法: make <target>

# 包含环境变量 (如果存在)
-include .env

# 默认目标
.DEFAULT_GOAL := help

# 定义颜色
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# 帮助信息
.PHONY: help
help: ## 显示此帮助信息
	@echo "$(BLUE)PostgreSQL Docker 项目管理工具$(NC)"
	@echo "=================================="
	@echo ""
	@echo "$(YELLOW)可用命令:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# 开发环境
.PHONY: dev
dev: ## 启动开发环境 (仅PostgreSQL)
	@echo "$(BLUE)启动开发环境...$(NC)"
	docker-compose -f docker-compose.dev.yml up -d
	@echo "$(GREEN)✅ 开发环境已启动$(NC)"
	@echo "PostgreSQL: localhost:$(POSTGRES_PORT)"

.PHONY: dev-logs
dev-logs: ## 查看开发环境日志
	docker-compose -f docker-compose.dev.yml logs -f

.PHONY: dev-stop
dev-stop: ## 停止开发环境
	@echo "$(YELLOW)停止开发环境...$(NC)"
	docker-compose -f docker-compose.dev.yml down

.PHONY: dev-clean
dev-clean: ## 清理开发环境（包括数据）
	@echo "$(RED)警告: 这将删除所有开发数据!$(NC)"
	@read -p "确认删除? (y/N): " confirm; [ "$$confirm" = "y" ] || exit 1
	docker-compose -f docker-compose.dev.yml down -v --remove-orphans

# 完整环境
.PHONY: up
up: ## 启动完整环境（所有服务）
	@echo "$(BLUE)启动完整环境...$(NC)"
	docker-compose --profile full up -d
	@echo "$(GREEN)✅ 完整环境已启动$(NC)"

.PHONY: up-admin
up-admin: ## 启动数据库+管理界面
	@echo "$(BLUE)启动管理环境...$(NC)"
	docker-compose --profile admin up -d
	@echo "$(GREEN)✅ 管理环境已启动$(NC)"
	@echo "pgAdmin: http://localhost:$(PGADMIN_PORT)"

.PHONY: up-cache
up-cache: ## 启动数据库+缓存
	@echo "$(BLUE)启动缓存环境...$(NC)"
	docker-compose --profile cache up -d
	@echo "$(GREEN)✅ 缓存环境已启动$(NC)"

.PHONY: up-monitoring
up-monitoring: ## 启动监控环境
	@echo "$(BLUE)启动监控环境...$(NC)"
	docker-compose --profile monitoring up -d
	@echo "$(GREEN)✅ 监控环境已启动$(NC)"
	@echo "Prometheus: http://localhost:$(PROMETHEUS_PORT)"
	@echo "Grafana: http://localhost:$(GRAFANA_PORT)"

.PHONY: down
down: ## 停止所有服务
	@echo "$(YELLOW)停止所有服务...$(NC)"
	docker-compose down

.PHONY: clean
clean: ## 清理所有数据和容器
	@echo "$(RED)警告: 这将删除所有数据!$(NC)"
	@read -p "确认删除? (y/N): " confirm; [ "$$confirm" = "y" ] || exit 1
	docker-compose down -v --remove-orphans
	docker system prune -f

# 构建和测试 (使用统一的build.sh)
.PHONY: build
build: ## 构建Docker镜像 (优化版本)
	@echo "$(BLUE)构建Docker镜像 (优化版本)...$(NC)"
	./build.sh build optimized latest auto

.PHONY: build-standard
build-standard: ## 构建标准版本
	@echo "$(BLUE)构建Docker镜像 (标准版本)...$(NC)"
	./build.sh build standard latest auto

.PHONY: build-china
build-china: ## 使用国内镜像源构建
	@echo "$(BLUE)使用国内镜像源构建...$(NC)"
	./build.sh build optimized latest china

.PHONY: build-international
build-international: ## 使用国际镜像源构建
	@echo "$(BLUE)使用国际镜像源构建...$(NC)"
	./build.sh build optimized latest international

.PHONY: test
test: ## 运行完整测试
	@echo "$(BLUE)运行完整测试...$(NC)"
	./build.sh test full

.PHONY: test-quick
test-quick: ## 运行快速测试
	@echo "$(BLUE)运行快速测试...$(NC)"
	./build.sh test quick

.PHONY: test-build
test-build: ## 运行构建测试
	@echo "$(BLUE)运行构建测试...$(NC)"
	./test-build.sh

.PHONY: benchmark
benchmark: ## 运行性能基准测试
	@echo "$(BLUE)运行性能基准测试...$(NC)"
	./build.sh benchmark 3

# 数据库管理
.PHONY: db-connect
db-connect: ## 连接到数据库
	docker exec -it $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

.PHONY: db-init
db-init: ## 初始化数据库扩展
	@echo "$(BLUE)初始化数据库扩展...$(NC)"
	@echo "🔧 安装基础扩展..."
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-time.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-audit-timetravel.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-gis.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-rag.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-olap-part1.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-olap-part2.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-modern-extensions.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-lang-types-part1.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-lang-types-part2.sql
	docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) < scripts/init-pigsty-extensions.sql
	@echo "$(GREEN)✅ 数据库扩展初始化完成$(NC)"

.PHONY: db-backup
db-backup: ## 备份数据库
	@echo "$(BLUE)备份数据库...$(NC)"
	mkdir -p $(BACKUP_PATH)
	docker exec $(COMPOSE_PROJECT_NAME)-postgres pg_dump -U $(POSTGRES_USER) $(POSTGRES_DB) | gzip > $(BACKUP_PATH)/backup_$(shell date +%Y%m%d_%H%M%S).sql.gz
	@echo "$(GREEN)✅ 备份完成$(NC)"

.PHONY: db-restore
db-restore: ## 恢复数据库 (需要指定: BACKUP_FILE=xxx.sql.gz)
	@if [ -z "$(BACKUP_FILE)" ]; then echo "$(RED)请指定备份文件: make db-restore BACKUP_FILE=backup.sql.gz$(NC)"; exit 1; fi
	@echo "$(BLUE)恢复数据库...$(NC)"
	gunzip -c $(BACKUP_PATH)/$(BACKUP_FILE) | docker exec -i $(COMPOSE_PROJECT_NAME)-postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)
	@echo "$(GREEN)✅ 恢复完成$(NC)"

# 日志和监控
.PHONY: logs
logs: ## 查看所有服务日志
	docker-compose logs -f

.PHONY: logs-postgres
logs-postgres: ## 查看PostgreSQL日志
	docker-compose logs -f postgres

.PHONY: status
status: ## 查看服务状态
	@echo "$(BLUE)服务状态:$(NC)"
	docker-compose ps
	@echo ""
	@echo "$(BLUE)资源使用:$(NC)"
	docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep $(COMPOSE_PROJECT_NAME) || echo "无运行中的容器"

# 维护
.PHONY: update
update: ## 更新镜像并重启
	@echo "$(BLUE)更新镜像...$(NC)"
	docker-compose pull
	docker-compose up -d
	@echo "$(GREEN)✅ 更新完成$(NC)"

.PHONY: health
health: ## 检查服务健康状态
	@echo "$(BLUE)检查服务健康状态...$(NC)"
	@docker inspect $(COMPOSE_PROJECT_NAME)-postgres --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy" && echo "$(GREEN)✅ PostgreSQL健康$(NC)" || echo "$(RED)❌ PostgreSQL不健康$(NC)"

# 开发工具
.PHONY: shell
shell: ## 进入PostgreSQL容器shell
	docker exec -it $(COMPOSE_PROJECT_NAME)-postgres bash

.PHONY: psql
psql: ## 连接到psql (别名)
psql: db-connect

# CI/CD (使用统一构建系统)
.PHONY: ci-build
ci-build: ## CI环境构建
	@echo "$(BLUE)CI环境构建...$(NC)"
	./build.sh build optimized latest international

.PHONY: ci-test
ci-test: ## CI环境测试
	@echo "$(BLUE)CI环境测试...$(NC)"
	./build.sh test quick

.PHONY: clean-build
clean-build: ## 清理构建缓存并重新构建
	@echo "$(BLUE)清理构建缓存...$(NC)"
	./build.sh clean
	@echo "$(BLUE)重新构建...$(NC)"
	./build.sh build optimized latest auto
