#!/bin/bash
# Complete Carambus API Deployment Workflow
# The starting point is the carambus_api_development database

set -e

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

# Configuration
SCENARIO_NAME="carambus_api"
PI_IP="api.carambus.de"
PI_USER="www-data"
PI_PORT="8910"

# Confirmation function
confirm() {
    local prompt="$1"
    local default="${2:-n}"

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

# Step 0: Complete Cleanup
step_zero_cleanup() {
    log "🧹 Step 0: Complete Cleanup"
    log "=========================="

    warning "This will completely remove:"
    warning "  - Scenario root folder: /Volumes/EXT2TB/gullrich/DEV/carambus/$SCENARIO_NAME"
    warning "  - Database: doesn't effect the mother of all carambus_api_development!"
    warning "  - Database: carambus_api_production"
    warning "  - Raspberry Pi: Puma service, Nginx config, production database"

    if ! confirm "Are you sure you want to proceed with complete cleanup?"; then
        log "Cleanup cancelled"
        return 1
    fi

    # Clean up local scenario root folder
    info "Removing local scenario root folder..."
    if [ -d "/Volumes/EXT2TB/gullrich/DEV/carambus/$SCENARIO_NAME" ]; then
        rm -rf "/Volumes/EXT2TB/gullrich/DEV/carambus/$SCENARIO_NAME"
        log "✅ Local scenario root folder removed"
    else
        info "Local scenario root folder not found (already clean)"
    fi

}

# Step 1: Prepare Development
step_one_prepare_development() {
    log "🔧 Step 1: Prepare Development Environment"
    log "========================================"

    info "This will:"
    info "  - Generate configuration files"
    info "  - Create Rails root folder"
    info "  - Create development database from template"
    info "  - Apply region filtering"
    info "  - Set up development environment"

    if ! confirm "Proceed with prepare_development?"; then
        log "Step 1 cancelled"
        return 1
    fi

    log "Running: rake scenario:prepare_development[$SCENARIO_NAME,development]"
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
    info "  - Copy deployment files (nginx, puma, etc.)"
    info "  - Upload config files to server shared directory"
    info "  - Create systemd service and Nginx configuration on server"
    info "  - Prepare for server deployment"

    if ! confirm "Proceed with prepare_deploy?"; then
        log "Step 2 cancelled"
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
        log "Step 3 cancelled"
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
        log "Step 4 cancelled"
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
        log "Step 5 cancelled"
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
    log "🎯 Complete Carambus Location 5101 Deployment Workflow"
    log "====================================================="
    log "Phillip's Table - Full Clean Deployment"
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
    log "Phillip's Table (Location 5101) is now fully deployed and operational"
    log ""
    log "Access Information:"
    log "  - Web Interface: http://$PI_IP:82"
    log "  - Scoreboard: http://$PI_IP:82/locations/48f7d3043bc03e6c48a6f0ebc0f258a8?sb_state=welcome"
    log "  - SSH Access: ssh -p $PI_PORT $PI_USER@$PI_IP"
    log ""
    log "Management Commands:"
    log "  - Restart Browser: rake scenario:restart_raspberry_pi_client[$SCENARIO_NAME]"
    log "  - Test Client: rake scenario:test_raspberry_pi_client[$SCENARIO_NAME]"
    log "  - Check Service: ssh -p $PI_PORT $PI_USER@$PI_IP 'sudo systemctl status scoreboard-kiosk'"
}

# Run main workflow
main "$@"
