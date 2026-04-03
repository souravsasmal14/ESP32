#!/bin/bash

# --- 🚀 NUCLEAR CONNECTION OPTION: HARDCODED CREDENTIALS ---
# This forces the app to look exactly at Railway's internal network, bypassing ALL configurations.

export SPRING_DATASOURCE_DRUID_URL="jdbc:mysql://mysql.railway.internal:3306/railway?allowPublicKeyRetrieval=true&useSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai"
export SPRING_DATASOURCE_DRUID_USERNAME="root"
export SPRING_DATASOURCE_DRUID_PASSWORD="sLCTiEareeqSjFEwftJTeuGbUeylEjId"

export SPRING_DATA_REDIS_URL="redis://default:hurbSCLJsRDHppIllmbNeEwJKzkyRwlS@redis.railway.internal:6379"

export SPRING_PROFILES_ACTIVE=prod

echo "--- 🛠️ DEBUG: Connection Params ---"
echo "Spring Datasource URL is hardcoded to Railway internal."
echo "-----------------------------------"

# --- 🏃 Start Java Backend ---
echo "Starting Java Backend on port 8003..."
java -jar /app/xiaozhi-esp32-api.jar --server.port=8003 &

# --- 🛰️ Configure Nginx ---
if [ ! -z "$PORT" ]; then
    echo "Updating Nginx for Railway public port: $PORT"
    sed -i "s/listen  8002;/listen ${PORT};/" /etc/nginx/nginx.conf
fi

# Ensure Nginx proxies to the correct port (8003)
sed -i 's/proxy_pass http:\/\/127.0.0.1:8002;/proxy_pass http:\/\/127.0.0.1:8003;/' /etc/nginx/nginx.conf

# --- Start Nginx ---
echo "Starting Nginx frontend..."
nginx -g 'daemon off;'