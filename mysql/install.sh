#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"

ensure_env

print_separator
echo "       OpenInsight MySQL 安装脚本"
print_separator

if is_external USE_EXTERNAL_MYSQL; then
    echo ""
    echo "检测到 USE_EXTERNAL_MYSQL=true，跳过内部 MySQL 部署"
    echo "将使用外部 MySQL 服务:"
    echo "  地址: ${MYSQL_HOST}"
    echo "  端口: ${MYSQL_PORT}"
    echo "  用户: ${MYSQL_USERNAME}"
    echo ""
    print_separator
    echo "       MySQL 外部模式配置完成!"
    print_separator
    exit 0
fi

cd "${SCRIPT_DIR}"

mkdir -p data logs
chmod 777 logs

# 替换 docker-compose.yml 中的配置
sed -i "s|MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}|g" docker-compose.yml
sed -i "s|openinsight_default|${DOCKER_NETWORK}|g" docker-compose.yml

ensure_docker_network

MYSQL_CONTAINER="openinsight-mysql"

echo "启动 MySQL 容器..."
docker-compose up -d

# 等待 MySQL 服务就绪
echo -n "等待 MySQL 服务就绪"
MAX_RETRIES=60
READY=0
count=0
while [ $count -lt $MAX_RETRIES ]; do
    if docker exec "${MYSQL_CONTAINER}" mysql \
        -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" \
        -u"${MYSQL_USERNAME}" -p"${MYSQL_ROOT_PASSWORD}" \
        -e "SELECT 1" > /dev/null 2>&1; then
        READY=1
        break
    fi
    echo -n "."
    sleep 2
    count=$((count + 1))
done
echo ""

if [ "${READY}" != "1" ]; then
    echo "错误: MySQL 服务启动超时，请检查容器状态"
    exit 1
fi

docker-compose ps

# 检查 openinsight 数据库是否已存在
DB_EXISTS=$(docker exec "${MYSQL_CONTAINER}" mysql \
    -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" \
    -u"${MYSQL_USERNAME}" -p"${MYSQL_ROOT_PASSWORD}" \
    -sse "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='${DMP_DB_NAME}';" 2>/dev/null || true)

if [ "${DB_EXISTS}" = "0" ] || [ -z "${DB_EXISTS}" ]; then
    echo ""
    print_separator
    echo "数据库 [${DMP_DB_NAME}] 不存在，开始初始化..."
    print_separator

    # 1) 创建数据库
    echo "创建数据库 [${DMP_DB_NAME}]..."
    docker exec "${MYSQL_CONTAINER}" mysql \
        -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" \
        -u"${MYSQL_USERNAME}" -p"${MYSQL_ROOT_PASSWORD}" \
        -e "CREATE DATABASE IF NOT EXISTS \`${DMP_DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

    # 2) 按顺序执行 initdb 脚本：先基础脚本 openinsight.sql，再按版本顺序执行 update*.sql
    SQL_FILES=()
    if [ -f "${SCRIPT_DIR}/initdb/openinsight.sql" ]; then
        SQL_FILES+=("initdb/openinsight.sql")
    fi
    while IFS= read -r f; do
        [ -n "$f" ] && SQL_FILES+=("initdb/$(basename "$f")")
    done < <(ls "${SCRIPT_DIR}/initdb"/update*.sql 2>/dev/null | sort -V)

    for sql_file in "${SQL_FILES[@]}"; do
        echo ""
        echo ">>> 执行: ${sql_file}"
        file_abs="${SCRIPT_DIR}/${sql_file}"
        case "${sql_file}" in
            */openinsight.sql)
                # 基础脚本通过 stdin 管道交给 mysql 原生解析器执行，
                # 可正确处理注释 / 字符串内分号 / 多行语句，比逐条切割更稳定
                if ! docker exec -i "${MYSQL_CONTAINER}" mysql \
                        -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" \
                        -u"${MYSQL_USERNAME}" -p"${MYSQL_ROOT_PASSWORD}" \
                        --default-character-set=utf8mb4 \
                        "${DMP_DB_NAME}" < "${file_abs}"; then
                    echo "警告: ${sql_file} 执行失败，请检查上方日志"
                fi
                ;;
            *)
                # 升级脚本保留逐条执行，便于定位失败语句
                bash "${SCRIPT_DIR}/execute_sql.sh" "${sql_file}" || {
                    echo "警告: ${sql_file} 执行过程中存在失败语句，请检查上方日志"
                }
                ;;
        esac
    done

    echo ""
    print_separator
    echo "       数据库 [${DMP_DB_NAME}] 初始化完成!"
    print_separator
else
    echo ""
    echo "数据库 [${DMP_DB_NAME}] 已存在，跳过初始化。"
fi

echo ""
print_separator
echo "       MySQL 安装完成!"
print_separator
echo "MySQL 连接信息:"
echo "  主机: ${MYSQL_HOST}"
echo "  端口: ${MYSQL_PORT}"
echo "  用户名: ${MYSQL_USERNAME}"
echo ""