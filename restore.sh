#!/bin/bash
# Restore script for Industrial Automation Stack volumes
# This script restores volumes from a backup created by backup.sh

set -euo pipefail

# Configuration
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-automation-stack}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    error "Docker is not installed or not in PATH"
    exit 1
fi

# Usage function
usage() {
    cat <<EOF
Usage: $0 <backup_directory>

Restores Docker volumes from a backup directory created by backup.sh

Arguments:
  backup_directory    Path to the backup directory (e.g., ./backups/automation-stack-backup_20240101_120000)

Examples:
  $0 ./backups/latest
  $0 ./backups/automation-stack-backup_20240101_120000

Environment Variables:
  COMPOSE_PROJECT_NAME    Docker Compose project name (default: automation-stack)

WARNING: This will OVERWRITE existing volumes. Make sure to backup current data first!
EOF
    exit 1
}

# Validate backup directory
validate_backup() {
    local backup_dir=$1
    
    if [ ! -d "$backup_dir" ]; then
        error "Backup directory does not exist: $backup_dir"
        exit 1
    fi
    
    # Check for metadata file
    if [ ! -f "${backup_dir}/metadata.txt" ]; then
        warn "No metadata.txt found in backup directory. Proceeding anyway..."
    else
        info "Found backup metadata:"
        cat "${backup_dir}/metadata.txt" | head -10
        echo ""
    fi
    
    # Check for backup files
    local backup_files=$(find "$backup_dir" -name "*.tar.gz" | wc -l)
    if [ "$backup_files" -eq 0 ]; then
        error "No backup files (.tar.gz) found in $backup_dir"
        exit 1
    fi
    
    info "Found $backup_files backup files"
}

# Restore a single volume
restore_volume() {
    local volume_name=$1
    local backup_file=$2
    local full_volume_name="${COMPOSE_PROJECT_NAME}_${volume_name}"
    
    info "Restoring volume: $full_volume_name"
    
    if [ ! -f "$backup_file" ]; then
        warn "Backup file not found: $backup_file, skipping..."
        return 0
    fi
    
    # Check if volume exists, create if not
    if ! docker volume inspect "$full_volume_name" &> /dev/null; then
        info "  Creating volume: $full_volume_name"
        docker volume create "$full_volume_name" > /dev/null
    else
        warn "  Volume already exists, will be overwritten"
    fi
    
    # Restore using temporary container
    docker run --rm \
        -v "$full_volume_name":/target \
        -v "$(dirname "$backup_file")":/backup:ro \
        alpine:latest \
        sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null || true; \
               tar xzf /backup/$(basename "$backup_file") -C /target" 2>/dev/null || {
        error "Failed to restore $full_volume_name"
        return 1
    }
    
    info "  ✓ Restored $full_volume_name"
    return 0
}

# Main restore function
main() {
    if [ $# -eq 0 ]; then
        usage
    fi
    
    local backup_dir="$1"
    
    # Resolve symlinks (e.g., if using ./backups/latest)
    if [ -L "$backup_dir" ]; then
        backup_dir=$(readlink -f "$backup_dir")
        info "Resolved symlink to: $backup_dir"
    fi
    
    # Validate backup
    validate_backup "$backup_dir"
    
    # Confirm restoration
    warn "WARNING: This will OVERWRITE existing volumes!"
    warn "Make sure you have a current backup before proceeding."
    echo ""
    read -p "Are you sure you want to continue? (yes/NO) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        info "Restore cancelled"
        exit 0
    fi
    
    info "Starting restore from: $backup_dir"
    info "Project name: ${COMPOSE_PROJECT_NAME}"
    echo ""
    
    # Find all backup files
    local backup_files=$(find "$backup_dir" -name "*.tar.gz" -type f)
    local success_count=0
    local fail_count=0
    local skip_count=0
    
    # Restore each volume
    for backup_file in $backup_files; do
        local volume_name=$(basename "$backup_file" .tar.gz)
        if restore_volume "$volume_name" "$backup_file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    info "Restore Summary:"
    info "  ✓ Successful: $success_count"
    if [ $fail_count -gt 0 ]; then
        warn "  ✗ Failed: $fail_count"
    fi
    
    echo ""
    if [ $fail_count -eq 0 ]; then
        info "Restore completed successfully!"
        info "You may need to restart the stack: docker compose restart"
    else
        warn "Some volumes failed to restore. Please review the errors above."
        exit 1
    fi
}

# Run main function
main "$@"
