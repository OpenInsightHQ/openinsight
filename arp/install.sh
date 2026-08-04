#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight ARP 智能问答平台 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 替换 .env 中的配置
update_env_key .env PORT "${ARP_PORT}"
update_env_key .env MONGO_URI "${MONGODB_URI}"
update_env_key .env DOMAIN_CLIENT "http://${HOST_IP}:${ARP_PORT}"
update_env_key .env DOMAIN_SERVER "http://${HOST_IP}:${ARP_PORT}"
update_env_key .env CONFIG_PATH "http://${DMP_API_HOST}:8090/admin-api/infra/agent-platform-config/get"
update_env_key .env DMP_HOST "http://${DMP_API_HOST}:8090"
update_env_key .env DMP_API_KEY "${DMP_API_KEY}"
update_env_key .env DMP_MCP_URL "http://${DMP_API_HOST}:8090/open-api/mcp"
update_env_key .env PI_HOST "${PI_HOST}"
update_env_key .env PI_API_KEY "${PI_API_KEY}"
update_env_key .env MEILI_HOST "${MEILI_HOST_URL}"
update_env_key .env MEILI_MASTER_KEY "${MEILI_MASTER_KEY}"
update_env_key .env LIBRECHAT_CODE_API_KEY "${LIBRECHAT_CODE_API_KEY}"
update_env_key .env LIBRECHAT_CODE_BASEURL "http://${CODE_INTERPRETER_HOST}:${CODE_INTERPRETER_API_PORT}"
update_env_key .env UID "${CONTAINER_UID}"
update_env_key .env GID "${CONTAINER_GID}"
update_env_key .env CREDS_KEY "${ARP_CREDS_KEY}"
update_env_key .env CREDS_IV "${ARP_CREDS_IV}"
update_env_key .env JWT_SECRET "${ARP_JWT_SECRET}"
update_env_key .env JWT_REFRESH_SECRET "${ARP_JWT_REFRESH_SECRET}"
update_env_key .env CSP_FRAME_SRC "http://${HOST_IP}:${ARP_PORT}"
update_env_key .env CSP_CONNECT_SRC "http://${HOST_IP}:${ARP_PORT}"

# 创建必要的目录
echo "创建目录结构..."
mkdir -p data/arp/images data/arp/uploads data/arp/logs data/arp/data
chmod 777 data/arp/images data/arp/uploads data/arp/logs data/arp/data

# 替换 docker-compose.yml 中的配置
sed -i "s|MONGO_URI=.*|MONGO_URI=${MONGODB_URI}|g" docker-compose.yml
sed -i "s|MEILI_HOST=.*|MEILI_HOST=${MEILI_HOST_URL}|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "重启 ARP 容器..."
docker-compose down
docker-compose up -d

sleep 5
docker-compose ps

echo ""
print_separator
echo "       ARP 安装完成!"
print_separator
echo "ARP 智能问答平台地址: http://${HOST_IP}:${ARP_PORT}/arp/"
echo ""
