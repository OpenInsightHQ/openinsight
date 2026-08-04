#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight MeiliSearch 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

mkdir -p data

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 替换 .env 中的配置
update_env_key .env MEILI_HOST "${MEILI_HOST_URL}"
update_env_key .env MEILI_MASTER_KEY "${MEILI_MASTER_KEY}"

# 替换 docker-compose.yml 中的配置
sed -i "s|MEILI_HOST=.*|MEILI_HOST=${MEILI_HOST_URL}|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "启动 MeiliSearch 容器..."
docker-compose up -d

sleep 3
docker-compose ps

echo ""
print_separator
echo "       MeiliSearch 安装完成!"
print_separator