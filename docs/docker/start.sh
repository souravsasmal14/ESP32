#!/bin/bash

# --- Database configuration (Dynamic mapping for Railway) ---
# Use individual components if available, otherwise fallback to defaults or explicit variables
MYSQL_URL_FINAL=${SPRING_DATASOURCE_DRUID_URL:-"jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${MYSQLDATABASE:-xiaozhi_esp32_server}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true"}
MYSQL_USER_FINAL=${SPRING_DATASOURCE_DRUID_USERNAME:-${MYSQLUSER:-root}}
MYSQL_PASS_FINAL=${SPRING_DATASOURCE_DRUID_PASSWORD:-${MYSQLPASSWORD:-123456}}

REDIS_HOST_FINAL=${SPRING_DATA_REDIS_HOST:-${REDISHOST:-localhost}}
REDIS_PORT_FINAL=${SPRING_DATA_REDIS_PORT:-${REDISPORT:-6379}}
REDIS_PASS_FINAL=${SPRING_DATA_REDIS_PASSWORD:-${REDISPASSWORD:-""}}

# 启动Java后端（docker内监听8003端口）
echo "Starting Java Backend on port 8003..."
java -jar /app/xiaozhi-esp32-api.jar \
  --server.port=8003 \
  --spring.datasource.druid.url="${MYSQL_URL_FINAL}" \
  --spring.datasource.druid.username="${MYSQL_USER_FINAL}" \
  --spring.datasource.druid.password="${MYSQL_PASS_FINAL}" \
  --spring.data.redis.host="${REDIS_HOST_FINAL}" \
  --spring.data.redis.password="${REDIS_PASS_FINAL}" \
  --spring.data.redis.port="${REDIS_PORT_FINAL}" &

# 更新Nginx端口从Railway提供的PORT变量（如果存在）
if [ ! -z "$PORT" ]; then
  echo "Updating Nginx port to $PORT"
  sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# 启动Nginx（前台运行保持容器存活）
echo "Starting Nginx..."
nginx -g 'daemon off;'