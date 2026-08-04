#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 从统一环境变量文件同步 MySQL 连接配置（与 env.sh 保持一致）
if [ -f "${PROJECT_ROOT}/env.sh" ]; then
    source "${PROJECT_ROOT}/env.sh"
fi

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USERNAME:-root}"
MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_DATABASE="${DMP_DB_NAME:-openinsight}"
MYSQL_CONTAINER="${MYSQL_CONTAINER_NAME:-openinsight-mysql}"

if [ -z "$1" ]; then
    echo "Usage: $0 <sql_file>"
    echo "Example: $0 initdb/update2.0.1.1.sql"
    exit 1
fi

SQL_FILE="$1"

if [ ! -f "$SQL_FILE" ]; then
    echo "Error: File not found: $SQL_FILE"
    exit 1
fi

SQL_FILE_ABS=$(cd "$(dirname "$SQL_FILE")" && pwd)/$(basename "$SQL_FILE")

echo "============================================"
echo "  MySQL SQL Executor (via Docker)"
echo "============================================"
echo "  Container: ${MYSQL_CONTAINER}"
echo "  Database:  ${MYSQL_DATABASE}"
echo "  File:      ${SQL_FILE}"
echo "============================================"
echo ""

docker exec $MYSQL_CONTAINER mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to MySQL via container [${MYSQL_CONTAINER}]."
    exit 1
fi
echo "Connection successful."
echo ""

TEMP_LOCAL=$(mktemp /tmp/sql_stripped_XXXXXX.sql)
trap "rm -f $TEMP_LOCAL" EXIT

awk '
BEGIN { in_comment = 0 }
{
    line = $0
    result = ""
    i = 1
    len = length(line)

    while (i <= len) {
        if (in_comment) {
            if (substr(line, i, 2) == "*/") {
                in_comment = 0
                i += 2
            } else {
                i++
            }
        } else {
            c2 = substr(line, i, 2)
            if (c2 == "/*") {
                in_comment = 1
                i += 2
            } else if (c2 == "--") {
                break
            } else {
                result = result substr(line, i, 1)
                i++
            }
        }
    }

    gsub(/\r/, "", result)
    gsub(/^[ \t]+/, "", result)
    gsub(/[ \t]+$/, "", result)

    if (result != "") print result
}
' "$SQL_FILE_ABS" > "$TEMP_LOCAL"

CONTAINER_SQL="/tmp/_exec_stripped.sql"
docker cp "$TEMP_LOCAL" "${MYSQL_CONTAINER}:${CONTAINER_SQL}"

docker exec "${MYSQL_CONTAINER}" bash -c '
MYSQL_CMD="mysql -h'"${MYSQL_HOST}"' -P'"${MYSQL_PORT}"' -u'"${MYSQL_USER}"' -p'"${MYSQL_PASSWORD}"' '"${MYSQL_DATABASE}"' --default-character-set=utf8mb4"

TOTAL=0
SUCCESS=0
FAIL=0
STMT=""

while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue

    if [ -z "$STMT" ]; then
        STMT="$line"
    else
        STMT="${STMT}
${line}"
    fi

    if [[ "$line" == *";" ]]; then
        TOTAL=$((TOTAL + 1))

        first_line=$(echo "$STMT" | head -1 | sed "s/^[[:space:]]*//")
        if [ ${#first_line} -gt 80 ]; then
            first_line="${first_line:0:80}..."
        fi
        echo "[${TOTAL}] ${first_line}"

        ERR=$(echo "$STMT" | $MYSQL_CMD 2>&1)
        ERR=$(echo "$ERR" | grep -v "Using a password on the command line interface can be insecure")

        if [ -n "$ERR" ]; then
            FAIL=$((FAIL + 1))
            echo "  [FAILED]"
            echo "$ERR" | head -5 | sed "s/^/    /"
            echo "  Statement:"
            echo "$STMT" | sed "s/^/    /"
            echo ""
        else
            SUCCESS=$((SUCCESS + 1))
            echo "  [OK]"
        fi

        STMT=""
    fi
done < "'${CONTAINER_SQL}'"

if [ -n "$STMT" ]; then
    trimmed=$(echo "$STMT" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
    if [ -n "$trimmed" ]; then
        TOTAL=$((TOTAL + 1))
        first_line=$(echo "$STMT" | head -1 | sed "s/^[[:space:]]*//")
        if [ ${#first_line} -gt 80 ]; then
            first_line="${first_line:0:80}..."
        fi
        echo "[${TOTAL}] ${first_line}"

        ERR=$(echo "$STMT" | $MYSQL_CMD 2>&1)
        ERR=$(echo "$ERR" | grep -v "Using a password on the command line interface can be insecure")

        if [ -n "$ERR" ]; then
            FAIL=$((FAIL + 1))
            echo "  [FAILED]"
            echo "$ERR" | head -5 | sed "s/^/    /"
            echo "  Statement:"
            echo "$STMT" | sed "s/^/    /"
        else
            SUCCESS=$((SUCCESS + 1))
            echo "  [OK]"
        fi
    fi
fi

echo ""
echo "============================================"
echo "  Total: ${TOTAL} | Success: ${SUCCESS} | Failed: ${FAIL}"
echo "============================================"

rm -f "'${CONTAINER_SQL}'"

if [ $FAIL -gt 0 ]; then
    exit 1
fi
'
