#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight MinIO 安装脚本"
print_separator

if is_external USE_EXTERNAL_MINIO; then
    echo ""
    echo "检测到 USE_EXTERNAL_MINIO=true，跳过内部 MinIO 部署"
    echo "将使用外部 MinIO 服务:"
    echo "  端点: ${MINIO_EXTERNAL_ENDPOINT}"
    echo "  Access Key: ${MINIO_ACCESS_KEY}"
    echo "  Bucket: ${MINIO_BUCKET}"
    echo ""
    print_separator
    echo "       MinIO 外部模式配置完成!"
    print_separator
    exit 0
fi

cd "${SCRIPT_DIR}"

mkdir -p data

# 确保 .env 存在
ensure_module_env "${SCRIPT_DIR}"

# 替换 .env 中的配置
update_env_key .env MINIO_ENDPOINT "localhost:${MINIO_API_PORT}"
update_env_key .env MINIO_ACCESS_KEY "${MINIO_ACCESS_KEY}"
update_env_key .env MINIO_SECRET_KEY "${MINIO_SECRET_KEY}"
update_env_key .env MINIO_BUCKET "${MINIO_BUCKET}"
update_env_key .env MINIO_REPORT_BUCKET "${MINIO_REPORT_BUCKET}"
update_env_key .env MINIO_REGION "${MINIO_REGION}"

# 替换 docker-compose.yml 中的配置
sed -i "s|127\.0\.0\.1:[0-9]*:9000|127.0.0.1:${MINIO_API_PORT}:9000|g" docker-compose.yml
sed -i "s|MINIO_ROOT_USER=.*|MINIO_ROOT_USER=${MINIO_ACCESS_KEY}|g" docker-compose.yml
sed -i "s|MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=${MINIO_SECRET_KEY}|g" docker-compose.yml
sed -i "s|MINIO_BROWSER_REDIRECT_URL=.*|MINIO_BROWSER_REDIRECT_URL=http://localhost:${MINIO_CONSOLE_PORT}|g" docker-compose.yml
sed -i "s|MINIO_ENDPOINT=.*|MINIO_ENDPOINT=${MINIO_INTERNAL_ENDPOINT}|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

echo "启动 MinIO 容器..."
docker-compose up -d

sleep 5
docker-compose ps

echo ""
print_separator
echo "       MinIO 安装完成!"
print_separator
echo "MinIO 访问信息:"
echo "  API: http://localhost:${MINIO_API_PORT}"
echo "  Console: http://localhost:${MINIO_CONSOLE_PORT}"
echo "  Access Key: ${MINIO_ACCESS_KEY}"
echo "  Secret Key: ${MINIO_SECRET_KEY}"
echo ""