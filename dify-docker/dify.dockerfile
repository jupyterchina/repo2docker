# 使用 Ubuntu 22.04 作为基础镜像
FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV NODE_VERSION=18.x
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=dify
ENV POSTGRES_DB=dify
ENV REDIS_HOST=localhost
ENV REDIS_PORT=6379
ENV REDIS_PASSWORD=dify

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    postgresql \
    postgresql-contrib \
    redis-server \
    curl \
    nginx \
    git \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# 安装 Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
    && apt-get install -y nodejs

# 克隆 Dify 项目
RUN git clone https://github.com/langgenius/dify.git /app
WORKDIR /app

# 安装后端依赖
RUN pip3 install -r api/requirements.txt

# 安装前端依赖并构建
WORKDIR /app/web
RUN npm install
RUN npm run build

# 配置 PostgreSQL
USER postgres
RUN /etc/init.d/postgresql start && \
    psql -c "ALTER USER postgres WITH PASSWORD '$POSTGRES_PASSWORD';" && \
    psql -c "CREATE DATABASE $POSTGRES_DB;"
USER root

# 配置 Redis
RUN sed -i 's/^# requirepass.*/requirepass dify/' /etc/redis/redis.conf

# 配置 Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# 配置 Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 暴露端口
EXPOSE 80 3000 5001

# 启动服务
CMD ["/usr/bin/supervisord", "-n"]
