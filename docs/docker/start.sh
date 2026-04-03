#!/bin/bash

# --- 🎯 强制生产环境配置 (PROD OVERRIDE) ---
# 使用 Spring Boot 宽松绑定属性，确保覆盖 application.yml
export SPRING_PROFILES_ACTIVE=prod

# 数据库
export SPRING_DATASOURCE_DRUID_URL="jdbc:mysql://mysql.railway.internal:3306/railway?allowPublicKeyRetrieval=true&useSSL=false&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_DRUID_USERNAME="root"
export SPRING_DATASOURCE_DRUID_PASSWORD="sLCTiEareeqSjFEwftJTeuGbUeylEjId"

# Redis
export SPRING_DATA_REDIS_HOST="redis.railway.internal"
export SPRING_DATA_REDIS_PORT="6379"
export SPRING_DATA_REDIS_PASSWORD="hurbSCLJsRDHppIllmbNeEwJKzkyRwlS"

echo "🚀 Starting Java Backend with Hardcoded Railway Internal Config..."
java -Dserver.port=8002 -jar /app/xiaozhi-esp32-api.jar &

# 等待 Java 启动
sleep 5

# --- 🕸️ Nginx 配置 ---
if [ ! -z "$PORT" ]; then
    echo "🌐 Setting Nginx to listen on Railway Port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# 确保代理指向 8002
sed -i 's/proxy_pass http:\/\/127.0.0.1:[0-9]*;/proxy_pass http:\/\/127.0.0.1:8002;/' /etc/nginx/nginx.conf

echo "✨ Starting Nginx Service..."
nginx -g 'daemon off;'