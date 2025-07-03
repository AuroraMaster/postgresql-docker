# 🌐 网络环境优化配置指南

## 📋 概述

本项目支持智能的网络环境检测和镜像源配置，确保在**国内**和**国际**网络环境下都能获得最佳的构建性能。

## 🎯 解决的问题

### 国内网络环境
- ✅ 使用清华大学等国内镜像源，提升下载速度
- ✅ 配置国内PyPI镜像，加速Python包安装
- ✅ 避免网络超时和连接失败

### 国际网络环境（GitHub Actions）
- ✅ 使用官方Debian镜像源，确保稳定性
- ✅ 配置官方PyPI源，避免镜像延迟
- ✅ 优化网络连接，减少构建失败

## 🚀 使用方法

### 1. 自动检测（推荐）
```bash
# 自动检测网络环境并构建
./build.sh build optimized latest auto
```

### 2. 手动指定环境
```bash
# 强制使用国内镜像源（适合国内用户，自动跳过Git扩展）
./build.sh build optimized latest china

# 强制使用国际镜像源（适合海外用户或CI/CD）
./build.sh build optimized latest international
```

### 3. 本地测试优化
```bash
# 国内环境本地测试 - 跳过Git扩展编译
SKIP_GIT_EXTENSIONS=true docker-compose build

# 或使用环境变量文件
echo "SKIP_GIT_EXTENSIONS=true" >> .env
docker-compose build
```

### 4. GitHub Actions自动配置
GitHub Actions会自动使用国际网络配置，包含完整的Git扩展编译。

## 🔧 技术实现

### 网络环境检测逻辑
```bash
# 检测网络环境
if curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
    # 国际网络环境
    NETWORK_ENVIRONMENT="international"
elif curl -s --connect-timeout 5 https://www.baidu.com > /dev/null; then
    # 国内网络环境
    NETWORK_ENVIRONMENT="china"
else
    # 网络检测失败，使用默认配置
    NETWORK_ENVIRONMENT="auto"
fi
```

### Dockerfile智能配置
```dockerfile
# 构建参数
ARG NETWORK_ENVIRONMENT=auto
ARG DEBIAN_MIRROR=auto
ARG PIP_INDEX_URL=auto

# 镜像源选择逻辑
RUN if [ "$NETWORK_ENVIRONMENT" = "international" ]; then \
        echo "使用国际镜像源" && \
        echo "deb https://deb.debian.org/debian bullseye main" > /etc/apt/sources.list; \
    else \
        echo "使用国内镜像源" && \
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main" > /etc/apt/sources.list; \
    fi
```

## 📊 性能对比

| 网络环境 | 镜像源 | Git扩展 | 预估构建时间 | 稳定性 |
|---------|--------|---------|-------------|---------|
| 国内网络 + 国内镜像源 | 清华大学 | 跳过 | ~8分钟 | ⭐⭐⭐⭐⭐ |
| 国内网络 + 国内镜像源 | 清华大学 | 编译 | ~15分钟 | ⭐⭐⭐⭐ |
| 国内网络 + 国际镜像源 | 官方源 | 编译 | ~45分钟 | ⭐⭐ |
| 国际网络 + 国际镜像源 | 官方源 | 编译 | ~20分钟 | ⭐⭐⭐⭐⭐ |

## 🛠️ GitHub Actions优化

### 自动网络环境配置
```yaml
- name: Configure build environment for international network
  run: |
    echo "🌐 Configuring international network environment..."
    echo "NETWORK_ENVIRONMENT=international" >> $GITHUB_ENV
    echo "BUILDKIT_PROGRESS=plain" >> $GITHUB_ENV
    echo "DOCKER_BUILDKIT=1" >> $GITHUB_ENV

- name: Build with network optimization
  uses: docker/build-push-action@v5
  with:
    build-args: |
      NETWORK_ENVIRONMENT=international
      DEBIAN_MIRROR=international
      PIP_INDEX_URL=https://pypi.org/simple
```

## 🔍 故障排除

### 构建超时
```bash
# 检查网络环境检测结果
./build.sh build optimized latest auto

# 如果自动检测失败，手动指定环境
./build.sh build optimized latest china  # 国内用户
./build.sh build optimized latest international  # 海外用户
```

### 镜像源连接问题
```bash
# 测试镜像源连接性
curl -I https://mirrors.tuna.tsinghua.edu.cn/debian/  # 国内镜像源
curl -I https://deb.debian.org/debian/                # 国际镜像源

# 根据测试结果选择合适的网络环境
```

### GitHub Actions构建失败
1. 检查是否正确设置了`NETWORK_ENVIRONMENT=international`
2. 确认build-args正确传递
3. 查看构建日志中的网络配置信息

## 📚 最佳实践

### 本地开发
- 使用自动检测：`./build.sh build optimized latest auto`
- 国内开发者可固定使用：`./build.sh build optimized latest china`

### CI/CD环境
- GitHub Actions：自动使用国际配置
- 其他CI：根据地理位置手动配置
- 容器化构建：传递正确的build-args

### Docker Compose
```yaml
services:
  postgres:
    build:
      context: .
      args:
        NETWORK_ENVIRONMENT: china  # 或 international
        DEBIAN_MIRROR: china
        PIP_INDEX_URL: https://pypi.tuna.tsinghua.edu.cn/simple
```

## 🚦 配置验证

验证网络环境配置是否正确：
```bash
# 构建时查看日志输出
./build.sh build optimized latest auto 2>&1 | grep "网络环境\|镜像源"

# 检查容器内的镜像源配置
docker run --rm your-image cat /etc/apt/sources.list
```

---

通过这套智能网络环境配置系统，确保项目在**全球范围内**都能获得最佳的构建体验！ 🌍✨
