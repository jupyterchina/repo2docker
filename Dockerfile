# 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置环境变量
ENV NODE_VERSION=18.x \
    POSTGRES_PASSWORD=difyai123456 \
    POSTGRES_DB=dify \
    REDIS_PASSWORD=difyai123456 \
    SANDBOX_API_KEY=dify-sandbox

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    supervisor \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 从官方镜像中拉取已经构建好的应用
FROM langgenius/dify-api:0.11.0 AS api
FROM langgenius/dify-web:0.11.0 AS web

# 复制应用文件
COPY --from=api /app /app
COPY --from=web /app/web /app/web

# 配置 PostgreSQL
USER postgres
RUN /etc/init.d/postgresql start && \
    psql -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';" && \
    psql -c "CREATE DATABASE ${POSTGRES_DB};"
USER root

# 配置 Redis
RUN sed -i 's/^# requirepass .*/requirepass '${REDIS_PASSWORD}'/' /etc/redis/redis.conf

# 配置 Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# 添加 supervisor 配置
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 创建需要的目录
RUN mkdir -p /app/api/storage/logs && \
    chown -R www-data:www-data /app/api/storage

# 复制启动脚本
COPY <<-'EOF' /app/start.sh
#!/bin/bash
service postgresql start
service redis-server start
supervisord -n
EOF

RUN chmod +x /app/start.sh

# 暴露端口
EXPOSE 80

CMD ["/app/start.sh"]