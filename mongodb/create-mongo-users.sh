#!/bin/bash
# ============================================================
# MongoDB 账号创建工具（用于已部署的实例补建 3 类账号）
# ------------------------------------------------------------
# 在【宿主机】上执行，通过 docker exec 连入运行中的 MongoDB 容器创建：
#   1) 管理员账号 (admin 库, root 角色)       —— mongo-express / 运维
#   2) 应用账号   (LibreChat 库, readWrite)    —— ARP / DMP 应用连接
#   3) 只读账号   (LibreChat 库, read)         —— 报表 / 排查
#
# 智能选择建号方式：
#   - 先尝试用管理员账号认证 → 能连说明已有用户，用其身份幂等补建
#   - 连不上 → 处于无用户状态，借 localhost exception 建立首个用户
#
# 用法:
#   bash create-mongo-users.sh                       # 用 env.sh 的默认账号/容器名
#   bash create-mongo-users.sh my-mongo-container    # 指定其他容器名
#
# 可用环境变量覆盖默认值（详见脚本末尾使用说明）:
#   MONGO_CONTAINER / MONGO_ROOT_USERNAME / MONGO_ROOT_PASSWORD
#   MONGO_APP_USERNAME / MONGO_APP_PASSWORD
#   MONGO_READONLY_USERNAME / MONGO_READONLY_PASSWORD
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 1) 加载 env.sh 的默认账号配置（若文件存在）
ENV_FILE="${PROJECT_ROOT}/env.sh"
if [ -f "${ENV_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
fi

# 2) 容器名：命令行第 1 个参数 > 环境变量 > env.sh 里的 MONGODB_HOST > 默认值
MONGO_CONTAINER="${MONGO_CONTAINER:-${1:-${MONGODB_HOST:-openinsight-mongodb}}}"

# 3) 账号配置（env.sh 已 source，这里给兜底默认值，防止未配置）
ROOT_USER="${MONGO_ROOT_USERNAME:-mongoadmin}"
ROOT_PWD="${MONGO_ROOT_PASSWORD:?请先运行 init-env.sh 生成 env.sh 或设置 MONGO_ROOT_PASSWORD}"
APP_USER="${MONGO_APP_USERNAME:-librechat}"
APP_PWD="${MONGO_APP_PASSWORD:?请先运行 init-env.sh 生成 env.sh 或设置 MONGO_APP_PASSWORD}"
RO_USER="${MONGO_READONLY_USERNAME:-librechat_readonly}"
RO_PWD="${MONGO_READONLY_PASSWORD:?请先运行 init-env.sh 生成 env.sh 或设置 MONGO_READONLY_PASSWORD}"

# 4) 校验容器存在且在运行
if ! docker ps --format '{{.Names}}' | grep -qx "${MONGO_CONTAINER}"; then
    echo "错误: MongoDB 容器 [${MONGO_CONTAINER}] 未运行"
    echo "可用容器: $(docker ps --format '{{.Names}}' | paste -sd, -)"
    exit 1
fi

echo "目标容器: ${MONGO_CONTAINER}"
echo "将创建/补建以下账号:"
echo "  管理员: ${ROOT_USER}  (admin 库, root)"
echo "  应用:   ${APP_USER}   (LibreChat 库, readWrite)"
echo "  只读:   ${RO_USER}    (LibreChat 库, read)"
echo ""

# 5) 探测认证模式：能否用管理员账号认证
AUTH_ARGS=""
if docker exec "${MONGO_CONTAINER}" mongosh --norc --quiet \
        -u "${ROOT_USER}" -p "${ROOT_PWD}" --authenticationDatabase admin \
        --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    AUTH_ARGS="-u ${ROOT_USER} -p ${ROOT_PWD} --authenticationDatabase admin"
    echo "检测到已有管理员账号，将以 [${ROOT_USER}] 身份补建其他账号。"
else
    AUTH_ARGS=""
    echo "未检测到可用管理员账号，将通过 localhost exception 创建（要求当前无任何用户）。"
fi
echo ""

# 6) 执行建号（单次 mongosh 连接，幂等：已存在的账号跳过）
#    说明：所有建号操作必须在【同一连接】内完成 —— 一旦创建首个用户，
#          localhost exception 立即对新连接失效。
docker exec -i "${MONGO_CONTAINER}" mongosh --norc ${AUTH_ARGS} <<EOF
const adminDb = db.getSiblingDB('admin');
if (!adminDb.getUser("${ROOT_USER}")) {
  adminDb.createUser({
    user: "${ROOT_USER}",
    pwd:  "${ROOT_PWD}",
    roles: [{ role: "root", db: "admin" }]
  });
  print("  [+] 已创建管理员账号: ${ROOT_USER}");
} else {
  print("  [=] 管理员账号已存在，跳过: ${ROOT_USER}");
}

const appDb = db.getSiblingDB('LibreChat');
if (!appDb.getUser("${APP_USER}")) {
  appDb.createUser({
    user: "${APP_USER}",
    pwd:  "${APP_PWD}",
    roles: [{ role: "readWrite", db: "LibreChat" }]
  });
  print("  [+] 已创建应用账号: ${APP_USER}");
} else {
  print("  [=] 应用账号已存在，跳过: ${APP_USER}");
}

if (!appDb.getUser("${RO_USER}")) {
  appDb.createUser({
    user: "${RO_USER}",
    pwd:  "${RO_PWD}",
    roles: [{ role: "read", db: "LibreChat" }]
  });
  print("  [+] 已创建只读账号: ${RO_USER}");
} else {
  print("  [=] 只读账号已存在，跳过: ${RO_USER}");
}
EOF

echo ""
echo "============================================================"
echo "  账号创建/校验完成!"
echo "============================================================"
echo "连接串参考 (authSource 很关键):"
echo "  管理员: mongodb://${ROOT_USER}:***@<host>:27017/?authSource=admin"
echo "  应用:   mongodb://${APP_USER}:***@<host>:27017/LibreChat?authSource=LibreChat"
echo "  只读:   mongodb://${RO_USER}:***@<host>:27017/LibreChat?authSource=LibreChat"
echo ""
echo "注意: 若是首次从 --noauth 切换到 --auth，请确保 MongoDB 已以 --auth 启动,"
echo "      且所有业务服务 (ARP/DMP/mongo-express) 的连接串已带上对应账号。"
