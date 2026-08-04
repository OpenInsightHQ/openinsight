#!/bin/bash
set -e

# ============================================================
# MongoDB 初始化建账号脚本（幂等）
# ------------------------------------------------------------
# 触发场景：
#   1) 全新部署：mongo 官方镜像 entrypoint 检测到 data 目录为空时，
#      会自动执行本脚本（此时尚未开启认证）。
#   2) 已有数据部署：install.sh 检测到 data 非空、entrypoint 不会执行
#      初始化脚本，于是通过 docker exec 调用本脚本，借助 localhost
#      exception 建立首个用户。
#
# 注意：整个建号流程在【单次 mongosh 连接】内完成。因为一旦创建首个
#       用户，localhost exception 即对新连接失效，必须同一连接内把
#       账号全部建好。
#
# 读取环境变量（由 docker-compose 的 environment 提供）：
#   MONGO_ROOT_USERNAME / MONGO_ROOT_PASSWORD     管理员账号（admin 库，root 角色）
#   MONGO_APP_USERNAME  / MONGO_APP_PASSWORD      应用账号（LibreChat 库，readWrite）
#   MONGO_READONLY_USERNAME / MONGO_READONLY_PASSWORD  只读账号（LibreChat 库，read）
# ============================================================

mongosh --norc <<EOF
const adminDb = db.getSiblingDB('admin');
if (!adminDb.getUser("${MONGO_ROOT_USERNAME}")) {
  adminDb.createUser({
    user: "${MONGO_ROOT_USERNAME}",
    pwd: "${MONGO_ROOT_PASSWORD}",
    roles: [{ role: "root", db: "admin" }]
  });
  print("已创建管理员账号: ${MONGO_ROOT_USERNAME}");
} else {
  print("管理员账号已存在，跳过: ${MONGO_ROOT_USERNAME}");
}

const appDb = db.getSiblingDB('LibreChat');
if (!appDb.getUser("${MONGO_APP_USERNAME}")) {
  appDb.createUser({
    user: "${MONGO_APP_USERNAME}",
    pwd: "${MONGO_APP_PASSWORD}",
    roles: [{ role: "readWrite", db: "LibreChat" }]
  });
  print("已创建应用账号: ${MONGO_APP_USERNAME}");
} else {
  print("应用账号已存在，跳过: ${MONGO_APP_USERNAME}");
}

if (!appDb.getUser("${MONGO_READONLY_USERNAME}")) {
  appDb.createUser({
    user: "${MONGO_READONLY_USERNAME}",
    pwd: "${MONGO_READONLY_PASSWORD}",
    roles: [{ role: "read", db: "LibreChat" }]
  });
  print("已创建只读账号: ${MONGO_READONLY_USERNAME}");
} else {
  print("只读账号已存在，跳过: ${MONGO_READONLY_USERNAME}");
}
EOF
