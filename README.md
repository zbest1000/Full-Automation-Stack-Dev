# Industrial Automation Stack via Tailscale

A complete industrial automation toolkit deployed as a Docker Compose stack, with all services exposed via both Tailscale sidecar and host ports for local access.

## Architecture Overview

This stack provides a comprehensive set of industrial automation and IoT tools:

- **Flow Automation**: Node-RED and FlowFuse for visual flow programming
- **MQTT Brokers**: HiveMQ CE, HiveMQ Edge, and MonsterMQ for messaging
- **SCADA/IIoT**: Inductive Automation Ignition gateway
- **Time-Series Data**: TimeBase (historian, explorer, collectors) and InfluxDB for historical data storage
- **Visualization**: Grafana for dashboards and monitoring
- **Data Storage**: PostgreSQL and Redis for application data
- **Networking**: Tailscale sidecar for secure, zero-trust remote access

All services communicate on a private Docker bridge network (`automation`). Services are accessible both:
- **Via Tailscale**: The Tailscale sidecar uses userspace networking only (`--tun=userspace-networking`) and exposes services via `tailscale serve` mappings for remote access
- **Via Host Ports**: Docker port mappings allow local access from the host machine

## Security Model

### Tailscale Integration

- **Userspace Networking**: The Tailscale sidecar runs with `--tun=userspace-networking`, requiring no kernel-level TUN device access
- **No Subnet Routes**: The sidecar does not advertise subnet routes or act as an exit node
- **Serve-Only Exposure**: Services are exposed via `tailscale serve tcp` mappings for remote access
- **Dual Access**: Services are accessible both via Tailscale (remote) and host ports (local)

### Access Control

- **Remote Access**: Services are accessible via Tailscale only to devices in your Tailscale tailnet
- **Local Access**: Services are accessible from the host machine via published Docker ports
- **Tailscale ACLs**: Can further restrict remote access by user, device, or service
- **Security Note**: Host ports are exposed on the local machine—ensure proper firewall rules if the host is internet-facing
- Credentials are managed via environment variables (never hardcoded)

### Credential Management

All sensitive values are provided via environment variables:
- Database credentials (PostgreSQL)
- Admin passwords (Grafana, InfluxDB)
- Tailscale auth keys
- Service-specific authentication

**Note**: MonsterMQ uses a `config.yaml` file for configuration (not environment variables). See the MonsterMQ configuration section for details.

**Never commit `.env` files or hardcode credentials in the compose file.**

## Stack Components

| Component | Image | Purpose | Persistent Volume |
|-----------|-------|---------|-------------------|
| **Tailscale** | `tailscale/tailscale:stable` | VPN sidecar for secure access | `tailscale-state` |
| **Node-RED (Standalone)** | `nodered/node-red:3.1` | Standalone Node-RED instance | `node-red-data` |
| **Node-RED (FlowFuse Test)** | `nodered/node-red:3.1` | Node-RED instance for FlowFuse testing | `node-red-flowfuse-test-data` |
| **FlowFuse** | `flowfuse/flowfuse:latest` | Collaborative Node-RED platform | `flowfuse-data` |
| **HiveMQ CE** | `hivemq/hivemq-ce:latest` | Production MQTT broker | `hivemq-data` |
| **HiveMQ Edge** | `hivemq/hivemq-edge:latest` | Edge MQTT gateway | `hivemq-edge-data` |
| **MonsterMQ** | `rocworks/monstermq:latest` | Multi-protocol messaging hub | `monstermq-config`, `monstermq-data`, `monstermq-logs` |
| **Ignition** | `kcollins/ignition:8.1` | SCADA/IIoT gateway | `ignition-data` |
| **TimeBase Historian** | `timebase/historian:latest` | TimeBase historian service | `timebase-historian` |
| **TimeBase Explorer** | `timebase/explorer:latest` | TimeBase explorer UI | `timebase-explorer` |
| **TimeBase Simulator** | `timebase/collector:latest` | Data simulator collector | `timebase-simulator` |
| **TimeBase OPC UA** | `timebase/collector:latest` | OPC UA collector | `timebase-opcua` |
| **TimeBase MQTT** | `timebase/collector:latest` | MQTT collector | `timebase-mqtt` |
| **TimeBase SparkPlug B** | `timebase/collector:latest` | SparkPlug B collector | `timebase-sparkplugb` |
| **InfluxDB** | `influxdb:2.7` | Time-series database | `influxdb-data`, `influxdb-config` |
| **Grafana** | `grafana/grafana:10.4.3` | Visualization platform | `grafana-data` |
| **PostgreSQL** | `postgres:15-alpine` | Relational database (used by FlowFuse and MonsterMQ) | `postgres-data` |
| **Redis** | `redis:7-alpine` | Cache/session store | `redis-data` |
| **Portainer** | `portainer/portainer-ce:latest` | Container management (optional) | `portainer-data` |

### Portainer Service (Optional)

The stack includes a Portainer service for managing containers on bare Docker hosts. **If you are deploying this stack from an existing Portainer instance, you MUST remove or disable the Portainer service** to avoid conflicts.

To disable:
1. Edit the stack in Portainer
2. Remove the `portainer:` service definition from the compose file
3. Remove `portainer-data` from the volumes section
4. Remove the Tailscale serve mapping for port 9443

## Service Access

Services are accessible via both Tailscale (remote) and host ports (local).

### Tailscale Service Mappings (Remote Access)

All services are accessible via Tailscale on the following ports:

| Tailscale Port | Service | Internal Target | Protocol |
|----------------|---------|-----------------|----------|
| `80` | FlowFuse | `flowfuse:3000` | HTTP |
| `1880` | Node-RED (Standalone) | `node-red-standalone:1880` | HTTP |
| `1881` | Node-RED (FlowFuse Test) | `node-red-flowfuse-test:1880` | HTTP |
| `1883` | HiveMQ CE | `hivemq:1883` | MQTT |
| `1884` | HiveMQ Edge | `hivemq-edge:1883` | MQTT |
| `1885` | MonsterMQ MQTT | `monstermq:1883` | MQTT |
| `4000` | MonsterMQ GraphQL | `monstermq:4000` | HTTP |
| `4840` | MonsterMQ OPC UA | `monstermq:4840` | OPC UA |
| `5432` | PostgreSQL | `postgres:5432` | PostgreSQL |
| `8088` | Ignition | `ignition:8088` | HTTP |
| `8885` | MonsterMQ MQTT/TLS | `monstermq:8883` | MQTT over TLS |
| `9000` | MonsterMQ WebSocket | `monstermq:9000` | WebSocket |
| `9001` | MonsterMQ WebSocket Secure | `monstermq:9001` | WSS |
| `4511`, `4512` | TimeBase Historian | `historian:4511`, `historian:4512` | TCP |
| `4531`, `4532` | TimeBase Explorer | `explorer:4531`, `explorer:4532` | HTTP, TCP |
| `4521`, `4522` | TimeBase Simulator | `simulator:4521`, `simulator:4522` | TCP |
| `4523`, `4524` | TimeBase OPC UA | `opcua:4521`, `opcua:4522` | TCP |
| `4525`, `4526` | TimeBase MQTT | `mqtt:4521`, `mqtt:4522` | TCP |
| `4527`, `4528` | TimeBase SparkPlug B | `sparkplugb:4521`, `sparkplugb:4522` | TCP |
| `9086` | InfluxDB | `influxdb:8086` | HTTP |
| `9090` | Grafana | `grafana:3000` | HTTP |
| `9443` | Portainer (optional) | `portainer:9443` | HTTPS |

### Host Port Mappings (Local Access)

All services are also accessible from the host machine on the following ports:

| Host Port | Service | Container Port | Protocol |
|-----------|---------|----------------|----------|
| `3000` | FlowFuse | `3000` | HTTP |
| `1880` | Node-RED (Standalone) | `1880` | HTTP |
| `1881` | Node-RED (FlowFuse Test) | `1880` | HTTP |
| `1883` | HiveMQ CE | `1883` | MQTT |
| `1884` | HiveMQ Edge | `1883` | MQTT |
| `1885` | MonsterMQ MQTT | `1883` | MQTT |
| `4000` | MonsterMQ GraphQL | `4000` | HTTP |
| `4840` | MonsterMQ OPC UA | `4840` | OPC UA |
| `5432` | PostgreSQL | `5432` | PostgreSQL |
| `8088` | Ignition | `8088` | HTTP |
| `8885` | MonsterMQ MQTT/TLS | `8883` | MQTT over TLS |
| `9000` | MonsterMQ WebSocket | `9000` | WebSocket |
| `9001` | MonsterMQ WebSocket Secure | `9001` | WSS |
| `4511`, `4512` | TimeBase Historian | `4511`, `4512` | TCP |
| `4531`, `4532` | TimeBase Explorer | `4531`, `4532` | HTTP, TCP |
| `4521`, `4522` | TimeBase Simulator | `4521`, `4522` | TCP |
| `4523`, `4524` | TimeBase OPC UA | `4521`, `4522` | TCP |
| `4525`, `4526` | TimeBase MQTT | `4521`, `4522` | TCP |
| `4527`, `4528` | TimeBase SparkPlug B | `4521`, `4522` | TCP |
| `9086` | InfluxDB | `8086` | HTTP |
| `9090` | Grafana | `3000` | HTTP |
| `9443` | Portainer (optional) | `9443` | HTTPS |

### Accessing Services

**Via Tailscale (Remote):**
```bash
# Example: Access Grafana
https://automation-stack:9090

# Example: Access Node-RED (Standalone)
http://automation-stack:1880

# Example: Access Node-RED (FlowFuse Test)
http://automation-stack:1881

# Example: Connect to HiveMQ MQTT
mqtt://automation-stack:1883
```

**Via Host Ports (Local):**
```bash
# Example: Access Grafana
http://localhost:9090

# Example: Access Node-RED (Standalone)
http://localhost:1880

# Example: Access Node-RED (FlowFuse Test)
http://localhost:1881

# Example: Connect to HiveMQ MQTT
mqtt://localhost:1883
```

## Project Structure

```
.
├── docker-compose.yaml          # Main Docker Compose file
├── .env.example                 # Environment variables template
├── .gitignore                   # Git ignore rules
├── config/
│   └── monstermq-config.yaml.example  # MonsterMQ configuration template
├── portainer-template.json      # Portainer App Template (for Portainer deployment)
└── README.md                    # This file
```

## Deployment

### Prerequisites

1. **Tailscale Account**: A Tailscale account and tailnet
2. **Tailscale Auth Key**: Generate a reusable or ephemeral auth key from the [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
3. **Docker & Docker Compose**: Docker Engine 20.10+ and Compose v2+
4. **Portainer** (optional): For template-based deployment

### Method 1: Deploy from Portainer Template

1. **Import Template**:
   - In Portainer, navigate to **App Templates**
   - Click **Add Template**
   - Paste the contents of `portainer-template.json`
   - Save the template

2. **Configure Environment Variables**:
   - Click **Deploy** on the template
   - Fill in all required environment variables:
     - `TS_AUTHKEY`: Your Tailscale auth key (required)
     - `TAILSCALE_HOSTNAME`: Desired hostname (default: `automation-stack`)
     - Database credentials (PostgreSQL)
     - Admin credentials (Grafana, InfluxDB)
     - HiveMQ settings
   - **Important**: If deploying from Portainer, remove the `portainer` service from the compose file
   - **Note**: After deployment, configure MonsterMQ by creating `config.yaml` in the `monstermq-config` volume (see MonsterMQ configuration section)

3. **Deploy Stack**:
   - Review the configuration
   - Click **Deploy the stack**
   - Monitor logs for startup progress

### Method 2: Deploy from Git/File

1. **Clone or Download**:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Create `.env` File**:
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

3. **Configure MonsterMQ** (optional, if using local config file):
   ```bash
   cp config/monstermq-config.yaml.example config/monstermq-config.yaml
   # Edit config/monstermq-config.yaml with your database settings
   # Then uncomment the config file mount in docker-compose.yaml
   ```

4. **Deploy with Docker Compose**:
   ```bash
   docker compose --env-file .env up -d
   ```

### Environment Variables

Create a `.env` file with the following variables:

```bash
# Tailscale Configuration
TS_AUTHKEY=tskey-auth-xxxxxxxxxxxxx
TAILSCALE_HOSTNAME=automation-stack

# PostgreSQL
POSTGRES_USER=flowfuse
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=flowfuse

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_secure_password

# InfluxDB
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=your_secure_password
INFLUXDB_BUCKET=automation
INFLUXDB_ORG=automation
INFLUXDB_RETENTION=0

# HiveMQ
HIVEMQ_ALLOW_ANONYMOUS=true
HIVEMQ_USER=
HIVEMQ_PASSWORD=

# MonsterMQ Configuration
# Note: MonsterMQ uses config.yaml file, not environment variables
# Create config.yaml in the monstermq-config volume after deployment
# See MonsterMQ service configuration section in README for example config.yaml
```

**Security Note**: Never commit `.env` files to version control. Use secrets management in production.

## Health Checks

All services include health checks with the following configuration:
- **Interval**: 5 seconds
- **Timeout**: 3 seconds
- **Retries**: 10

| Service | Health Check |
|---------|--------------|
| Tailscale | `tailscale status --json` |
| PostgreSQL | `pg_isready -U $POSTGRES_USER` |
| Redis | `redis-cli ping` |
| Node-RED (Standalone) | `wget -qO- http://localhost:1880/` |
| Node-RED (FlowFuse Test) | `wget -qO- http://localhost:1881/` |
| FlowFuse | `wget -qO- http://localhost:3000/` |
| HiveMQ | `nc -z localhost 1883` |
| HiveMQ Edge | `nc -z localhost 1883` |
| MonsterMQ | `nc -z localhost 1883` or GraphQL check |
| Ignition | `nc -z localhost 8088` or HTTP health endpoint |
| TimeBase Historian | `nc -z localhost 4511` |
| TimeBase Explorer | `nc -z localhost 4531` |
| TimeBase Simulator | `nc -z localhost 4521` |
| TimeBase OPC UA | `nc -z localhost 4521` |
| TimeBase MQTT | `nc -z localhost 4521` |
| TimeBase SparkPlug B | `nc -z localhost 4521` |
| InfluxDB | `wget -qO- http://localhost:8086/health` |
| Grafana | `wget -qO- http://localhost:3000/login` |
| Portainer | `wget -qO- http://localhost:9443/api/status` |

## Service Configuration

### Node-RED Instances

The stack includes **two Node-RED instances**:

1. **Node-RED (Standalone)** - `node-red-standalone`
   - **Projects Enabled**: `NODE_RED_ENABLE_PROJECTS=true`
   - **Persistent Storage**: `node-red-data` volume
   - **Port**: `1880` (host and Tailscale)
   - **Access**: `http://<tailscale-host>:1880` or `http://localhost:1880`
   - **Purpose**: Standalone Node-RED for direct use

2. **Node-RED (FlowFuse Test)** - `node-red-flowfuse-test`
   - **Projects Enabled**: `NODE_RED_ENABLE_PROJECTS=true`
   - **Persistent Storage**: `node-red-flowfuse-test-data` volume
   - **Port**: `1881` (host and Tailscale)
   - **Access**: `http://<tailscale-host>:1881` or `http://localhost:1881`
   - **Purpose**: Test instance for FlowFuse integration testing

**Note**: FlowFuse also creates Node-RED instances dynamically through its platform. These two instances are pre-configured for standalone use and testing.

### FlowFuse

- **Backend**: PostgreSQL + Redis
- **Database**: Uses PostgreSQL service (database specified in `POSTGRES_DB`, default: `flowfuse`)
- **Note**: Shares the same PostgreSQL instance with MonsterMQ (different databases)
- **Docker Driver**: Mounts Docker socket to create Node-RED instances dynamically
- **Domain Configuration**: Requires `DOMAIN` environment variable for Node-RED instance routing (set via `FLOWFUSE_DOMAIN` in `.env`)
- **Persistent Storage**: `/var/lib/flowfuse` volume
- **Access**: `http://<tailscale-host>:80` or `http://localhost:3000`
- **Node-RED Instances**: FlowFuse creates Node-RED instances dynamically via Docker. A separate test instance (`node-red-flowfuse-test`) is also available on port 1881.

### HiveMQ CE

- **Anonymous Access**: Configurable via `HIVEMQ_ALLOW_ANONYMOUS`
- **Authentication**: Optional username/password via env vars
- **Persistent Storage**: `/opt/hivemq/data` volume
- **Access**: MQTT `mqtt://<tailscale-host>:1883`

### MonsterMQ

- **Multi-Protocol**: MQTT, MQTT/TLS, WebSocket, WSS, OPC UA, GraphQL
- **Configuration**: Uses `config.yaml` file (mounted at `/app/config/config.yaml`)
- **Database**: Uses the same PostgreSQL service from the stack (configured in `config.yaml`)
- **Database Support**: PostgreSQL (default), CrateDB, MongoDB, SQLite (configured in `config.yaml`)
- **Persistent Volumes**: Config (`/app/config`), data (`/app/data`), and logs (`/app/logs`)
- **Access**: Multiple ports via Tailscale (see mapping table)
- **Dependencies**: Waits for PostgreSQL to be healthy before starting

**Configuration**: MonsterMQ requires a `config.yaml` file. You have two options:

**Option 1: Use local config file (recommended for development)**
1. Copy the example: `cp config/monstermq-config.yaml.example config/monstermq-config.yaml`
2. Edit `config/monstermq-config.yaml` with your settings
3. Uncomment the config file mount in `docker-compose.yaml`:
   ```yaml
   volumes:
     - ./config/monstermq-config.yaml:/app/config/config.yaml:ro
   ```
4. Deploy: `docker compose up -d`

**Option 2: Use Docker volume (default)**
1. Deploy the stack first
2. Access the `monstermq-config` volume
3. Create `/app/config/config.yaml` with your database and service settings
4. Restart the MonsterMQ container

Example `config.yaml` (see `config/monstermq-config.yaml.example` for full template):
```yaml
TCP: 1883
TCPS: 8883
WS: 9000
WSS: 9001

DefaultStoreType: POSTGRES

# Uses the same PostgreSQL service from the stack
Postgres:
  Url: jdbc:postgresql://postgres:5432/monstermq
  User: ${POSTGRES_USER}  # Use the same POSTGRES_USER from .env
  Pass: ${POSTGRES_PASSWORD}  # Use the same POSTGRES_PASSWORD from .env
  Schema: monstermq

GraphQL:
  Enabled: true
  Port: 4000

OPCUA:
  Enabled: true
  Port: 4840
```

**Important Notes**:
- MonsterMQ uses the **same PostgreSQL service** as FlowFuse (the `postgres` container)
- MonsterMQ creates its own database called `monstermq` automatically
- Both services use the same `POSTGRES_USER` and `POSTGRES_PASSWORD` from your `.env` file
- FlowFuse uses the database specified in `POSTGRES_DB` (default: `flowfuse`)
- You can optionally configure MonsterMQ to use the same database as FlowFuse with a different schema (see the example config file)

See the [MonsterMQ GitHub repository](https://github.com/vogler75/monster-mq) for complete configuration documentation.

### Ignition

- **EULA Accepted**: `ACCEPT_EULA=Y`
- **Persistent Storage**: `/usr/local/share/ignition/data` volume
- **Access**: `http://<tailscale-host>:8088`

### TimeBase Services

The stack includes a complete TimeBase ecosystem. Each TimeBase service uses **two ports** by design:

- **Port 1** (e.g., 4511, 4531, 4521): Control/Administration interface (HTTP for Explorer, TCP for others)
- **Port 2** (e.g., 4512, 4532, 4522): Data/Messaging interface (TCP for data streaming)

**Services:**

- **TimeBase Historian**: Main historian service for time-series data storage
  - **Ports**: `4511` (control), `4512` (data) - both TCP
  - **Persistent Storage**: `timebase-historian` volume
  - **Access**: `tcp://<host>:4511` (control) or `tcp://<host>:4512` (data) or via Tailscale

- **TimeBase Explorer**: Web UI for exploring TimeBase data
  - **Ports**: `4531` (HTTP - web UI), `4532` (TCP - data access)
  - **Persistent Storage**: `timebase-explorer` volume
  - **Access**: `http://<host>:4531` (web UI) or via Tailscale

- **TimeBase Collectors**: Data collection services (disabled by default, set `Active=true` to enable)
  - **Simulator**: Data simulator collector (ports `4521` control, `4522` data)
  - **OPC UA**: OPC UA protocol collector (ports `4523` control, `4524` data)
  - **MQTT**: MQTT protocol collector (ports `4525` control, `4526` data)
  - **SparkPlug B**: SparkPlug B protocol collector (ports `4527` control, `4528` data)
  - **Persistent Storage**: Individual volumes for each collector
  - **Note**: Collectors internally use ports 4521/4522, but are mapped to unique host ports to avoid conflicts

### InfluxDB 2.x

- **Bootstrap**: Automatic setup via `DOCKER_INFLUXDB_INIT_*` env vars
- **Persistent Storage**: Data and config volumes
- **Access**: `http://<tailscale-host>:9086`

### Grafana

- **Admin Credentials**: Set via environment variables
- **Persistent Storage**: `/var/lib/grafana` volume
- **Access**: `http://<tailscale-host>:9090`

## Tailscale Auth Key Rotation

To rotate your Tailscale auth key:

1. **Generate New Key**:
   - Visit [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
   - Create a new reusable auth key
   - Copy the key

2. **Update Stack**:
   - In Portainer: Edit the stack, update `TS_AUTHKEY` environment variable
   - Via Compose: Update `.env` file, then `docker compose up -d`

3. **Restart Tailscale Service**:
   ```bash
   docker compose restart tailscale
   ```

4. **Verify**:
   ```bash
   docker compose exec tailscale tailscale status
   ```

5. **Revoke Old Key** (optional):
   - In Tailscale Admin Console, revoke the old auth key

## Backup and Restore

### Backup Volumes

All persistent data is stored in Docker named volumes. To backup:

```bash
# List volumes
docker volume ls | grep automation-stack

# Backup individual volumes
docker run --rm -v automation-stack_postgres-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres-data-backup.tar.gz -C /data .

# Backup all volumes
for volume in $(docker volume ls -q | grep automation-stack); do
  docker run --rm -v $volume:/data -v $(pwd):/backup \
    alpine tar czf /backup/${volume}-backup.tar.gz -C /data .
done
```

### Restore Volumes

```bash
# Stop the stack
docker compose down

# Restore a volume
docker run --rm -v automation-stack_postgres-data:/data -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/postgres-data-backup.tar.gz"

# Start the stack
docker compose up -d
```

### Automated Backups

Consider using a backup solution like:
- **Velero** for Kubernetes
- **Docker volume backup scripts** with cron
- **Portainer backup** feature (if using Portainer)

## Updating Images

To safely update service images:

1. **Backup Volumes** (see Backup section above)

2. **Update Image Tags**:
   - In Portainer: Edit stack, update image tags in compose file
   - Via Compose: Update `image:` fields in `docker-compose.yaml`

3. **Pull New Images**:
   ```bash
   docker compose pull
   ```

4. **Update Stack**:
   ```bash
   docker compose up -d
   ```

5. **Verify Health**:
   ```bash
   docker compose ps
   docker compose logs <service-name>
   ```

6. **Rollback if Needed**:
   ```bash
   # Restore volumes
   # Revert image tags
   docker compose up -d
   ```

## Troubleshooting

### Tailscale Service Fails to Start

**Symptoms**: Tailscale container exits immediately

**Solutions**:
- Verify `TS_AUTHKEY` is set and valid
- Check Tailscale logs: `docker compose logs tailscale`
- Ensure auth key has not expired
- Verify Tailscale admin console shows the node

### Services Not Accessible via Tailscale

**Symptoms**: Cannot connect to services on Tailscale ports

**Solutions**:
- Verify Tailscale status: `docker compose exec tailscale tailscale status`
- Check serve mappings: `docker compose exec tailscale tailscale serve status`
- Ensure your device is in the same Tailscale tailnet
- Check Tailscale ACLs for access restrictions
- Verify service health: `docker compose ps`

### Database Connection Errors

**Symptoms**: FlowFuse cannot connect to PostgreSQL

**Solutions**:
- Verify PostgreSQL is healthy: `docker compose ps postgres`
- Check PostgreSQL logs: `docker compose logs postgres`
- Verify credentials match in environment variables
- Ensure `depends_on` health checks are passing

**MonsterMQ Database Issues**:
- MonsterMQ uses `config.yaml` for database configuration, not environment variables
- Verify `config.yaml` in the `monstermq-config` volume has correct database connection settings
- Check MonsterMQ logs: `docker compose logs monstermq`
- Ensure PostgreSQL is accessible from the MonsterMQ container (same Docker network)

### High Memory Usage

**Symptoms**: Containers are OOM killed or system is slow

**Solutions**:
- Limit container memory in compose file using `deploy.resources.limits.memory`
- Monitor with `docker stats`
- Consider running on a host with more RAM
- TimeBase services have resource limits configured (see service definitions)

### Port Conflicts

**Symptoms**: Tailscale serve mappings fail

**Solutions**:
- Verify no other Tailscale nodes are using the same ports
- Adjust Tailscale port mappings in the compose file
- Check for port conflicts: `docker compose exec tailscale tailscale serve status`

## Network Diagram

The following Mermaid diagram illustrates the container-level architecture and service relationships:

```mermaid
flowchart LR
  TS[Tailscale Sidecar<br/>userspace-networking<br/>serve-only]
  
  subgraph AppNet["Automation Network (bridge)"]
    NR[Node-RED Standalone<br/>:1880]
    NRT[Node-RED FlowFuse Test<br/>:1881]
    FF[FlowFuse<br/>:3000]
    HM[HiveMQ CE<br/>:1883]
    HME[HiveMQ Edge<br/>:1883]
    IG[Ignition<br/>:8088]
    MQ[MonsterMQ<br/>1883/8883/9000/9001<br/>4840/4000]
    TBH[TimeBase Historian<br/>:4511/:4512]
    TBE[TimeBase Explorer<br/>:4531/:4532]
    TBS[TimeBase Simulator<br/>:4521/:4522]
    TBO[TimeBase OPC UA<br/>:4523/:4524]
    TBM[TimeBase MQTT<br/>:4525/:4526]
    TBSP[TimeBase SparkPlug B<br/>:4527/:4528]
    IF[InfluxDB<br/>:8086]
    GF[Grafana<br/>:3000]
    PG[PostgreSQL<br/>:5432]
    RD[Redis<br/>:6379]
    PT[Portainer<br/>:9443<br/>optional]
  end
  
  TS -->|serve tcp 1880| NR
  TS -->|serve tcp 1881| NRT
  TS -->|serve tcp 80| FF
  TS -->|serve tcp 1883| HM
  TS -->|serve tcp 1884| HME
  TS -->|serve tcp 1885| MQ
  TS -->|serve tcp 8885| MQ
  TS -->|serve tcp 9000| MQ
  TS -->|serve tcp 9001| MQ
  TS -->|serve tcp 4840| MQ
  TS -->|serve tcp 4000| MQ
  TS -->|serve tcp 8088| IG
  TS -->|serve tcp 4511| TBH
  TS -->|serve tcp 4512| TBH
  TS -->|serve tcp 4531| TBE
  TS -->|serve tcp 4532| TBE
  TS -->|serve tcp 4521| TBS
  TS -->|serve tcp 4522| TBS
  TS -->|serve tcp 4523| TBO
  TS -->|serve tcp 4524| TBO
  TS -->|serve tcp 4525| TBM
  TS -->|serve tcp 4526| TBM
  TS -->|serve tcp 4527| TBSP
  TS -->|serve tcp 4528| TBSP
  TS -->|serve tcp 9086| IF
  TS -->|serve tcp 9090| GF
  TS -->|serve tcp 5432| PG
  TS -->|serve tcp 9443| PT
  
  FF -->|PostgreSQL| PG
  FF -->|Redis| RD
  MQ -.->|optional DB| PG
  
  style TS fill:#ff6b6b,stroke:#c92a2a,stroke-width:3px,color:#fff
  style AppNet fill:#e7f5ff,stroke:#339af0,stroke-width:2px
  style PT fill:#ffe3e3,stroke:#ff8787,stroke-width:2px,stroke-dasharray: 5 5
```

## Support and Contributions

For issues, questions, or contributions:
- Open an issue in the repository
- Review service-specific documentation:
  - [Node-RED Docs](https://nodered.org/docs/)
  - [FlowFuse Docs](https://flowfuse.com/docs/)
  - [HiveMQ Docs](https://www.hivemq.com/docs/)
  - [Ignition Docs](https://docs.inductiveautomation.com/)
  - [TimeBase Docs](https://github.com/finos/timebase-server)
  - [MonsterMQ](https://github.com/rocworks/monstermq)

## License

This stack template is provided as-is. Individual services have their own licenses:
- **Node-RED**: Apache 2.0
- **FlowFuse**: Commercial (free tier available)
- **HiveMQ CE**: Apache 2.0
- **Ignition**: Commercial (trial available)
- **TimeBase**: Apache 2.0
- **InfluxDB**: MIT
- **Grafana**: AGPL 3.0
- **PostgreSQL**: PostgreSQL License
- **Redis**: BSD 3-Clause
- **Tailscale**: Proprietary (free for personal use)

Ensure compliance with all service licenses before production use.
