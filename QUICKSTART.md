# Quick Start Guide

## Prerequisites
- Docker and Docker Compose installed
- Tailscale account and auth key

## Quick Deployment

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Set up environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env and add your Tailscale auth key and other credentials
   ```

3. **Configure MonsterMQ** (optional):
   ```bash
   cp config/monstermq-config.yaml.example config/monstermq-config.yaml
   # Edit config/monstermq-config.yaml with your database settings
   # Uncomment the config mount in docker-compose.yaml if using local file
   ```

4. **Deploy the stack**:
   ```bash
   docker compose --env-file .env up -d
   ```

5. **Verify services**:
   ```bash
   docker compose ps
   docker compose logs tailscale
   ```

## Accessing Services

- **Via Tailscale**: Use your Tailscale hostname/IP with the ports listed in README
- **Via Host**: Use `localhost` with the host ports listed in README

## Next Steps

- Configure MonsterMQ `config.yaml` if not done during setup
- Access Grafana at `http://localhost:9090` to set up dashboards
- Access Node-RED at `http://localhost:1880` to create flows
- Check service status: `./status.sh`
- See README.md for detailed documentation

## Utility Scripts

The stack includes utility scripts for common operations:

- **`./status.sh`** - Quick health check and status overview
- **`./backup.sh`** - Automated backup of all volumes
- **`./restore.sh`** - Restore volumes from backup

See the [Utility Scripts section in README.md](README.md#utility-scripts) for detailed usage.
