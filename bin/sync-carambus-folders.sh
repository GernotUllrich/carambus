#!/bin/bash

# Carambus Folder Synchronization Script
# This script helps manage the synchronization between carambus and carambus_api folders

set -e

# Configuration
CARAMBUS_API="/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api"
CARAMBUS="/Volumes/EXT2TB/gullrich/DEV/projects/carambus"
BACKUP_DIR="/Volumes/EXT2TB/gullrich/DEV/projects/carambus_backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Files that need to be synced (critical shared files)
SHARED_FILES=(
    "app/models/application_record.rb"
    "config/initializers/location.rb"
    "app/controllers/application_controller.rb"
    "app/helpers/current_helper.rb"
    "app/models/local_protector.rb"
    "app/models/api_protector.rb"
    "config/application.rb"
    "config/environments/development.rb"
    "config/environments/development-carambus.rb"
)

# Files that should NOT be synced (environment-specific)
EXCLUDED_FILES=(
    "config/database.yml"
    "config/credentials.yml.enc"
    "config/master.key"
    ".env"
    "log/"
    "tmp/"
    "node_modules/"
)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to create backup
create_backup() {
    local timestamp=$(date +'%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/carambus_backup_$timestamp"
    
    log "Creating backup at $backup_path"
    cp -r "$CARAMBUS" "$backup_path"
    log "Backup created successfully"
}

# Function to sync from carambus_api to carambus
sync_to_carambus() {
    log "Syncing from carambus_api to carambus..."
    
    for file in "${SHARED_FILES[@]}"; do
        if [ -f "$CARAMBUS_API/$file" ]; then
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "$CARAMBUS/$file")"
            
            # Check if files are different
            if ! cmp -s "$CARAMBUS_API/$file" "$CARAMBUS/$file"; then
                cp "$CARAMBUS_API/$file" "$CARAMBUS/$file"
                log "Synced: $file"
            else
                log "No changes needed: $file"
            fi
        else
            warn "File not found: $CARAMBUS_API/$file"
        fi
    done
    
    log "Sync to carambus completed"
}

# Function to sync from carambus to carambus_api
sync_to_carambus_api() {
    log "Syncing from carambus to carambus_api..."
    
    for file in "${SHARED_FILES[@]}"; do
        if [ -f "$CARAMBUS/$file" ]; then
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "$CARAMBUS_API/$file")"
            
            # Check if files are different
            if ! cmp -s "$CARAMBUS/$file" "$CARAMBUS_API/$file"; then
                cp "$CARAMBUS/$file" "$CARAMBUS_API/$file"
                log "Synced: $file"
            else
                log "No changes needed: $file"
            fi
        else
            warn "File not found: $CARAMBUS/$file"
        fi
    done
    
    log "Sync to carambus_api completed"
}

# Function to check for differences
check_differences() {
    log "Checking for differences between folders..."
    
    local differences_found=false
    
    for file in "${SHARED_FILES[@]}"; do
        if [ -f "$CARAMBUS_API/$file" ] && [ -f "$CARAMBUS/$file" ]; then
            if ! cmp -s "$CARAMBUS_API/$file" "$CARAMBUS/$file"; then
                echo -e "${YELLOW}Difference found in: $file${NC}"
                differences_found=true
            fi
        elif [ -f "$CARAMBUS_API/$file" ]; then
            echo -e "${YELLOW}File only exists in carambus_api: $file${NC}"
            differences_found=true
        elif [ -f "$CARAMBUS/$file" ]; then
            echo -e "${YELLOW}File only exists in carambus: $file${NC}"
            differences_found=true
        fi
    done
    
    if [ "$differences_found" = false ]; then
        log "No differences found between folders"
    fi
}

# Function to show help
show_help() {
    echo "Carambus Folder Synchronization Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  to-carambus     Sync files from carambus_api to carambus"
    echo "  to-api          Sync files from carambus to carambus_api"
    echo "  check           Check for differences between folders"
    echo "  backup          Create backup of carambus folder"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 to-carambus  # Sync changes to carambus folder"
    echo "  $0 check        # Check for differences"
    echo "  $0 backup       # Create backup before syncing"
}

# Main script logic
case "${1:-help}" in
    "to-carambus")
        create_backup
        sync_to_carambus
        ;;
    "to-api")
        create_backup
        sync_to_carambus_api
        ;;
    "check")
        check_differences
        ;;
    "backup")
        create_backup
        ;;
    "help"|*)
        show_help
        ;;
esac 