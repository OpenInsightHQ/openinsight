#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight Redis 安装脚本"
print_separator

if is_external USE_EXTERNAL_REDIS; then
    echo ""
    echo "检测到 USE_EXTERNAL_REDIS=true，跳过内部 Redis 部署"
    echo "将使用外部 Redis 服务:"
    echo "  地址: ${REDIS_HOST}"
    echo "  端口: ${REDIS_PORT}"
    echo ""
    print_separator
    echo "       Redis 外部模式配置完成!"
    print_separator
    exit 0
fi

cd "${SCRIPT_DIR}"

mkdir -p data

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 替换 .env 中的配置
update_env_key .env REDIS_HOST "${REDIS_HOST}"
update_env_key .env REDIS_PORT "${REDIS_PORT}"
update_env_key .env REDIS_PASSWORD "${REDIS_PASSWORD}"
update_env_key .env REDIS_DB "0"

# 替换 docker-compose.yml 中的配置
sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=${REDIS_PASSWORD}|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "启动 Redis 容器..."
docker-compose up -d

sleep 3
docker-compose ps

echo ""
print_separator
echo "       Redis 安装完成!"
print_separator
echo "Redis 连接信息:"
echo "  主机: ${REDIS_HOST}"
echo "  端口: ${REDIS_PORT}"
echo "  密码: \${REDIS_PASSWORD}"
echo ""