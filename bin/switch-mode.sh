#!/bin/bash

# Carambus Mode Switcher
# Switches between local development mode and API mode

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api"
BACKUP_DIR="$PROJECT_ROOT/tmp/mode_backups"

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

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to create backup
create_backup() {
    local timestamp=$(date +'%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/config_backup_$timestamp"
    
    log "Creating backup at $backup_path"
    mkdir -p "$backup_path"
    
    # Backup current configuration files
    cp "$PROJECT_ROOT/config/carambus.yml" "$backup_path/" 2>/dev/null || true
    cp "$PROJECT_ROOT/config/database.yml" "$backup_path/" 2>/dev/null || true
    cp "$PROJECT_ROOT/config/deploy/production.rb" "$backup_path/" 2>/dev/null || true
    cp "$PROJECT_ROOT/config/deploy.rb" "$backup_path/" 2>/dev/null || true
    
    # Backup current log files
    mkdir -p "$backup_path/log"
    cp "$PROJECT_ROOT/log/development.log" "$backup_path/log/" 2>/dev/null || true
    cp "$PROJECT_ROOT/log/development-local.log" "$backup_path/log/" 2>/dev/null || true
    cp "$PROJECT_ROOT/log/development-api.log" "$backup_path/log/" 2>/dev/null || true
    
    log "Backup created successfully"
}

# Function to switch to LOCAL mode
switch_to_local() {
    log "Switching to LOCAL mode..."
    
    # Update carambus.yml
    log "Updating carambus.yml..."
    cat > "$PROJECT_ROOT/config/carambus.yml" << 'EOF'
---
default:
  :carambus_api_url: https://api.carambus.de/
  :location_id: 1
  :application_name: Carambus
  :support_email: gernot.ullrich@gmx.de
  :business_name: Ullrich IT Consulting
  :business_address: 22869 Schenefeld, Sandstückenweg 15
  :carambus_domain: carambus.de
  :queue_adapter: async
  :small_table_no: 0
  :large_table_no: 0
  :pool_table_no: 0
  :snooker_table_no: 0
  :context: NBV
  :season_name: 2023/2024
  :force_update: 'true'
  :no_local_protection: 'false'
  :club_id: 357
development:
  carambus_api_url:  # Empty for local mode
  location_id: 1
  application_name: Carambus
  support_email: gernot.ullrich@gmx.de
  business_name: Ullrich IT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  context: LOCAL
  season_name: 2024/2025
  force_update: 'true'
  no_local_protection: 'true'
  club_id: 357
test:
  carambus_api_url: https://api.carambus.de/
  location_id: 1
  application_name: Carambus
  support_email: gernot.ullrich@gmx.de
  business_name: Ullrich IT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  small_table_no: 0
  large_table_no: 0
  pool_table_no: 0
  snooker_table_no: 0
production:
  carambus_api_url: https://api.carambus.de/
  location_id: 1
  application_name: Carambus
  support_email: gernot.ullrich@gmx.de
  business_name: Ullrich IT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  small_table_no: 0
  large_table_no: 0
  pool_table_no: 0
  snooker_table_no: 0
EOF

    # Update database.yml
    log "Updating database.yml..."
    cat > "$PROJECT_ROOT/config/database.yml" << 'EOF'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: carambus_local_development
  username: <%= ENV.fetch("DB_USERNAME", nil) %>
  password: <%= ENV.fetch("DB_PASSWORD", nil) %>
  host: <%= ENV.fetch("DB_HOST", "localhost") %>

test:
  <<: *default
  database: carambus_test
  username: <%= ENV.fetch("DB_USERNAME", nil) %>
  password: <%= ENV.fetch("DB_PASSWORD", nil) %>
  host: <%= ENV.fetch("DB_HOST", "localhost") %>

production:
  <<: *default
  database: carambus2_api_production
EOF

    # Update production.rb (local testing server)
    log "Updating production.rb..."
    cat > "$PROJECT_ROOT/config/deploy/production.rb" << 'EOF'
# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# LOCAL MODE - Testing server
server '192.168.178.81', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4bw (local testing)

# API MODE - Production server (commented out)
# server 'carambus.de', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # carambus global

# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# The server-based syntax can be used to override options:
# ------------------------------------
# server 'carambus.de',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
EOF

    # Update deploy.rb for LOCAL mode
    log "Updating deploy.rb..."
    update_deploy_rb "carambus_local"
    
    # Manage log files for LOCAL mode
    log "Managing log files for LOCAL mode..."
    manage_log_files "local"
    
    log "Switched to LOCAL mode successfully"
    log "Current mode: LOCAL (carambus_api_url is empty, local database, local deployment server)"
}

# Function to switch to API mode
switch_to_api() {
    log "Switching to API mode..."
    
    # Update carambus.yml
    log "Updating carambus.yml..."
    cat > "$PROJECT_ROOT/config/carambus.yml" << 'EOF'
---
default:
  :carambus_api_url: https://api.carambus.de/
  :location_id: 1
  :application_name: Carambus
  :support_email: gernot.ullrich@gmx.de
  :business_name: Ullrich IT Consulting
  :business_address: 22869 Schenefeld, Sandstückenweg 15
  :carambus_domain: carambus.de
  :queue_adapter: async
  :small_table_no: 0
  :large_table_no: 0
  :pool_table_no: 0
  :snooker_table_no: 0
  :context: NBV
  :season_name: 2023/2024
  :force_update: 'true'
  :no_local_protection: 'false'
  :club_id: 357
development:
  carambus_api_url: https://api.carambus.de/
  location_id: 1
  application_name: Carambus
  support_email: gernot.ullrich@gmx.de
  business_name: Ullrich IT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  context: API
  season_name: 2024/2025
  force_update: 'true'
  no_local_protection: 'false'
  club_id: 357
test:
  carambus_api_url: https://api.carambus.de/
  location_id: 1
  application_name: Carambus
  support_email: gernot.ullrich@gmx.de
  business_name: Ullrich IT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  small_table_no: 0
  large_table_no: 0
  pool_table_no: 0
  snooker_table_no: 0
production:
  carambus_api_url: https://api.carambus.de/
  location_id: 1
  application_name: Carambus
  support_email: gernot.ullrich@gmx.de
  business_name: Ullrich IT Consulting
  business_address: 22869 Schenefeld, Sandstückenweg 15
  carambus_domain: carambus.de
  queue_adapter: async
  small_table_no: 0
  large_table_no: 0
  pool_table_no: 0
  snooker_table_no: 0
EOF

    # Update database.yml
    log "Updating database.yml..."
    cat > "$PROJECT_ROOT/config/database.yml" << 'EOF'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: carambus_api_development
  username: <%= ENV.fetch("DB_USERNAME", nil) %>
  password: <%= ENV.fetch("DB_PASSWORD", nil) %>
  host: <%= ENV.fetch("DB_HOST", "localhost") %>

test:
  <<: *default
  database: carambus_test
  username: <%= ENV.fetch("DB_USERNAME", nil) %>
  password: <%= ENV.fetch("DB_PASSWORD", nil) %>
  host: <%= ENV.fetch("DB_HOST", "localhost") %>

production:
  <<: *default
  database: carambus2_api_production
EOF

    # Update production.rb (production server)
    log "Updating production.rb..."
    cat > "$PROJECT_ROOT/config/deploy/production.rb" << 'EOF'
# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# API MODE - Production server
server 'carambus.de', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # carambus global

# LOCAL MODE - Testing server (commented out)
# server '192.168.178.81', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4bw (local testing)

# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# The server-based syntax can be used to override options:
# ------------------------------------
# server 'carambus.de',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
EOF

    # Update deploy.rb for API mode
    log "Updating deploy.rb..."
    update_deploy_rb "carambus_api"
    
    # Manage log files for API mode
    log "Managing log files for API mode..."
    manage_log_files "api"
    
    log "Switched to API mode successfully"
    log "Current mode: API (carambus_api_url is set, API database, production deployment server)"
}

# Function to show current mode
show_current_mode() {
    log "Checking current mode..."
    
    if [ -f "$PROJECT_ROOT/config/carambus.yml" ]; then
        local api_url=$(grep -A 1 "development:" "$PROJECT_ROOT/config/carambus.yml" | grep "carambus_api_url:" | head -1 | sed 's/.*carambus_api_url: *//')
        local database=$(grep -A 1 "development:" "$PROJECT_ROOT/config/database.yml" | grep "database:" | head -1 | sed 's/.*database: *//')
        local server=$(grep "server '" "$PROJECT_ROOT/config/deploy/production.rb" | head -1 | sed "s/.*server '//" | sed "s/'.*//")
        local basename=$(grep "set :basename," "$PROJECT_ROOT/config/deploy.rb" | sed 's/.*set :basename, *"//' | sed 's/".*//')
        
        # Check log file status
        local log_status=""
        if [ -L "$PROJECT_ROOT/log/development.log" ]; then
            local log_target=$(readlink "$PROJECT_ROOT/log/development.log")
            log_status=$(basename "$log_target")
        else
            log_status="direct file (not linked)"
        fi
        
        echo -e "${BLUE}Current Configuration:${NC}"
        echo -e "  API URL: ${YELLOW}$api_url${NC}"
        echo -e "  Database: ${YELLOW}$database${NC}"
        echo -e "  Deploy Server: ${YELLOW}$server${NC}"
        echo -e "  Deploy Basename: ${YELLOW}$basename${NC}"
        echo -e "  Log File: ${YELLOW}$log_status${NC}"
        
        if [ -z "$api_url" ] || [ "$api_url" = "" ]; then
            echo -e "${GREEN}Current Mode: LOCAL${NC}"
        else
            echo -e "${GREEN}Current Mode: API${NC}"
        fi
    else
        error "Configuration file not found"
    fi
}

# Function to show help
show_help() {
    echo "Carambus Mode Switcher"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  local          Switch to LOCAL mode (empty carambus_api_url, local database)"
    echo "  api            Switch to API mode (set carambus_api_url, API database)"
    echo "  status         Show current mode and configuration"
    echo "  backup         Create backup of current configuration"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local       # Switch to local development mode"
    echo "  $0 api         # Switch to API mode"
    echo "  $0 status      # Show current configuration"
    echo ""
    echo "Mode Differences:"
    echo "  LOCAL:  carambus_api_url is empty, local database, local deployment server"
    echo "  API:    carambus_api_url is set, API database, production deployment server"
}

# Function to update deploy.rb basename
update_deploy_rb() {
    local basename="$1"
    local deploy_file="$PROJECT_ROOT/config/deploy.rb"
    
    if [ -f "$deploy_file" ]; then
        # Create a temporary file
        local temp_file=$(mktemp)
        
        # Update the basename line
        sed "s/set :basename, File.basename(\`pwd\`).strip/set :basename, \"$basename\"/" "$deploy_file" > "$temp_file"
        
        # Replace the original file
        mv "$temp_file" "$deploy_file"
        
        log "Updated deploy.rb basename to: $basename"
    else
        warn "deploy.rb not found, skipping basename update"
    fi
}

# Function to manage log files
manage_log_files() {
    local mode="$1"
    local log_dir="$PROJECT_ROOT/log"
    
    # Ensure log directory exists
    mkdir -p "$log_dir"
    
    # Backup current development.log if it exists
    if [ -f "$log_dir/development.log" ]; then
        local timestamp=$(date +'%Y%m%d_%H%M%S')
        mv "$log_dir/development.log" "$log_dir/development.log.backup_$timestamp"
        log "Backed up current development.log"
    fi
    
    # Create symbolic link to mode-specific log file
    if [ "$mode" = "local" ]; then
        # For LOCAL mode, link to development-local.log
        if [ -f "$log_dir/development-local.log" ]; then
            ln -sf "$log_dir/development-local.log" "$log_dir/development.log"
            log "Linked development.log to development-local.log"
        else
            # Create empty log file if it doesn't exist
            touch "$log_dir/development-local.log"
            ln -sf "$log_dir/development-local.log" "$log_dir/development.log"
            log "Created and linked development-local.log"
        fi
    elif [ "$mode" = "api" ]; then
        # For API mode, link to development-api.log
        if [ -f "$log_dir/development-api.log" ]; then
            ln -sf "$log_dir/development-api.log" "$log_dir/development.log"
            log "Linked development.log to development-api.log"
        else
            # Create empty log file if it doesn't exist
            touch "$log_dir/development-api.log"
            ln -sf "$log_dir/development-api.log" "$log_dir/development.log"
            log "Created and linked development-api.log"
        fi
    fi
}

# Main script logic
case "${1:-help}" in
    "local")
        create_backup
        switch_to_local
        ;;
    "api")
        create_backup
        switch_to_api
        ;;
    "status")
        show_current_mode
        ;;
    "backup")
        create_backup
        ;;
    "help"|*)
        show_help
        ;;
esac 