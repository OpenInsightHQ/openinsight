#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0") && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight MongoDB 安装脚本"
print_separator

cd "${SCRIPT_DIR}"

mkdir -p data

# 替换配置
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

# 注入账号配置（与 env.sh 保持一致）
sed -i "s|MONGO_ROOT_USERNAME=.*|MONGO_ROOT_USERNAME=${MONGO_ROOT_USERNAME}|g" docker-compose.yml
sed -i "s|MONGO_ROOT_PASSWORD=.*|MONGO_ROOT_PASSWORD=${MONGO_ROOT_PASSWORD}|g" docker-compose.yml
sed -i "s|MONGO_APP_USERNAME=.*|MONGO_APP_USERNAME=${MONGO_APP_USERNAME}|g" docker-compose.yml
sed -i "s|MONGO_APP_PASSWORD=.*|MONGO_APP_PASSWORD=${MONGO_APP_PASSWORD}|g" docker-compose.yml
sed -i "s|MONGO_READONLY_USERNAME=.*|MONGO_READONLY_USERNAME=${MONGO_READONLY_USERNAME}|g" docker-compose.yml
sed -i "s|MONGO_READONLY_PASSWORD=.*|MONGO_READONLY_PASSWORD=${MONGO_READONLY_PASSWORD}|g" docker-compose.yml

# 检测是否为已有数据的部署（entrypoint 仅在 data 为空时执行初始化脚本）
EXISTING_DATA=false
if [ -n "$(ls -A data 2>/dev/null)" ]; then
    EXISTING_DATA=true
fi

ensure_docker_network

echo "启动 MongoDB 容器..."
docker-compose up -d

MONGO_CONTAINER="openinsight-mongodb"

# 等待 MongoDB 服务就绪
echo -n "等待 MongoDB 服务就绪"
MAX_RETRIES=60
READY=0
count=0
while [ $count -lt $MAX_RETRIES ]; do
    if docker exec "${MONGO_CONTAINER}" mongosh --norc --quiet --eval "db.adminCommand('ping').ok" >/dev/null 2>&1; then
        READY=1
        break
    fi
    echo -n "."
    sleep 2
    count=$((count + 1))
done
echo ""

if [ "${READY}" != "1" ]; then
    echo "错误: MongoDB 服务启动超时，请检查容器状态"
    exit 1
fi

# 已有数据：entrypoint 不会执行 /docker-entrypoint-initdb.d 下的脚本，
# 需手动创建账号。先尝试用管理员账号认证，连得上说明账号已存在；
# 否则借助 localhost exception（尚无任何用户时生效）创建首个用户。
if [ "${EXISTING_DATA}" = "true" ]; then
    if docker exec "${MONGO_CONTAINER}" mongosh --norc --quiet \
            -u "${MONGO_ROOT_USERNAME}" -p "${MONGO_ROOT_PASSWORD}" --authenticationDatabase admin \
            --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        echo "MongoDB 账号已存在，跳过创建"
    else
        echo "检测到已有数据且首次启用认证，通过 localhost exception 创建账号..."
        docker exec \
            -e MONGO_ROOT_USERNAME="${MONGO_ROOT_USERNAME}" \
            -e MONGO_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD}" \
            -e MONGO_APP_USERNAME="${MONGO_APP_USERNAME}" \
            -e MONGO_APP_PASSWORD="${MONGO_APP_PASSWORD}" \
            -e MONGO_READONLY_USERNAME="${MONGO_READONLY_USERNAME}" \
            -e MONGO_READONLY_PASSWORD="${MONGO_READONLY_PASSWORD}" \
            "${MONGO_CONTAINER}" bash /docker-entrypoint-initdb.d/create-users.sh
    fi
fi

sleep 3
docker-compose ps

echo ""
print_separator
echo "       MongoDB 安装完成!"
print_separator
echo "MongoDB 连接信息:"
echo "  主机: ${MONGODB_HOST}"
echo "  端口: 27017"
echo "  管理员账号: ${MONGO_ROOT_USERNAME} (authSource=admin)"
echo "  应用账号:   ${MONGO_APP_USERNAME} (authSource=LibreChat)"
echo "  只读账号:   ${MONGO_READONLY_USERNAME} (authSource=LibreChat)"
echo ""
