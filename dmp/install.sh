#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight DMP 管理平台 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

# 创建必要的目录
echo "创建目录结构..."
mkdir -p data

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 根据中间件部署模式确定连接地址
MYSQL_CONN_HOST="${MYSQL_HOST}"
MYSQL_CONN_PORT="${MYSQL_PORT}"
REDIS_CONN_HOST="${REDIS_HOST}"
REDIS_CONN_PORT="${REDIS_PORT}"
MINIO_CONN_ENDPOINT="$(get_minio_internal_endpoint)"

# 替换 .env 中的配置
update_env_key .env DMP_MYSQL_HOST "${MYSQL_CONN_HOST}"
update_env_key .env DMP_MYSQL_PORT "${MYSQL_CONN_PORT}"
update_env_key .env DMP_MYSQL_USERNAME "${MYSQL_USERNAME}"
update_env_key .env DMP_MYSQL_PASSWORD "${MYSQL_ROOT_PASSWORD}"
update_env_key .env DMP_DB_NAME "${DMP_DB_NAME}"
update_env_key .env DMP_REDIS_HOST "${REDIS_CONN_HOST}"
update_env_key .env DMP_REDIS_PORT "${REDIS_CONN_PORT}"
update_env_key .env DMP_REDIS_PASSWORD "${REDIS_PASSWORD}"
update_env_key .env DMP_REDIS_DATABASE "${DMP_REDIS_DATABASE}"
update_env_key .env OSS_ENDPOINT "http://${MINIO_CONN_ENDPOINT}"
update_env_key .env MONGODB_URI "${MONGODB_URI}"
update_env_key .env AGENT_PLATFORM_BASE_URL "http://${ARP_API_HOST}:${ARP_PORT}"
update_env_key .env DMP_PUBLIC_WEB_PORT "${DMP_PORT}"
update_env_key .env MEILI_HOST "${MEILI_HOST_URL}"
update_env_key .env MEILI_MASTER_KEY "${MEILI_MASTER_KEY}"
update_env_key .env PI_HOST "${PI_HOST}"
update_env_key .env PI_API_KEY "${PI_API_KEY}"
update_env_key .env DMP_HOST "http://${HOST_IP}:${DMP_PORT}"

# 替换 docker-compose.yml 中的配置
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "拉取最新镜像（DMP_IMAGE_TAG=${DMP_IMAGE_TAG:-latest}）..."
docker-compose pull

echo "重启 DMP 容器..."
docker-compose down
docker-compose up -d

sleep 5
docker-compose ps

echo ""
print_separator
echo "       DMP 安装完成!"
print_separator
echo "DMP 管理平台地址: http://${HOST_IP}:${DMP_PORT}/dmp/"
echo ""
