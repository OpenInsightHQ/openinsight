#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"
ensure_env

print_separator
echo "       OpenInsight MinIO 鍗歌浇鑴氭湰"
print_separator

if is_external USE_EXTERNAL_MINIO; then
    echo ""
    echo "妫€娴嬪埌 USE_EXTERNAL_MINIO=true锛岃烦杩?MinIO 鍗歌浇锛堜娇鐢ㄥ閮ㄦ湇鍔★級"
    echo ""
    exit 0
fi

cd "${SCRIPT_DIR}"

echo "鍋滄骞剁Щ闄?MinIO 瀹瑰櫒..."
docker-compose down

echo ""
print_separator
echo "       MinIO 宸插嵏杞?"
print_separator
echo "濡傞渶娓呴櫎鏁版嵁锛岃鎵嬪姩鍒犻櫎: rm -rf ${SCRIPT_DIR}/data"
echo ""