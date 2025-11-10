# Industrial Automation Stack via Tailscale

A complete industrial automation toolkit deployed as a Docker Compose stack, with all services exposed exclusively through a Tailscale sidecar. No host ports are published—all access is via your Tailscale tailnet.

## Architecture Overview

This stack provides a comprehensive set of industrial automation and IoT tools:

- **Flow Automation**: Node-RED and FlowFuse for visual flow programming
- **MQTT Brokers**: HiveMQ CE, HiveMQ Edge, and MonsterMQ for messaging
- **SCADA/IIoT**: Inductive Automation Ignition gateway
- **Time-Series Data**: TimeBase and InfluxDB for historical data storage
- **Visualization**: Grafana for dashboards and monitoring
- **Data Storage**: PostgreSQL and Redis for application data
- **Networking**: Tailscale sidecar for secure, zero-trust access

All services communicate on a private Docker bridge network (`automation`). The Tailscale sidecar uses userspace networking only (`--tun=userspace-networking`) and exposes services via `tailscale serve` mappings. No Docker ports are published to the host.

## Security Model

### Tailscale Integration

- **Userspace Networking**: The Tailscale sidecar runs with `--tun=userspace-networking`, requiring no kernel-level TUN device access
- **No Subnet Routes**: The sidecar does not advertise subnet routes or act as an exit node
- **Serve-Only Exposure**: Services are exposed via `tailscale serve tcp` mappings only
- **No Host Ports**: Zero Docker port mappings—all traffic flows through Tailscale

### Access Control

- All services are accessible only to devices in your Tailscale tailnet
- Tailscale ACLs can further restrict access by user, device, or service
- No services are exposed to the public internet
- Credentials are managed via environment variables (never hardcoded)

### Credential Management

All sensitive values are provided via environment variables:
- Database credentials (PostgreSQL, MonsterMQ)
- Admin passwords (Grafana, InfluxDB)
- Tailscale auth keys
- Service-specific authentication

**Never commit `.env` files or hardcode credentials in the compose file.**

## Stack Components

| Component | Image | Purpose | Persistent Volume |
|-----------|-------|---------|-------------------|
| **Tailscale** | `tailscale/tailscale:stable` | VPN sidecar for secure access | `tailscale-state` |
| **Node-RED** | `nodered/node-red:3.1` | Visual flow programming | `node-red-data` |
| **FlowFuse** | `flowfuse/flowfuse:latest` | Collaborative Node-RED platform | `flowfuse-data` |
| **HiveMQ CE** | `hivemq/hivemq-ce:latest` | Production MQTT broker | `hivemq-data` |
| **HiveMQ Edge** | `hivemq/hivemq-edge:latest` | Edge MQTT gateway | `hivemq-edge-data` |
| **MonsterMQ** | `rocworks/monstermq:latest` | Multi-protocol messaging hub | `monstermq-config`, `monstermq-log`, `monstermq-security` |
| **Ignition** | `kcollins/ignition:8.1` | SCADA/IIoT gateway | `ignition-data` |
| **TimeBase** | `finos/timebase-server:6.1` | FINOS time-series database | `timebase-data` |
| **TimeBase Historian** | `finos/timebase-server:6.1` | Secondary TimeBase node | `timebase-historian-data` |
| **InfluxDB** | `influxdb:2.7` | Time-series database | `influxdb-data`, `influxdb-config` |
| **Grafana** | `grafana/grafana:10.4.3` | Visualization platform | `grafana-data` |
| **PostgreSQL** | `postgres:15-alpine` | Relational database | `postgres-data` |
| **Redis** | `redis:7-alpine` | Cache/session store | `redis-data` |
| **Portainer** | `portainer/portainer-ce:latest` | Container management (optional) | `portainer-data` |

### Portainer Service (Optional)

The stack includes a Portainer service for managing containers on bare Docker hosts. **If you are deploying this stack from an existing Portainer instance, you MUST remove or disable the Portainer service** to avoid conflicts.

To disable:
1. Edit the stack in Portainer
2. Remove the `portainer:` service definition from the compose file
3. Remove `portainer-data` from the volumes section
4. Remove the Tailscale serve mapping for port 9443

## Tailscale Service Mappings

All services are accessible via Tailscale on the following ports:

| Tailscale Port | Service | Internal Target | Protocol |
|----------------|---------|-----------------|----------|
| `80` | FlowFuse | `flowfuse:3000` | HTTP |
| `1880` | Node-RED | `node-red:1880` | HTTP |
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
| `9002` | TimeBase Web Admin | `timebase:8011` | HTTP |
| `9003` | TimeBase Message Endpoint | `timebase:8013` | TCP |
| `9004` | TimeBase Historian Admin | `timebase-historian:8011` | HTTP |
| `9005` | TimeBase Historian Endpoint | `timebase-historian:8013` | TCP |
| `9086` | InfluxDB | `influxdb:8086` | HTTP |
| `9090` | Grafana | `grafana:3000` | HTTP |
| `9443` | Portainer (optional) | `portainer:9443` | HTTPS |

### Accessing Services

Once deployed, access services using your Tailscale device's IP or hostname:

```bash
# Example: Access Grafana
https://automation-stack:9090

# Example: Access Node-RED
http://automation-stack:1880

# Example: Connect to HiveMQ MQTT
mqtt://automation-stack:1883
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
     - Database credentials (PostgreSQL, MonsterMQ)
     - Admin credentials (Grafana, InfluxDB)
     - HiveMQ settings
   - **Important**: If deploying from Portainer, remove the `portainer` service from the compose file

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

3. **Deploy with Docker Compose**:
   ```bash
   docker compose -f templates/automation-stack-compose.yaml --env-file .env up -d
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

# MonsterMQ
MONSTERMQ_DB_URL=postgresql://postgres:5432/monstermq
MONSTERMQ_DB_USER=monstermq
MONSTERMQ_DB_PASSWORD=your_secure_password
MONSTERMQ_TCP_PORT=1883
MONSTERMQ_TLS_PORT=8883
MONSTERMQ_WS_PORT=9000
MONSTERMQ_WSS_PORT=9001
MONSTERMQ_OPCUA_PORT=4840
MONSTERMQ_GRAPHQL_PORT=4000
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
| Node-RED | `wget -qO- http://localhost:1880/` |
| FlowFuse | `wget -qO- http://localhost:3000/` |
| HiveMQ | `nc -z localhost 1883` |
| HiveMQ Edge | `nc -z localhost 1883` |
| MonsterMQ | `nc -z localhost 1883` or GraphQL check |
| Ignition | `nc -z localhost 8088` or HTTP health endpoint |
| TimeBase | `nc -z localhost 8011` |
| TimeBase Historian | `nc -z localhost 8011` |
| InfluxDB | `wget -qO- http://localhost:8086/health` |
| Grafana | `wget -qO- http://localhost:3000/login` |
| Portainer | `wget -qO- http://localhost:9443/api/status` |

## Service Configuration

### Node-RED

- **Projects Enabled**: `NODE_RED_ENABLE_PROJECTS=true`
- **Persistent Storage**: `/data` volume
- **Access**: `http://<tailscale-host>:1880`

### FlowFuse

- **Backend**: PostgreSQL + Redis
- **Persistent Storage**: `/var/lib/flowfuse` volume
- **Access**: `http://<tailscale-host>:80`

### HiveMQ CE

- **Anonymous Access**: Configurable via `HIVEMQ_ALLOW_ANONYMOUS`
- **Authentication**: Optional username/password via env vars
- **Persistent Storage**: `/opt/hivemq/data` volume
- **Access**: MQTT `mqtt://<tailscale-host>:1883`

### MonsterMQ

- **Multi-Protocol**: MQTT, MQTT/TLS, WebSocket, WSS, OPC UA, GraphQL
- **Database**: PostgreSQL (configurable via env)
- **Persistent Volumes**: Config, log, and security directories
- **Access**: Multiple ports via Tailscale (see mapping table)

### Ignition

- **EULA Accepted**: `ACCEPT_EULA=Y`
- **Persistent Storage**: `/usr/local/share/ignition/data` volume
- **Access**: `http://<tailscale-host>:8088`

### TimeBase

- **Heap Size**: 2GB (configurable)
- **Persistent Storage**: `/timebase` volume
- **Access**: Admin `http://<tailscale-host>:9002`, Messages `tcp://<tailscale-host>:9003`

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
   - Via Compose: Update `image:` fields in `templates/automation-stack-compose.yaml`

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

**Symptoms**: FlowFuse or MonsterMQ cannot connect to PostgreSQL

**Solutions**:
- Verify PostgreSQL is healthy: `docker compose ps postgres`
- Check PostgreSQL logs: `docker compose logs postgres`
- Verify credentials match in environment variables
- Ensure `depends_on` health checks are passing

### High Memory Usage

**Symptoms**: Containers are OOM killed or system is slow

**Solutions**:
- Adjust TimeBase heap size: `TB_HEAP=1G` (reduce from 2G)
- Limit container memory in compose file
- Monitor with `docker stats`
- Consider running on a host with more RAM

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
    NR[Node-RED<br/>:1880]
    FF[FlowFuse<br/>:3000]
    HM[HiveMQ CE<br/>:1883]
    HME[HiveMQ Edge<br/>:1883]
    IG[Ignition<br/>:8088]
    MQ[MonsterMQ<br/>1883/8883/9000/9001<br/>4840/4000]
    TB[TimeBase<br/>:8011/:8013]
    TH[TimeBase Historian<br/>:8011/:8013]
    IF[InfluxDB<br/>:8086]
    GF[Grafana<br/>:3000]
    PG[PostgreSQL<br/>:5432]
    RD[Redis<br/>:6379]
    PT[Portainer<br/>:9443<br/>optional]
  end
  
  TS -->|serve tcp 1880| NR
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
  TS -->|serve tcp 9002| TB
  TS -->|serve tcp 9003| TB
  TS -->|serve tcp 9004| TH
  TS -->|serve tcp 9005| TH
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
