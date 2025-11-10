#!/bin/bash
# Health check and status script for Industrial Automation Stack
# Provides a quick overview of all services and their health status

set -euo pipefail

# Configuration
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-automation-stack}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

section() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if docker compose is available
if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
    error "Docker Compose is not installed or not in PATH"
    exit 1
fi

# Get compose command
COMPOSE_CMD="docker compose"
if ! $COMPOSE_CMD version &> /dev/null; then
    COMPOSE_CMD="docker-compose"
fi

# Service status check
check_service_status() {
    local service_name=$1
    local status=$($COMPOSE_CMD ps "$service_name" --format json 2>/dev/null | jq -r '.[0].State' 2>/dev/null || echo "unknown")
    
    case "$status" in
        "running")
            echo -e "${GREEN}✓${NC} Running"
            return 0
            ;;
        "restarting")
            echo -e "${YELLOW}⟳${NC} Restarting"
            return 1
            ;;
        "exited"|"dead")
            echo -e "${RED}✗${NC} Stopped"
            return 1
            ;;
        *)
            echo -e "${YELLOW}?${NC} Unknown"
            return 1
            ;;
    esac
}

# Health check status
check_health() {
    local service_name=$1
    local health=$($COMPOSE_CMD ps "$service_name" --format json 2>/dev/null | jq -r '.[0].Health' 2>/dev/null || echo "none")
    
    case "$health" in
        "healthy")
            echo -e "${GREEN}healthy${NC}"
            return 0
            ;;
        "unhealthy")
            echo -e "${RED}unhealthy${NC}"
            return 1
            ;;
        "starting")
            echo -e "${YELLOW}starting${NC}"
            return 1
            ;;
        *)
            echo -e "${YELLOW}no healthcheck${NC}"
            return 0
            ;;
    esac
}

# Main status display
main() {
    section "Automation Stack Status"
    
    # Overall stack status
    info "Project: ${COMPOSE_PROJECT_NAME}"
    info "Date: $(date)"
    echo ""
    
    # Service list
    section "Service Status"
    
    # Core services
    local core_services=(
        "tailscale:Networking"
        "postgres:Database"
        "redis:Cache"
        "dnsmasq:DNS"
    )
    
    # Application services
    local app_services=(
        "node-red-a:Node-RED A"
        "node-red-b:Node-RED B"
        "flowfuse:FlowFuse"
        "monstermq:MonsterMQ"
        "hivemq:HiveMQ CE"
        "hivemq-edge:HiveMQ Edge"
        "ignition:Ignition"
    )
    
    # TimeBase services
    local timebase_services=(
        "timebase-historian:TimeBase Historian"
        "timebase-explorer:TimeBase Explorer"
        "timebase-simulator:TimeBase Simulator"
        "timebase-opcua:TimeBase OPC UA"
        "timebase-mqtt:TimeBase MQTT"
        "timebase-sparkplugb:TimeBase SparkPlug B"
    )
    
    # Data services
    local data_services=(
        "influxdb:InfluxDB"
        "grafana:Grafana"
        "portainer:Portainer"
    )
    
    echo -e "${BLUE}Core Services:${NC}"
    for svc_info in "${core_services[@]}"; do
        IFS=':' read -r svc_name svc_label <<< "$svc_info"
        printf "  %-25s " "$svc_label:"
        check_service_status "$svc_name"
        printf "    Health: "
        check_health "$svc_name"
    done
    
    echo -e "\n${BLUE}Application Services:${NC}"
    for svc_info in "${app_services[@]}"; do
        IFS=':' read -r svc_name svc_label <<< "$svc_info"
        printf "  %-25s " "$svc_label:"
        check_service_status "$svc_name"
        printf "    Health: "
        check_health "$svc_name"
    done
    
    echo -e "\n${BLUE}TimeBase Services:${NC}"
    for svc_info in "${timebase_services[@]}"; do
        IFS=':' read -r svc_name svc_label <<< "$svc_info"
        printf "  %-25s " "$svc_label:"
        check_service_status "$svc_name"
        printf "    Health: "
        check_health "$svc_name"
    done
    
    echo -e "\n${BLUE}Data Services:${NC}"
    for svc_info in "${data_services[@]}"; do
        IFS=':' read -r svc_name svc_label <<< "$svc_info"
        printf "  %-25s " "$svc_label:"
        check_service_status "$svc_name"
        printf "    Health: "
        check_health "$svc_name"
    done
    
    # Container summary
    section "Container Summary"
    $COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || {
        warn "Could not get container list. Is the stack running?"
    }
    
    # Tailscale status
    section "Tailscale Status"
    if $COMPOSE_CMD ps tailscale | grep -q "Up"; then
        info "Tailscale is running"
        echo ""
        $COMPOSE_CMD exec -T tailscale tailscale status 2>/dev/null || warn "Could not get Tailscale status"
    else
        warn "Tailscale is not running"
    fi
    
    # Volume status
    section "Volume Status"
    local volumes=(
        "tailscale-state"
        "postgres-data"
        "redis-data"
        "flowfuse-data"
        "node-red-a-data"
        "node-red-b-data"
        "monstermq-config"
        "monstermq-data"
        "hivemq-data"
        "hivemq-edge-data"
        "ignition-data"
        "timebase-historian"
        "timebase-explorer"
        "timebase-simulator"
        "timebase-opcua"
        "timebase-mqtt"
        "timebase-sparkplugb"
        "influxdb-data"
        "influxdb-config"
        "grafana-data"
        "portainer-data"
        "dnsmasq-config"
    )
    
    local existing_count=0
    for vol in "${volumes[@]}"; do
        full_vol="${COMPOSE_PROJECT_NAME}_${vol}"
        if docker volume inspect "$full_vol" &> /dev/null; then
            ((existing_count++))
        fi
    done
    
    info "Volumes: ${existing_count}/${#volumes[@]} exist"
    
    # Network status
    section "Network Status"
    local network_name="${COMPOSE_PROJECT_NAME}_automation"
    if docker network inspect "$network_name" &> /dev/null; then
        info "Network '$network_name' exists"
        local container_count=$(docker network inspect "$network_name" --format '{{len .Containers}}' 2>/dev/null || echo "0")
        info "Connected containers: $container_count"
    else
        warn "Network '$network_name' does not exist"
    fi
    
    # Resource usage (if available)
    section "Resource Usage"
    if command -v docker stats &> /dev/null; then
        info "Top 5 services by CPU/Memory usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
            $($COMPOSE_CMD ps -q 2>/dev/null | head -5) 2>/dev/null || warn "Could not get resource stats"
    fi
    
    echo ""
    section "Quick Commands"
    echo "  View logs:        $COMPOSE_CMD logs -f [service-name]"
    echo "  Restart service:  $COMPOSE_CMD restart [service-name]"
    echo "  Stop stack:       $COMPOSE_CMD down"
    echo "  Start stack:      $COMPOSE_CMD up -d"
    echo ""
}

# Run main function
main
