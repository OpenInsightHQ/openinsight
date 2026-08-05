#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"
ensure_env

cd "${SCRIPT_DIR}"

print_separator
echo "       OpenInsight DMP 数据库增量更新脚本"
print_separator

# 检测 DMP API 更新程序包（不存在则终止）
DMP_API_PACKAGE=$(ls dmp-api-*.jar 2>/dev/null | head -n 1)
if [ -z "${DMP_API_PACKAGE}" ]; then
    echo "错误: 未发现 DMP API 更新程序包（dmp-api-*.jar），终止更新"
    exit 1
fi

# 从安装包文件名截取版本号，如 dmp-api-2.0.2.7.jar -> 2.0.2.7
DMP_VERSION="${DMP_API_PACKAGE#dmp-api-}"
DMP_VERSION="${DMP_VERSION%.jar}"
echo "发现更新程序包 ${DMP_API_PACKAGE}（发布版本 ${DMP_VERSION}）"

# 读取 .env 中已部署的版本号
CURRENT_VERSION=""
if [ -f ".env" ]; then
    CURRENT_VERSION=$(awk -F= '
/^DMP_VERSION=/ {
    v=$2
    gsub(/^[ \t\r\n"]+/, "", v)
    gsub(/[ \t\r\n"]+$/, "", v)
}
END { print v }
' .env 2>/dev/null || true)
fi

# .env 中未配置版本号则跳过整个下载执行流程
if [ -z "${CURRENT_VERSION}" ]; then
    echo ".env 中未配置 DMP_VERSION，跳过数据库更新脚本下载与执行"
    exit 0
fi

# 版本号比较（a.b.c.d 数字格式，不可直接字符串比较）
# 返回: 0=相等, 1=v1>v2, 2=v1<v2
version_compare() {
    local v1="$1" v2="$2"
    if [ "$v1" = "$v2" ]; then
        return 0
    fi
    local IFS=.
    local a1=($v1)
    local a2=($v2)
    local len=${#a1[@]}
    [ ${#a2[@]} -gt $len ] && len=${#a2[@]}
    local i n1 n2
    for ((i = 0; i < len; i++)); do
        n1=${a1[i]:-0}
        n2=${a2[i]:-0}
        if ((n1 > n2)); then
            return 1
        elif ((n1 < n2)); then
            return 2
        fi
    done
    return 0
}

echo "当前已部署版本 ${CURRENT_VERSION}，将执行 (${CURRENT_VERSION}, ${DMP_VERSION}] 范围内的更新脚本"

SQL_BASE_URL="${SQL_DOWNLOAD_URL:-https://github.com/OpenInsightHQ/openinsight/releases/latest/download/sql/}"
SQL_DOWNLOAD_DIR="${SCRIPT_DIR}/sql-updates"
mkdir -p "${SQL_DOWNLOAD_DIR}"

echo "获取更新脚本列表..."
LISTING=$(wget -q -O - "${SQL_BASE_URL}" 2>/dev/null || true)
if [ -z "${LISTING}" ]; then
    echo "错误: 无法获取更新脚本列表（${SQL_BASE_URL}）"
    exit 1
fi

# 提取所有 update<a.b.c.d>.sql 文件名并按版本顺序排序
UPDATE_FILES=$(echo "${LISTING}" | grep -oE "update[0-9]+(\.[0-9]+)+\.sql" | sort -u -V || true)

EXECUTED=0
SKIPPED=0
for sql_file in ${UPDATE_FILES}; do
    file_version="${sql_file#update}"
    file_version="${file_version%.sql}"

    # 条件: file_version > CURRENT_VERSION 且 file_version <= DMP_VERSION
    cmp_current=0
    version_compare "${file_version}" "${CURRENT_VERSION}" || cmp_current=$?
    cmp_release=0
    version_compare "${file_version}" "${DMP_VERSION}" || cmp_release=$?

    if [ "${cmp_current}" -eq 1 ] && [ "${cmp_release}" -ne 1 ]; then
        target="${SQL_DOWNLOAD_DIR}/${sql_file}"
        if [ ! -f "${target}" ]; then
            echo "下载 ${sql_file} ..."
            if ! wget -q -O "${target}" "${SQL_BASE_URL}${sql_file}"; then
                echo "警告: 下载 ${sql_file} 失败，跳过"
                rm -f "${target}"
                continue
            fi
        else
            echo "已存在 ${sql_file}，跳过下载"
        fi

        echo "执行更新脚本 ${sql_file}（版本 ${file_version}）..."
        bash "${PROJECT_ROOT}/mysql/execute_sql.sh" "${target}" || {
            echo "警告: ${sql_file} 执行过程中存在失败语句，请检查上方日志"
        }
        EXECUTED=$((EXECUTED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done

echo ""
echo "数据库更新脚本处理完成（执行 ${EXECUTED} 个，跳过 ${SKIPPED} 个）"
