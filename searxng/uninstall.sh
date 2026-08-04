#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"
ensure_env

print_separator
echo "       OpenInsight SearXNG 鍗歌浇鑴氭湰"
print_separator

cd "${SCRIPT_DIR}"

echo "鍋滄骞剁Щ闄?SearXNG 瀹瑰櫒..."
docker-compose down

echo ""
print_separator
echo "       SearXNG 宸插嵏杞?"
print_separator
echo "濡傞渶娓呴櫎鏁版嵁锛岃鎵嬪姩鍒犻櫎: rm -rf ${SCRIPT_DIR}/data"
echo ""