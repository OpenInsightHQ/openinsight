#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"
ensure_env

print_separator
echo "       OpenInsight Mongo Express 鍗歌浇鑴氭湰"
print_separator

cd "${SCRIPT_DIR}"

echo "鍋滄骞剁Щ闄?Mongo Express 瀹瑰櫒..."
docker-compose down

echo ""
print_separator
echo "       Mongo Express 宸插嵏杞?"
print_separator