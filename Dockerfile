# 第一阶段：从官方 API 镜像获取文件
FROM langgenius/dify-api:0.11.0 as api

# 第二阶段：从官方 Web 镜像获取文件
FROM langgenius/dify-web:0.11.0 as web

# 最终阶段：构建运行环境
FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置环境变量
ENV NODE_VERSION=18.x
ENV POSTGRES_PASSWORD=difyai123456
ENV POSTGRES_DB=dify
ENV REDIS_PASSWORD=difyai123456
ENV SANDBOX_API_KEY=dify-sandbox

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-dev \
    python3.10-venv \
    postgresql \
    postgresql-contrib \
    redis-server \
    curl \
    nginx \
    git \
    supervisor \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
    && apt-get install -y nodejs

# 创建工作目录
WORKDIR /app

# 从之前的阶段复制文件
COPY --from=api /app/api /app/api
COPY --from=web /app/web /app/web

# 创建并激活 Python 虚拟环境
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 更新 pip 并安装后端依赖
RUN pip3 install --upgrade pip
WORKDIR /app/api
RUN pip3 install --no-cache-dir -r requirements.txt

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

# 设置工作目录
WORKDIR /app

# 添加 supervisor 配置
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 创建需要的目录
RUN mkdir -p /app/api/storage/logs && \
    chown -R www-data:www-data /app/api/storage

# 暴露端口
EXPOSE 80

# 启动脚本
RUN echo '#!/bin/bash\n\
service postgresql start\n\
service redis-server start\n\
supervisord -n' > /app/start.sh && \
chmod +x /app/start.sh

CMD ["/app/start.sh"]