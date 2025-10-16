#!/bin/bash
# Complete Raspberry Pi Table Client Setup Script
# Configures WLAN, static IP, and installs scoreboard client
# Usage: ./bin/setup-raspi-table-client.sh <scenario_name> <current_ip> <target_ssid> <target_password> <static_ip> <table_number>

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
CURRENT_IP=""
TARGET_SSID=""
TARGET_PASSWORD=""
STATIC_IP=""
TABLE_NUMBER=""
SSH_PORT="22"
SSH_USER="pi"

show_usage() {
    echo "Usage: $0 <scenario_name> <current_ip> <target_ssid> <target_password> <static_ip> <table_number> [ssh_port] [ssh_user]"
    echo ""
    echo "Arguments:"
    echo "  scenario_name      Name of the scenario (e.g., carambus_bcw)"
    echo "  current_ip         Current IP address of the Raspberry Pi"
    echo "  target_ssid        Target WLAN SSID"
    echo "  target_password    Target WLAN password"
    echo "  static_ip          Static IP address to assign"
    echo "  table_number       Table number (e.g., 4)"
    echo "  ssh_port           SSH port (default: 22)"
    echo "  ssh_user           SSH username (default: pi)"
    echo ""
    echo "Examples:"
    echo "  $0 carambus_bcw 192.168.178.81 WLAN-15AE35 password123 192.168.2.214 4"
    echo ""
    echo "This script will:"
    echo "  1. Configure WLAN with the target SSID and password"
    echo "  2. Set up static IP address"
    echo "  3. Retrieve location MD5 hash from database"
    echo "  4. Install scoreboard client software"
    echo "  5. Create and enable systemd service"
    echo "  6. Update table IP in database"
}

# Parse arguments
if [ $# -lt 6 ]; then
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
CURRENT_IP="$2"
TARGET_SSID="$3"
TARGET_PASSWORD="$4"
STATIC_IP="$5"
TABLE_NUMBER="$6"

if [ $# -ge 7 ]; then
    SSH_PORT="$7"
fi

if [ $# -ge 8 ]; then
    SSH_USER="$8"
fi

# Validate arguments
if [ -z "$SCENARIO_NAME" ] || [ -z "$CURRENT_IP" ] || [ -z "$TARGET_SSID" ] || [ -z "$TARGET_PASSWORD" ] || [ -z "$STATIC_IP" ] || [ -z "$TABLE_NUMBER" ]; then
    error "All required arguments must be provided"
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
LOCATION_ID=$(grep "location_id:" "$SCENARIO_CONFIG" | awk '{print $2}')

if [ -z "$WEBSERVER_HOST" ] || [ -z "$WEBSERVER_PORT" ] || [ -z "$LOCATION_ID" ]; then
    error "Failed to extract required configuration from $SCENARIO_CONFIG"
    exit 1
fi

# Get MD5 hash from Rails application
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
MD5_HASH=$(cd "$RAILS_APP_DIR" && RAILS_ENV=development bundle exec rails runner "puts Location.find($LOCATION_ID).md5" 2>/dev/null | tail -1)

if [ -z "$MD5_HASH" ] || [[ "$MD5_HASH" == *"Error"* ]]; then
    error "Failed to get MD5 hash for location $LOCATION_ID"
    exit 1
fi

# Calculate gateway and netmask from static IP
IFS='.' read -r -a ip_parts <<< "$STATIC_IP"
GATEWAY="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.1"
NETMASK="255.255.255.0"

# Generate scoreboard URL
SCOREBOARD_URL="http://${WEBSERVER_HOST}:${WEBSERVER_PORT}/locations/${MD5_HASH}?sb_state=welcome"

log "🎯 Raspberry Pi Table Client Setup"
log "==================================="
log "Scenario: $SCENARIO_NAME"
log "Current IP: $CURRENT_IP"
log "Target SSID: $TARGET_SSID"
log "Static IP: $STATIC_IP"
log "Gateway: $GATEWAY"
log "Table Number: $TABLE_NUMBER"
log "Server: ${WEBSERVER_HOST}:${WEBSERVER_PORT}"
log "Location ID: $LOCATION_ID"
log "Location MD5: $MD5_HASH"
log "Scoreboard URL: $SCOREBOARD_URL"
echo ""

# Function to execute SSH commands
execute_ssh_command() {
    local cmd="$1"
    local description="$2"
    
    info "$description"
    if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CURRENT_IP" "$cmd" 2>/dev/null; then
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
    if echo "$content" | ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CURRENT_IP" "cat > $remote_path" 2>/dev/null; then
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

info "Testing SSH connection to $SSH_USER@$CURRENT_IP:$SSH_PORT..."
if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CURRENT_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    log "✅ SSH connection successful"
else
    error "❌ SSH connection failed"
    exit 1
fi
echo ""

# Step 2: Configure WLAN
log "📡 Step 2: Configuring WLAN"
log "=========================="

# Create wpa_supplicant configuration
WPA_SUPPLICANT_CONFIG="ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE

network={
    ssid=\"${TARGET_SSID}\"
    psk=\"${TARGET_PASSWORD}\"
    key_mgmt=WPA-PSK
    priority=1
}"

upload_file_content "$WPA_SUPPLICANT_CONFIG" "/tmp/wpa_supplicant.conf" "Uploading wpa_supplicant configuration"
execute_ssh_command "sudo mv /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf" "Installing wpa_supplicant configuration"
execute_ssh_command "sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf" "Setting wpa_supplicant permissions"
echo ""

# Step 3: Configure Static IP
log "🌐 Step 3: Configuring Static IP"
log "==============================="

# Detect network management system
info "Detecting network management system..."
NETWORK_MANAGER=$(ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP "systemctl is-active NetworkManager 2>/dev/null || echo inactive")
DHCPCD_SERVICE=$(ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP "systemctl is-active dhcpcd 2>/dev/null || echo inactive")

if [ "$NETWORK_MANAGER" = "active" ]; then
    log "✓ NetworkManager detected - using nmcli for configuration"
    
    # Get current WiFi connection name
    WIFI_CONN=$(ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP "nmcli -t -f NAME,TYPE connection show | grep wireless | head -1 | cut -d: -f1")
    
    if [ -z "$WIFI_CONN" ]; then
        warning "No WiFi connection found, using SSID as connection name"
        WIFI_CONN="$TARGET_SSID"
    fi
    
    info "WiFi connection: $WIFI_CONN"
    
    # Configure static IP using nmcli
    execute_ssh_command "sudo nmcli connection modify '$WIFI_CONN' ipv4.addresses ${STATIC_IP}/24" "Setting static IP"
    execute_ssh_command "sudo nmcli connection modify '$WIFI_CONN' ipv4.gateway ${GATEWAY}" "Setting gateway"
    execute_ssh_command "sudo nmcli connection modify '$WIFI_CONN' ipv4.dns '8.8.8.8 1.1.1.1'" "Setting DNS"
    execute_ssh_command "sudo nmcli connection modify '$WIFI_CONN' ipv4.method manual" "Switching to manual IP configuration"
    
    log "✅ NetworkManager configuration complete"
    
elif [ "$DHCPCD_SERVICE" = "active" ]; then
    log "✓ dhcpcd detected - using dhcpcd.conf for configuration"
    
    # Create dhcpcd configuration for static IP
    DHCPCD_CONFIG="
# Static IP configuration for Table ${TABLE_NUMBER}
interface wlan0
static ip_address=${STATIC_IP}/24
static routers=${GATEWAY}
static domain_name_servers=8.8.8.8 1.1.1.1
"
    
    upload_file_content "$DHCPCD_CONFIG" "/tmp/dhcpcd_static.conf" "Uploading dhcpcd configuration"
    execute_ssh_command "sudo sh -c 'cat /tmp/dhcpcd_static.conf >> /etc/dhcpcd.conf'" "Appending static IP configuration to dhcpcd.conf"
    
    log "✅ dhcpcd configuration complete"
    
else
    warning "⚠️  Could not detect network manager (NetworkManager or dhcpcd)"
    warning "    Trying dhcpcd.conf as fallback..."
    
    # Fallback to dhcpcd configuration
    DHCPCD_CONFIG="
# Static IP configuration for Table ${TABLE_NUMBER}
interface wlan0
static ip_address=${STATIC_IP}/24
static routers=${GATEWAY}
static domain_name_servers=8.8.8.8 1.1.1.1
"
    
    upload_file_content "$DHCPCD_CONFIG" "/tmp/dhcpcd_static.conf" "Uploading dhcpcd configuration"
    execute_ssh_command "sudo sh -c 'cat /tmp/dhcpcd_static.conf >> /etc/dhcpcd.conf'" "Appending static IP configuration to dhcpcd.conf"
fi

echo ""

# Step 4: Install required packages
log "📦 Step 4: Installing Required Packages"
log "======================================"

execute_ssh_command "sudo apt update" "Updating package list"
execute_ssh_command "sudo apt install -y chromium-browser wmctrl xdotool" "Installing packages (chromium, wmctrl, xdotool)"
echo ""

# Step 5: Create autostart script
log "🚀 Step 5: Creating Autostart Script"
log "==================================="

AUTOSTART_SCRIPT='#!/bin/bash
# Carambus Scoreboard Autostart Script for Table '"$TABLE_NUMBER"'

export DISPLAY=:0

# Wait for display to be ready
sleep 5

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Scoreboard URL
SCOREBOARD_URL="'"$SCOREBOARD_URL"'"

echo "Table '"$TABLE_NUMBER"': Using scoreboard URL: $SCOREBOARD_URL"

# Clean up old chromium data
rm -rf /tmp/chromium-scoreboard 2>/dev/null || true

# Start browser in fullscreen
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

# Ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true'

upload_file_content "$AUTOSTART_SCRIPT" "/tmp/autostart-scoreboard.sh" "Uploading autostart script"
execute_ssh_command "chmod +x /tmp/autostart-scoreboard.sh" "Making autostart script executable"
execute_ssh_command "sudo mv /tmp/autostart-scoreboard.sh /usr/local/bin/autostart-scoreboard.sh" "Installing autostart script"
echo ""

# Step 6: Create systemd service
log "⚙️  Step 6: Creating Systemd Service"
log "=================================="

SYSTEMD_SERVICE="[Unit]
Description=Carambus Scoreboard Kiosk - Table ${TABLE_NUMBER}
After=graphical.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SSH_USER
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target"

upload_file_content "$SYSTEMD_SERVICE" "/tmp/scoreboard-kiosk.service" "Uploading systemd service file"
execute_ssh_command "sudo mv /tmp/scoreboard-kiosk.service /etc/systemd/system/scoreboard-kiosk.service" "Installing systemd service file"
execute_ssh_command "sudo systemctl daemon-reload" "Reloading systemd configuration"
execute_ssh_command "sudo systemctl enable scoreboard-kiosk.service" "Enabling scoreboard service for autostart"
echo ""

# Step 7: Verify database configuration
log "💾 Step 7: Verifying Database Configuration"
log "==========================================="

info "Checking if table IP is already configured in database..."
DB_IP=$(cd "$RAILS_APP_DIR" && RAILS_ENV=development bundle exec rails runner "
location = Location.find($LOCATION_ID)
table = location.tables.where(name: ['Tisch $TABLE_NUMBER', 'Table $TABLE_NUMBER']).or(location.tables.where('name LIKE ?', '%$TABLE_NUMBER%')).first
if table && table.table_local
  puts table.ip_address
else
  puts 'MISSING'
end
" 2>/dev/null | tail -1)

if [ "$DB_IP" = "$STATIC_IP" ]; then
  log "✅ Table IP in database matches: $DB_IP"
elif [ "$DB_IP" = "MISSING" ]; then
  warning "⚠️  Table $TABLE_NUMBER or its table_local entry not found in database"
  warning "    The table_locals should be migrated from production database"
else
  warning "⚠️  IP mismatch: Database has $DB_IP, but configuring $STATIC_IP"
  warning "    Consider updating the database or adjusting the static IP"
fi
echo ""

# Step 8: Reboot information
log "🔄 Step 8: Next Steps"
log "===================="
warning "The Raspberry Pi needs to be rebooted to apply network changes."
warning ""
warning "After reboot, the Raspberry Pi will:"
warning "  - Connect to WLAN: $TARGET_SSID"
warning "  - Use static IP: $STATIC_IP"
warning "  - Automatically start the scoreboard for Table $TABLE_NUMBER"
warning ""
info "To reboot now, run:"
echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP 'sudo reboot'"
warning ""
info "After reboot, verify the setup:"
echo "  ping $STATIC_IP"
echo "  ssh -p $SSH_PORT $SSH_USER@$STATIC_IP 'sudo systemctl status scoreboard-kiosk'"
echo ""

# Final success message
log "🎉 SETUP COMPLETED!"
log "=================="
log "Raspberry Pi configured for Table $TABLE_NUMBER"
log ""
log "Configuration Summary:"
log "  - Scenario: $SCENARIO_NAME"
log "  - Table: $TABLE_NUMBER"
log "  - Current IP: $CURRENT_IP"
log "  - Target SSID: $TARGET_SSID"
log "  - Static IP: $STATIC_IP"
log "  - Gateway: $GATEWAY"
log "  - Server: ${WEBSERVER_HOST}:${WEBSERVER_PORT}"
log "  - Location MD5: $MD5_HASH"
log "  - Scoreboard URL: $SCOREBOARD_URL"
log ""
log "⚠️  REMEMBER TO REBOOT THE RASPBERRY PI!"

