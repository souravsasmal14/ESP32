#!/bin/bash

# --- 🚀 调试模式: 打印环境变量 (Debug Mode) ---
echo "--- ENVIRONMENT CHECK ---"
echo "MYSQLHOST: $MYSQLHOST (Link success if not empty)"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "REDISHOST: $REDISHOST (Link success if not empty)"
echo "REDIS_URL: ${REDIS_URL:0:10}... (Hidden for security)"
echo "DB_URL: ${MYSQL_URL:0:10}... (Hidden for security)"
echo "PORT: $PORT"
echo "--------------------------"

# --- 🎯 数据库配置 (Railway 环境自动适配) ---

# 优先使用完整的 CONNECTION_URL (如果存在)
if [ ! -z "$MYSQL_URL" ]; then
    echo "✅ Found MYSQL_URL, using it for database connection."
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_URL}"
else
    # 否则使用单个字段拼接
    DB_NAME=${MYSQLDATABASE:-"xiaozhi_esp32_server"}
    if [ "$MYSQLDATABASE" == "railway" ]; then
        DB_NAME="railway"
    fi
    MYSQL_URL_FINAL="jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${DB_NAME}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true"
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_URL_FINAL} --spring.datasource.druid.username=${MYSQLUSER:-root} --spring.datasource.druid.password=${MYSQLPASSWORD:-123456}"
fi

# --- 🎯 Redis 配置 ---
if [ ! -z "$REDIS_URL" ]; then
    echo "✅ Found REDIS_URL, using it for Redis connection."
    REDIS_OPTS="--spring.data.redis.url=${REDIS_URL}"
else
    # 否则使用单个字段拼接
    REDIS_OPTS="--spring.data.redis.host=${REDISHOST:-localhost} --spring.data.redis.port=${REDISPORT:-6379} --spring.data.redis.password=${REDISPASSWORD:-""}"
fi

# --- 🛡️ 等待数据库准备就绪 (解决应用启动过快导致崩溃) ---
HOST_TO_CHECK=${MYSQLHOST:-localhost}
PORT_TO_CHECK=${MYSQLPORT:-3306}

echo "Probing Database at ${HOST_TO_CHECK}:${PORT_TO_CHECK}..."
for i in {1..30}; do
    if bash -c "exec 6<>/dev/tcp/${HOST_TO_CHECK}/${PORT_TO_CHECK}" 2>/dev/null; then
        echo "✅ Database portal is OPEN!"
        exec 6>&-
        break
    fi
    echo "⏳ Database portal not open yet (attempt $i/30), retrying in 2s..."
    sleep 2
done

# --- 🏃 启动 Java 后端 ---
echo "Starting Java Backend on internal port 8003..."
java -jar /app/xiaozhi-esp32-api.jar \
  --server.port=8003 \
  $DB_OPTS \
  $REDIS_OPTS &

# 检查后端是否启动成功 (等待 5s)
sleep 5
echo "Checking if Java Backend is responding..."
if bash -c "exec 6<>/dev/tcp/127.0.0.1/8003" 2>/dev/null; then
    echo "✅ Java Backend is UP and listening!"
else
    echo "⚠️ Warning: Java Backend is taking its time. It may still be finishing Liquibase migrations."
fi

# --- 🕸️ 适配 Railway 动态分配的公共端口 ---
if [ ! -z "$PORT" ]; then
    echo "Updating Nginx to serve on Railway public port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# --- 启动 Nginx ---
echo "Starting Nginx frontend..."
nginx -g 'daemon off;'