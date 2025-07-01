# 🚀 快速入门：提交消息触发构建

## 📝 常用提交消息模板

### 🔧 日常开发场景

```bash
# 修复bug后构建测试
git commit -m "修复数据库连接超时问题 [build]"

# 添加新功能后构建
git commit -m "新增用户认证功能 [build] [pg16]"

# 更新依赖后强制重建
git commit -m "更新PostgreSQL扩展版本 [build] [both] [force]"

# 发布版本
git commit -m "发布v2.1.0版本 [build] [both] [tag:v2.1.0]"
```

### 🎯 特定场景示例

#### 紧急修复
```bash
git commit -m "🚨 紧急修复安全漏洞 [build] [both] [force] [tag:security-patch]"
```

#### 性能优化
```bash
git commit -m "优化查询性能和索引配置 [build] [pg15] [tag:performance-v1]"
```

#### 配置更新
```bash
git commit -m "更新pg_hba.conf认证配置 [build] [pg16]"
```

#### 扩展更新
```bash
git commit -m "升级PostGIS到最新版本 [build] [both] [force]"
```

## 🛠️ 实践流程

### 1. 开发修改
```bash
# 编辑文件
vim Dockerfile
vim config/postgresql.conf

# 本地测试（可选）
./build-helper.sh test-local
```

### 2. 提交并触发构建
```bash
# 添加更改
git add .

# 使用触发标签提交
git commit -m "优化内存配置参数 [build] [pg15]"

# 推送触发构建
git push origin main
```

### 3. 监控构建状态
```bash
# 检查构建状态
./build-helper.sh status

# 查看详细日志
open https://github.com/AuroraMaster/postgresql-docker/actions
```

### 4. 验证结果
```bash
# 构建成功后测试镜像
docker pull ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg15-latest

# 启动容器测试
docker run -d --name test-pg \
  -e POSTGRES_PASSWORD=testpass \
  -p 5432:5432 \
  ghcr.io/auroramaster/postgresql-docker/postgres-custom:pg15-latest
```

## 📊 标签组合速查表

| 场景 | 提交消息示例 | 说明 |
|------|-------------|------|
| 基本构建 | `[build]` | 构建PG15默认版本 |
| 指定版本 | `[build] [pg16]` | 仅构建PG16 |
| 构建全部 | `[build] [both]` | 构建PG15+PG16 |
| 强制重建 | `[build] [force]` | 无缓存重建 |
| 版本标签 | `[build] [tag:v1.0]` | 添加自定义标签 |
| 完整组合 | `[build] [both] [force] [tag:release]` | 全功能组合 |

## 🌍 多语言支持

### 中文标签
```bash
git commit -m "数据库配置优化 [构建] [强制]"
```

### 命令行风格
```bash
git commit -m "update postgresql extensions --build --pg16 --force"
```

### 混合风格
```bash
git commit -m "重要更新 [build] --both [tag:milestone]"
```

## ⚡ 高效工作流

### 开发分支策略
```bash
# 功能分支正常提交（不触发构建）
git checkout -b feature/new-extension
git commit -m "添加新扩展配置文件"
git commit -m "更新文档说明"

# 合并到主分支时触发构建
git checkout main
git merge feature/new-extension
git commit -m "合并新扩展功能 [build] [both] [tag:new-feature]"
git push origin main
```

### 批量修改
```bash
# 多个小改动，最后一次性构建
git commit -m "修复Dockerfile语法"
git commit -m "更新配置注释"
git commit -m "优化启动脚本"
git commit -m "完成配置优化，触发构建 [build] [both]"
```

## 🔍 故障排除

### 构建未触发
```bash
# 检查最近的提交
git log -1 --oneline

# 验证标签格式
./build-helper.sh test-commit "你的提交消息"

# 手动触发备用方案
./build-helper.sh trigger 15
```

### 构建失败
```bash
# 查看构建日志
open https://github.com/AuroraMaster/postgresql-docker/actions

# 强制重建
git commit --amend -m "修复构建问题 [build] [pg15] [force]"
git push --force-with-lease origin main
```

## 💡 最佳实践

1. **明确意图**: 提交消息要说明为什么需要构建
2. **版本选择**: 开发测试用单版本，发布用both
3. **强制重建**: 仅在依赖更新或构建问题时使用
4. **标签管理**: 重要版本使用有意义的标签
5. **频率控制**: 避免频繁触发构建消耗资源

## 🎯 典型一天的工作流

```bash
# 早晨开始工作
git pull origin main

# 开发阶段 - 不触发构建
git commit -m "添加新配置选项"
git commit -m "修复注释错误"
git commit -m "更新README"

# 午间测试 - 触发测试构建
git commit -m "配置完成，中期测试 [build] [pg15]"

# 下午继续开发
git commit -m "优化性能参数"
git commit -m "添加错误处理"

# 下班前发布 - 完整构建
git commit -m "今日开发完成，发布测试版 [build] [both] [tag:daily-$(date +%Y%m%d)]"
```
