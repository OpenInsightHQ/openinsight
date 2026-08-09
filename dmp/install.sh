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

# DMP 应用专属密钥：首次部署由 common.sh 生成；升级场景（旧 env.sh 无此键）在此回填到根 env.sh
ENV_SH="${PROJECT_ROOT}/env.sh"
ensure_dmp_secret() {
    local key="$1" gen="$2"
    local current
    current="$(grep "^${key}=" "${ENV_SH}" 2>/dev/null | head -1 | cut -d'=' -f2-)"
    if [ -z "${current}" ]; then
        local val
        val="$(eval "${gen}")"
        if grep -q "^${key}=" "${ENV_SH}" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${val}|" "${ENV_SH}"
        else
            echo "${key}=${val}" >> "${ENV_SH}"
        fi
        eval "export ${key}=\"\${val}\""
    fi
}
ensure_dmp_secret MYBATIS_PLUS_ENCRYPTOR_PASSWORD 'gen_password'
ensure_dmp_secret ARP_API_KEY                 'echo "sk-$(gen_hex 32)"'

# 根据中间件部署模式确定连接地址
MYSQL_CONN_HOST="${MYSQL_HOST}"
MYSQL_CONN_PORT="${MYSQL_PORT}"
REDIS_CONN_HOST="${REDIS_HOST}"
REDIS_CONN_PORT="${REDIS_PORT}"
ARP_BASE="http://${ARP_API_HOST}:${ARP_PORT}"
DMP_API_BASE="http://${DMP_API_HOST}:8090"

# 替换 .env 中的配置
update_env_key .env SERVER_PORT 8090
update_env_key .env DMP_MYSQL_HOST "${MYSQL_CONN_HOST}"
update_env_key .env DMP_MYSQL_PORT "${MYSQL_CONN_PORT}"
update_env_key .env DMP_MYSQL_USERNAME "${MYSQL_USERNAME}"
update_env_key .env DMP_MYSQL_PASSWORD "${MYSQL_ROOT_PASSWORD}"
update_env_key .env DMP_DB_NAME "${DMP_DB_NAME}"
update_env_key .env DMP_REDIS_HOST "${REDIS_CONN_HOST}"
update_env_key .env DMP_REDIS_PORT "${REDIS_CONN_PORT}"
update_env_key .env DMP_REDIS_PASSWORD "${REDIS_PASSWORD}"
update_env_key .env DMP_REDIS_DATABASE "${DMP_REDIS_DATABASE}"
update_env_key .env MONGODB_URI "${MONGODB_URI}"
update_env_key .env MEILI_HOST "${MEILI_HOST_URL}"
update_env_key .env MEILI_MASTER_KEY "${MEILI_MASTER_KEY}"
update_env_key .env PI_HOST "${PI_HOST}"
update_env_key .env PI_API_KEY "${PI_API_KEY}"
update_env_key .env AGENT_PLATFORM_BASE_URL "${ARP_BASE}"
update_env_key .env ARP_HOST "${ARP_BASE}"
update_env_key .env ARP_API_KEY "${ARP_API_KEY}"
update_env_key .env MYBATIS_PLUS_ENCRYPTOR_PASSWORD "${MYBATIS_PLUS_ENCRYPTOR_PASSWORD}"
update_env_key .env DMP_API_KEY "${DMP_API_KEY}"
update_env_key .env DMP_MCP_URL "${DMP_API_BASE}/open-api/mcp"
update_env_key .env DMP_HOST "http://${HOST_IP}:${DMP_PORT}"
update_env_key .env ADMIN_UI_URL "http://${HOST_IP}:${DMP_PORT}"
update_env_key .env DMP_REPORT_TOKEN_SECRET "${STANDARD_REPORT_DOWNLOAD_TOKEN_SECRET}"
update_env_key .env DMP_PUBLIC_WEB_PORT "${DMP_PORT}"

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

# 管理员密码提示
ADMIN_INIT_PASSWORD_VAL="$(grep '^ADMIN_INIT_PASSWORD=' .env | head -1 | cut -d'=' -f2-)"
if [ -z "${ADMIN_INIT_PASSWORD_VAL}" ]; then
    echo ""
    echo "⚠ 未配置 ADMIN_INIT_PASSWORD，管理员初始密码已由系统随机生成。"
    echo "  请通过以下命令查看 dmp-api 日志中的初始密码，并尽快登录修改："
    echo "    docker logs openinsight-dmp-api 2>&1 | grep 'initial password'"
fi
echo ""
