#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 确保 env.sh 已生成并加载
ensure_env

echo "============================================================"
echo "       OpenInsight 全量安装脚本"
echo "  此脚本将按依赖顺序安装所有子系统"
echo "============================================================"
echo ""

# 显示中间件部署模式
echo "中间件部署模式:"
echo "  MySQL:  $(is_external USE_EXTERNAL_MYSQL && echo '外部' || echo '内部')"
echo "  Redis:  $(is_external USE_EXTERNAL_REDIS && echo '外部' || echo '内部')"
echo "  MinIO:  $(is_external USE_EXTERNAL_MINIO && echo '外部' || echo '内部')"
echo ""

STEP=0
TOTAL=10

# 1. 基础设施层（无依赖）
STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 MongoDB..."
bash "${SCRIPT_DIR}/mongodb/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 MySQL..."
bash "${SCRIPT_DIR}/mysql/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 Redis..."
bash "${SCRIPT_DIR}/redis/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 MinIO..."
bash "${SCRIPT_DIR}/minio/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 MeiliSearch..."
bash "${SCRIPT_DIR}/meilisearch/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 SearXNG..."
bash "${SCRIPT_DIR}/searxng/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 Code Interpreter API..."
bash "${SCRIPT_DIR}/codeinterpreter-api/install.sh"

# 3. 应用层（依赖中间件）
STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 PI Agent..."
bash "${SCRIPT_DIR}/pi-agent/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 DMP 管理平台..."
bash "${SCRIPT_DIR}/dmp/install.sh"

STEP=$((STEP + 1))
echo ""
echo ">>> [${STEP}/${TOTAL}] 安装 ARP 智能问答平台..."
bash "${SCRIPT_DIR}/arp/install.sh"

echo ""
echo "============================================================"
echo "       OpenInsight 全量安装完成!"
echo "============================================================"
echo ""
echo "服务访问地址："
echo "  ARP 智能问答平台:  http://${HOST_IP}:${ARP_PORT}/arp/"
echo "  DMP 管理平台:      http://${HOST_IP}:${DMP_PORT}/dmp/"
if ! is_external USE_EXTERNAL_MINIO; then
    echo "  MinIO Console:     http://localhost:${MINIO_CONSOLE_PORT}"
fi
echo "  Mongo Express:     http://localhost:${MONGO_EXPRESS_PORT}"
echo ""
echo "中间件连接信息："
echo "  MySQL:   ${MYSQL_HOST}:${MYSQL_PORT} (用户: ${MYSQL_USERNAME})"
echo "  Redis:   ${REDIS_HOST}:${REDIS_PORT}"
if ! is_external USE_EXTERNAL_MINIO; then
    echo "  MinIO:   localhost:${MINIO_API_PORT}"
else
    echo "  MinIO:   ${MINIO_EXTERNAL_ENDPOINT}"
fi
echo ""
echo "提示: 请根据实际需要修改 env.sh 后重新运行 install.sh"
echo ""