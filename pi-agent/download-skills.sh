#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/common.sh"
ensure_env

SKILL_REPO_DIR="${SCRIPT_DIR}/skill-repo"
SKILL_BASE_URL="${SKILLS_DOWNLOAD_URL:-https://github.com/OpenInsightBH/openinsight/releases/latest/download/skills}"
SKILL_LIST_URL="${SKILL_BASE_URL}/list.txt"

print_separator() {
    echo "========================================="
}

print_separator
echo "       PI Agent Skills 下载脚本"
print_separator

mkdir -p "${SKILL_REPO_DIR}"

# 获取 skill 清单到临时文件
LIST_FILE="$(mktemp)"
trap 'rm -f "${LIST_FILE}"' EXIT

echo "获取 skill 清单: ${SKILL_LIST_URL}"
if ! wget -q -O "${LIST_FILE}" "${SKILL_LIST_URL}"; then
    echo "错误: 无法获取 skill 清单 (${SKILL_LIST_URL})"
    exit 1
fi

# 检查 unzip 是否可用（zip 格式的 skill 需要解压）
if ! command -v unzip >/dev/null 2>&1; then
    echo "错误: 未找到 unzip 命令，请先安装 unzip"
    exit 1
fi

SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

while IFS= read -r line; do
    # 跳过空行和注释行
    [ -z "${line}" ] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue

    # 去除前后空白
    rel_path="${line#"${line%%[![:space:]]*}"}"
    rel_path="${rel_path%"${rel_path##*[![:space:]]}"}"

    # 去除开头的斜杠
    rel_path="${rel_path#/}"

    [ -z "${rel_path}" ] && continue

    url="${SKILL_BASE_URL}/${rel_path}"
    target="${SKILL_REPO_DIR}/${rel_path}"
    target_dir="$(dirname "${target}")"

    # 判断是否为 zip 文件，并计算解压后预期目录
    is_zip=false
    if [[ "${rel_path}" == *.zip ]]; then
        is_zip=true
        zip_base="$(basename "${rel_path}" .zip)"
        extracted_dir="${target_dir}/${zip_base}"
    else
        extracted_dir=""
    fi

    mkdir -p "${target_dir}"

    # 跳过判断：zip 按解压目录判断，非 zip 按文件存在判断
    if [ "${is_zip}" = true ] && [ -d "${extracted_dir}" ]; then
        echo "已存在解压目录 ${rel_path%.zip}/，跳过下载"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    elif [ "${is_zip}" = false ] && [ -f "${target}" ]; then
        echo "已存在 ${rel_path}，跳过下载"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    echo "下载 ${rel_path} ..."
    if wget -q -O "${target}" "${url}"; then
        if [ "${is_zip}" = true ]; then
            echo "  解压 ${rel_path} ..."
            if unzip -o -q "${target}" -d "${target_dir}"; then
                rm -f "${target}"
                echo "  完成: ${rel_path}（已解压到 ${rel_path%.zip}/）"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "  解压失败: ${rel_path}"
                rm -f "${target}"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo "  完成: ${rel_path}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    else
        echo "  失败: ${rel_path}"
        rm -f "${target}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done < "${LIST_FILE}"

echo ""
print_separator
echo "下载完成: 成功 ${SUCCESS_COUNT} 个, 跳过 ${SKIP_COUNT} 个, 失败 ${FAIL_COUNT} 个"
echo "Skill 仓库目录: ${SKILL_REPO_DIR}"
print_separator

if [ "${FAIL_COUNT}" -gt 0 ]; then
    exit 1
fi
