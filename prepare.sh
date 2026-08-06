#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
ensure_env

GHCR="${GHCR_REGISTRY:-ghcr.io/openinsighthq}"

echo "============================================================"
echo "       OpenInsight 镜像准备脚本"
echo "  拉取所有 Docker 镜像到本地"
echo "============================================================"
echo ""

# 官方镜像（Docker Hub）
OFFICIAL_IMAGES=(
  "mysql:8.0.36"
  "redis:7.2.11"
  "mongo:8.0.17"
  "minio/minio:latest"
  "minio/mc:latest"
  "getmeili/meilisearch:v1.12.3"
  "searxng/searxng:latest"
  "mongo-express:latest"
)

# 自研镜像（GitHub Container Registry）
GHCR_IMAGES=(
  "${GHCR}/arp:latest"
  "${GHCR}/dmp-api:latest"
  "${GHCR}/dmp-nginx:latest"
  "${GHCR}/one-pi:latest"
  "${GHCR}/librecodeinterpreter-api:latest"
  "${GHCR}/mcp-searxng:latest"
  "${GHCR}/mcp-searxng-proxy:latest"
)

# Code Interpreter 执行环境镜像（拉取后重命名为本地短名）
CI_IMAGES=(
  "${GHCR}/code-interpreter-nodejs:latest"
  "${GHCR}/code-interpreter-python:latest"
)

echo ">>> 拉取官方镜像..."
for image in "${OFFICIAL_IMAGES[@]}"; do
  echo "  docker pull ${image}"
  docker pull "${image}"
done

echo ""
echo ">>> 拉取自研镜像（GHCR）..."
for image in "${GHCR_IMAGES[@]}"; do
  echo "  docker pull ${image}"
  docker pull "${image}"
done

echo ""
echo ">>> 拉取 Code Interpreter 执行环境镜像并重命名..."
for image in "${CI_IMAGES[@]}"; do
  echo "  docker pull ${image}"
  docker pull "${image}"
done
docker tag "${GHCR}/code-interpreter-nodejs:latest" code-interpreter/nodejs
docker tag "${GHCR}/code-interpreter-python:latest" code-interpreter/python

echo ""
echo "============================================================"
echo "       所有镜像拉取完成!"
echo "============================================================"
