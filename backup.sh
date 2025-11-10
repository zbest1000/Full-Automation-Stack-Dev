#!/bin/bash
# Backup script for Industrial Automation Stack volumes
# This script creates timestamped backups of all Docker volumes used by the stack

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PREFIX="automation-stack-backup"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-automation-stack}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# List of volumes to backup (from docker-compose.yaml)
VOLUMES=(
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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if volumes exist
check_volumes() {
    local missing_volumes=()
    for volume in "${VOLUMES[@]}"; do
        full_volume_name="${COMPOSE_PROJECT_NAME}_${volume}"
        if ! docker volume inspect "$full_volume_name" &> /dev/null; then
            missing_volumes+=("$full_volume_name")
        fi
    done
    
    if [ ${#missing_volumes[@]} -gt 0 ]; then
        warn "Some volumes do not exist (they may not have been created yet):"
        for vol in "${missing_volumes[@]}"; do
            echo "  - $vol"
        done
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Create backup directory
create_backup_dir() {
    local backup_path="${BACKUP_DIR}/${BACKUP_PREFIX}_${TIMESTAMP}"
    mkdir -p "$backup_path"
    echo "$backup_path"
}

# Backup a single volume
backup_volume() {
    local volume_name=$1
    local backup_path=$2
    local full_volume_name="${COMPOSE_PROJECT_NAME}_${volume_name}"
    
    info "Backing up volume: $full_volume_name"
    
    if ! docker volume inspect "$full_volume_name" &> /dev/null; then
        warn "Volume $full_volume_name does not exist, skipping..."
        return 0
    fi
    
    local backup_file="${backup_path}/${volume_name}.tar.gz"
    
    # Create a temporary container to access the volume
    docker run --rm \
        -v "$full_volume_name":/source:ro \
        -v "$backup_path":/backup \
        alpine:latest \
        tar czf "/backup/${volume_name}.tar.gz" -C /source . 2>/dev/null || {
        error "Failed to backup $full_volume_name"
        return 1
    }
    
    # Verify backup file was created and has content
    if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        info "  ✓ Backed up to ${backup_file} (${size})"
        return 0
    else
        error "  ✗ Backup file is empty or missing"
        return 1
    fi
}

# Create metadata file
create_metadata() {
    local backup_path=$1
    local metadata_file="${backup_path}/metadata.txt"
    
    cat > "$metadata_file" <<EOF
Automation Stack Backup Metadata
================================
Backup Date: $(date)
Backup Timestamp: ${TIMESTAMP}
Docker Compose Project: ${COMPOSE_PROJECT_NAME}
Docker Version: $(docker --version)
Docker Compose Version: $(docker compose version 2>/dev/null || echo "N/A")

Volumes Backed Up:
$(for vol in "${VOLUMES[@]}"; do echo "  - ${COMPOSE_PROJECT_NAME}_${vol}"; done)

System Information:
$(uname -a)

To restore this backup, use:
  ./restore.sh ${backup_path}
EOF
    
    info "Created metadata file: $metadata_file"
}

# Main backup function
main() {
    info "Starting backup of Automation Stack volumes..."
    info "Backup directory: ${BACKUP_DIR}"
    info "Project name: ${COMPOSE_PROJECT_NAME}"
    echo ""
    
    # Check volumes
    check_volumes
    
    # Create backup directory
    local backup_path=$(create_backup_dir)
    info "Backup location: $backup_path"
    echo ""
    
    # Backup each volume
    local success_count=0
    local fail_count=0
    local skip_count=0
    
    for volume in "${VOLUMES[@]}"; do
        if backup_volume "$volume" "$backup_path"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    info "Backup Summary:"
    info "  ✓ Successful: $success_count"
    if [ $fail_count -gt 0 ]; then
        warn "  ✗ Failed: $fail_count"
    fi
    
    # Create metadata
    create_metadata "$backup_path"
    
    # Create a symlink to latest backup
    local latest_link="${BACKUP_DIR}/latest"
    rm -f "$latest_link"
    ln -s "$(basename "$backup_path")" "$latest_link"
    info "Created symlink: ${latest_link} -> $(basename "$backup_path")"
    
    echo ""
    info "Backup completed! Backup location: $backup_path"
    info "Total size: $(du -sh "$backup_path" | cut -f1)"
    
    if [ $fail_count -gt 0 ]; then
        warn "Some volumes failed to backup. Please review the errors above."
        exit 1
    fi
}

# Run main function
main
