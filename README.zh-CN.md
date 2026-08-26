# Open Insight

> 🌐 语言：**简体中文** | [English](README.md)

### 为你的企业打造下一代 AI 员工。

> **一队 AI 员工：理解你的业务、执行专业工作、交付真实的业务成果。**

它让 AI 理解企业系统、企业数据、企业知识与个人记忆，并通过可复用的 **Enterprise Skills（企业技能）** 执行真实的业务任务。

| 组件 | 角色 | License |
|---|---|---|
| **[ARP](https://github.com/OpenInsightHQ/arp)** | AI 员工的运行时——任意模型、任意工具、任意技能 | Apache-2.0 |
| **[ONE-PI](https://github.com/OpenInsightHQ/one-pi)** | 推理引擎——能理解、推理、执行的虚拟专家 | Apache-2.0 |
| **DMP** | 企业核心——四大学习引擎，教会 AI 你的数据、系统与知识 | 商业授权 |

员工在浏览器中工作，零安装。部署在你自己的基础设施上。

📘 **[部署指南 →](docs/DEPLOYMENT.md)** · 完整故事：**[组织主页](https://github.com/OpenInsightHQ)**

---

## 架构

> **企业 AI，始于理解企业。**

<p align="center">
  <img src="docs/assets/architecture-diagram.png" alt="Open Insight 架构图" width="720">
</p>

### ONE-PI Agent 架构

ONE-PI 连接一组可扩展的专家智能体，每个专家配备 Prompt、MCP、API 与 Skill 能力。

<p align="center">
  <img src="docs/assets/one-pi-agent-architecture.svg" alt="ONE-PI Agent 架构" width="720">
</p>

## 产品体验

### Agent 运行平台（ARP）

<p align="center">
  <img src="docs/assets/01-arp-main.png" alt="Agent 运行平台" width="820">
</p>

<p align="center">
  <img src="docs/assets/02-arp-agent.png" alt="Agent 运行平台" width="820">
</p>

### 企业数据与 AI 管理（DMP）

<p align="center">
  <img src="docs/assets/03-dmp.png" alt="企业数据与 AI 管理" width="820">
</p>

## 为什么是 Open Insight？

大多数 Data Agent 系统，为回答问题而设计。

**Open Insight 为达成业务目标而设计。**

企业不衡量对话。

**企业衡量结果。**

## 为企业而生，而非个人 AI

大多数 AI Agent 为个人用户设计：每个用户都要自己安装、配置、管理自己的 AI 环境。

Open Insight 选择了另一条路。**企业学习一次，人人受益。**

Open Insight 持续向企业学习——它的数据、系统、业务知识、工作流、技能与经验。这些知识被集中管理、统一治理，并提供给组织内的每一位员工。

它运行在企业基础设施上，而不是个人电脑。员工无需安装、无需配置、无需维护。它 **7×24** 工作着——监控系统、处理任务、与其他部门的 AI 智能体协作。

## 路线图

| 组件 | 已发布 | 下一步 |
|---|---|---|
| **ARP**——AI 员工在哪运行 | 多模型对话 · Agent 与 MCP · 共享技能 · 私有化部署 | 更深入的 ONE-PI 集成 · 社区 Agent 与 MCP 模板 · 本地浏览器插件 |
| **ONE-PI**——AI 员工如何思考 | 虚拟专家 · 共享技能仓库 · OpenAI 兼容 Agent API | **A2A 协作** · 更多专家 |
| **DMP**——企业得到什么 | 四大学习引擎 · 治理型企业核心 *（商业版）* | 更深的企业知识库 · 更多企业连接器 · 更深度的治理 |

**重新定义 A2A。** 传统多智能体系统，是由一个框架编排多个智能体。Open Insight 的 A2A 不同：每个人指挥自己的 AI，过去发生在人与人之间的协作，如今发生在智能体与智能体之间——由人来批准关键事项。

---

## 社区版与企业版

OpenInsight 采用 **Open Core（开放核心）** 授权模式，提供两个版本：

|                     | Community Edition（社区版） | Enterprise Edition（企业版） |
| ------------------- | ---------------------- | ----------------------- |
| **核心平台**          | ✓                      | ✓                       |
| **部署方式**          | 私有化部署                 | 私有化部署                   |
| **企业级功能**         | —                      | ✓                       |
| **许可证**            | 不需要                    | 需要                      |

**Community Edition（社区版）** 免费使用，无需商业授权即可部署和使用。

**Enterprise Edition（企业版）** 在社区版基础上提供额外的企业级及商业功能，需要使用由 OpenInsight 官方签发的有效 License 文件。

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

无需商业授权。安装完成后即可直接访问平台：

* **DMP：** `http://<HOST_IP>:30080/dmp/`
* **ARP：** `http://<HOST_IP>:33080/arp/`

**Enterprise Edition（企业版）**

企业级功能需要有效的 License 文件。安装完成后，进入 DMP 管理界面上传并激活 Enterprise License。

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
├── pi-agent/                # ONE-PI（PI Agent）服务
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
* 企业级功能及其他专有商业能力，需要有效的商业 **License 文件**。

请参阅 [`LICENSE`](./LICENSE) 了解 Apache License 2.0，参阅 [`LICENSE-COMMERCIAL.md`](./LICENSE-COMMERCIAL.md) 了解商业授权信息。
