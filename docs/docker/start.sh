#!/bin/bash

# --- 🚀 调试模式: 打印环境变量 (Debug Mode) ---
echo "--- ENVIRONMENT CHECK ---"
echo "MYSQLHOST: $MYSQLHOST"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "REDISHOST: $REDISHOST"
echo "REDIS_URL: ${REDIS_URL:0:15}... (Hidden)"
echo "MYSQL_URL: ${MYSQL_URL:0:15}... (Hidden)"
echo "PORT: $PORT"
echo "--------------------------"

# --- 🎯 数据库配置 (Railway 环境自动适配) ---

# 优先使用完整的 CONNECTION_URL (如果存在)
if [ ! -z "$MYSQL_URL" ]; then
    echo "✅ Found MYSQL_URL, fixing for JDBC."
    # Change mysql:// to jdbc:mysql:// if needed
    MYSQL_JDBC_URL=$(echo $MYSQL_URL | sed 's|^mysql://|jdbc:mysql://|')
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_JDBC_URL} --spring.datasource.druid.username=${MYSQLUSER:-root} --spring.datasource.druid.password=${MYSQLPASSWORD:-123456}"
    echo "Using JDBC URL: ${MYSQL_JDBC_URL:0:20}..."
else
    # 否则使用单个字段拼接
    DB_NAME=${MYSQLDATABASE:-"railway"}
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

# --- 🛡️ 等待数据库准备就绪 (使用 127.0.0.1 也可以，但最好检查 host) ---
HOST_TO_CHECK=${MYSQLHOST:-localhost}
PORT_TO_CHECK=${MYSQLPORT:-3306}

echo "Probing Database portal at ${HOST_TO_CHECK}:${PORT_TO_CHECK}..."
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
sleep 8
echo "Final Backend check..."
if bash -c "exec 6<>/dev/tcp/127.0.0.1/8003" 2>/dev/null; then
    echo "✅✅ Java Backend is CONFIRMED UP!"
else
    echo "⚠️ Java Backend is taking its time... showing Nginx anyway."
fi

# --- 🕸️ 适配 Railway 动态分配的公共端口 ---
if [ ! -z "$PORT" ]; then
    echo "Exposing Nginx on Railway port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# --- 启动 Nginx ---
echo "Starting Nginx frontend..."
nginx -g 'daemon off;'