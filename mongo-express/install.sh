#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight Mongo Express 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

# 替换 docker-compose.yml 中的配置
sed -i "s|ME_CONFIG_MONGODB_SERVER:.*|ME_CONFIG_MONGODB_SERVER: ${MONGODB_HOST}|g" docker-compose.yml
sed -i "s|ME_CONFIG_MONGODB_URL:.*|ME_CONFIG_MONGODB_URL: mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@${MONGODB_HOST}:27017/?authSource=admin|g" docker-compose.yml
sed -i "s|ME_CONFIG_MONGODB_ADMINUSERNAME:.*|ME_CONFIG_MONGODB_ADMINUSERNAME: ${MONGO_ROOT_USERNAME}|g" docker-compose.yml
sed -i "s|ME_CONFIG_MONGODB_ADMINPASSWORD:.*|ME_CONFIG_MONGODB_ADMINPASSWORD: ${MONGO_ROOT_PASSWORD}|g" docker-compose.yml
sed -i "s|ME_CONFIG_BASICAUTH_USERNAME:.*|ME_CONFIG_BASICAUTH_USERNAME: ${MONGO_EXPRESS_USERNAME}|g" docker-compose.yml
sed -i "s|ME_CONFIG_BASICAUTH_PASSWORD:.*|ME_CONFIG_BASICAUTH_PASSWORD: ${MONGO_EXPRESS_PASSWORD}|g" docker-compose.yml
sed -i "s|\"[0-9]*:8081\"|\"${MONGO_EXPRESS_PORT}:8081\"|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "启动 Mongo Express 容器..."
docker-compose up -d

sleep 3
docker-compose ps

echo ""
print_separator
echo "       Mongo Express 安装完成!"
print_separator
echo "Mongo Express 地址: http://${HOST_IP}:${MONGO_EXPRESS_PORT}"
echo "用户名: ${MONGO_EXPRESS_USERNAME}"
echo ""