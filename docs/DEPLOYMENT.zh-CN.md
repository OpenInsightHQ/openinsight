# OpenInsight 2.0 私有化部署文档

## 目录

1. [概述](#1-概述)
2. [系统要求](#2-系统要求)
3. [架构说明](#3-架构说明)
4. [安装前准备](#4-安装前准备)
5. [快速部署](#5-快速部署)
6. [安装步骤详解](#6-安装步骤详解)
7. [配置说明](#7-配置说明)
8. [服务管理](#8-服务管理)
9. [验证部署](#9-验证部署)
10. [应用更新](#10-应用更新)
11. [卸载](#11-卸载)
12. [常见问题](#12-常见问题)

---

## 1. 概述

本文档描述 OpenInsight 2.0.2 产品的私有化部署方法，适用于需要将系统部署在私有环境中的用户。

### 1.1 主要组件

| 组件名称 | 说明 |
|---------|------|
| DMP (数据管理平台) | 后端服务 + 前端管理界面 |
| ARP (智能问答平台) | 用户使用的对话智能体平台 |
| PI Agent | PI 智能代理服务 |
| MongoDB | 数据存储数据库 |
| MySQL | 数据管理平台数据库 |
| Redis | 缓存服务 |
| Meilisearch | 全文搜索引擎 |
| MinIO | 对象存储服务 |
| Code Interpreter API | 代码解释器服务 |
| SearXNG | 网络搜索服务 |

### 1.2 部署方式

部署采用 **统一环境变量 + 模块化安装脚本** 的方式：

- **统一配置**：所有配置集中在根目录 `env.sh` 文件中，默认情况下只需修改 `HOST_IP` 即可完成部署
- **模块化安装**：每个子系统目录下都有独立的 `install.sh` 脚本，按顺序执行即可
- **一键安装**：提供 `install_all.sh` 全量安装脚本，可自动按依赖顺序安装所有组件

### 1.3 前置依赖

- Docker 24.07+
- Docker Compose v2.26.1+

### 1.4 根目录脚本说明

部署包根目录下包含以下脚本文件，**所有脚本均需在项目根目录下通过 `bash xxx.sh` 方式执行**：

| 脚本文件 | 执行命令 | 说明 |
|---------|---------|------|
| `env.sh.example` | （无需执行） | 统一环境变量配置模板，提交到 Git。所有密钥/密码预置为空 |
| `init-env.sh` | `bash init-env.sh` | **环境初始化脚本**：从 `env.sh.example` 生成 `env.sh`，自动随机填充所有密码和密钥 |
| `common.sh` | （无需执行） | 公共函数库，由各子系统的 `install.sh` / `uninstall.sh` 自动 `source` 引入，不单独执行 |
| `prepare.sh` | `bash prepare.sh` | **在线环境**准备脚本：拉取所有 Docker 镜像（官方镜像 + GHCR 自研镜像） |
| `save-images.sh` | `bash save-images.sh` | **离线部署**镜像导出脚本：将本地 Docker 镜像打包为 `docker-images.tar.gz`，需在已拉取镜像的环境中执行 |
| `load-images.sh` | `bash load-images.sh` | **离线部署**镜像导入脚本：将 `docker-images.tar.gz` 导入目标服务器，需在离线目标服务器执行 |
| `install_all.sh` | `bash install_all.sh` | **一键全量安装**脚本：按依赖顺序自动安装所有子系统（推荐） |
| `uninstall_all.sh` | `bash uninstall_all.sh` | **一键全量卸载**脚本：按依赖反序卸载所有子系统 |

> **执行注意事项：**
>
> 1. **首次部署必须先执行 `bash init-env.sh`**，生成 `env.sh` 并自动填充随机密钥。
> 2. **然后修改 `env.sh` 中的 `HOST_IP`** 为实际服务器 IP，这是最核心的一步。
> 3. 镜像准备脚本根据网络环境**二选一**：
>    - 在线环境：执行 `bash prepare.sh`
>    - 离线环境：先在联网机器执行 `bash save-images.sh`，再将产物拷贝到目标服务器执行 `bash load-images.sh`
> 4. `common.sh` 不可单独执行，它是各 `install.sh` 依赖的函数库。
> 5. 所有子系统的 `install.sh` 会自动读取 `env.sh` 配置并写入各模块的 `.env` 和 `docker-compose.yml`，因此修改配置后重新执行 `install.sh` 即可生效。
> 6. 部分子系统目录下还包含专用辅助脚本（执行命令需 `cd` 到对应目录）：
>    - `pi-agent/download-skills.sh` — 下载 PI Agent 官方 Skills 仓库，详见 [6.8 PI Agent](#68-pi-agent)
>    - `dmp/update_sql.sh` — DMP 升级时执行数据库增量 SQL，详见 [10.2 DMP 数据库增量更新](#102-dmp-数据库增量更新)

---

## 2. 系统要求

### 2.1 最低配置要求

| 项目 | 要求     |
|-----|--------|
| CPU | 4 核    |
| 内存 | 16 GB   |
| 硬盘 | 100 GB |

### 2.2 推荐配置要求

| 项目 | 要求 |
|-----|------|
| CPU | 16 核 |
| 内存 | 32 GB |
| 硬盘 | 500 GB |

### 2.3 支持的操作系统

- Ubuntu 20.04
- Ubuntu 22.04
- CentOS/RedHat 7.9
- CentOS 8.6
- RedHat 8.5

---

## 3. 架构说明

### 3.1 系统架构图

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              OpenInsight 2.0.2                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────────┐  │
│  │   DMP 前端    │     │   ARP 前端   │     │      Code Interpreter        │  │
│  │  (Nginx)      │     │  (Node.js)   │     │         API                 │  │
│  │  Port: 30080 │     │  Port: 33080 │     │       Port: 8000             │  │
│  └──────┬───────┘     └──────┬───────┘     └─────────────┬────────────────┘  │
│         │                    │                            │                   │
│  ┌──────▼────────────────────▼────────────────────────────▼────────────────┐  │
│  │                          DMP API & ARP API                              │  │
│  │                    (数据管理平台 & 智能问答平台后端)                         │  │
│  │    ┌─────────────────┐           ┌─────────────────┐                    │  │
│  │    │   DMP API       │           │   ARP API       │                    │  │
│  │    │   (Java)        │◄─────────►│   (Node.js)     │                    │  │
│  │    │   Port: 8090    │           │   Port: 33080   │                    │  │
│  │    └────────┬────────┘           └────────┬────────┘                    │  │
│  └─────────────┼──────────────────────────────┼────────────────────────────┘  │
│                │                              │                               │
│  ┌─────────────▼──────────────────────────────▼────────────────────────────┐  │
│  │                         PI Agent                                         │  │
│  │    ┌─────────────────┐                                                   │  │
│  │    │   PI Agent      │                                                   │  │
│  │    │   Port: 3000    │                                                   │  │
│  │    └─────────────────┘                                                   │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                         基础设施服务                                      │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────┐                │  │
│  │  │  MySQL    │ │  Redis   │ │ Meilisearch  │ │  MinIO    │              │  │
│  │  │  Port:3306│ │ Port:6379│ │  Port: 7700  │ │ Port:9000 │              │  │
│  │  └──────────┘ └──────────┘ └──────────────┘ └──────────┘                │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                                 │  │
│  │  │ MongoDB  │ │SearXNG   │ │Mongo     │                                 │  │
│  │  │Port:27017│ │Port:8080 │ │Express   │                                 │  │
│  │  └──────────┘ └──────────┘ │Port:18081│                                 │  │
│  │                           └──────────┘                                 │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
└────────────────────────────────────────────────────────────────────────────-──┘
```

### 3.2 组件说明

| 模块名称                | 说明 | 目录 |
|---------------------|------|------|
| mysql               | MySQL 数据库 | `mysql/` |
| mongodb             | MongoDB 数据库 | `mongodb/` |
| redis               | Redis 缓存服务 | `redis/` |
| minio               | MinIO 对象存储服务 | `minio/` |
| meilisearch         | Meilisearch 全文索引服务 | `meilisearch/` |
| searxng             | SearXNG 网络搜索服务 | `searxng/` |
| codeinterpreter-api | 代码解释器 API | `codeinterpreter-api/` |
| pi-agent            | PI 智能代理服务 | `pi-agent/` |
| dmp-api             | 数据管理平台后端 | `dmp/` |
| dmp-nginx           | 数据管理平台前端 | `dmp/` |
| arp                 | 智能问答平台后端 | `arp/` |

### 3.3 目录结构

```
openinsight/
├── README.md                          # 英文项目说明
├── README.zh-CN.md                    # 中文项目说明
├── LICENSE                            # Apache-2.0
├── env.sh.example                     # 统一环境变量配置模板（提交到 Git）
├── init-env.sh                        # 环境初始化（生成 env.sh + 随机密钥）
├── common.sh                          # 公共函数库
├── install_all.sh                     # 一键安装脚本
├── uninstall_all.sh                   # 一键卸载脚本
├── prepare.sh                         # 拉取 Docker 镜像脚本
├── save-images.sh                     # 导出 Docker 镜像脚本（离线部署）
├── load-images.sh                     # 导入 Docker 镜像脚本（离线部署）
├── docs/
│   ├── DEPLOYMENT.md                  # 英文部署文档
│   ├── DEPLOYMENT.zh-CN.md            # 中文部署文档
│   └── DeepSeek-V4-Flash-Setup.zh-CN.md
├── mysql/
│   ├── conf/
│   ├── initdb/                        # 数据库初始化 SQL 脚本
│   ├── docker-compose.yml
│   ├── execute_sql.sh
│   ├── install.sh
│   └── uninstall.sh
├── mongodb/
│   ├── init/
│   ├── docker-compose.yml
│   ├── create-mongo-users.sh
│   ├── install.sh
│   └── uninstall.sh
├── redis/
│   ├── conf/
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   └── uninstall.sh
├── minio/
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   └── uninstall.sh
├── meilisearch/
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   └── uninstall.sh
├── searxng/
│   ├── config/
│   ├── docker-compose.yml
│   ├── install.sh
│   └── uninstall.sh
├── codeinterpreter-api/
│   ├── ssl/
│   ├── docker/
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   └── uninstall.sh
├── pi-agent/
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   ├── uninstall.sh
│   ├── download-skills.sh             # PI Agent Skills 下载脚本
│   └── skill-repo/                    # Skills 仓库目录（由 download-skills.sh 生成）
├── dmp/
│   ├── data/
│   ├── sql-updates/                   # 增量 SQL 脚本目录（由 update_sql.sh 生成）
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   ├── uninstall.sh
│   └── update_sql.sh                  # DMP 数据库增量更新脚本
├── arp/
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── install.sh
│   └── uninstall.sh
└── mongo-express/
    ├── docker-compose.yml
    ├── install.sh
    └── uninstall.sh
```

---

## 4. 安装前准备

### 4.1 创建网络

所有服务使用统一的 Docker 网络，需要提前创建：

```bash
docker network create openinsight_default
```

### 4.2 克隆仓库

```bash
git clone https://github.com/OpenInsightHQ/openinsight.git
cd openinsight
```

### 4.3 准备 Docker 镜像

#### 4.3.1 在线环境（有网络）

直接执行 `prepare.sh` 脚本拉取所有镜像：

```bash
bash prepare.sh
```

**`prepare.sh` 脚本功能：**

该脚本用于在能访问镜像仓库的在线环境中一次性完成所有镜像的准备工作：
- 拉取官方镜像（MySQL、Redis、MongoDB、MinIO、Meilisearch、SearXNG 等）从 Docker Hub
- 拉取自研镜像（ARP、DMP、PI Agent、Code Interpreter 等）从 GitHub Container Registry（`ghcr.io/openinsighthq`）
- 对 Code Interpreter 的 Node.js / Python 镜像执行 `docker tag` 重命名为本地短名

#### 4.3.2 离线环境（无网络）

1. 在一台能访问镜像仓库的服务器上执行 `save-images.sh`，将所有镜像打包成 `docker-images.tar.gz`：

```bash
bash save-images.sh
```

2. 将 `docker-images.tar.gz` 传输到目标服务器上，执行 `load-images.sh` 加载镜像：

```bash
bash load-images.sh
```

### 4.4 初始化环境变量

**这是部署过程中最核心的一步。**

#### 4.4.1 生成配置文件

执行初始化脚本，自动从模板生成 `env.sh` 并随机填充所有密钥/密码：

```bash
bash init-env.sh
```

#### 4.4.2 设置服务器 IP

编辑生成的 `env.sh`，**只需修改 `HOST_IP`**：

```bash
vi env.sh
```

```env
HOST_IP=192.168.1.100    # 改为实际服务器 IP
```

> **提示**：`init-env.sh` 已自动生成所有组件的密码、密钥，`install.sh` 安装脚本会自动读取 `env.sh` 中的配置并写入到各子系统的 `.env` 和 `docker-compose.yml` 中。除非有特殊需求，否则不需要修改其他配置。

`env.sh` 主要配置项说明：

| 配置项 | 说明 | 默认值 |
|-------|------|--------|
| `HOST_IP` | 部署主机 IP（**必须修改**） | （空，必须填写） |
| `GHCR_REGISTRY` | 自研镜像仓库地址 | `ghcr.io/openinsighthq` |
| `DOCKER_NETWORK` | Docker 网络名称 | `openinsight_default` |
| `USE_EXTERNAL_MYSQL` | 是否使用外部 MySQL | `false` |
| `USE_EXTERNAL_REDIS` | 是否使用外部 Redis | `false` |
| `USE_EXTERNAL_MINIO` | 是否使用外部 MinIO | `false` |
| `DMP_PORT` | DMP 管理平台端口 | `30080` |
| `ARP_PORT` | ARP 智能问答平台端口 | `33080` |

---

## 5. 快速部署

### 5.1 一键安装（推荐）

依次执行初始化、设置 IP、一键安装：

```bash
# 1. 生成 env.sh（自动填充随机密钥）
bash init-env.sh

# 2. 修改 HOST_IP
vi env.sh

# 3. 拉取镜像
bash prepare.sh

# 4. 一键安装
bash install_all.sh
```

脚本会按照依赖顺序自动安装所有组件。

> **注意**：一键安装脚本执行完成后，仍需手动完成以下步骤：
> 1. MySQL 启动后需要执行数据库初始化脚本（见 [6.1 MySQL](#61-mysql)）
> 2. DMP 启动后需要激活 License（见 [6.9 DMP](#69-dmp)）
> 3. DMP 完全激活后才能启动 ARP（见 [6.10 ARP](#610-arp)）

### 5.2 按模块手动安装

如果需要分步控制安装过程，请按照以下 **严格顺序** 逐个执行各模块的 `install.sh`：

```bash
# (1) MongoDB
cd mongodb && bash install.sh && cd ..

# (2) MySQL - 启动后需执行数据库初始化
cd mysql && bash install.sh && cd ..

# (3) Redis
cd redis && bash install.sh && cd ..

# (4) MinIO
cd minio && bash install.sh && cd ..

# (5) Meilisearch
cd meilisearch && bash install.sh && cd ..

# (6) SearXNG
cd searxng && bash install.sh && cd ..

# (7) Code Interpreter API
cd codeinterpreter-api && bash install.sh && cd ..

# (8) PI Agent
cd pi-agent && bash install.sh && cd ..

# (9) DMP - 启动后需激活 License
cd dmp && bash install.sh && cd ..

# (10) ARP - 必须等 DMP 完全激活后才能启动
cd arp && bash install.sh && cd ..
```

> **重要**：安装顺序不可调换，前后组件之间存在依赖关系。

---

## 6. 安装步骤详解

以下详细说明每个模块的安装步骤和注意事项。

### 6.1 MySQL

```bash
cd mysql
bash install.sh
```

**安装脚本功能：**
- 创建 `data/`、`logs/` 目录
- 自动将 `env.sh` 中的 MySQL 密码写入 `docker-compose.yml`
- 创建 Docker 网络
- 启动 MySQL 容器
- 数据库未创建的情况下，install.sh会自动创建数据库并完成整个数据库的初始化，执行initdb文件下的所有脚本，如果失败请手动完成数据库初始化

**数据库初始化（必须执行）：**

MySQL 容器启动完成后，需要手动执行数据库初始化脚本。初始化 SQL 脚本位于 `mysql/initdb/` 目录下，**必须严格按照以下顺序依次执行**（先执行全量初始化脚本，再按版本号顺序执行增量更新脚本）：

| 执行顺序 | 脚本文件 | 说明 |
|:-------:|---------|------|
| 1 | `openinsight.sql` | 全量初始化脚本（数据库基础表结构和初始数据，**必须最先执行**） |
| 2 | `update2.0.1.1.sql` | 增量更新：数据权限表 `dm_data_permission` |
| 3 | `update2.0.1.2.sql` | 增量更新：制式报告相关表 |
| 4 | `update2.0.2.1.sql` | 增量更新：HTTP 技能表 `store_http_skill` |
| 5 | `update2.0.2.2.sql` | 增量更新：角色第三方 ID 字段、问数提示词模板 |
| 6 | `update2.0.2.3.sql` | 增量更新：会话消息查询菜单 |
| 7 | `update2.0.2.4.sql` | 增量更新：表注释增强提示词模板 |
| 8 | `update2.0.2.5.sql` | 增量更新：HTTP 技能 PI 字段、Agent 应用分类字典 |
| 9 | `update2.0.2.6.sql` | 增量更新：角色表 `system_role` 新增 `arp_role_id` 字段（关联 MongoDB roles 表 _id） |
| 10 | `update2.0.2.7.sql` | 增量更新：API 密钥表 `infra_api_key.api_key` 字段长度调整为 `varchar(100)` |

> **⚠️ 重要**：`initdb/` 目录下的脚本存在前后依赖关系，**严禁打乱执行顺序或跳过某个脚本**。建议从 `openinsight.sql` 开始依次执行到最后一个 `update2.0.2.7.sql`。

> **⚠️ 前置操作**：SQL 脚本不包含建库语句，执行任何脚本前**必须先创建数据库并切换**：
> ```sql
> CREATE DATABASE IF NOT EXISTS `openinsight` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
> USE `openinsight`;
> ```

**执行方式二：进入 MySQL 容器手动执行**

`mysql/` initdb目录复制到data目录下

```bash
# 进入 MySQL 容器
docker exec -it openinsight-mysql mysql -uroot -p

# 先创建数据库并切换
CREATE DATABASE IF NOT EXISTS `openinsight` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `openinsight`;

# 按顺序逐个执行
source /var/lib/mysql/initdb/openinsight.sql
source /var/lib/mysql/initdb/update2.0.1.1.sql
source /var/lib/mysql/initdb/update2.0.1.2.sql
source /var/lib/mysql/initdb/update2.0.2.1.sql
source /var/lib/mysql/initdb/update2.0.2.2.sql
source /var/lib/mysql/initdb/update2.0.2.3.sql
source /var/lib/mysql/initdb/update2.0.2.4.sql
source /var/lib/mysql/initdb/update2.0.2.5.sql
source /var/lib/mysql/initdb/update2.0.2.6.sql
source /var/lib/mysql/initdb/update2.0.2.7.sql
```

**执行方式三：使用数据库客户端工具**

使用 Navicat、DBeaver 等客户端工具连接 MySQL，先创建数据库 `openinsight` 并选中，再按上表顺序依次导入并执行 `initdb/` 目录下的 SQL 脚本。

> **如果 `USE_EXTERNAL_MYSQL=true`**，`install.sh` 会跳过内部 MySQL 容器部署，使用外部 MySQL 服务。此时需要在外部 MySQL 上按上述顺序手动执行 `initdb/` 目录下的初始化脚本。

### 6.2 MongoDB

```bash
cd mongodb
bash install.sh
```

**安装脚本功能：**
- 创建 `data/` 目录
- 创建 Docker 网络
- 启动 MongoDB 容器

MongoDB 无需手动初始化，首次启动会自动创建数据库。

### 6.3 Redis

```bash
cd redis
bash install.sh
```

**安装脚本功能：**
- 创建 `data/` 目录
- 自动将 `env.sh` 中的 Redis 密码写入 `docker-compose.yml`
- 创建 Docker 网络
- 启动 Redis 容器

> **如果 `USE_EXTERNAL_REDIS=true`**，`install.sh` 会跳过内部 Redis 容器部署。

### 6.4 MinIO

```bash
cd minio
bash install.sh
```

**安装脚本功能：**
- 创建 `data/` 目录
- 自动将 `env.sh` 中的 MinIO 配置写入 `.env` 和 `docker-compose.yml`
- 创建 Docker 网络
- 启动 MinIO 容器

> **如果 `USE_EXTERNAL_MINIO=true`**，`install.sh` 会跳过内部 MinIO 容器部署。

### 6.5 Meilisearch

```bash
cd meilisearch
bash install.sh
```

**安装脚本功能：**
- 创建 `data/` 目录
- 自动将 `env.sh` 中的 Meilisearch 配置写入 `.env`
- 创建 Docker 网络
- 启动 Meilisearch 容器

### 6.6 SearXNG

```bash
cd searxng
bash install.sh
```

**安装脚本功能：**
- 创建 `config/`、`data/` 目录
- 自动将 `env.sh` 中的 SearXNG 配置写入配置文件
- 创建 Docker 网络
- 启动 SearXNG 容器

> **注意**：SearXNG 网络搜索服务需要服务器能够访问外网。

### 6.7 Code Interpreter API

```bash
cd codeinterpreter-api
bash install.sh
```

**安装脚本功能：**
- 创建必要的目录结构
- 自动将 `env.sh` 中的配置写入 `.env` 和 `docker-compose.yml`
- 创建 Docker 网络
- 启动 Code Interpreter API 容器

### 6.8 PI Agent

```bash
cd pi-agent
bash install.sh
```

**安装脚本功能：**
- 创建 `pi-data/`、`skill-repo/` 目录结构
- 自动将 `env.sh` 中的配置写入 `.env` 和 `docker-compose.yml`
- 创建 Docker 网络
- 启动 PI Agent 容器（程序包已内置于镜像中）

**下载 Skills（建议执行）：**

PI Agent 通过 Skills 扩展能力（如 PPT 生成、Word/PDF/Excel 文档解析、技能创建工具等）。`install.sh` 执行完成后，建议运行 `download-skills.sh` 下载官方 Skills 仓库：

```bash
cd pi-agent
bash download-skills.sh
```

**`download-skills.sh` 脚本功能：**

- 从 GitHub Releases 获取官方 Skill 清单 `list.txt`（清单中每一行为 skill 的相对路径，如 `file-processing/ppt-master.zip`、`general/skill-creator.zip`）
- 按清单中的相对路径下载到 `pi-agent/skill-repo/<分类>/<文件名>`，自动按一级目录（`file-processing` / `general` 等）归类
- 已存在的文件自动跳过，**支持重复执行，仅下载增量**；下载失败的文件会清理残文件并在最后汇总（成功 / 跳过 / 失败数量）

下载后的目录结构示例：

```
pi-agent/skill-repo/
├── file-processing/
│   ├── ppt-master.zip         # PPT 生成技能
│   ├── minimax-docx.zip       # Word 文档解析技能
│   ├── minimax-pdf.zip        # PDF 解析技能
│   └── minimax-xlsx.zip       # Excel 表格处理技能
└── general/
    └── skill-creator.zip      # 技能创建辅助工具
```

> **说明**：`skill-repo` 目录已通过 `docker-compose.yml` 挂载到 PI Agent 容器内的 `/app/skill-repo`，下载完成后无需重启容器即可被 PI Agent 识别使用。后续如需补充新 Skill，重新执行该脚本即可。

### 6.9 DMP

```bash
cd dmp
bash install.sh
```

**安装脚本功能：**
- 创建 `data/` 目录
- 自动将 `env.sh` 中的 MySQL、Redis、MongoDB、Meilisearch 等配置写入 `.env`
- 创建 Docker 网络
- 启动 DMP 容器（`dmp-api` + `dmp-nginx`，程序包已内置于镜像中）

**激活 License（必须执行）：**

DMP 启动成功后，需要激活 License：

1. 打开浏览器访问 `http://<HOST_IP>:30080/dmp/`
2. 使用默认账户登录：
   - 用户名：`chatbi`
   - 密码：`ADMIN_INIT_PASSWORD` 中配置的明文密码（默认 `Chatbi.123`）。
     若将该配置项留空，系统会在首次启动时随机生成 16 位密码，并打印在 dmp-api 启动日志中（搜索关键字 `initial password`）：
     ```bash
     docker logs openinsight-dmp-api 2>&1 | grep 'initial password'
     ```
     获取后请尽快登录并修改密码。
3. 首次登录需要上传 License 文件，`http://<HOST_IP>:30080/dmp/infra/certifcate`
4. 上传 License 后系统完成激活

> **必须在 DMP 完全激活后，才能启动 ARP 系统。**

### 6.10 ARP

**前置条件：DMP 系统必须完全启动并激活 License 后，才能启动 ARP。**

```bash
cd arp
bash install.sh
```

**安装脚本功能：**
- 创建 `data/arp/` 目录结构
- 自动将 `env.sh` 中的所有配置写入 `.env` 和 `docker-compose.yml`，包括：
  - MongoDB 连接地址
  - DMP 平台地址和 API Key
  - PI Agent 地址和 API Key
  - Meilisearch 配置
  - CSP 安全策略
  - JWT 密钥等
- 创建 Docker 网络
- 启动 ARP 容器（程序包已内置于镜像中）

> **注意**：如果 ARP 系统启动失败，请确认 DMP 系统已完全启动并激活 License，然后重新执行 `bash install.sh`。

**ARP 可选配置项说明（`arp/.env`）：**

以下配置项用于控制 ARP 界面展示、水印以及 LLM 流式日志记录，可按需在 `arp/.env` 中手动调整（修改后需重启 ARP 容器：`docker-compose restart` 或 `docker-compose down && docker-compose up -d`）。

| 配置项 | 默认值 | 说明 |
|-------|--------|------|
| `UI_LEFT_SIDEBAR_HIDDEN` | `false` | 是否隐藏左侧导航栏。设为 `true` 后 ARP 界面不显示左侧侧边栏 |
| `UI_LEFT_SIDEBAR_BUTTON_HIDDEN` | `false` | 是否隐藏左侧导航栏的展开/收起按钮。设为 `true` 后不显示该切换按钮 |
| `UI_PREVIEW_CODE_HIDDEN` | `false` | 是否隐藏 Artifact 中的代码 Tab。设为 `true` 后 Artifact 不显示代码标签页，直接展示预览效果 |
| `UI_PREVIEW_AUTO_REFRESH` | `true` | Artifact 流式生成过程中的预览刷新策略。设为 `true`（默认）时，生成期间按定时刷新实时渲染预览；设为 `false` 时，生成过程中仅保留 "generating" 占位提示，待消息生成完成后才一次性渲染预览（不做定时刷新），可降低生成期间的渲染开销 |
| `UI_FOOTER_HIDDEN` | `false` | 是否隐藏聊天界面底部的 Footer。设为 `true` 后 ARP 不显示聊天页脚 |
| `WATERMARK_CHAT_ENABLED` | `false` | 聊天气泡水印开关。设为 `true` 后在聊天气泡上叠加用户信息水印 |
| `WATERMARK_ARTIFACTS_ENABLED` | `false` | Artifact 水印开关。设为 `true` 后在 Artifact 内容上叠加用户信息水印 |
| `WATERMARK_TEMPLATE` | `{department}-{name}` | 水印文本模板，支持占位符 `{department}`（部门）和 `{name}`（姓名），由用户信息自动填充。可不配置，默认即为此值 |
| `WATERMARK_OPACITY` | `0.08` | 水印透明度，取值范围 `0`~`1`，默认 `0.08`。暗色模式或打印模式下水印会自动加强 |
| `WATERMARK_FONT_SIZE` | `14` | 水印字号（px），默认 `14` |
| `WATERMARK_DENSITY` | `5` | 水印密度，取值范围 `1`~`10`，默认 `5`（对应约 4 列 × 6 行）。数值越大水印越密集 |
| `WATERMARK_ROTATION` | `-10` | 水印旋转角度，取值范围 `-90`~`90`，默认 `-10` |
| `LOG_LLM_STREAM` | `false` | 是否记录 LLM 原始流式响应（SSE）。设为 `true` 后，LLM 返回的原始 stream 会被捕获并存储到 assistant 消息记录的 `streamLog` 字段（`messages` 表）。适用于所有对话路径：主 UI 流程、v1/v2/responses agent API 以及 legacy assistants API；中断/出错时也会保存部分流。开启会增加数据库存储开销，仅在排障/审计需要时开启 |

**SSO 免密登录配置（JWT）：**

以下 `AUTO_SSO_*` 配置用于对接外部系统的 JWT 免密登录（单点登录 SSO）。启用后，ARP 会从请求中读取外部系统签发的 JWT Token，验签通过后自动完成登录，无需用户在 ARP 再次输入账号密码。**注意：`AUTO_SSO_SECRET_KEY` 必须与外部系统签发 JWT 时使用的密钥保持一致**，否则验签失败会导致登录无效。

| 配置项 | 默认值 | 说明                                                               |
|-------|--------|------------------------------------------------------------------|
| `AUTO_SSO` | `false` | 是否启用 SSO 免密登录。设为 `true` 后启用 JWT 自动登录流程                           |
| `AUTO_SSO_TOKEN_NAME` | `ecdp-auth` | 携带 JWT 的字段名称（如 queryString 名称或 Header 名称），由外部系统在请求中带入            |
| `AUTO_SSO_TOKEN_TYPE` | `JWT` | Token 类型，固定为 `JWT`                                               |
| `AUTO_SSO_ALG` | `HS256` | JWT 签名算法，常用 `HS256`（HMAC-SHA256），需与签发方一致                         |
| `AUTO_SSO_SECRET_KEY` | `abcdefgh` | JWT 验签密钥。**必须与外部系统签发 Token 时使用的密钥完全一致**，否则验签失败。生产环境建议修改为高强度随机字符串 |
| `AUTO_SSO_USER_MAPPING` | 见下文 | 外部系统 JWT Payload 字段与 ARP 用户字段的映射关系                               |

**`AUTO_SSO_USER_MAPPING` 字段映射说明：**

格式为 `外部字段=本地字段` 的逗号分隔列表（冒号 `:` 与等号 `=` 均可作为分隔符），用于将 JWT Payload 中的用户信息字段映射到 ARP 内部的用户字段。默认值：

```env
AUTO_SSO_USER_MAPPING=userId:user_id,account=account,userName=user_name,roleId=role_id,roleName=role_name,deptId=dept_id,deptName=dept_name,remark=__all
```

| 外部字段 | 本地字段 | 含义                                  |
|--------|--------|-------------------------------------|
| `userId` | `user_id` | 用户 ID                               |
| `account` | `account` | 登录账号                                |
| `userName` | `user_name` | 用户姓名（水印中的 `{name}` 占位符即取自此字段）       |
| `roleId` | `role_id` | 角色 ID                               |
| `roleName` | `role_name` | 角色名称                                |
| `deptId` | `dept_id` | 部门 ID                               |
| `deptName` | `dept_name` | 部门名称（水印中的 `{department}` 占位符即取自此字段） |
| `remark` | `__all` | 特殊标记，`__all` 表示所有字段内容               |

> **提示**：可根据外部系统 JWT Payload 的实际字段名调整映射关系，但右侧本地字段（`user_id`、`account` 等）为 ARP 内部约定，请勿随意修改。

配置示例：

```env
UI_LEFT_SIDEBAR_HIDDEN=false
UI_LEFT_SIDEBAR_BUTTON_HIDDEN=false
UI_PREVIEW_CODE_HIDDEN=true
UI_PREVIEW_AUTO_REFRESH=true
UI_FOOTER_HIDDEN=false

WATERMARK_CHAT_ENABLED=false
WATERMARK_ARTIFACTS_ENABLED=false
WATERMARK_TEMPLATE={department}-{name}
WATERMARK_OPACITY=0.08
WATERMARK_FONT_SIZE=14
WATERMARK_DENSITY=5
WATERMARK_ROTATION=-10

# SSO 免密登录（JWT）
AUTO_SSO=false
AUTO_SSO_TOKEN_NAME=ecdp-auth
AUTO_SSO_TOKEN_TYPE=JWT
AUTO_SSO_ALG=HS256
AUTO_SSO_SECRET_KEY=abcdefgh
AUTO_SSO_USER_MAPPING=userId:user_id,account=account,userName=user_name,roleId=role_id,roleName=role_name,deptId=dept_id,deptName=dept_name,remark=__all

LOG_LLM_STREAM=true
```

---

## 7. 配置说明

### 7.1 env.sh 统一配置文件

所有配置集中在根目录 `env.sh` 文件中，分为以下几大区域：

#### 7.1.1 基础配置

```env
HOST_IP=                         # 部署主机 IP（必改）
DOMAIN=                          # 域名（可选）
GHCR_REGISTRY=ghcr.io/openinsighthq
DOCKER_NETWORK=openinsight_default
TIMEZONE=Asia/Shanghai
```

#### 7.1.2 中间件部署模式

```env
USE_EXTERNAL_MYSQL=false       # true 表示使用外部 MySQL
USE_EXTERNAL_REDIS=false       # true 表示使用外部 Redis
USE_EXTERNAL_MINIO=false       # true 表示使用外部 MinIO
```

设为 `true` 时，对应组件的 `install.sh` 会跳过内部容器部署，使用 `env.sh` 中配置的外部连接参数。

#### 7.1.3 端口配置

```env
ARP_PORT=33080                 # ARP 智能问答平台端口
DMP_PORT=30080                 # DMP 管理平台端口
CODE_INTERPRETER_API_PORT=8000 # Code Interpreter API 端口
MINIO_API_PORT=19000           # MinIO API 端口
MINIO_CONSOLE_PORT=19001       # MinIO Console 端口
MONGO_EXPRESS_PORT=18081       # Mongo Express 端口
```

#### 7.1.4 MySQL 配置

```env
MYSQL_HOST=openinsight-mysql
MYSQL_PORT=3306
MYSQL_USERNAME=root
MYSQL_ROOT_PASSWORD=             # init-env.sh 自动生成
DMP_DB_NAME=openinsight
```

#### 7.1.5 Redis 配置

```env
REDIS_HOST=openinsight-redis
REDIS_PORT=6379
REDIS_PASSWORD=                  # init-env.sh 自动生成
DMP_REDIS_DATABASE=11
```

#### 7.1.6 MinIO 配置

```env
MINIO_INTERNAL_ENDPOINT=openinsight-minio:9000
MINIO_EXTERNAL_ENDPOINT=localhost:19000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET=code-interpreter-files
```

### 7.2 端口配置

默认端口映射：

| 服务 | 主机端口 | 容器端口 | 说明 |
|-----|---------|---------|------|
| DMP 前端 | 30080 | 80 | 数据管理平台 Web 界面 |
| ARP 前端 | 33080 | 3000 | 智能问答平台 |
| Code Interpreter | 8000 | 8000 | 代码解释器 API |
| MinIO API | 19000 | 9000 | 对象存储 API |
| MinIO Console | 19001 | 9001 | 对象存储控制台 |
| SearXNG | 38888 | 8080 | 网络搜索服务 |
| Meilisearch | 37700 | 7700 | 全文搜索服务 |

### 7.3 默认账户

| 平台 | 用户名 | 密码 |
|-----|-------|------|
| DMP 管理平台 | chatbi | `ADMIN_INIT_PASSWORD` 中配置的明文密码（默认 `Chatbi.123`） |
| ARP 智能问答平台 | chatbi@example.com | 与 DMP 管理员密码一致 |

> **说明**：管理员密码由 `dmp/.env` 中的 `ADMIN_INIT_PASSWORD`（明文）统一控制，同时作用于 DMP（MySQL）与 ARP（MongoDB）管理员账号。
> 若将该配置项留空，系统会在首次启动时随机生成 16 位密码，并打印在 dmp-api 启动日志中（搜索关键字 `initial password`），获取后请尽快登录并修改密码。
> 若系统中已存在的管理员账号密码为空，系统启动时也会自动随机重置并打印日志。

### 7.4 SSL 证书配置（可选）

如需支持 HTTPS，需配置 SSL 证书：

1. 将 SSL 证书文件放置到 `codeinterpreter-api/ssl/` 目录

**临时解决方案（未配置 SSL 证书时）：**

Chrome 浏览器进行以下配置：
1. 访问 `chrome://flags/#unsafely-treat-insecure-origin-as-secure`
2. 在 "Insecure origins treated as secure" 输入框输入：
   `http://<IP>:33080`
3. 将其设置为 Enabled
4. 点击 "Relaunch" 重启浏览器

### 7.5 防火墙端口开放

需要开放以下端口：

| 端口 | 用途 |
|-----|------|
| 30080 | 数据管理平台（DMP） |
| 33080 | 智能体系统（ARP） |

---

## 8. 服务管理

### 8.1 启动单个服务

```bash
cd <module-directory>
docker-compose up -d
```

### 8.2 停止单个服务

```bash
cd <module-directory>
docker-compose down
```

### 8.3 重启单个服务

```bash
cd <module-directory>
docker-compose restart
```

### 8.4 查看服务状态

```bash
docker ps --filter "name=openinsight-"
```

### 8.5 查看服务日志

```bash
# 查看特定服务日志
cd <module-directory>
docker-compose logs -f

# 或直接指定容器名
docker logs -f openinsight-dmp-api
docker logs -f openinsight-arp
```

---

## 9. 验证部署

### 9.1 DMP 数据管理平台验证

1. 打开浏览器访问 `http://<HOST_IP>:30080/dmp/`
2. 使用默认账户登录：
   - 用户名：`chatbi`
   - 密码：`ADMIN_INIT_PASSWORD` 中配置的明文密码（默认 `Chatbi.123`）。若该配置项留空，初始密码为系统随机生成，可在 dmp-api 日志中查看：`docker logs openinsight-dmp-api 2>&1 | grep 'initial password'`
3. 首次登录需要上传 License 文件
4. 上传证书后重新登录

### 9.2 ARP 智能问答平台验证

1. 访问 `http://<HOST_IP>:33080/arp/`
2. 使用默认账户登录：
   - 用户名：`chatbi@example.com`
   - 密码：与 DMP 管理员密码一致（由 `ADMIN_INIT_PASSWORD` 控制）
3. 测试对话功能是否正常

### 9.3 服务健康检查

```bash
# 检查所有容器状态
docker ps --filter "name=openinsight-"

# 检查特定端口是否可访问
curl http://localhost:30080/dmp/
curl http://localhost:33080/arp/
```

---

## 10. 应用更新

### 10.1 使用安装脚本更新

各组件的安装脚本支持重复执行，可用于更新程序：

```bash
# 更新 DMP
cd dmp
bash install.sh

# 更新 ARP
cd ../arp
bash install.sh
```

### 10.2 DMP 数据库增量更新

当仅升级 DMP API 程序包（不重装整个系统）时，需同步执行对应版本的数据库增量更新脚本。`dmp/update_sql.sh` 用于自动完成增量 SQL 的下载与执行。

**前置准备：**

1. 将新版 DMP API 程序包（如 `dmp-api-2.0.2.8.jar`）放入 `dmp/` 目录
2. 确认 `dmp/.env` 中已配置 `DMP_VERSION=<当前已部署版本号>`（脚本依据此字段判断需要执行哪些更新脚本）。若 `.env` 中未配置 `DMP_VERSION`，脚本会跳过整个下载与执行流程。

**执行方式：**

```bash
cd dmp
bash update_sql.sh
```

**`update_sql.sh` 脚本功能：**

1. 检测 `dmp/` 目录下的 `dmp-api-*.jar` 程序包，从文件名解析出目标版本号（如 `dmp-api-2.0.2.8.jar` → `2.0.2.8`）。未发现程序包则终止。
2. 读取 `dmp/.env` 中的 `DMP_VERSION` 作为当前已部署版本号
3. 从 GitHub Releases 获取所有 `update<a.b.c.d>.sql` 脚本列表
4. 按"四段版本号"逐段数值比较，筛选出 `(CURRENT_VERSION, TARGET_VERSION]` 区间内的更新脚本，并按版本号从小到大顺序依次下载并执行
5. 已下载过的脚本保存在 `dmp/sql-updates/` 目录，避免重复下载

**典型场景示例：**

假设当前已部署版本为 `2.0.2.7`，新放入 `dmp-api-2.0.2.8.jar` 后执行 `update_sql.sh`，脚本会自动下载并执行 `update2.0.2.11.sql`（若该脚本存在），跳过 `2.0.2.7` 及更早版本的脚本。

> **注意**：
> 1. 脚本通过 `mysql/execute_sql.sh` 执行 SQL，对单条语句失败有容错（仅输出警告），但建议执行完成后检查日志确认是否有失败语句。
> 2. `DMP_VERSION` 字段不会被脚本自动更新，**更新完成后请手动将其改为新版本号**，以便下次升级时正确判断区间。
> 3. 首次全新部署无需执行此脚本，初始化 SQL 由 [6.1 MySQL](#61-mysql) 节中描述的 `initdb/` 流程完成。

### 10.3 全量更新

修改 `env.sh` 后重新执行一键安装脚本：

```bash
bash install_all.sh
```

> **注意**：安装脚本会检测已存在的程序包，不会重复下载。

---

## 11. 卸载

### 11.1 一键卸载

```bash
bash uninstall_all.sh
```

脚本会按依赖反序卸载所有子系统（ARP -> DMP -> ... -> MySQL -> MongoDB）。

### 11.2 手动卸载

```bash
cd <module-directory>
bash uninstall.sh
```

> **提示**：卸载不会删除数据目录（`data/`）。如需彻底清除数据，请手动删除各子系统目录下的 `data/` 文件夹。如需清除 Docker 网络，请执行 `docker network rm openinsight_default`。

---

## 12. 常见问题

### 12.1 服务启动失败

**问题**：服务无法启动

**解决方案**：
1. 检查 Docker 服务状态：`systemctl status docker`
2. 检查端口是否被占用：`netstat -tlnp | grep <port>`
3. 查看日志：`docker-compose logs -f <service-name>`
4. 检查网络是否正确创建：`docker network inspect openinsight_default`
5. 验证 `env.sh` 配置是否正确

### 12.2 数据库连接失败

**问题**：无法连接到 MySQL/MongoDB/Redis

**解决方案**：
1. 检查数据库容器是否运行：`docker ps | grep mysql`
2. 验证 `env.sh` 中的连接信息
3. 检查网络连接：`docker network inspect openinsight_default`

### 12.3 License 上传失败

**问题**：上传 License 文件后系统提示失败

**解决方案**：
1. 确保 License 文件格式正确
2. 检查 DMP API 服务是否正常运行
3. 查看 DMP API 日志获取详细错误信息：`docker logs -f openinsight-dmp-api`

### 12.4 ARP 启动失败

**问题**：ARP 系统启动失败

**解决方案**：
1. 确认 DMP 系统已完全启动并激活 License
2. 确认 MySQL 已执行数据库初始化脚本
3. 确认 MongoDB、Redis 等基础设施服务正常运行
4. 重新执行 `cd arp && bash install.sh`

### 12.5 模型调用失败

**问题**：对话时提示模型调用失败

**解决方案**：
1. 检查 DMP 平台的模型配置
2. 验证 API-Key 是否正确配置
3. 确认网络连接是否正常
4. 检查模型服务的可用性

### 12.6 代码执行失败

**问题**：代码执行返回错误

**解决方案**：
1. 检查 Code Interpreter API 服务状态
2. 验证 MinIO 存储服务是否正常
3. 检查 Redis 连接配置
4. 查看代码执行日志

---

## 附录

### A. Docker 网络信息

- 网络名称：`openinsight_default`
- 网络类型：bridge
- 外部网络，需要提前创建（`install.sh` 会自动创建）

### B. 数据持久化路径

所有数据目录建议进行定期备份：

- `mysql/data/` - MySQL 数据
- `mongodb/data/` - MongoDB 数据
- `redis/data/` - Redis 数据
- `minio/data/` - MinIO 存储
- `meilisearch/data/` - 搜索索引
- `dmp/data/` - DMP 应用数据
- `arp/data/` - ARP 应用数据
- `pi-agent/pi-data/` - PI Agent 数据
- `codeinterpreter-api/data/` - 代码解释器数据

### C. 安全建议

1. 修改 `env.sh` 中所有默认密码和密钥
2. 配置 SSL/TLS 证书
3. 限制数据库访问端口，不要将 MySQL、MongoDB、Redis 端口暴露到外网
4. 定期更新安全补丁
5. 启用防火墙规则，仅开放必要端口
6. 定期备份重要数据

### D. 安装顺序依赖关系

```
MySQL ──┐
MongoDB ├── DMP ── ARP
Redis ──┤   ↑
MinIO ──┤   │ (需激活 License)
Meilisearch ┘
SearXNG
Code Interpreter API
PI Agent
```

---

*文档版本：v2.0.2*
*更新日期：2026-06-30*
