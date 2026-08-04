#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight PI Agent 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 替换 .env 中的配置
update_env_key .env PI_HTTP_PORT "3000"
update_env_key .env PI_API_KEY "${PI_API_KEY}"
update_env_key .env SKILL_REPO_DIR "/app/skill-repo"
update_env_key .env OPENCODE_API_KEY "${OPENCODE_API_KEY}"
update_env_key .env PI_PROVIDER "${PI_PROVIDER:-opencode}"
update_env_key .env PI_MODEL "${PI_MODEL:-minimax-m2.5-free}"

# 创建必要的目录
echo "创建目录结构..."
mkdir -p pi-data skill-repo
chmod 777 pi-data skill-repo

# 替换 docker-compose.yml 中的配置
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "重启 PI Agent 容器..."
docker-compose down
docker-compose up -d

sleep 5
docker-compose ps

echo ""
print_separator
echo "       PI Agent 安装完成!"
print_separator
echo "PI Agent 地址: http://openinsight-pi-agent:3000"
echo ""
