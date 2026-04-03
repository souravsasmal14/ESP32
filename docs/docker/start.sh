#!/bin/bash

# --- 🚀 强制设置环境变量 (Force Environment Variables) ---
# 这些变量会覆盖 application.yml 中的任何 localhost 设置

if [ ! -z "$MYSQL_URL" ]; then
    echo "✅ Forcing MySQL Connection via MYSQL_URL"
    # 将 mysql:// 转换为 jdbc:mysql:// 并添加强制参数
    export SPRING_DATASOURCE_DRUID_URL=$(echo $MYSQL_URL | sed 's|^mysql://|jdbc:mysql://|' | sed 's|?|?allowPublicKeyRetrieval=true\&useSSL=false\&|')
    if [[ ! "$SPRING_DATASOURCE_DRUID_URL" == *"?"* ]]; then
        export SPRING_DATASOURCE_DRUID_URL="${SPRING_DATASOURCE_DRUID_URL}?allowPublicKeyRetrieval=true&useSSL=false"
    fi
else
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

echo "--- CONNECTION DEBUG ---"
echo "Spring Datasource URL: ${SPRING_DATASOURCE_DRUID_URL:0:30}..."
echo "-----------------------"

# --- 🏃 启动 Java 后端 ---
echo "Starting Java Backend on port 8002..."
java -jar /app/xiaozhi-esp32-api.jar --server.port=8002 &

# --- 🕸️ 配置 Nginx ---
if [ ! -z "$PORT" ]; then
    echo "Updating Nginx for Railway public port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# 修改 Nginx 反向代理到 Java 后端 (确保指向 8002)
sed -i 's/proxy_pass http:\/\/127.0.0.1:8003;/proxy_pass http:\/\/127.0.0.1:8002;/' /etc/nginx/nginx.conf

# --- 启动 Nginx ---
echo "Starting Nginx frontend..."
nginx -g 'daemon off;'