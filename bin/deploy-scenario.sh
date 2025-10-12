#!/bin/bash
# Generic Carambus Scenario Deployment Workflow
# Usage: ./bin/deploy-scenario.sh <scenario_name> [-y]

set -e

# Load Carambus environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/carambus_env.sh" ]; then
    source "$SCRIPT_DIR/lib/carambus_env.sh"
else
    echo "ERROR: carambus_env.sh not found"
    exit 1
fi

# Reduce Ruby warning noise in output
export RUBYOPT="${RUBYOPT:-} -W0"
export BUNDLE_SILENCE_DEPRECATIONS=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Parse command line arguments
SCENARIO_NAME=""
AUTO_CONFIRM=false

show_usage() {
    echo "Usage: $0 <scenario_name> [-y]"
    echo ""
    echo "Arguments:"
    echo "  scenario_name    Name of the scenario to deploy (e.g., carambus_location_5101)"
    echo "  -y               Auto-confirm all steps (skip interactive prompts)"
    echo ""
    echo "Examples:"
    echo "  $0 carambus_location_5101"
    echo "  $0 carambus_location_5101 -y"
    echo ""
    echo "This script will:"
    echo "  1. Clean up existing deployment"
    echo "  2. Prepare development environment"
    echo "  3. Prepare deployment configuration"
    echo "  4. Deploy to server"
    echo "  5. Prepare Raspberry Pi client"
    echo "  6. Deploy client configuration"
    echo "  7. Run final tests"
}

# Parse arguments
if [ $# -eq 0 ]; then
    error "No scenario name provided"
    show_usage
    exit 1
fi

# Check for help first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

SCENARIO_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate scenario name
if [ -z "$SCENARIO_NAME" ]; then
    error "Scenario name cannot be empty"
    exit 1
fi

# Confirmation function
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$AUTO_CONFIRM" = true ]; then
        log "Auto-confirming: $prompt"
        return 0
    fi
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if production database version is higher than development OR has local data
check_production_version() {
    local scenario_name="$1"
    
    # Get development database version
    local dev_version
    dev_version=$(psql -d "${scenario_name}_development" -t -c "SELECT last_version_id FROM schema_migrations ORDER BY version DESC LIMIT 1;" 2>/dev/null | xargs)
    
    # Check if production database exists on remote server
    if ! ssh -p 8910 www-data@192.168.178.107 "sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw ${scenario_name}_production" 2>/dev/null; then
        info "Production database ${scenario_name}_production does not exist on remote server"
        return 0  # Allow drop (nothing to drop)
    fi
    
    # Check for local data: official id>50M in core tables or any rows in extension tables
    info "Checking for local data (ID > 50,000,000 or extension tables present)..."
    local has_local_data
    local local_query
    local_query="SELECT (
      (SELECT COUNT(*) FROM (SELECT 1 FROM games WHERE id > 50000000 LIMIT 1) AS t1) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM tournaments WHERE id > 50000000 LIMIT 1) AS t2) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM tables WHERE id > 50000000 LIMIT 1) AS t3) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM users WHERE id > 50000000 LIMIT 1) AS t4) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM players WHERE id > 50000000 LIMIT 1) AS t5) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM table_locals LIMIT 1) AS t6) +
      (SELECT COUNT(*) FROM (SELECT 1 FROM tournament_locals LIMIT 1) AS t7)
    );"
    has_local_data=$(ssh -p 8910 www-data@192.168.178.107 "sudo -u postgres psql -d ${scenario_name}_production -t -c \"${local_query}\"" 2>/dev/null | xargs)
    
    if [ "$has_local_data" != "0" ]; then
        warning "Production database contains local data (ID > 50,000,000)"
        warning "Database will NOT be dropped in cleanup - local data will be preserved"
        info "Step 2 (prepare_deploy) will automatically backup and restore local data"
        return 1  # Don't drop - has local data
    fi
    
    # Get production database version from remote server
    local prod_version
    prod_version=$(ssh -p 8910 www-data@192.168.178.107 "sudo -u postgres psql -d ${scenario_name}_production -t -c \"SELECT last_version_id FROM schema_migrations ORDER BY version DESC LIMIT 1;\"" 2>/dev/null | xargs)
    
    # If either version is empty or not numeric, assume we should drop
    if [[ ! "$dev_version" =~ ^[0-9]+$ ]] || [[ ! "$prod_version" =~ ^[0-9]+$ ]]; then
        return 0  # Allow drop
    fi
    
    # Compare versions
    if [ "$prod_version" -gt "$dev_version" ]; then
        warning "Production database version ($prod_version) is higher than development ($dev_version)"
        return 1  # Don't drop - production is newer
    else
        info "Production database version ($prod_version) is same or lower than development ($dev_version)"
        return 0  # Allow drop - development is same or newer
    fi
}

# Step 0: Complete Cleanup
step_zero_cleanup() {
    log "🧹 Step 0: Complete Cleanup"
    log "=========================="
    
    warning "This will completely remove:"
    warning "  - Scenario root folder: $CARAMBUS_BASE/$SCENARIO_NAME"
    if [ "$SCENARIO_NAME" = "carambus_api" ]; then
        warning "  - Database: ${SCENARIO_NAME}_development (SKIPPED - API server database)"
    else
        warning "  - Database: ${SCENARIO_NAME}_development"
    fi
    warning "  - Database: ${SCENARIO_NAME}_production (checked for local data & version)"
    warning "  - Raspberry Pi: Puma service, Nginx config, production database"
    info ""
    info "Note: Production database will NOT be dropped if:"
    info "  - It contains local data (ID > 50,000,000)"
    info "  - Its version is higher than development"
    info "  → In these cases, Step 2 (prepare_deploy) will handle data preservation"
    
    if ! confirm "Proceed with complete cleanup?"; then
        log "Cleanup cancelled"
        return 1
    fi
    
    # Clean up local scenario root folder
    info "Removing local scenario root folder..."
    if [ -d "$CARAMBUS_BASE/$SCENARIO_NAME" ]; then
        rm -rf "$CARAMBUS_BASE/$SCENARIO_NAME"
        log "✅ Local scenario root folder removed"
    else
        info "Local scenario root folder not found (already clean)"
    fi
    
    # Drop development database (skip for carambus_api)
    info "Dropping development database..."
    if [ "$SCENARIO_NAME" = "carambus_api" ]; then
        info "Skipping development database drop for carambus_api (API server database)"
    elif psql -lqt | cut -d \| -f 1 | grep -qw "${SCENARIO_NAME}_development"; then
        dropdb "${SCENARIO_NAME}_development"
        log "✅ Development database dropped"
    else
        info "Development database not found (already clean)"
    fi
    
    # Clean up Raspberry Pi
    info "Cleaning up Raspberry Pi..."
    
    # Stop and remove Puma service
    ssh -p 8910 www-data@192.168.178.107 "sudo systemctl stop puma-${SCENARIO_NAME}.service || true"
    ssh -p 8910 www-data@192.168.178.107 "sudo systemctl disable puma-${SCENARIO_NAME}.service || true"
    ssh -p 8910 www-data@192.168.178.107 "sudo rm -f /etc/systemd/system/puma-${SCENARIO_NAME}.service || true"
    log "✅ Puma service removed"
    
    # Remove Nginx configuration
    ssh -p 8910 www-data@192.168.178.107 "sudo rm -f /etc/nginx/sites-enabled/*${SCENARIO_NAME}* || true"
    ssh -p 8910 www-data@192.168.178.107 "sudo rm -f /etc/nginx/sites-available/*${SCENARIO_NAME}* || true"
    ssh -p 8910 www-data@192.168.178.107 "sudo systemctl reload nginx || true"
    log "✅ Nginx configuration removed"
    
    # Drop production database (only if version check AND local data check pass)
    info "Checking production database (version and local data)..."
    if check_production_version "$SCENARIO_NAME"; then
        info "No conflicts detected - dropping database on remote server"
        if ssh -p 8910 www-data@192.168.178.107 "sudo -u postgres dropdb ${SCENARIO_NAME}_production 2>/dev/null"; then
            log "✅ Production database dropped"
        else
            info "Production database not found or already dropped"
        fi
    else
        log "✅ Production database preserved (has local data or newer version)"
        info "Step 2 (prepare_deploy) will handle database update with data preservation"
    fi
    
    # Remove deployment directory
    ssh -p 8910 www-data@192.168.178.107 "sudo rm -rf /var/www/${SCENARIO_NAME} || true"
    log "✅ Deployment directory removed"
    
    log "✅ Complete cleanup finished"
    echo ""
}

# Step 1: Prepare Development
step_one_prepare_development() {
    log "🔧 Step 1: Prepare Development Environment"
    log "========================================"
    
    info "This will:"
    info "  - Generate configuration files"
    info "  - Create Rails root folder"
    info "  - Check and sync with carambus_api_production if newer"
    info "  - Create development database from template"
    info "  - Apply region filtering"
    info "  - Set up development environment"
    
    if ! confirm "Proceed with prepare_development?"; then
        log "Development preparation cancelled"
        return 1
    fi
    
    if [ "$SCENARIO_NAME" = "carambus_api" ]; then
        info "Special handling for carambus_api (API server):"
        info "  - Development environment will be created normally"
        info "  - Database operations are protected by rake task"
        info "  - No filtering, Version.sequence_reset, or settings manipulation"
        info "  - API sync step will be skipped (it is the source)"
        log "Running: rake scenario:prepare_development[$SCENARIO_NAME,development] (API mode)"
    else
        info "This scenario will sync with carambus_api_production if newer data is available"
        log "Running: rake scenario:prepare_development[$SCENARIO_NAME,development]"
    fi
    rake "scenario:prepare_development[$SCENARIO_NAME,development]"
    
    log "✅ Step 1 completed: Development environment prepared"
    echo ""
}

# Step 2: Prepare Deploy
step_two_prepare_deploy() {
    log "📦 Step 2: Prepare Deployment"
    log "============================"
    
    info "This will:"
    info "  - Generate production configuration files"
    info "  - Create production database from development dump"
    info "  - **AUTOMATICALLY** backup local data (id > 50,000,000) if present"
    info "  - **AUTOMATICALLY** restore local data after database replacement"
    info "  - Copy deployment files (nginx, puma, etc.)"
    info "  - Upload config files to server shared directory"
    info "  - Create systemd service and Nginx configuration on server"
    info "  - Prepare for server deployment"
    info ""
    info "Note: Local data preservation is automatic - no manual steps needed!"
    
    if ! confirm "Proceed with prepare_deploy?"; then
        log "Deployment preparation cancelled"
        return 1
    fi
    
    log "Running: rake scenario:prepare_deploy[$SCENARIO_NAME]"
    rake "scenario:prepare_deploy[$SCENARIO_NAME]"
    
    log "✅ Step 2 completed: Deployment prepared"
    echo ""
}

# Step 3: Deploy
step_three_deploy() {
    log "🚀 Step 3: Deploy to Server"
    log "=========================="
    
    info "This will:"
    info "  - Execute pure Capistrano deployment"
    info "  - Automatically restart Puma service via Capistrano"
    info "  - Complete the application deployment"
    info "  - Database and config files already prepared by prepare_deploy"
    
    if ! confirm "Proceed with server deployment?"; then
        log "Server deployment cancelled"
        return 1
    fi
    
    log "Running: rake scenario:deploy[$SCENARIO_NAME]"
    rake "scenario:deploy[$SCENARIO_NAME]"
    
    log "✅ Step 3 completed: Server deployment finished"
    echo ""
}

# Step 4: Prepare Client
step_four_prepare_client() {
    log "🍓 Step 4: Prepare Raspberry Pi Client"
    log "====================================="
    
    info "This will:"
    info "  - Install required packages (chromium, wmctrl, xdotool)"
    info "  - Create kiosk user"
    info "  - Setup systemd service"
    info "  - Prepare for kiosk mode"
    
    if ! confirm "Proceed with client preparation?"; then
        log "Client preparation cancelled"
        return 1
    fi
    
    log "Running: rake scenario:setup_raspberry_pi_client[$SCENARIO_NAME]"
    rake "scenario:setup_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "✅ Step 4 completed: Client prepared"
    echo ""
}

# Step 5: Deploy Client
step_five_deploy_client() {
    log "📱 Step 5: Deploy Client Configuration"
    log "====================================="
    
    info "This will:"
    info "  - Upload scoreboard URL"
    info "  - Install autostart script"
    info "  - Enable systemd service"
    info "  - Start kiosk mode"
    
    if ! confirm "Proceed with client deployment?"; then
        log "Client deployment cancelled"
        return 1
    fi
    
    log "Running: rake scenario:deploy_raspberry_pi_client[$SCENARIO_NAME]"
    rake "scenario:deploy_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "✅ Step 5 completed: Client deployed"
    echo ""
}

# Final Test
final_test() {
    log "🧪 Final Test"
    log "============"
    
    info "Testing complete functionality..."
    
    log "Running: rake scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    rake "scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "Testing browser restart functionality..."
    rake "scenario:restart_raspberry_pi_client[$SCENARIO_NAME]"
    
    log "✅ Final test completed"
    echo ""
}

# Main workflow
main() {
    log "🎯 Complete Carambus Scenario Deployment Workflow"
    log "================================================"
    log "Scenario: $SCENARIO_NAME"
    if [ "$AUTO_CONFIRM" = true ]; then
        log "Mode: Auto-confirm (non-interactive)"
    else
        log "Mode: Interactive"
    fi
    echo ""
    
    # Step 0: Complete Cleanup
    step_zero_cleanup
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at cleanup step"
        exit 1
    fi
    
    # Step 1: Prepare Development
    step_one_prepare_development
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at development preparation"
        exit 1
    fi
    
    # Step 2: Prepare Deploy
    step_two_prepare_deploy
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at deployment preparation"
        exit 1
    fi
    
    # Step 3: Deploy
    step_three_deploy
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at server deployment"
        exit 1
    fi
    
    # Step 4: Prepare Client
    step_four_prepare_client
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at client preparation"
        exit 1
    fi
    
    # Step 5: Deploy Client
    step_five_deploy_client
    if [ $? -ne 0 ]; then
        log "Workflow cancelled at client deployment"
        exit 1
    fi
    
    # Final Test
    final_test
    
    log "🎉 COMPLETE WORKFLOW SUCCESSFUL!"
    log "================================"
    log "Scenario '$SCENARIO_NAME' is now fully deployed and operational"
    log ""
    # Read the correct port from scenario configuration
    if [ -f "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" ]; then
        WEBSERVER_PORT=$(grep -A 10 "production:" "$SCENARIOS_PATH/$SCENARIO_NAME/config.yml" | grep "webserver_port:" | awk '{print $2}')
    else
        WEBSERVER_PORT=3131  # Default for carambus_bcw
    fi
    
    log "Access Information:"
    log "  - Web Interface: http://192.168.178.107:$WEBSERVER_PORT"
    log "  - SSH Access: ssh -p 8910 www-data@192.168.178.107"
    log ""
    log "Management Commands:"
    log "  - Restart Browser: rake scenario:restart_raspberry_pi_client[$SCENARIO_NAME]"
    log "  - Test Client: rake scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    log "  - Check Service: ssh -p 8910 www-data@192.168.178.107 'sudo systemctl status scoreboard-kiosk'"
}

# Run main workflow
main "$@"
