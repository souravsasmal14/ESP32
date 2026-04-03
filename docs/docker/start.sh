#!/bin/bash

# --- 🚀 调试模式: 打印环境变量 (Debug Mode) ---
echo "--- ENVIRONMENT CHECK ---"
echo "MYSQLHOST: $MYSQLHOST"
echo "REDISHOST: $REDISHOST"
echo "MYSQL_URL: ${MYSQL_URL:0:15}... (Hidden)"
echo "REDIS_URL: ${REDIS_URL:0:15}... (Hidden)"
echo "--------------------------"

# --- 🎯 数据库与 Redis 配置 (使用 Railway 完整连接串) ---
# 修复 JDBC URL 格式并添加 SSL 属性
if [ ! -z "$MYSQL_URL" ]; then
    echo "✅ Using MYSQL_URL with JDBC conversion."
    # 将 mysql:// 替换为 jdbc:mysql:// 并添加强制性的 SSL 设置
    MYSQL_JDBC_URL=$(echo $MYSQL_URL | sed 's|^mysql://|jdbc:mysql://|')
    # 添加 allowPublicKeyRetrieval=true 和 useSSL=false 应对 Railway 5.7/8.0 常见连接错误
    if [[ "$MYSQL_JDBC_URL" == *"?"* ]]; then
        MYSQL_JDBC_URL="${MYSQL_JDBC_URL}&allowPublicKeyRetrieval=true&useSSL=false"
    else
        MYSQL_JDBC_URL="${MYSQL_JDBC_URL}?allowPublicKeyRetrieval=true&useSSL=false"
    fi
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_JDBC_URL} --spring.datasource.druid.username=${MYSQLUSER:-root} --spring.datasource.druid.password=${MYSQLPASSWORD:-123456}"
else
    DB_NAME=${MYSQLDATABASE:-"railway"}
    MYSQL_URL_FINAL="jdbc:mysql://${MYSQLHOST:-localhost}:${MYSQLPORT:-3306}/${DB_NAME}?allowPublicKeyRetrieval=true&useSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai"
    DB_OPTS="--spring.datasource.druid.url=${MYSQL_URL_FINAL} --spring.datasource.druid.username=${MYSQLUSER:-root} --spring.datasource.druid.password=${MYSQLPASSWORD:-123456}"
fi

if [ ! -z "$REDIS_URL" ]; then
    echo "✅ Using REDIS_URL for connection."
    REDIS_OPTS="--spring.data.redis.url=${REDIS_URL}"
else
    REDIS_OPTS="--spring.data.redis.host=${REDISHOST:-localhost} --spring.data.redis.port=${REDISPORT:-6379} --spring.data.redis.password=${REDISPASSWORD:-""}"
fi

# --- 🏃 启动 Java 后端 ---
echo "Starting Java Backend on internal port 8003..."
java -jar /app/xiaozhi-esp32-api.jar \
  --server.port=8003 \
  $DB_OPTS \
  $REDIS_OPTS &

# 等待 Java 后端监听
echo "Waiting for backend port 8003 to open..."
for i in {1..20}; do
    if bash -c "exec 6<>/dev/tcp/127.0.0.1/8003" 2>/dev/null; then
        echo "✅ Backend is UP!"
        break
    fi
    echo "Current retry: $i/20"
    sleep 2
done

# --- 🕸️ 适配 Railway 动态分配的公共端口 ---
if [ ! -z "$PORT" ]; then
    echo "Updating Nginx for Railway public port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# --- 启动 Nginx ---
echo "Starting Nginx..."
nginx -g 'daemon off;'