#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight SearXNG 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

mkdir -p data

# 替换 docker-compose.yml 中的配置
sed -i "s|SEARXNG_URL=.*|SEARXNG_URL=${SEARXNG_URL}|g" docker-compose.yml
sed -i "s|UPSTREAM_URL=.*|UPSTREAM_URL=http://${MCP_SEARXNG_HOST}:3000/mcp|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

# 替换 SearXNG settings.yml 中的密钥
sed -i "s|secret_key:.*|secret_key: \"${SEARXNG_SECRET_KEY}\"|g" config/settings.yml

ensure_docker_network

echo "启动 SearXNG 容器..."
docker-compose up -d

sleep 3
docker-compose ps

echo ""
print_separator
echo "       SearXNG 安装完成!"
print_separator