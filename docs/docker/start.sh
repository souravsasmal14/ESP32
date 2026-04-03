#!/bin/bash

# --- 数据库配置 (Railway 环境自动适配) ---
# 使用 Railway 注入的变量，否则回退到默认值
MYSQL_URL_FINAL=${SPRING_DATASOURCE_DRUID_URL:-"jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${MYSQLDATABASE:-xiaozhi_esp32_server}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai&nullCatalogMeansCurrent=true"}
MYSQL_USER_FINAL=${SPRING_DATASOURCE_DRUID_USERNAME:-${MYSQLUSER:-root}}
MYSQL_PASS_FINAL=${SPRING_DATASOURCE_DRUID_PASSWORD:-${MYSQLPASSWORD:-123456}}

REDIS_HOST_FINAL=${SPRING_DATA_REDIS_HOST:-${REDISHOST:-localhost}}
REDIS_PORT_FINAL=${SPRING_DATA_REDIS_PORT:-${REDISPORT:-6379}}
REDIS_PASS_FINAL=${SPRING_DATA_REDIS_PASSWORD:-${REDISPASSWORD:-""}}

# --- 等待数据库准备就绪 (解决应用启动过快导致崩溃) ---
if [ ! -z "$MYSQLHOST" ]; then
    echo "Waiting for MySQL at ${MYSQLHOST}:${MYSQLPORT:-3306}..."
    # 使用 bash 的 /dev/tcp 特性进行探测
    for i in {1..30}; do
        if bash -c "exec 6<>/dev/tcp/${MYSQLHOST}/${MYSQLPORT:-3306}" 2>/dev/null; then
            echo "MySQL is ready!"
            exec 6>&-
            break
        fi
        echo "MySQL not ready yet, retrying in 2s..."
        sleep 2
    done
fi

# 启动 Java 后端 (监听 8003，仅对 Nginx 内部开放)
echo "Starting Java Backend on port 8003..."
java -jar /app/xiaozhi-esp32-api.jar \
  --server.port=8003 \
  --spring.datasource.druid.url="${MYSQL_URL_FINAL}" \
  --spring.datasource.druid.username="${MYSQL_USER_FINAL}" \
  --spring.datasource.druid.password="${MYSQL_PASS_FINAL}" \
  --spring.data.redis.host="${REDIS_HOST_FINAL}" \
  --spring.data.redis.password="${REDIS_PASS_FINAL}" \
  --spring.data.redis.port="${REDIS_PORT_FINAL}" &

# 适配 Railway 动态分配的公共端口
if [ ! -z "$PORT" ]; then
    echo "Adapting Nginx to Railway's public port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# 启动 Nginx (前台运行保持容器活动)
echo "Starting Nginx..."
nginx -g 'daemon off;'