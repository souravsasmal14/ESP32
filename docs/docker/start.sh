#!/bin/bash

# --- 🚀 Debug: List all files in /app to locate the JAR ---
echo "--- LISTING / ---"
ls -F /
echo "--- LISTING /app ---"
ls -F /app 2>/dev/null || echo "/app not found"

# --- 🎯 Search for the JAR file anywhere ---
echo "Searching for xiaozhi-esp32-api.jar..."
export BACKEND_JAR=$(find / -name "xiaozhi-esp32-api.jar" 2>/dev/null | head -n 1)

if [ -z "$BACKEND_JAR" ]; then
    echo "❌ CRITICAL ERROR: xiaozhi-esp32-api.jar NOT FOUND in the container!"
    # Fallback guess
    BACKEND_JAR="/app/xiaozhi-esp32-api.jar"
else
    echo "✅ SUCCESS: JAR found at $BACKEND_JAR"
fi

# --- 🎯 Database & Redis URLs (Railway) ---
# Use JDBC prefix fix
if [ ! -z "$MYSQL_URL" ]; then
    MYSQL_JDBC_URL=$(echo $MYSQL_URL | sed 's|^mysql://|jdbc:mysql://|')
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_JDBC_URL} --spring.datasource.druid.username=${MYSQLUSER:-root} --spring.datasource.druid.password=${MYSQLPASSWORD:-123456}"
else
    DB_NAME=${MYSQLDATABASE:-"railway"}
    MYSQL_URL_FINAL="jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${DB_NAME}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true"
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_URL_FINAL} --spring.datasource.druid.username=${MYSQLUSER:-root} --spring.datasource.druid.password=${MYSQLPASSWORD:-123456}"
fi

if [ ! -z "$REDIS_URL" ]; then
    REDIS_OPTS="--spring.data.redis.url=${REDIS_URL}"
else
    REDIS_OPTS="--spring.data.redis.host=${REDISHOST:-localhost} --spring.data.redis.port=${REDISPORT:-6379} --spring.data.redis.password=${REDISPASSWORD:-""}"
fi

# --- 🏃 Start Java Backend ---
echo "Starting Java Backend on port 8003..."
java -jar "$BACKEND_JAR" \
  --server.port=8003 \
  $DB_OPTS \
  $REDIS_OPTS &

# --- 🕸️ Change Port in Nginx ---
if [ ! -z "$PORT" ]; then
    echo "Updating Nginx for Railway port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# --- 启动 Nginx ---
echo "Starting Nginx frontend..."
nginx -g 'daemon off;'