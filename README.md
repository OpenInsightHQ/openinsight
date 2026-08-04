# OpenInsight

> 🌐 Languages: **English** | [简体中文](README.zh-CN.md)

Enterprise AI agent platform — unified config + modular install + one-click deployment.

📘 **[Deployment Guide →](docs/DEPLOYMENT.md)**

## Overview

OpenInsight is an enterprise-grade AI agent platform with these core components:

| Component | Description |
|-----------|-------------|
| **DMP** (Data Management Platform) | Backend + admin UI; manages model config, users, permissions |
| **ARP** (Agent Response Platform) | Conversational AI agent platform; multi-model, Artifacts, code execution |
| **PI Agent** | PI agent service; code execution, file processing, skill extensibility |

Infrastructure: MySQL, MongoDB, Redis, MinIO, Meilisearch, SearXNG, Code Interpreter API.

## System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 4 cores | 16 cores |
| RAM | 16 GB | 32 GB |
| Disk | 100 GB | 500 GB |

**Prerequisites:** Docker 24.07+, Docker Compose v2.26.1+

**OS:** Ubuntu 20.04/22.04, CentOS/RHEL 7.9, CentOS 8.6, RHEL 8.5

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/OpenInsightBH/openinsight.git
cd openinsight
```

### 2. Initialize environment

```bash
bash init-env.sh
```

This generates `env.sh` from `env.sh.example` and auto-fills all passwords/keys with random values.

### 3. Set the server IP

Edit the generated `env.sh` and change `HOST_IP` to the actual server IP:

```bash
vi env.sh
```

```env
HOST_IP=192.168.1.100    # Your server IP
```

### 4. Pull images (online)

```bash
bash prepare.sh
```

> Offline: run `bash save-images.sh` on a networked machine, copy `docker-images.tar.gz` to the target server, then run `bash load-images.sh`.

### 5. One-click install

```bash
bash install_all.sh
```

### 6. Post-install steps

1. **Activate License**: open `http://<HOST_IP>:30080/dmp/`, log in (`chatbi` / `Chatbi.123`), upload the License file.
2. **Access ARP**: once DMP is activated, ARP starts automatically. Open `http://<HOST_IP>:33080/arp/`.

📖 For full details, see the **[Deployment Guide](docs/DEPLOYMENT.md)**.

## Configuration

All config lives in `env.sh` (generated from `env.sh.example` by `init-env.sh`).

- **Secrets/Passwords**: auto-generated randomly on first run — no manual input
- **HOST_IP**: the only setting you must change
- **External middleware**: set `USE_EXTERNAL_MYSQL/REDIS/MINIO=true` to use external services
- **PI Agent LLM**: configure `OPENCODE_API_KEY` and `PI_MODEL` after deployment

## Directory Structure

```
openinsight/
├── init-env.sh              # Environment init (generates env.sh + random secrets)
├── install_all.sh           # One-click install
├── uninstall_all.sh         # One-click uninstall
├── prepare.sh               # Pull Docker images
├── save-images.sh           # Export images (offline)
├── load-images.sh           # Import images (offline)
├── env.sh.example           # Config template (committed to Git)
├── common.sh                # Shared function library
├── docs/                    # Documentation
├── mysql/                   # MySQL + init SQL
├── mongodb/                 # MongoDB
├── redis/                   # Redis
├── minio/                   # MinIO object storage
├── meilisearch/             # Meilisearch full-text search
├── searxng/                 # SearXNG + MCP
├── codeinterpreter-api/     # Code Interpreter API
├── pi-agent/                # PI Agent
├── dmp/                     # DMP data management platform
├── arp/                     # ARP agent platform
└── mongo-express/           # Mongo Express admin UI
```

## Service Management

```bash
# Start / stop / restart a single service
cd <module> && docker-compose up -d
cd <module> && docker-compose down
cd <module> && docker-compose restart

# View all service statuses
docker ps --filter "name=openinsight-"

# One-click uninstall (keeps data)
bash uninstall_all.sh
```

## Default Ports

| Service | Port |
|---------|------|
| DMP | 30080 |
| ARP | 33080 |
| Code Interpreter API | 8000 |

## License

[Apache License 2.0](LICENSE)
