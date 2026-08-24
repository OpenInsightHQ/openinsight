# OpenInsight

> 🌐 语言：**简体中文** | [English](README.md)

企业级 AI Agent 平台 — 统一配置、模块化安装、一键部署。

📘 **[部署指南 →](docs/DEPLOYMENT.md)**

## 产品概览

OpenInsight 是一个企业级 AI Agent 平台，包含以下核心组件：

| 组件                                | 说明                                        |
| --------------------------------- | ----------------------------------------- |
| **DMP**（Data Management Platform） | 数据与 AI 管理平台，负责模型配置、用户、权限及数据管理             |
| **ARP**（Agent Runtime Platform）   | Agent 运行平台，支持多模型、Artifacts、代码执行及 Agent 能力 |
| **PI Agent**                      | PI Agent 服务，支持代码执行、文件处理及 Skill 扩展         |

基础设施：MySQL、MongoDB、Redis、MinIO、Meilisearch、SearXNG、Code Interpreter API。

## 社区版与企业版

OpenInsight 采用 **Open Core（开放核心）** 模式，提供两个版本：

|                 | Community Edition（社区版） | Enterprise Edition（企业版） |
| --------------- | ---------------------- | ----------------------- |
| **核心平台**        | ✓                      | ✓                       |
| **部署方式**        | 私有化部署                  | 私有化部署                   |
| **企业级功能**       | —                      | ✓                       |
| **License Key** | 不需要                    | 需要                      |

**Community Edition（社区版）** 免费使用，无需商业 License Key 即可部署和使用。

**Enterprise Edition（企业版）** 在社区版基础上提供额外的企业级及商业功能，需要使用由 OpenInsight 官方提供的有效 License Key。

更多信息请参阅 [`LICENSE-COMMERCIAL.md`](./LICENSE-COMMERCIAL.md)。

## 系统要求

| 项目  | 最低配置   | 推荐配置   |
| --- | ------ | ------ |
| CPU | 4 核    | 16 核   |
| 内存  | 16 GB  | 32 GB  |
| 磁盘  | 100 GB | 500 GB |

**前置要求：** Docker 24.07+、Docker Compose v2.26.1+

**操作系统：** Ubuntu 20.04/22.04、CentOS/RHEL 7.9、CentOS 8.6、RHEL 8.5

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/OpenInsightHQ/openinsight.git
cd openinsight
```

### 2. 初始化环境

```bash
bash init-env.sh
```

该命令会根据 `env.sh.example` 生成 `env.sh`，并自动为密码和密钥生成随机值。

### 3. 设置服务器 IP

编辑生成的 `env.sh`，将 `HOST_IP` 修改为实际服务器 IP：

```bash
vi env.sh
```

```env
HOST_IP=192.168.1.100    # 服务器 IP
```

### 4. 拉取镜像（在线部署）

```bash
bash prepare.sh
```

> 离线部署：在联网机器上执行 `bash save-images.sh`，将生成的 `docker-images.tar.gz` 复制到目标服务器，然后执行 `bash load-images.sh`。

### 5. 一键安装

```bash
bash install_all.sh
```

### 6. 安装完成后

**Community Edition（社区版）**

无需商业 License Key。安装完成后即可直接访问平台：

* **DMP：** `http://<HOST_IP>:30080/dmp/`
* **ARP：** `http://<HOST_IP>:33080/arp/`

**Enterprise Edition（企业版）**

企业级功能需要有效的 License Key。安装完成后，进入 DMP 管理界面激活 Enterprise License。

📖 完整部署说明请参阅 **[部署指南](docs/DEPLOYMENT.md)**。

## 配置

所有配置均位于 `env.sh`，由 `init-env.sh` 根据 `env.sh.example` 自动生成。

* **密码/密钥：** 首次运行时自动随机生成
* **HOST_IP：** 唯一需要手动修改的配置
* **外部中间件：** 设置 `USE_EXTERNAL_MYSQL/REDIS/MINIO=true` 使用外部服务
* **PI Agent LLM：** 部署完成后配置 `OPENCODE_API_KEY` 和 `PI_MODEL`

## 目录结构

```text
openinsight/
├── init-env.sh              # 环境初始化
├── install_all.sh           # 一键安装
├── uninstall_all.sh         # 一键卸载
├── prepare.sh               # 拉取 Docker 镜像
├── save-images.sh           # 导出离线部署镜像
├── load-images.sh           # 导入离线部署镜像
├── env.sh.example           # 配置模板
├── common.sh                # 共享函数库
├── docs/                    # 文档
├── mysql/                   # MySQL + 初始化 SQL
├── mongodb/                 # MongoDB
├── redis/                   # Redis
├── minio/                   # MinIO 对象存储
├── meilisearch/             # Meilisearch 全文搜索
├── searxng/                 # SearXNG + MCP
├── codeinterpreter-api/     # Code Interpreter API
├── pi-agent/                # PI Agent
├── dmp/                     # DMP 数据管理平台
├── arp/                     # ARP Agent 平台
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

| 服务                   | 端口    |
| -------------------- | ----- |
| DMP                  | 30080 |
| ARP                  | 33080 |
| Code Interpreter API | 8000  |

## License

OpenInsight 采用 **Open Core（开放核心）** 授权模式。

* 本仓库中适用开源许可证的组件和材料，按照其对应的开源许可证授权，其中包括 **Apache License 2.0**。
* 企业级功能及其他专有商业能力需要有效的商业 **License Key**。

请参阅 [`LICENSE`](./LICENSE) 了解 Apache License 2.0，参阅 [`LICENSE-COMMERCIAL.md`](./LICENSE-COMMERCIAL.md) 了解商业授权信息。
