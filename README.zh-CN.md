# OpenInsight

> 🌐 语言：[English](README.md) | **简体中文**

企业级 AI 智能体平台 —— 统一配置 + 模块化安装 + 一键部署。

📘 **[部署文档 →](docs/DEPLOYMENT.zh-CN.md)**

## 简介

OpenInsight 是一套企业级 AI 智能体平台，包含以下核心组件：

| 组件 | 说明 |
|------|------|
| **DMP**（数据管理平台） | 后端服务 + 前端管理界面，统一管理模型配置、用户、权限 |
| **ARP**（智能问答平台） | 用户对话智能体平台，支持多模型、Artifacts、代码执行 |
| **PI Agent** | PI 智能代理服务，支持代码执行、文件处理、技能扩展 |

基础设施服务：MySQL、MongoDB、Redis、MinIO、Meilisearch、SearXNG、Code Interpreter API。

## 系统要求

| 项目 | 最低 | 推荐 |
|------|------|------|
| CPU | 4 核 | 16 核 |
| 内存 | 16 GB | 32 GB |
| 硬盘 | 100 GB | 500 GB |

**前置依赖：** Docker 24.07+、Docker Compose v2.26.1+

**操作系统：** Ubuntu 20.04/22.04、CentOS/RedHat 7.9、CentOS 8.6、RedHat 8.5

## 快速部署

### 1. 克隆仓库

```bash
git clone https://github.com/OpenInsightHQ/openinsight.git
cd openinsight
```

### 2. 初始化环境配置

```bash
bash init-env.sh
```

脚本会自动从 `env.sh.example` 生成 `env.sh` 并随机填充所有密码和密钥。

### 3. 设置服务器 IP

编辑生成的 `env.sh`，将 `HOST_IP` 改为实际服务器 IP：

```bash
vi env.sh
```

```env
HOST_IP=192.168.1.100    # 改为你的服务器 IP
```

### 4. 拉取镜像（在线环境）

```bash
bash prepare.sh
```

> 离线环境：先在联网机器执行 `bash save-images.sh`，将 `docker-images.tar.gz` 传输到目标服务器执行 `bash load-images.sh`。

### 5. 一键安装

```bash
bash install_all.sh
```

### 6. 安装后步骤

1. **激活 License**：访问 `http://<HOST_IP>:30080/dmp/`，使用默认账户登录（用户名 `chatbi`，密码 `Chatbi.123`），上传 License 文件。
2. **访问 ARP**：DMP 激活后，ARP 会自动启动。访问 `http://<HOST_IP>:33080/arp/`。

📖 完整说明请参阅 **[部署文档](docs/DEPLOYMENT.zh-CN.md)**。

## 配置说明

所有配置集中在 `env.sh` 中（由 `init-env.sh` 从 `env.sh.example` 自动生成）。

- **密钥/密码**：首次运行 `init-env.sh` 时自动随机生成，无需手动填写
- **HOST_IP**：唯一必须手动修改的配置项
- **外部中间件**：设置 `USE_EXTERNAL_MYSQL/REDIS/MINIO=true` 可使用外部服务
- **PI Agent LLM**：需在 `env.sh` 中配置 `OPENCODE_API_KEY` 和 `PI_MODEL`

## 目录结构

```
openinsight/
├── init-env.sh              # 环境初始化（生成 env.sh + 随机密钥）
├── install_all.sh           # 一键安装
├── uninstall_all.sh         # 一键卸载
├── prepare.sh               # 拉取 Docker 镜像
├── save-images.sh           # 导出镜像（离线部署）
├── load-images.sh           # 导入镜像（离线部署）
├── env.sh.example           # 配置模板（提交到 Git）
├── common.sh                # 公共函数库
├── docs/                    # 文档目录
├── mysql/                   # MySQL + 初始化 SQL
├── mongodb/                 # MongoDB
├── redis/                   # Redis
├── minio/                   # MinIO 对象存储
├── meilisearch/             # Meilisearch 全文搜索
├── searxng/                 # SearXNG + MCP
├── codeinterpreter-api/     # Code Interpreter API
├── pi-agent/                # PI Agent
├── dmp/                     # DMP 数据管理平台
├── arp/                     # ARP 智能问答平台
└── mongo-express/           # Mongo Express 管理界面
```

## 服务管理

```bash
# 启动 / 停止 / 重启单个服务
cd <module> && docker-compose up -d
cd <module> && docker-compose down
cd <module> && docker-compose restart

# 查看所有服务状态
docker ps --filter "name=openinsight-"

# 一键卸载（保留数据）
bash uninstall_all.sh
```

## 默认端口

| 服务 | 端口 |
|------|------|
| DMP 管理平台 | 30080 |
| ARP 智能问答平台 | 33080 |
| Code Interpreter API | 8000 |

## 开源协议

[Apache License 2.0](LICENSE)
