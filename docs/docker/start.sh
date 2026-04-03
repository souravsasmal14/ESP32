#!/bin/bash

# --- 🚀 强制设置环境变量 (Force Environment Variables) ---
# 这些变量会覆盖 application.yml 中的任何 localhost 设置

if [ ! -z "$MYSQL_URL" ]; then
    echo "✅ Using MYSQL_URL from Railway."
    # 将 mysql:// 替换为 jdbc:mysql://
    RAW_JDBC=$(echo $MYSQL_URL | sed 's|^mysql://|jdbc:mysql://|')
    
    # 智能添加 allowPublicKeyRetrieval=true 和 useSSL=false 应对 Railway SSL 问题
    if [[ "$RAW_JDBC" == *"?"* ]]; then
        export SPRING_DATASOURCE_DRUID_URL="${RAW_JDBC}&allowPublicKeyRetrieval=true&useSSL=false"
    else
        export SPRING_DATASOURCE_DRUID_URL="${RAW_JDBC}?allowPublicKeyRetrieval=true&useSSL=false"
    fi
else
    # 备选使用单个字段拼接
    echo "⚠️ MYSQL_URL not found, building from components."
    export SPRING_DATASOURCE_DRUID_URL="jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${MYSQLDATABASE:-railway}?allowPublicKeyRetrieval=true&useSSL=false"
fi

export SPRING_DATASOURCE_DRUID_USERNAME="${MYSQLUSER:-root}"
export SPRING_DATASOURCE_DRUID_PASSWORD="${MYSQLPASSWORD:-123456}"

if [ ! -z "$REDIS_URL" ]; then
    export SPRING_DATA_REDIS_URL="${REDIS_URL}"
else
    export SPRING_DATA_REDIS_HOST="${REDISHOST:-localhost}"
    export SPRING_DATA_REDIS_PORT="${REDISPORT:-6379}"
    export SPRING_DATA_REDIS_PASSWORD="${REDISPASSWORD}"
fi

# 确保以 prod 模式启动，避免读取 application-dev.yml
export SPRING_PROFILES_ACTIVE=prod

echo "--- 🛠️ DEBUG: Connection Params ---"
echo "Spring Datasource URL: ${SPRING_DATASOURCE_DRUID_URL:0:30}..."
echo "-----------------------------------"

# --- 🏃 启动 Java 后端 ---
echo "Starting Java Backend on port 8002..."
java -jar /app/xiaozhi-esp32-api.jar --server.port=8002 &

# --- 🛰️ 配置 Nginx ---
if [ ! -z "$PORT" ]; then
    echo "Updating Nginx for Railway public port: $PORT"
    # 修改 listen 这里的逻辑，确保 Nginx 对外使用 Railway PORT 变量
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# 确保 Nginx 代理到 127.0.0.1:8002
sed -i 's/proxy_pass http:\/\/127.0.0.1:8003;/proxy_pass http:\/\/127.0.0.1:8002;/' /etc/nginx/nginx.conf

# --- 启动 Nginx ---
echo "Starting Nginx frontend..."
nginx -g 'daemon off;'