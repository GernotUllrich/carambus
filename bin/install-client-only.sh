#!/bin/bash
# Carambus Client-Only Installation Script
# Usage: ./bin/install-client-only.sh <scenario_name> <client_ip> [ssh_port] [ssh_user]

set -e

# Load Carambus environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/carambus_env.sh" ]; then
    source "$SCRIPT_DIR/lib/carambus_env.sh"
else
    echo "ERROR: carambus_env.sh not found"
    exit 1
fi

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
CLIENT_IP=""
SSH_PORT="22"
SSH_USER="pi"

show_usage() {
    echo "Usage: $0 <scenario_name> <client_ip> [ssh_port] [ssh_user]"
    echo ""
    echo "Arguments:"
    echo "  scenario_name    Name of the scenario (e.g., carambus_bcw)"
    echo "  client_ip        IP address of the Raspberry Pi client"
    echo "  ssh_port         SSH port (default: 22)"
    echo "  ssh_user         SSH username (default: pi)"
    echo ""
    echo "Examples:"
    echo "  $0 carambus_bcw 192.168.1.100"
    echo "  $0 carambus_bcw 192.168.1.100 22 pi"
    echo ""
    echo "This script will:"
    echo "  1. Load scenario configuration from carambus_data/scenarios/"
    echo "  2. Retrieve location MD5 hash from database"
    echo "  3. Install required packages on the Raspberry Pi"
    echo "  4. Create the scoreboard autostart script with correct URL"
    echo "  5. Create systemd service for kiosk mode"
    echo "  6. Enable and start the scoreboard service"
    echo ""
    echo "Note: The script automatically uses the production server configuration"
    echo "      from the scenario and generates the correct scoreboard URL format:"
    echo "      http://server:port/locations/{md5}?sb_state=welcome"
}

# Parse arguments
if [ $# -lt 2 ]; then
    error "Missing required arguments"
    show_usage
    exit 1
fi

# Check for help first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

SCENARIO_NAME="$1"
CLIENT_IP="$2"

if [ $# -ge 3 ]; then
    SSH_PORT="$3"
fi

if [ $# -ge 4 ]; then
    SSH_USER="$4"
fi

# Validate scenario name
if [ -z "$SCENARIO_NAME" ]; then
    error "Scenario name cannot be empty"
    exit 1
fi

# Validate IP address
if [ -z "$CLIENT_IP" ]; then
    error "Client IP cannot be empty"
    exit 1
fi

# Load scenario configuration
SCENARIO_CONFIG="$SCENARIOS_PATH/$SCENARIO_NAME/config.yml"
if [ ! -f "$SCENARIO_CONFIG" ]; then
    error "Scenario configuration not found: $SCENARIO_CONFIG"
    exit 1
fi

# Extract configuration values
WEBSERVER_HOST=$(grep -A 20 "production:" "$SCENARIO_CONFIG" | grep "webserver_host:" | awk '{print $2}')
WEBSERVER_PORT=$(grep -A 20 "production:" "$SCENARIO_CONFIG" | grep "webserver_port:" | awk '{print $2}')

if [ -z "$WEBSERVER_HOST" ] || [ -z "$WEBSERVER_PORT" ]; then
    error "Failed to extract required configuration from $SCENARIO_CONFIG"
    exit 1
fi

# Get MD5 hash from Rails application
# Determine which Rails application directory to use
RAILS_APP_DIR=""
if [ -d "$CARAMBUS_BASE/${SCENARIO_NAME}" ]; then
    RAILS_APP_DIR="$CARAMBUS_BASE/${SCENARIO_NAME}"
elif [ -d "$CARAMBUS_MASTER" ]; then
    RAILS_APP_DIR="$CARAMBUS_MASTER"
else
    error "Could not find Rails application directory"
    error "Checked: $CARAMBUS_BASE/${SCENARIO_NAME} and $CARAMBUS_MASTER"
    exit 1
fi

info "Getting location MD5 hash from database..."
MD5_HASH=$(cd "$RAILS_APP_DIR" && RAILS_ENV=development bundle exec rails scenarios:get_location_md5[$SCENARIO_NAME] 2>/dev/null | tail -1)

if [ -z "$MD5_HASH" ] || [[ "$MD5_HASH" == *"Error"* ]]; then
    error "Failed to get MD5 hash for scenario $SCENARIO_NAME"
    error "Make sure the database is set up and the location exists"
    exit 1
fi

log "Location MD5 hash: $MD5_HASH"

# Generate scoreboard URL with MD5 and welcome state
SCOREBOARD_URL="http://${WEBSERVER_HOST}:${WEBSERVER_PORT}/locations/${MD5_HASH}?sb_state=welcome"

log "🎯 Carambus Client-Only Installation"
log "=================================="
log "Scenario: $SCENARIO_NAME"
log "Client IP: $CLIENT_IP"
log "SSH Port: $SSH_PORT"
log "SSH User: $SSH_USER"
log "Server: ${WEBSERVER_HOST}:${WEBSERVER_PORT}"
log "Location MD5: $MD5_HASH"
log "Scoreboard URL: $SCOREBOARD_URL"
echo ""

# Function to execute SSH commands
execute_ssh_command() {
    local cmd="$1"
    local description="$2"
    
    info "$description"
    if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CLIENT_IP" "$cmd" 2>/dev/null; then
        log "   ✅ $description completed"
        return 0
    else
        error "   ❌ $description failed"
        return 1
    fi
}

# Function to upload file content via SSH
upload_file_content() {
    local content="$1"
    local remote_path="$2"
    local description="$3"
    
    info "$description"
    if echo "$content" | ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CLIENT_IP" "cat > $remote_path" 2>/dev/null; then
        log "   ✅ $description completed"
        return 0
    else
        error "   ❌ $description failed"
        return 1
    fi
}

# Step 1: Test SSH connection
log "🔌 Step 1: Testing SSH Connection"
log "================================"

info "Testing SSH connection to $SSH_USER@$CLIENT_IP:$SSH_PORT..."
if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CLIENT_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    log "✅ SSH connection successful"
else
    error "❌ SSH connection failed"
    error "Please ensure:"
    error "  - Raspberry Pi is accessible at $CLIENT_IP:$SSH_PORT"
    error "  - SSH is enabled on the Raspberry Pi"
    error "  - User $SSH_USER exists and has SSH access"
    error "  - SSH key authentication is set up or password authentication is enabled"
    exit 1
fi
echo ""

# Step 2: Install required packages
log "📦 Step 2: Installing Required Packages"
log "======================================"

execute_ssh_command "sudo apt update" "Updating package list"
execute_ssh_command "sudo apt install -y chromium-browser wmctrl xdotool" "Installing required packages (chromium, wmctrl, xdotool)"
echo ""

# Step 3: Create autostart script
log "🚀 Step 3: Creating Autostart Script"
log "=================================="

# Create the autostart script content
AUTOSTART_SCRIPT='#!/bin/bash
# Carambus Scoreboard Autostart Script (Client-Only)
# This script is designed to be called from systemd

# Set display environment
export DISPLAY=:0

# Wait for display to be ready
sleep 5

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Get scoreboard URL
SCOREBOARD_URL="'$SCOREBOARD_URL'"

echo "Using scoreboard URL: $SCOREBOARD_URL"

# Ensure chromium data directory has correct permissions for current user
if [ -d /tmp/chromium-scoreboard ]; then
    chmod 755 /tmp/chromium-scoreboard 2>/dev/null || true
fi

# Clean up old chromium data to prevent disk space issues
rm -rf /tmp/chromium-scoreboard 2>/dev/null || true

# Start browser in fullscreen with additional flags to handle display issues
/usr/bin/chromium-browser \
  --start-fullscreen \
  --disable-restore-session-state \
  --user-data-dir=/tmp/chromium-scoreboard \
  --disable-features=VizDisplayCompositor \
  --disable-dev-shm-usage \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-background-networking \
  --disable-sync \
  --disable-default-apps \
  --disable-extensions \
  --disable-plugins \
  --disable-translate \
  --disable-logging \
  --disable-gpu-logging \
  --silent-debugger-extension-api \
  --app="$SCOREBOARD_URL" \
  >/dev/null 2>&1 &

# Wait and ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true'

# Upload the autostart script
upload_file_content "$AUTOSTART_SCRIPT" "/tmp/autostart-scoreboard.sh" "Uploading autostart script"

# Make it executable and move to system location
execute_ssh_command "chmod +x /tmp/autostart-scoreboard.sh" "Making autostart script executable"
execute_ssh_command "sudo mv /tmp/autostart-scoreboard.sh /usr/local/bin/autostart-scoreboard.sh" "Installing autostart script"
echo ""

# Step 4: Create systemd service
log "⚙️  Step 4: Creating Systemd Service"
log "=================================="

# Create the systemd service content
SYSTEMD_SERVICE="[Unit]
Description=Carambus Scoreboard Kiosk (Client-Only)
After=graphical.target

[Service]
Type=simple
User=$SSH_USER
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target"

# Upload the systemd service
upload_file_content "$SYSTEMD_SERVICE" "/tmp/scoreboard-kiosk.service" "Uploading systemd service file"

# Install the systemd service
execute_ssh_command "sudo mv /tmp/scoreboard-kiosk.service /etc/systemd/system/scoreboard-kiosk.service" "Installing systemd service file"
execute_ssh_command "sudo systemctl daemon-reload" "Reloading systemd configuration"
echo ""

# Step 5: Enable and start service
log "🚀 Step 5: Starting Scoreboard Service"
log "===================================="

execute_ssh_command "sudo systemctl enable scoreboard-kiosk.service" "Enabling scoreboard service for autostart"
execute_ssh_command "sudo systemctl start scoreboard-kiosk.service" "Starting scoreboard service"
echo ""

# Step 6: Verify installation
log "🧪 Step 6: Verifying Installation"
log "==============================="

info "Checking service status..."
if execute_ssh_command "sudo systemctl is-active scoreboard-kiosk.service" "Checking if service is active"; then
    log "✅ Scoreboard service is running"
else
    warning "⚠️  Scoreboard service may not be running properly"
fi

info "Checking service logs..."
execute_ssh_command "sudo systemctl status scoreboard-kiosk.service --no-pager -l" "Displaying service status"

info "Checking if Chromium process is running..."
execute_ssh_command "pgrep -f chromium-browser" "Checking for Chromium process"
echo ""

# Final success message
log "🎉 CLIENT-ONLY INSTALLATION COMPLETED!"
log "====================================="
log "Raspberry Pi at $CLIENT_IP is now configured as a Carambus scoreboard client"
log ""
log "Configuration Details:"
log "  - Scenario: $SCENARIO_NAME"
log "  - Server: ${WEBSERVER_HOST}:${WEBSERVER_PORT}"
log "  - Location MD5: $MD5_HASH"
log "  - Scoreboard URL: $SCOREBOARD_URL"
log "  - Service: scoreboard-kiosk.service"
log ""
log "Management Commands:"
log "  - Check Status: ssh -p $SSH_PORT $SSH_USER@$CLIENT_IP 'sudo systemctl status scoreboard-kiosk'"
log "  - Restart Service: ssh -p $SSH_PORT $SSH_USER@$CLIENT_IP 'sudo systemctl restart scoreboard-kiosk'"
log "  - Stop Service: ssh -p $SSH_PORT $SSH_USER@$CLIENT_IP 'sudo systemctl stop scoreboard-kiosk'"
log "  - View Logs: ssh -p $SSH_PORT $SSH_USER@$CLIENT_IP 'sudo journalctl -u scoreboard-kiosk -f'"
log ""
log "The scoreboard should now be visible on the Raspberry Pi display!"


