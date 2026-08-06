#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
ensure_env

GHCR="${GHCR_REGISTRY:-ghcr.io/openinsighthq}"

IMAGES=(
  # 官方镜像
  "mysql:8.0.36"
  "redis:7.2.11"
  "mongo:8.0.17"
  "minio/minio:latest"
  "minio/mc:latest"
  "getmeili/meilisearch:v1.12.3"
  "searxng/searxng:latest"
  "mongo-express:latest"
  # 自研镜像（GHCR）
  "${GHCR}/arp:latest"
  "${GHCR}/dmp-api:latest"
  "${GHCR}/dmp-nginx:latest"
  "${GHCR}/one-pi:latest"
  "${GHCR}/librecodeinterpreter-api:latest"
  "${GHCR}/mcp-searxng:latest"
  "${GHCR}/mcp-searxng-proxy:latest"
  "${GHCR}/code-interpreter-nodejs:latest"
  "${GHCR}/code-interpreter-python:latest"
  # Code Interpreter 本地别名
  "code-interpreter/nodejs"
  "code-interpreter/python"
)

OUTPUT_DIR="./docker-images"
mkdir -p "$OUTPUT_DIR"

for image in "${IMAGES[@]}"; do
  safe_name=$(echo "$image" | sed 's/[:/]/-/g')
  tar_path="$OUTPUT_DIR/${safe_name}.tar"

  if [ -f "$tar_path" ]; then
    echo "File $tar_path already exists, skipping..."
    continue
  fi

  if docker image inspect "$image" >/dev/null 2>&1; then
    echo "Image $image exists, saving..."
    docker save -o "$tar_path" "$image"
  else
    echo "Image $image not found, skipping..."
  fi
done

echo "Compressing all images..."
tar -czvf docker-images.tar.gz -C "$OUTPUT_DIR" .

echo "Done! Images saved to docker-images.tar.gz"
