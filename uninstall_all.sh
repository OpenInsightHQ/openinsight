#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
ensure_env

echo "============================================================"
echo "       OpenInsight 全量卸载脚本"
echo "  此脚本将按依赖反序卸载所有子系统"
echo "============================================================"
echo ""

# 按依赖反序卸载（应用层 -> 中间件层 -> 基础设施层）
echo ">>> [1/11] 卸载 ARP..."
bash "${SCRIPT_DIR}/arp/uninstall.sh"

echo ""
echo ">>> [2/11] 卸载 DMP..."
bash "${SCRIPT_DIR}/dmp/uninstall.sh"

echo ""
echo ">>> [3/11] 卸载 PI Agent..."
bash "${SCRIPT_DIR}/pi-agent/uninstall.sh"

echo ""
echo ">>> [4/11] 卸载 Code Interpreter API..."
bash "${SCRIPT_DIR}/codeinterpreter-api/uninstall.sh"

echo ""
echo ">>> [5/11] 卸载 SearXNG..."
bash "${SCRIPT_DIR}/searxng/uninstall.sh"

echo ""
echo ">>> [6/11] 卸载 Mongo Express..."
bash "${SCRIPT_DIR}/mongo-express/uninstall.sh"

echo ""
echo ">>> [7/11] 卸载 MeiliSearch..."
bash "${SCRIPT_DIR}/meilisearch/uninstall.sh"

echo ""
echo ">>> [8/11] 卸载 MinIO..."
bash "${SCRIPT_DIR}/minio/uninstall.sh"

echo ""
echo ">>> [9/11] 卸载 Redis..."
bash "${SCRIPT_DIR}/redis/uninstall.sh"

echo ""
echo ">>> [10/11] 卸载 MySQL..."
bash "${SCRIPT_DIR}/mysql/uninstall.sh"

echo ""
echo ">>> [11/11] 卸载 MongoDB..."
bash "${SCRIPT_DIR}/mongodb/uninstall.sh"

echo ""
echo "============================================================"
echo "       OpenInsight 全量卸载完成!"
echo "============================================================"
echo ""
echo "提示: 如需清除数据，请手动删除各子系统目录下的 data 文件夹"
echo "      如需清除 Docker 网络，请执行: docker network rm ${DOCKER_NETWORK}"
echo ""
