# OpenInsight Deployment Guide

## Table of Contents

1. [Overview](#1-overview)
2. [System Requirements](#2-system-requirements)
3. [Architecture](#3-architecture)
4. [Pre-installation](#4-pre-installation)
5. [Quick Start](#5-quick-start)
6. [Installation Details](#6-installation-details)
7. [Configuration](#7-configuration)
8. [Service Management](#8-service-management)
9. [Verify Deployment](#9-verify-deployment)
10. [Updates](#10-updates)
11. [Uninstall](#11-uninstall)
12. [FAQ](#12-faq)

---

## 1. Overview

This document describes the private deployment method for OpenInsight, suitable for users who need to deploy the system in a private environment.

### 1.1 Main Components

| Component | Description |
|-----------|-------------|
| DMP (Data Management Platform) | Backend service + frontend admin UI |
| ARP (Agent Response Platform) | Conversational AI agent platform for end users |
| PI Agent | PI intelligent agent service |
| MongoDB | Document database |
| MySQL | DMP database |
| Redis | Cache service |
| Meilisearch | Full-text search engine |
| MinIO | Object storage service |
| Code Interpreter API | Code execution service |
| SearXNG | Web search service |

### 1.2 Deployment Approach

The deployment uses a **unified environment variables + modular install scripts** approach:

- **Unified configuration**: All settings are centralized in the root `env.sh` file. By default, only `HOST_IP` needs to be modified.
- **Modular installation**: Each subsystem directory has its own `install.sh` script, executed in dependency order.
- **One-click install**: The `install_all.sh` script installs all components automatically in the correct order.
- **Auto-generated secrets**: All passwords and keys are randomly generated on first run by `init-env.sh`.

### 1.3 Prerequisites

- Docker 24.07+
- Docker Compose v2.26.1+

### 1.4 Root Scripts

All scripts must be executed from the project root via `bash xxx.sh`:

| Script | Command | Description |
|--------|---------|-------------|
| `env.sh.example` | (no execution) | Unified environment variable template, committed to Git. All secrets are empty. |
| `init-env.sh` | `bash init-env.sh` | **Environment init script**: generates `env.sh` from `env.sh.example`, auto-fills all passwords and keys with random values. |
| `common.sh` | (no execution) | Shared function library, auto-sourced by each subsystem's `install.sh` / `uninstall.sh`. |
| `prepare.sh` | `bash prepare.sh` | **Online environment** prep script: pulls all Docker images (official images + GHCR self-built images). |
| `save-images.sh` | `bash save-images.sh` | **Offline deployment** image export script: packages local Docker images into `docker-images.tar.gz`. Run on a machine with images already pulled. |
| `load-images.sh` | `bash load-images.sh` | **Offline deployment** image import script: loads `docker-images.tar.gz` on the target server. |
| `install_all.sh` | `bash install_all.sh` | **One-click full install** script: installs all subsystems in dependency order (recommended). |
| `uninstall_all.sh` | `bash uninstall_all.sh` | **One-click full uninstall** script: uninstalls all subsystems in reverse order. |

> **Important notes:**
>
> 1. **First-time deployment must run `bash init-env.sh`** to generate `env.sh` and auto-fill random secrets.
> 2. **Then modify `HOST_IP` in `env.sh`** to the actual server IP — this is the most critical step.
> 3. Image prep is a choice of two based on network:
>    - Online: run `bash prepare.sh`
>    - Offline: run `bash save-images.sh` on a networked machine, then copy the output to the target server and run `bash load-images.sh`.
> 4. `common.sh` cannot be run standalone; it is a function library used by `install.sh`.
> 5. Each subsystem's `install.sh` auto-reads `env.sh` and writes config into the module's `.env` and `docker-compose.yml`. Re-run `install.sh` after config changes.
> 6. Some subsystems have dedicated helper scripts (run with `cd` into the directory):
>    - `pi-agent/download-skills.sh` — downloads PI Agent Skills repo, see [6.8 PI Agent](#68-pi-agent)
>    - `dmp/update_sql.sh` — executes incremental DB SQL during DMP upgrades, see [10.2 DMP Incremental SQL](#102-dmp-incremental-sql)

---

## 2. System Requirements

### 2.1 Minimum Requirements

| Item | Requirement |
|------|-------------|
| CPU | 4 cores |
| RAM | 16 GB |
| Disk | 100 GB |

### 2.2 Recommended Requirements

| Item | Requirement |
|------|-------------|
| CPU | 16 cores |
| RAM | 32 GB |
| Disk | 500 GB |

### 2.3 Supported Operating Systems

- Ubuntu 20.04
- Ubuntu 22.04
- CentOS/RedHat 7.9
- CentOS 8.6
- RedHat 8.5

---

## 3. Architecture

### 3.1 Core Components

| Module | Description | Directory |
|--------|-------------|-----------|
| mysql | MySQL database | `mysql/` |
| mongodb | MongoDB database | `mongodb/` |
| redis | Redis cache | `redis/` |
| minio | MinIO object storage | `minio/` |
| meilisearch | Meilisearch full-text index | `meilisearch/` |
| searxng | SearXNG web search | `searxng/` |
| codeinterpreter-api | Code Interpreter API | `codeinterpreter-api/` |
| pi-agent | PI Agent service | `pi-agent/` |
| dmp | DMP backend + frontend | `dmp/` |
| arp | ARP backend + frontend | `arp/` |

---

## 4. Pre-installation

### 4.1 Create Docker Network

All services use a unified Docker network, create it beforehand:

```bash
docker network create openinsight_default
```

### 4.2 Clone the Repository

```bash
git clone https://github.com/OpenInsightBH/openinsight.git
cd openinsight
```

### 4.3 Prepare Docker Images

#### 4.3.1 Online (with network)

Run `prepare.sh` to pull all images:

```bash
bash prepare.sh
```

**`prepare.sh` functionality:**
- Pulls official images (MySQL, Redis, MongoDB, MinIO, Meilisearch, SearXNG, etc.) from Docker Hub
- Pulls self-built images (ARP, DMP, PI Agent, Code Interpreter, etc.) from GitHub Container Registry (`ghcr.io/openinsighthq`)
- Tags Code Interpreter Node.js / Python images with local short names

#### 4.3.2 Offline (no network)

1. On a networked machine, run `save-images.sh` to package all images into `docker-images.tar.gz`:

```bash
bash save-images.sh
```

2. Transfer `docker-images.tar.gz` to the target server and run `load-images.sh`:

```bash
bash load-images.sh
```

### 4.4 Initialize Environment Variables

**This is the most critical step.**

#### 4.4.1 Generate the config file

Run the init script to auto-generate `env.sh` from the template and fill all secrets with random values:

```bash
bash init-env.sh
```

#### 4.4.2 Set the server IP

Edit the generated `env.sh` — **only `HOST_IP` needs to be changed**:

```bash
vi env.sh
```

```env
HOST_IP=192.168.1.100    # Change to your server IP
```

> **Tip**: `init-env.sh` has auto-generated all passwords and keys. The `install.sh` scripts read `env.sh` and write the config into each subsystem's `.env` and `docker-compose.yml`. No other changes are needed unless you have special requirements.

Main `env.sh` settings:

| Setting | Description | Default |
|---------|-------------|---------|
| `HOST_IP` | Server IP (**must change**) | (empty, required) |
| `GHCR_REGISTRY` | Self-built image registry | `ghcr.io/openinsighthq` |
| `DOCKER_NETWORK` | Docker network name | `openinsight_default` |
| `USE_EXTERNAL_MYSQL` | Use external MySQL | `false` |
| `USE_EXTERNAL_REDIS` | Use external Redis | `false` |
| `USE_EXTERNAL_MINIO` | Use external MinIO | `false` |
| `DMP_PORT` | DMP port | `30080` |
| `ARP_PORT` | ARP port | `33080` |

---

## 5. Quick Start

### 5.1 One-click Install (Recommended)

Run init, set IP, then one-click install:

```bash
# 1. Generate env.sh (auto-fills random secrets)
bash init-env.sh

# 2. Modify HOST_IP
vi env.sh

# 3. Pull images
bash prepare.sh

# 4. One-click install
bash install_all.sh
```

The script installs all components in dependency order.

> **Note**: After the one-click install completes, you must manually:
> 1. Activate License after DMP starts (see [6.9 DMP](#69-dmp))
> 2. ARP requires DMP to be fully activated (see [6.10 ARP](#610-arp))

### 5.2 Manual Module-by-Module Install

To control the process step by step, run each module's `install.sh` in this **strict order**:

```bash
# (1) MongoDB
cd mongodb && bash install.sh && cd ..

# (2) MySQL - run DB init after start
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

# (9) DMP - activate License after start
cd dmp && bash install.sh && cd ..

# (10) ARP - must wait for DMP to be fully activated
cd arp && bash install.sh && cd ..
```

> **Important**: The order cannot be changed — there are dependencies between components.

---

## 6. Installation Details

### 6.1 MySQL

```bash
cd mysql
bash install.sh
```

**Install script functions:**
- Creates `data/`, `logs/` directories
- Writes the MySQL password from `env.sh` into `docker-compose.yml`
- Creates the Docker network
- Starts the MySQL container
- If the database does not exist, `install.sh` auto-creates it and runs all `initdb/` scripts. If it fails, complete DB init manually.

**Database initialization (required):**

After MySQL starts, run the init scripts. They are in `mysql/initdb/` and **must be executed in this order** (base script first, then incremental updates by version):

| Order | Script | Description |
|:-----:|--------|-------------|
| 1 | `openinsight.sql` | Base init script (schema + seed data, **must run first**) |
| 2 | `update2.0.1.1.sql` | Incremental: data permission table `dm_data_permission` |
| 3 | `update2.0.1.2.sql` | Incremental: standard report tables |
| ... | ... | Subsequent `update*.sql` in version order |

> **Warning**: The `initdb/` scripts have dependencies — **never run out of order or skip any**.

> **Prerequisite**: The scripts do not include `CREATE DATABASE`. Before running any script, create and switch to the database:
> ```sql
> CREATE DATABASE IF NOT EXISTS `openinsight` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
> USE `openinsight`;
> ```

**Alternative — execute inside the MySQL container:**

Copy `mysql/` initdb into the data directory, then:

```bash
docker exec -it openinsight-mysql mysql -uroot -p

CREATE DATABASE IF NOT EXISTS `openinsight` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `openinsight`;

source /var/lib/mysql/initdb/openinsight.sql;
source /var/lib/mysql/initdb/update2.0.1.1.sql;
# ... run all update scripts in order
```

> **If `USE_EXTERNAL_MYSQL=true`**, `install.sh` skips the internal MySQL container and uses the external MySQL. You must manually run the `initdb/` scripts on the external MySQL in the order above.

### 6.2 MongoDB

```bash
cd mongodb
bash install.sh
```

**Install script functions:**
- Creates `data/` directory
- Creates the Docker network
- Starts the MongoDB container

MongoDB needs no manual init — the database is auto-created on first start.

### 6.3 Redis

```bash
cd redis
bash install.sh
```

**Install script functions:**
- Creates `data/` directory
- Writes the Redis password from `env.sh` into `.env` and `docker-compose.yml`
- Creates the Docker network
- Starts the Redis container

> **If `USE_EXTERNAL_REDIS=true`**, `install.sh` skips the internal Redis container.

### 6.4 MinIO

```bash
cd minio
bash install.sh
```

**Install script functions:**
- Creates `data/` directory
- Writes MinIO config from `env.sh` into `.env` and `docker-compose.yml`
- Creates the Docker network
- Starts the MinIO container

> **If `USE_EXTERNAL_MINIO=true`**, `install.sh` skips the internal MinIO container.

### 6.5 Meilisearch

```bash
cd meilisearch
bash install.sh
```

**Install script functions:**
- Creates `data/` directory
- Writes Meilisearch config from `env.sh` into `.env`
- Creates the Docker network
- Starts the Meilisearch container

### 6.6 SearXNG

```bash
cd searxng
bash install.sh
```

**Install script functions:**
- Creates `config/`, `data/` directories
- Writes SearXNG config from `env.sh`
- Creates the Docker network
- Starts the SearXNG container

> **Note**: SearXNG web search requires the server to have internet access.

### 6.7 Code Interpreter API

```bash
cd codeinterpreter-api
bash install.sh
```

**Install script functions:**
- Creates necessary directories
- Writes config from `env.sh` into `.env` and `docker-compose.yml`
- Creates the Docker network
- Starts the Code Interpreter API container

### 6.8 PI Agent

```bash
cd pi-agent
bash install.sh
```

**Install script functions:**
- Creates `pi-data/`, `skill-repo/` directories
- Writes config from `env.sh` into `.env` and `docker-compose.yml`
- Creates the Docker network
- Starts the PI Agent container (app package is built into the image)

**Download Skills (recommended):**

PI Agent extends its capabilities via Skills (e.g., PPT generation, Word/PDF/Excel parsing, skill creation tools). After `install.sh`, run `download-skills.sh` to fetch the official Skills repo:

```bash
cd pi-agent
bash download-skills.sh
```

**`download-skills.sh` functions:**
- Fetches the official Skill manifest `list.txt` from GitHub Releases
- Downloads each skill to `pi-agent/skill-repo/<category>/<filename>`
- Skips existing files — **safe to re-run, downloads only deltas**; failed downloads are cleaned up and summarized at the end

> **Note**: `skill-repo` is mounted to `/app/skill-repo` in the container. After download, PI Agent can use them without a restart. Re-run the script to add new Skills.

### 6.9 DMP

```bash
cd dmp
bash install.sh
```

**Install script functions:**
- Creates the `data/` directory
- Writes MySQL, Redis, MongoDB, Meilisearch etc. config from `env.sh` into `.env`
- Creates the Docker network
- Starts the DMP containers (`dmp-api` + `dmp-nginx`, app packages are built into the images)

**Activate License (required):**

After DMP starts successfully, activate the License:

1. Open `http://<HOST_IP>:30080/dmp/` in a browser
2. Log in with the default account:
   - Username: `chatbi`
   - Password: `Chatbi.123`
3. On first login, upload a License file at `http://<HOST_IP>:30080/dmp/infra/certifcate`
4. The system is activated after uploading the License

> **ARP can only be started after DMP is fully activated.**

### 6.10 ARP

**Prerequisite: DMP must be fully started and the License activated before starting ARP.**

```bash
cd arp
bash install.sh
```

**Install script functions:**
- Creates the `data/arp/` directory structure
- Writes all config from `env.sh` into `.env` and `docker-compose.yml`, including:
  - MongoDB connection
  - DMP platform address and API Key
  - PI Agent address and API Key
  - Meilisearch config
  - CSP security policy
  - JWT secrets etc.
- Creates the Docker network
- Starts the ARP container (app package is built into the image)

> **Note**: If ARP fails to start, confirm DMP is fully started and the License is activated, then re-run `bash install.sh`.

---

## 7. Configuration

### 7.1 Unified `env.sh`

All config is centralized in the root `env.sh` (generated from `env.sh.example` by `init-env.sh`).

- **Secrets/Passwords**: auto-generated randomly on first `init-env.sh` run — no manual input needed
- **HOST_IP**: the only setting that must be changed manually
- **External middleware**: set `USE_EXTERNAL_MYSQL/REDIS/MINIO=true` to use external services
- **PI Agent LLM**: configure `OPENCODE_API_KEY` and `PI_MODEL` in `env.sh` after deployment

### 7.2 Ports

Default port mappings:

| Service | Host Port | Container Port | Description |
|---------|-----------|----------------|-------------|
| DMP frontend | 30080 | 80 | DMP web UI |
| ARP frontend | 33080 | 3000 | Agent platform |
| Code Interpreter | 8000 | 8000 | Code Interpreter API |
| MinIO API | 19000 | 9000 | Object storage API |
| MinIO Console | 19001 | 9001 | Object storage console |

### 7.3 Default Accounts

| Platform | Username | Password |
|----------|----------|----------|
| DMP admin | chatbi | Chatbi.123 |
| ARP | chatbi@example.com | Chatbi.123 |

### 7.4 SSL Certificate (optional)

To support HTTPS, configure an SSL certificate:

1. Place certificate files in `codeinterpreter-api/ssl/`

**Temporary workaround (without SSL):**

Configure Chrome:
1. Visit `chrome://flags/#unsafely-treat-insecure-origin-as-secure`
2. Enter: `http://<IP>:33080`
3. Set to Enabled
4. Click "Relaunch"

### 7.5 Firewall Ports

Open these ports:

| Port | Purpose |
|------|---------|
| 30080 | DMP |
| 33080 | ARP |

---

## 8. Service Management

### 8.1 Start a single service

```bash
cd <module-directory>
docker-compose up -d
```

### 8.2 Stop a single service

```bash
cd <module-directory>
docker-compose down
```

### 8.3 Restart a single service

```bash
cd <module-directory>
docker-compose restart
```

### 8.4 View service status

```bash
docker ps --filter "name=openinsight-"
```

### 8.5 View service logs

```bash
cd <module-directory>
docker-compose logs -f

# Or specify a container name
docker logs -f openinsight-dmp-api
docker logs -f openinsight-arp
```

---

## 9. Verify Deployment

### 9.1 DMP

1. Open `http://<HOST_IP>:30080/dmp/` in a browser
2. Log in with the default account:
   - Username: `chatbi`
   - Password: `Chatbi.123`
3. Upload a License file on first login
4. Re-login after uploading the certificate

### 9.2 ARP

1. Open `http://<HOST_IP>:33080/arp/`
2. Log in with the default account:
   - Username: `chatbi@example.com`
   - Password: `Chatbi.123`
3. Test that the chat function works

### 9.3 Health check

```bash
# Check all container statuses
docker ps --filter "name=openinsight-"

# Check port accessibility
curl http://localhost:30080/dmp/
curl http://localhost:33080/arp/
```

---

## 10. Updates

### 10.1 Update via install scripts

Each component's install script supports re-execution for updates:

```bash
# Update DMP
cd dmp
bash install.sh

# Update ARP
cd ../arp
bash install.sh
```

### 10.2 DMP Incremental SQL

When upgrading only the DMP API image (without reinstalling the whole system), you must run the corresponding incremental DB SQL. `dmp/update_sql.sh` automates the download and execution of incremental SQL.

**Prerequisites:**

1. Confirm `dmp/.env` has `DMP_VERSION=<currently deployed version>`. The script uses this to determine which update scripts to run. If `.env` does not have `DMP_VERSION`, the script skips the whole process.

**Execution:**

```bash
cd dmp
bash update_sql.sh
```

**`update_sql.sh` functions:**

1. Reads `DMP_VERSION` from `dmp/.env` as the current version
2. Fetches all `update<a.b.c.d>.sql` script listings from GitHub Releases
3. Filters scripts in the `(CURRENT_VERSION, TARGET_VERSION]` range by comparing version segments numerically
4. Downloads and executes them in ascending version order
5. Already-downloaded scripts are cached in `dmp/sql-updates/`

> **Note**:
> 1. The script executes SQL via `mysql/execute_sql.sh` with fault tolerance for individual statements (only warns). Check logs for failures after execution.
> 2. `DMP_VERSION` is **not** auto-updated by the script — **manually update it to the new version after the upgrade**.
> 3. A fresh first-time deployment does not need this script — initial SQL is handled by the `initdb/` flow in [6.1 MySQL](#61-mysql).

---

## 11. Uninstall

### 11.1 One-click Uninstall

```bash
bash uninstall_all.sh
```

The script uninstalls all subsystems in reverse dependency order (ARP -> DMP -> ... -> MySQL -> MongoDB).

### 11.2 Manual Uninstall

```bash
cd <module-directory>
bash uninstall.sh
```

> **Tip**: Uninstall does not delete data directories (`data/`). To fully clear data, manually delete the `data/` folders under each subsystem. To remove the Docker network, run `docker network rm openinsight_default`.

---

## 12. FAQ

### 12.1 Service fails to start

**Problem**: Service won't start

**Solution**:
1. Check Docker status: `systemctl status docker`
2. Check if the port is in use: `netstat -tlnp | grep <port>`
3. View logs: `docker-compose logs -f <service-name>`
4. Check the network: `docker network inspect openinsight_default`
5. Verify `env.sh` config

### 12.2 Database connection failure

**Problem**: Cannot connect to MySQL/MongoDB/Redis

**Solution**:
1. Check if the DB container is running: `docker ps | grep mysql`
2. Verify connection info in `env.sh`
3. Check network connectivity: `docker network inspect openinsight_default`

### 12.3 License upload failure

**Problem**: System reports failure after uploading License

**Solution**:
1. Ensure the License file format is correct
2. Check if DMP API is running normally
3. View DMP API logs: `docker logs -f openinsight-dmp-api`

### 12.4 ARP startup failure

**Problem**: ARP fails to start

**Solution**:
1. Confirm DMP is fully started and the License is activated
2. Confirm MySQL DB init scripts have been executed
3. Confirm MongoDB, Redis etc. are running normally
4. Re-run `cd arp && bash install.sh`

### 12.5 Model invocation failure

**Problem**: Chat shows model invocation failure

**Solution**:
1. Check model configuration in the DMP platform
2. Verify the API-Key is configured correctly
3. Confirm network connectivity
4. Check model service availability

### 12.6 Code execution failure

**Problem**: Code execution returns an error

**Solution**:
1. Check Code Interpreter API status
2. Verify MinIO storage is working
3. Check Redis connection config
4. View code execution logs

---

## Appendix

### A. Docker Network

- Network name: `openinsight_default`
- Type: bridge
- External network, must be created beforehand (`install.sh` creates it automatically)

### B. Data Persistence Paths

Back up these directories regularly:

- `mysql/data/` - MySQL data
- `mongodb/data/` - MongoDB data
- `redis/data/` - Redis data
- `minio/data/` - MinIO storage
- `meilisearch/data/` - Search index
- `dmp/data/` - DMP app data
- `arp/data/` - ARP app data
- `pi-agent/pi-data/` - PI Agent data
- `codeinterpreter-api/data/` - Code interpreter data

### C. Security Recommendations

1. All passwords and keys in `env.sh` are auto-generated — change them if needed
2. Configure SSL/TLS certificates
3. Do not expose MySQL, MongoDB, Redis ports to the public internet
4. Apply security patches regularly
5. Enable firewall rules, only open necessary ports
6. Back up important data regularly

### D. Install Dependency Order

```
MySQL ──┐
MongoDB ├── DMP ── ARP
Redis ──┤   ↑
MinIO ──┤   │ (License required)
Meilisearch ┘
SearXNG
Code Interpreter API
PI Agent
```

---

*Document version: v2.0.2*
