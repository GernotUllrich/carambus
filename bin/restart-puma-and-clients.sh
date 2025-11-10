#!/bin/bash
# Restart Puma Server and All Scoreboard Kiosk Clients
# Usage: ./bin/restart-puma-and-clients.sh [scenario_name]
#
# This script is designed to run on the production server only.
# It:
# 1. Restarts the Puma server
# 2. Waits for Puma to be ready
# 3. Restarts all scoreboard-kiosk services on table clients
#
# Run from the deployment directory (e.g., /var/www/carambus_*/current)

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

# Show usage
show_usage() {
    echo "Usage: $0 [scenario_name]"
    echo ""
    echo "This script restarts the Puma server and all scoreboard-kiosk services on table clients."
    echo "Must be run on the production server from the deployment directory."
    echo ""
    echo "Arguments:"
    echo "  scenario_name  - Optional. Scenario name (e.g., carambus_bcw)."
    echo "                   If not provided, will detect from current directory."
    echo ""
    echo "Examples:"
    echo "  cd /var/www/carambus_bcw/current && $0 carambus_bcw"
    echo "  cd /var/www/carambus_bcw/current && $0  # Auto-detect"
    exit 1
}

# Parse arguments
SCENARIO_NAME="$1"

# Detect scenario and puma basename from current directory (deployment structure)
if [ -z "$SCENARIO_NAME" ]; then
    if [[ "$PWD" == */current ]]; then
        # We're in /var/www/carambus_*/current
        SCENARIO_NAME=$(basename $(dirname "$PWD"))
    elif [[ "$PWD" == */releases/* ]]; then
        # We're in /var/www/carambus_*/releases/...
        SCENARIO_NAME=$(echo "$PWD" | sed 's|.*/\([^/]*\)/releases/.*|\1|')
    else
        error "Could not detect scenario name from current directory"
        error "Please run from deployment directory (e.g., /var/www/carambus_*/current)"
        echo ""
        show_usage
    fi
fi

PUMA_BASENAME="$SCENARIO_NAME"

if [ -z "$PUMA_BASENAME" ]; then
    error "Could not determine Puma basename"
    echo ""
    show_usage
fi

log "🔄 Restart Puma and Scoreboard Clients"
log "======================================"
info "Scenario: $SCENARIO_NAME"
info "Puma Basename: $PUMA_BASENAME"
echo ""

# Rails app directory is current directory (we're in the deployment)
RAILS_APP_DIR="$PWD"
if [ ! -f "$RAILS_APP_DIR/config/application.rb" ]; then
    error "Not in a Rails application directory"
    error "Current directory: $RAILS_APP_DIR"
    exit 1
fi

info "Rails App Directory: $RAILS_APP_DIR"

# Step 1: Restart Puma
log "📦 Step 1: Restarting Puma Server"
log "================================="

PUMA_SERVICE="puma-${PUMA_BASENAME}.service"
info "Puma service: $PUMA_SERVICE"

# Verify we're on the server
if ! command -v systemctl >/dev/null 2>&1; then
    error "systemctl not found - this script must be run on the production server"
    exit 1
fi

if ! systemctl list-units --type=service --all 2>/dev/null | grep -q "$PUMA_SERVICE"; then
    error "Puma service '$PUMA_SERVICE' not found"
    error "Available puma services:"
    systemctl list-units --type=service --all 2>/dev/null | grep "puma-" || echo "  (none found)"
    exit 1
fi

if sudo systemctl is-active --quiet "$PUMA_SERVICE" 2>/dev/null; then
    info "Service is running, performing graceful restart..."
    sudo systemctl reload "$PUMA_SERVICE" 2>/dev/null || {
        warning "Reload failed, attempting full restart..."
        sudo systemctl restart "$PUMA_SERVICE" 2>/dev/null
    }
    
    # Wait for service to be active
    info "Waiting for Puma to be ready..."
    for i in {1..10}; do
        if sudo systemctl is-active --quiet "$PUMA_SERVICE" 2>/dev/null; then
            log "✅ Puma service is active"
            break
        fi
        if [ $i -eq 10 ]; then
            error "Puma service failed to start"
            exit 1
        fi
        sleep 1
    done
else
    info "Service is not running, starting service..."
    sudo systemctl start "$PUMA_SERVICE" 2>/dev/null || {
        error "Failed to start Puma service"
        exit 1
    }
fi

# Additional wait for Puma to accept connections
info "Waiting for Puma to accept connections..."
sleep 3

log "✅ Puma server restarted"
echo ""

# Step 2: Get table client IPs from database
log "📋 Step 2: Getting Table Client IPs"
log "===================================="

# Get location_id from database (production)
info "Querying production database for location_id..."
LOCATION_ID=$(cd "$RAILS_APP_DIR" && RAILS_ENV=production bundle exec rails runner "
# Try to find location by name matching scenario, or use first location
location = Location.where('name ILIKE ?', '%$SCENARIO_NAME%').first
location ||= Location.first
if location
  puts location.id
else
  puts 'NOT_FOUND'
end
" 2>/dev/null | tail -1)

if [ -z "$LOCATION_ID" ] || [ "$LOCATION_ID" = "NOT_FOUND" ]; then
    error "Could not get location_id from production database"
    error "Please ensure the database is accessible and contains location data"
    exit 1
fi

info "Location ID: $LOCATION_ID"

# Get all table IPs for this location
info "Querying production database for table client IPs..."
TABLE_IPS=$(cd "$RAILS_APP_DIR" && RAILS_ENV=production bundle exec rails runner "
location = Location.find($LOCATION_ID)
tables = location.tables.joins(:table_local).where.not(table_locals: { ip_address: [nil, ''] })
tables.each do |table|
  if table.table_local&.ip_address.present?
    puts table.table_local.ip_address
  end
end
" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)

if [ -z "$TABLE_IPS" ]; then
    warning "No table clients found with IP addresses"
    warning "Skipping client restarts"
    exit 0
fi

TABLE_COUNT=$(echo "$TABLE_IPS" | wc -l | tr -d ' ')
log "✅ Found $TABLE_COUNT table client(s)"
echo ""

# Step 3: Restart scoreboard-kiosk on each client
log "🖥️  Step 3: Restarting Scoreboard Clients"
log "=========================================="

SSH_USER="pi"
SSH_PORT="22"
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_IPS=()

for TABLE_IP in $TABLE_IPS; do
    info "Restarting scoreboard-kiosk on $TABLE_IP..."
    
    # Test SSH connection first
    if ! ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$TABLE_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
        warning "  ⚠️  Cannot connect to $TABLE_IP - skipping"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_IPS+=("$TABLE_IP")
        continue
    fi
    
    # Restart scoreboard-kiosk service
    if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$TABLE_IP" \
        "sudo systemctl restart scoreboard-kiosk" >/dev/null 2>&1; then
        
        # Verify service is running
        sleep 1
        if ssh -p "$SSH_PORT" -o ConnectTimeout=5 "$SSH_USER@$TABLE_IP" \
            "sudo systemctl is-active --quiet scoreboard-kiosk" >/dev/null 2>&1; then
            log "  ✅ $TABLE_IP - scoreboard-kiosk restarted successfully"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            warning "  ⚠️  $TABLE_IP - restart command succeeded but service not active"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_IPS+=("$TABLE_IP")
        fi
    else
        warning "  ⚠️  $TABLE_IP - failed to restart scoreboard-kiosk"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_IPS+=("$TABLE_IP")
    fi
done

echo ""
log "📊 Summary"
log "=========="
log "✅ Successfully restarted: $SUCCESS_COUNT client(s)"
if [ $FAIL_COUNT -gt 0 ]; then
    warning "❌ Failed: $FAIL_COUNT client(s)"
    for failed_ip in "${FAILED_IPS[@]}"; do
        warning "   - $failed_ip"
    done
    echo ""
    info "To troubleshoot failed clients, try:"
    echo "  ssh -p $SSH_PORT $SSH_USER@<failed_ip> 'sudo systemctl status scoreboard-kiosk'"
    echo "  ssh -p $SSH_PORT $SSH_USER@<failed_ip> 'sudo journalctl -u scoreboard-kiosk -n 50'"
else
    log "✅ All clients restarted successfully"
fi
echo ""

log "🎉 Restart complete!"
log "==================="

