#!/bin/bash
#============================================================
# OpenInsight 部署公共函数库
# 各子系统的 install.sh / uninstall.sh 请 source 此文件
#============================================================

# 获取项目根目录（common.sh 所在目录）
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载环境变量
load_env() {
    source "${PROJECT_ROOT}/env.sh"
}

#============================================================
# 密钥/密码随机生成函数
#============================================================

# 生成字母数字密码（默认 24 字符）
# 用法: gen_password [长度]
gen_password() {
    local length="${1:-24}"
    tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "${length}" || \
        cat /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "${length}"
}

# 生成 hex 密钥（默认 64 字符 = 256 bit）
# 用法: gen_hex [字节数]
gen_hex() {
    local bytes="${1:-32}"
    openssl rand -hex "${bytes}" 2>/dev/null || \
        head -c "$((bytes * 2))" /dev/urandom | od -A n -t x1 | tr -d ' \n'
}

# 生成带前缀的 API Key（如 ak-xxxxxxxx）
# 用法: gen_api_key [前缀]
gen_api_key() {
    local prefix="${1:-ak}"
    echo "${prefix}-$(gen_hex 16)"
}

#============================================================
# env.sh 初始化（首次部署时从模板生成并填充随机密钥）
#============================================================

# 确保 env.sh 存在；若不存在则从 env.sh.example 生成并填充随机密钥
ensure_env() {
    local env_file="${PROJECT_ROOT}/env.sh"
    local template="${PROJECT_ROOT}/env.sh.example"

    if [ ! -f "${env_file}" ]; then
        if [ ! -f "${template}" ]; then
            echo "错误: 未找到配置模板 ${template}"
            exit 1
        fi
        echo "首次部署：从 env.sh.example 生成 env.sh 并填充随机密钥..."
        cp "${template}" "${env_file}"

        # 逐项填充随机生成的密钥/密码
        _fill_secret "${env_file}" MYSQL_ROOT_PASSWORD    "$(gen_password)"
        _fill_secret "${env_file}" REDIS_PASSWORD         "$(gen_password)"
        _fill_secret "${env_file}" MINIO_ACCESS_KEY       "$(gen_password 20)"
        _fill_secret "${env_file}" MINIO_SECRET_KEY       "$(gen_password 40)"
        _fill_secret "${env_file}" MEILI_MASTER_KEY       "$(gen_hex)"
        _fill_secret "${env_file}" MONGO_EXPRESS_PASSWORD "$(gen_password)"
        _fill_secret "${env_file}" MONGO_ROOT_PASSWORD    "$(gen_password)"
        _fill_secret "${env_file}" MONGO_APP_PASSWORD     "$(gen_password)"
        _fill_secret "${env_file}" MONGO_READONLY_PASSWORD "$(gen_password)"
        _fill_secret "${env_file}" DMP_API_KEY            "$(gen_api_key ak)"
        _fill_secret "${env_file}" MYBATIS_PLUS_ENCRYPTOR_PASSWORD "$(gen_password)"
        _fill_secret "${env_file}" ARP_API_KEY            "sk-$(gen_hex 32)"
        _fill_secret "${env_file}" PI_API_KEY             "$(gen_password 32)"
        _fill_secret "${env_file}" LIBRECHAT_CODE_API_KEY "$(gen_hex)"
        _fill_secret "${env_file}" CODE_INTERPRETER_MASTER_API_KEY "$(gen_hex)"
        _fill_secret "${env_file}" ARP_JWT_SECRET         "$(gen_hex)"
        _fill_secret "${env_file}" ARP_JWT_REFRESH_SECRET  "$(gen_hex)"
        _fill_secret "${env_file}" ARP_CREDS_KEY          "$(gen_hex)"
        _fill_secret "${env_file}" ARP_CREDS_IV           "$(gen_hex 16)"
        _fill_secret "${env_file}" SEARXNG_SECRET_KEY     "$(gen_hex)"
        _fill_secret "${env_file}" STANDARD_REPORT_DOWNLOAD_TOKEN_SECRET "$(gen_hex)"

        echo "env.sh 生成完成，随机密钥已填充"
        echo ""

        # 检查 HOST_IP 是否已填写
        if ! grep -q '^HOST_IP=[0-9]' "${env_file}" 2>/dev/null; then
            echo "========================================="
            echo "  ⚠ 重要：请先编辑 env.sh 设置 HOST_IP"
            echo "========================================="
            echo "  当前 HOST_IP 为空，请修改为实际部署服务器 IP。"
            echo "  示例: HOST_IP=192.168.1.100"
            echo ""
            echo "  修改完成后重新运行安装脚本即可。"
            echo "========================================="
            exit 1
        fi
    fi

    # 加载 env.sh
    source "${env_file}"
}

# 内部函数：填充 env 文件中的密钥项（仅当值为空时填充）
# 用法: _fill_secret <file> <key> <value>
_fill_secret() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -q "^${key}=$" "$file" 2>/dev/null; then
        sed -i "s|^${key}=$|${key}=${value}|" "$file"
    fi
}

#============================================================
# 模块 .env 文件初始化
# 若模块目录下 .env 不存在，则从 .env.example 复制
# 用法: ensure_module_env <模块目录>
#============================================================
ensure_module_env() {
    local module_dir="$1"
    local env_file="${module_dir}/.env"
    local template="${module_dir}/.env.example"

    if [ ! -f "${env_file}" ]; then
        if [ -f "${template}" ]; then
            echo "从 ${template} 生成 .env ..."
            cp "${template}" "${env_file}"
        else
            echo "警告: ${template} 不存在，将创建空 .env"
            touch "${env_file}"
        fi
    fi
}

# 转义 sed 替换字符串中的特殊字符
# sed 替换部分中 & 和 \ 是特殊字符，需要转义
escape_sed_replacement() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    printf '%s' "$value"
}

# 更新 .env 文件中的配置项
# 用法: update_env_key <file> <key> <value>
update_env_key() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [ ! -f "$file" ]; then
        echo "错误: 配置文件 ${file} 不存在"
        return 1
    fi
    local escaped_value
    escaped_value="$(escape_sed_replacement "$value")"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${escaped_value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# 更新 .env 文件中的配置项（如果key存在且非注释行）
# 用法: update_env_key_strict <file> <key> <value>
update_env_key_strict() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [ ! -f "$file" ]; then
        echo "错误: 配置文件 ${file} 不存在"
        return 1
    fi
    local escaped_value
    escaped_value="$(escape_sed_replacement "$value")"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${escaped_value}|" "$file"
    else
        echo "警告: 配置项 ${key} 在 ${file} 中不存在，已追加"
        echo "${key}=${value}" >> "$file"
    fi
}

# 判断是否使用外部中间件
# 用法: is_external <变量名>
# 例如: is_external USE_EXTERNAL_MYSQL
is_external() {
    local var_name="$1"
    local val="${!var_name}"
    [ "${val,,}" = "true" ] || [ "${val}" = "1" ]
}

# 确保 Docker 网络存在
ensure_docker_network() {
    echo "检查 Docker 网络 ${DOCKER_NETWORK}..."
    docker network create "${DOCKER_NETWORK}" 2>/dev/null || true
}

# 等待服务就绪
# 用法: wait_for_service <host> <port> <max_retries> <service_name>
wait_for_service() {
    local host="$1"
    local port="$2"
    local max_retries="${3:-30}"
    local service_name="${4:-service}"
    local count=0
    echo -n "等待 ${service_name} (${host}:${port}) 就绪..."
    while ! nc -z "$host" "$port" 2>/dev/null; do
        count=$((count + 1))
        if [ $count -ge $max_retries ]; then
            echo " 超时!"
            return 1
        fi
        echo -n "."
        sleep 2
    done
    echo " 就绪!"
}

# 打印分隔线
print_separator() {
    echo "========================================="
}

# 获取 MySQL 连接地址（根据部署模式返回内部或外部地址）
get_mysql_host() {
    echo "${MYSQL_HOST}"
}

get_mysql_port() {
    echo "${MYSQL_PORT}"
}

# 获取 Redis 连接地址（根据部署模式返回内部或外部地址）
get_redis_host() {
    echo "${REDIS_HOST}"
}

get_redis_port() {
    echo "${REDIS_PORT}"
}

# 获取 MinIO 内部端点（容器间通信）
get_minio_internal_endpoint() {
    if is_external USE_EXTERNAL_MINIO; then
        echo "${MINIO_EXTERNAL_ENDPOINT}"
    else
        echo "${MINIO_INTERNAL_ENDPOINT}"
    fi
}

# 获取 MinIO 外部端点（供客户端使用）
get_minio_external_endpoint() {
    echo "${MINIO_EXTERNAL_ENDPOINT}"
}