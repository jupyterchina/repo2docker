# 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置环境变量
ENV NODE_VERSION=18.x \
    POSTGRES_PASSWORD=difyai123456 \
    POSTGRES_DB=dify \
    REDIS_PASSWORD=difyai123456 \
    SANDBOX_API_KEY=dify-sandbox \
    PYTHONPATH=/app/api \
    PATH="/opt/venv/bin:$PATH"

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

# 创建工作目录并克隆代码
WORKDIR /app
RUN git clone --depth 1 --branch main https://github.com/langgenius/dify.git .

# 创建并激活 Python 虚拟环境
RUN python3 -m venv /opt/venv

# 安装后端依赖
WORKDIR /app/api
RUN pip3 install --upgrade pip \
    && pip3 install --no-cache-dir -r requirements.txt

# 安装并构建前端 Console
WORKDIR /app/web/console
RUN npm install \
    && npm run build

# 安装并构建前端 Share
WORKDIR /app/web/share
RUN npm install \
    && npm run build

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