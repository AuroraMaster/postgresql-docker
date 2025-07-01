# 🚀 自动构建触发器使用指南

本项目支持通过**Git提交消息参数**自动触发Docker镜像构建，无需手动操作GitHub Actions。

## 📝 基本用法

在Git提交消息中加入特定的标签即可触发自动构建：

```bash
git commit -m "修复数据库连接问题 [build] [pg15]"
git push origin main
```

## 🏷️ 支持的构建标签

### 构建触发器（必需）
以下任一标签都可以触发构建：
- `[build]` - 英文标签
- `[构建]` - 中文标签
- `--build` - 命令行风格

### PostgreSQL版本选择
- `[pg15]` 或 `[postgresql-15]` 或 `--pg15` - 仅构建PostgreSQL 15
- `[pg16]` 或 `[postgresql-16]` 或 `--pg16` - 仅构建PostgreSQL 16
- `[pgboth]` 或 `[postgresql-both]` 或 `--pgboth` 或 `[both]` - 构建两个版本

**默认**: 如果不指定版本，默认构建PostgreSQL 15

### 强制重建（可选）
- `[force]` 或 `[强制]` 或 `--force` 或 `--no-cache` - 强制重建，不使用缓存

### 标签后缀（可选）
- `[tag:自定义后缀]` - 为Docker镜像添加自定义标签后缀

## 📚 提交消息示例

### 基本构建
```bash
# 构建PostgreSQL 15 (默认)
git commit -m "更新配置文件 [build]"

# 构建PostgreSQL 16
git commit -m "添加新功能 [build] [pg16]"

# 构建两个版本
git commit -m "重要更新 [build] [both]"
```

### 强制重建
```bash
# 强制重建PostgreSQL 15，不使用缓存
git commit -m "修复构建问题 [build] [pg15] [force]"

# 强制重建所有版本
git commit -m "依赖更新 [build] [both] [force]"
```

### 自定义标签
```bash
# 添加自定义标签后缀
git commit -m "发布版本 [build] [pg15] [tag:v1.2.0]"

# 组合使用
git commit -m "紧急修复 [build] [both] [force] [tag:hotfix]"
```

### 多种写法
```bash
# 中文标签
git commit -m "数据库优化 [构建] [强制]"

# 命令行风格
git commit -m "update extensions --build --pg16 --force"

# 混合风格
git commit -m "重要更新 [build] --pg16 [tag:release]"
```

## 🔍 构建触发逻辑

1. **触发检查**: 提交消息必须包含构建触发器标签
2. **版本解析**: 按优先级解析PostgreSQL版本（both > 16 > 15）
3. **参数提取**: 解析强制重建和标签后缀参数
4. **构建执行**: 根据解析的参数执行相应的构建job

## 🚫 不触发构建的提交

如果提交消息不包含构建触发器，则**不会**触发构建：

```bash
# 这些提交不会触发构建
git commit -m "更新文档"
git commit -m "代码重构"
git commit -m "修复拼写错误"
git commit -m "添加注释"
```

## 📊 构建状态检查

构建触发后，可以在以下位置查看状态：

1. **GitHub Actions页面**: `https://github.com/你的用户名/postgresql-docker/actions`
2. **提交页面**: 提交旁边会显示构建状态图标
3. **Releases页面**: 成功构建后会自动创建Release

## 🔧 手动触发（备用方案）

除了提交消息触发，仍然支持手动触发：

### 使用脚本
```bash
./build-helper.sh trigger 15          # 构建PG15
./build-helper.sh trigger 16 true     # 强制构建PG16
./build-helper.sh trigger both false  # 构建两个版本
```

### 使用GitHub网页界面
1. 访问 Actions 页面
2. 选择 "Build Custom PostgreSQL Docker Images"
3. 点击 "Run workflow"
4. 填写参数并执行

## 📝 最佳实践

1. **明确意图**: 在提交消息中清楚说明为什么要构建
2. **版本选择**: 根据实际需求选择合适的PostgreSQL版本
3. **强制重建**: 仅在必要时使用（如依赖更新、构建问题）
4. **标签管理**: 使用有意义的标签后缀进行版本管理

## ❗ 注意事项

- 构建过程需要5-15分钟，请耐心等待
- 强制重建会清除缓存，构建时间更长
- 同时构建两个版本会消耗更多资源
- 频繁触发构建可能受到GitHub Actions使用限制

## 🐛 故障排除

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
# 查看构建状态
./build-helper.sh status

# 强制重建
git commit --amend -m "修复构建问题 [build] [pg15] [force]"
git push --force-with-lease origin main
```

### 参数解析错误
- 使用`./build-helper.sh test-commit "消息"`验证解析
- 确保标签格式正确（方括号、正确拼写）
- 避免在标签中使用特殊字符
