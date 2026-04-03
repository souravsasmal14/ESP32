#!/bin/bash

# --- 🚀 调试模式: 打印环境变量 (Debug Mode) ---
echo "--- ENVIRONMENT CHECK ---"
echo "MYSQLHOST: $MYSQLHOST"
echo "MYSQLPORT: $MYSQLPORT"
echo "MYSQLDATABASE: $MYSQLDATABASE"
echo "MYSQLUSER: $MYSQLUSER"
echo "REDISHOST: $REDISHOST"
echo "PORT: $PORT"
echo "--------------------------"

# --- 🎯 数据库配置 (Railway 环境自动适配) ---
# 检查默认数据库名是否为 railway
DB_NAME=${MYSQLDATABASE:-"xiaozhi_esp32_server"}
if [ "$MYSQLDATABASE" == "railway" ]; then
    echo "Using default Railway database name: railway"
    DB_NAME="railway"
fi

MYSQL_URL_FINAL="jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${DB_NAME}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true"
echo "Connecting to MySQL at: ${MYSQL_URL_FINAL}"

MYSQL_USER_FINAL=${MYSQLUSER:-root}
MYSQL_PASS_FINAL=${MYSQLPASSWORD:-123456}

REDIS_HOST_FINAL=${REDISHOST:-localhost}
REDIS_PORT_FINAL=${REDISPORT:-6379}
REDIS_PASS_FINAL=${REDISPASSWORD:-""}

# --- 🛡️ 等待数据库准备就绪 (解决应用启动过快导致崩溃) ---
if [ ! -z "$MYSQLHOST" ]; then
    echo "Probing MySQL at ${MYSQLHOST}:${MYSQLPORT:-3306}..."
    for i in {1..30}; do
        if bash -c "exec 6<>/dev/tcp/${MYSQLHOST}/${MYSQLPORT:-3306}" 2>/dev/null; then
            echo "✅ MySQL is ready and responding!"
            exec 6>&-
            break
        fi
        echo "⏳ MySQL not ready yet (attempt $i/30), retrying in 2s..."
        sleep 2
    done
fi

# --- 🏃 启动 Java 后端 ---
echo "Starting Java Backend on internal port 8003..."
# 使用 nohup 运行并重定向输出以便调试
java -jar /app/xiaozhi-esp32-api.jar \
  --server.port=8003 \
  --spring.datasource.druid.url="${MYSQL_URL_FINAL}" \
  --spring.datasource.druid.username="${MYSQL_USER_FINAL}" \
  --spring.datasource.druid.password="${MYSQL_PASS_FINAL}" \
  --spring.data.redis.host="${REDIS_HOST_FINAL}" \
  --spring.data.redis.password="${REDIS_PASS_FINAL}" \
  --spring.data.redis.port="${REDIS_PORT_FINAL}" &

# 等待后端端口检查
sleep 5
if bash -c "exec 6<>/dev/tcp/127.0.0.1/8003" 2>/dev/null; then
    echo "✅ Java Backend is UP on port 8003!"
else
    echo "⚠️ Java Backend is NOT responding on port 8003 yet. Check JAR logs."
fi

# --- 🕸️ 适配 Railway 动态分配的公共端口 ---
if [ ! -z "$PORT" ]; then
    echo "Adapting Nginx to Railway's public port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# --- 启动 Nginx ---
echo "Starting Nginx..."
nginx -g 'daemon off;'