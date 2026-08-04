#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight Code Interpreter API 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

mkdir -p data logs dashboard

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 根据中间件部署模式确定连接地址
REDIS_CONN_HOST="${REDIS_HOST}"
REDIS_CONN_PORT="${REDIS_PORT}"
MINIO_CONN_ENDPOINT="$(get_minio_internal_endpoint)"

# 替换 .env 中的配置
update_env_key .env API_PORT "${CODE_INTERPRETER_API_PORT}"
update_env_key .env HTTPS_PORT "${CODE_INTERPRETER_HTTPS_PORT}"
update_env_key .env API_KEY "${LIBRECHAT_CODE_API_KEY}"
update_env_key .env MASTER_API_KEY "${CODE_INTERPRETER_MASTER_API_KEY}"
update_env_key .env REDIS_HOST "${REDIS_CONN_HOST}"
update_env_key .env REDIS_PORT "${REDIS_CONN_PORT}"
update_env_key .env REDIS_PASSWORD "${REDIS_PASSWORD}"
update_env_key .env MINIO_ENDPOINT "${MINIO_CONN_ENDPOINT}"
update_env_key .env MINIO_ACCESS_KEY "${MINIO_ACCESS_KEY}"
update_env_key .env MINIO_SECRET_KEY "${MINIO_SECRET_KEY}"
update_env_key .env MINIO_BUCKET "${MINIO_BUCKET}"
update_env_key .env MINIO_REGION "${MINIO_REGION}"
update_env_key .env MINIO_SECURE "${MINIO_SECURE}"
update_env_key .env CONTAINER_POOL_PY "${CONTAINER_POOL_PY}"
update_env_key .env CONTAINER_POOL_JS "${CONTAINER_POOL_JS}"
update_env_key .env WAN_DNS_SERVERS "${WAN_DNS_SERVERS}"

# 自动检测宿主机 docker 组 GID
DOCKER_GID=$(getent group docker 2>/dev/null | cut -d: -f3 || echo "${CONTAINER_GID}")
echo "检测到 docker 组 GID: ${DOCKER_GID}"

# 替换 docker-compose.yml 中的配置
sed -i "s|user: \"[0-9]*:[0-9]*\"|user: \"${CONTAINER_UID}:${DOCKER_GID}\"|g" docker-compose.yml
sed -i "s|REDIS_HOST=.*|REDIS_HOST=${REDIS_CONN_HOST}|g" docker-compose.yml
sed -i "s|REDIS_PORT=.*|REDIS_PORT=${REDIS_CONN_PORT}|g" docker-compose.yml
sed -i "s|MINIO_ENDPOINT=.*|MINIO_ENDPOINT=${MINIO_CONN_ENDPOINT}|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml
sed -i "s|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/16.*code-interpreter-network|${CODE_INTERPRETER_NETWORK_SUBNET}|g" docker-compose.yml
sed -i "s|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/16.*code-interpreter-wan|${CODE_INTERPRETER_WAN_SUBNET}|g" docker-compose.yml

ensure_docker_network

echo "启动 Code Interpreter API 容器..."
docker-compose up -d

sleep 5
docker-compose ps

echo ""
print_separator
echo "       Code Interpreter API 安装完成!"
print_separator
echo "API 地址: http://${HOST_IP}:${CODE_INTERPRETER_API_PORT}"
echo ""