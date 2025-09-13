# 简化版Dockerfile - 使用本地构建内容

# 构建阶段：仅构建后端
FROM python:3.9-slim AS backend-builder

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制后端源码
COPY backend.py .

# 最终运行镜像
FROM python:3.9-slim

# 安装nginx
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# 创建应用用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# 复制本地构建的前端文件（需要先在本地执行npm run build）
COPY ./dist ./dist

# 从构建阶段复制后端文件
COPY --from=backend-builder /app/requirements.txt .
COPY --from=backend-builder /app/backend.py .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制nginx配置
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/default.conf /etc/nginx/conf.d/default.conf

# 复制启动脚本
COPY docker/start.sh /app/start.sh

# 设置权限
RUN chmod +x /app/start.sh

# 创建必要目录并设置权限
RUN mkdir -p /app/logs /var/lib/nginx/body /var/lib/nginx/proxy /var/lib/nginx/fastcgi /var/lib/nginx/uwsgi /var/lib/nginx/scgi \
    && touch /app/logs/backend.log \
    && touch /app/logs/nginx.access.log \
    && touch /app/logs/nginx.error.log \
    && chown -R appuser:appuser /app /var/lib/nginx \
    && chmod -R 755 /app/logs /var/lib/nginx

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# 暴露端口
EXPOSE 80

# 切换到应用用户
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/api/health || exit 1

# 启动命令
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/start.sh"]