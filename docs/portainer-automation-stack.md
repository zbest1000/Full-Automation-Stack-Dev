# Portainer Automation Stack Template

This document describes the services and configuration that are deployed by the provided Portainer application template. The stack is designed to expose every service through a shared Tailscale sidecar so that the applications are reachable only across your tailnet.

## Overview of Services

The stack provisions the following containers:

| Service | Image | Purpose | Notes |
| --- | --- | --- | --- |
| `tailscale` | `tailscale/tailscale:stable` | Terminates tailnet connections and proxies traffic to the internal services via `tailscale serve`. | Requires a reusable auth key with `tagged` or `ephemeral` scopes. Persisted state is stored in the `tailscale-state` volume. |
| `postgres` | `postgres:15-alpine` | Relational database that backs FlowFuse and is available for your own automations. | The default database name, user, and password are controlled with the template variables. |
| `redis` | `redis:7-alpine` | Session store required by FlowFuse. | Data are persisted in the `redis-data` volume. |
| `flowfuse` | `flowfuse/flowfuse:latest` | Manages collaborative Node-RED deployments. | Automatically connects to the bundled Postgres and Redis services. |
| `node-red` | `nodered/node-red:3.1` | Standalone Node-RED runtime with Projects and persistent storage enabled. | The Projects feature is enabled via the `NODE_RED_ENABLE_PROJECTS` environment variable. |
| `monster-mq` | Built from `https://github.com/vogler75/monster-mq.git` | MQTT testing and bridging utility. | Built directly from the upstream Git repository. |
| `hivemq` | `hivemq/hivemq-ce:2023.1` | Production-grade MQTT broker. | Exposes ports 1883 (MQTT) and 8080 (control center) through Tailscale. |
| `hivemq-edge` | `hivemq/hivemq-edge:latest` | Edge-optimized MQTT broker and protocol converter. | Intended for OT-to-IT bridging scenarios. |
| `ignition` | `kcollins/ignition:8.1` | Inductive Automation Ignition gateway. | Requires you to accept licensing terms during first start-up. |
| `timebase` | `finos/timebase-server:6.1` | FINOS TimeBase message historian. | Uses the `timebase-data` volume to persist its journal. |
| `timebase-historian` | `finos/timebase-server:6.1` | Secondary TimeBase node that can be repurposed as a historian or replication peer. | Disabled by default; adjust or remove the service if you maintain only one TimeBase node. |
| `influxdb` | `influxdb:2.7` | Time-series database suitable for metric storage. | Default admin credentials are provided via template variables. |
| `grafana` | `grafana/grafana:10.4.3` | Visualization and dashboarding solution. | Pre-provisioned admin credentials via template variables. |

All services share an internal Docker network (`automation`) so that only the Tailscale sidecar can reach them. No container publishes ports directly on the host.

## Tailscale Serving Layout

The `tailscale` container is responsible for registering the host with your tailnet and proxying inbound connections to the private services. The template pre-configures the following TCP mappings using `tailscale serve`:

| Tailnet Port | Upstream | Target Service |
| --- | --- | --- |
| `80` | `flowfuse:3000` | FlowFuse web UI |
| `1880` | `node-red:1880` | Node-RED editor and runtime |
| `1883` | `hivemq:1883` | HiveMQ MQTT broker |
| `1884` | `hivemq-edge:1883` | HiveMQ Edge MQTT broker |
| `8080` | `hivemq:8080` | HiveMQ Control Center |
| `8088` | `ignition:8088` | Ignition gateway |
| `8123` | `monster-mq:8080` | Monster MQ web UI |
| `9000` | `timebase:8011` | TimeBase Web Admin |
| `9001` | `timebase:8013` | TimeBase message endpoint |
| `9002` | `timebase-historian:8011` | Secondary TimeBase admin |
| `9003` | `timebase-historian:8013` | Secondary TimeBase message endpoint |
| `9090` | `grafana:3000` | Grafana dashboards |
| `9086` | `influxdb:8086` | InfluxDB UI and API |
| `5432` | `postgres:5432` | Postgres database access |

You can edit the serve commands inside the template if you need a different exposure strategy (for example, mapping multiple HTTP sites via HTTPS endpoints or enabling Funnel).

## Required Secrets and Variables

The template exposes several environment variables in Portainer so that you can inject credentials without editing the template JSON:

- `TS_AUTHKEY`: A Tailscale auth key that allows the container to join your tailnet. Generate a tagged, reusable key if you want the connection to survive restarts.
- `TAILSCALE_HOSTNAME`: Optional name that the node will use inside your tailnet.
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`: Credentials for the bundled Postgres instance.
- `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`: Admin credentials for Grafana.
- `INFLUXDB_ADMIN_USER`, `INFLUXDB_ADMIN_PASSWORD`, `INFLUXDB_BUCKET`, `INFLUXDB_ORG`, `INFLUXDB_RETENTION`: Bootstrap values for the InfluxDB 2.x setup wizard.

Update the defaults as needed inside Portainer before deploying the stack.

## First-Time Setup Checklist

1. **Create or reuse a Tailscale auth key.** Visit the Tailscale admin console and generate an auth key with the necessary permissions. Store it securely because the template references it directly.
2. **Deploy the stack from the Portainer template.** The services will start in order, but Ignition may take several minutes to become available while it performs a first-run configuration.
3. **Authorize the Tailscale node.** Depending on your tailnet policy, you may need to approve the new node in the admin console.
4. **Initialize InfluxDB, Grafana, and FlowFuse.** Visit their respective web interfaces over Tailscale to finalize setup steps (creating organizations, adding data sources, etc.).
5. **Import or create Node-RED projects.** The Projects feature stores flows in a Git repository under the mounted `node-red-data` volume.
6. **Review storage allocations.** Each service mounts a named Docker volume. Adjust the template if you prefer bind mounts.

## Maintenance Tips

- **Backups:** Snapshot the Docker volumes periodically to protect against data loss.
- **Upgrades:** Update the template image tags to newer versions, then redeploy the stack in Portainer.
- **Monitoring:** Grafana and InfluxDB are included so that you can ingest metrics from the rest of the stack. Configure appropriate exporters or flows through Node-RED or FlowFuse.
- **Security:** Because all access funnels through Tailscale, the services are not exposed on the public internet. Nevertheless, keep credentials strong and rotate your Tailscale auth keys on a regular schedule.

## Troubleshooting

- If the `tailscale` container fails to start, verify that the auth key is valid and has not expired.
- Ensure that the Docker host kernel allows the creation of `/dev/net/tun`. When running on Portainer agents with restricted permissions, you may need to enable `NET_ADMIN` and TUN device access explicitly.
- Inspect the Tailscale logs (`docker logs <stack>_tailscale`) to confirm that the serve configuration loaded successfully.

