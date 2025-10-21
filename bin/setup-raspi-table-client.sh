#!/bin/bash
# Complete Raspberry Pi Table Client Setup Script
# Configures multiple WLANs (dev + customer), static IP, and installs scoreboard client
# Usage: ./bin/setup-raspi-table-client.sh <scenario_name> <current_ip> <table_number> [options]

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

# Default values
SCENARIO_NAME=""
CURRENT_IP=""
TABLE_NUMBER=""
SSH_PORT="22"
SSH_USER="pi"

# WLAN configurations (can be overridden via command line)
DEV_SSID="MeinHomeWLAN"
DEV_PASSWORD=""
DEV_PRIORITY="10"
DEV_IP_METHOD="auto"  # DHCP for development

CUSTOMER_SSID=""
CUSTOMER_PASSWORD=""
CUSTOMER_PRIORITY="20"  # Higher priority - preferred when available
CUSTOMER_STATIC_IP=""

show_usage() {
    echo "Usage: $0 <scenario_name> <current_ip> <table_number> [options]"
    echo ""
    echo "Required Arguments:"
    echo "  scenario_name      Name of the scenario (e.g., carambus_bcw)"
    echo "  current_ip         Current IP address of the Raspberry Pi"
    echo "  table_number       Table number (e.g., 4)"
    echo ""
    echo "Options:"
    echo "  --dev-ssid SSID          Development WLAN SSID"
    echo "  --dev-password PWD       Development WLAN password"
    echo "  --dev-priority NUM       Development WLAN priority (default: 10)"
    echo ""
    echo "  --customer-ssid SSID     Customer WLAN SSID (required)"
    echo "  --customer-password PWD  Customer WLAN password (required)"
    echo "  --customer-ip IP         Static IP for customer WLAN (required)"
    echo "  --customer-priority NUM  Customer WLAN priority (default: 20)"
    echo ""
    echo "  --ssh-port PORT          SSH port (default: 22)"
    echo "  --ssh-user USER          SSH username (default: pi)"
    echo ""
    echo "Examples:"
    echo "  # With dev and customer WLAN:"
    echo "  $0 carambus_bcw 192.168.178.81 4 \\"
    echo "    --dev-ssid \"HomeWLAN\" --dev-password \"home123\" \\"
    echo "    --customer-ssid \"WLAN-15AE35\" --customer-password \"cust456\" \\"
    echo "    --customer-ip 192.168.2.214"
    echo ""
    echo "  # Customer WLAN only:"
    echo "  $0 carambus_bcw 192.168.2.134 4 \\"
    echo "    --customer-ssid \"WLAN-15AE35\" --customer-password \"cust456\" \\"
    echo "    --customer-ip 192.168.2.214"
}

# Parse arguments
if [ $# -lt 3 ]; then
    error "Missing required arguments"
    show_usage
    exit 1
fi

# Check for help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

SCENARIO_NAME="$1"
CURRENT_IP="$2"
TABLE_NUMBER="$3"
shift 3

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dev-ssid)
            DEV_SSID="$2"
            shift 2
            ;;
        --dev-password)
            DEV_PASSWORD="$2"
            shift 2
            ;;
        --dev-priority)
            DEV_PRIORITY="$2"
            shift 2
            ;;
        --customer-ssid)
            CUSTOMER_SSID="$2"
            shift 2
            ;;
        --customer-password)
            CUSTOMER_PASSWORD="$2"
            shift 2
            ;;
        --customer-ip)
            CUSTOMER_STATIC_IP="$2"
            shift 2
            ;;
        --customer-priority)
            CUSTOMER_PRIORITY="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$SCENARIO_NAME" ] || [ -z "$CURRENT_IP" ] || [ -z "$TABLE_NUMBER" ]; then
    error "Missing required arguments"
    show_usage
    exit 1
fi

if [ -z "$CUSTOMER_SSID" ] || [ -z "$CUSTOMER_PASSWORD" ] || [ -z "$CUSTOMER_STATIC_IP" ]; then
    error "Customer WLAN configuration is required (--customer-ssid, --customer-password, --customer-ip)"
    show_usage
    exit 1
fi

# Load scenario configuration
SCENARIO_CONFIG="$SCENARIOS_PATH/$SCENARIO_NAME/config.yml"
if [ ! -f "$SCENARIO_CONFIG" ]; then
    error "Scenario configuration not found: $SCENARIO_CONFIG"
    exit 1
fi

# Extract configuration values
WEBSERVER_HOST=$(grep -A 20 "production:" "$SCENARIO_CONFIG" | grep "webserver_host:" | head -1 | awk '{print $2}')
WEBSERVER_PORT=$(grep -A 20 "production:" "$SCENARIO_CONFIG" | grep "webserver_port:" | head -1 | awk '{print $2}')
LOCATION_ID=$(grep "location_id:" "$SCENARIO_CONFIG" | head -1 | awk '{print $2}')

if [ -z "$WEBSERVER_HOST" ] || [ -z "$WEBSERVER_PORT" ] || [ -z "$LOCATION_ID" ]; then
    error "Failed to extract required configuration from $SCENARIO_CONFIG"
    exit 1
fi

# Calculate gateway from static IP
IFS='.' read -r -a ip_parts <<< "$CUSTOMER_STATIC_IP"
GATEWAY="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.1"

# Get MD5 hash from Rails application
RAILS_APP_DIR=""
if [ -d "$CARAMBUS_BASE/${SCENARIO_NAME}" ]; then
    RAILS_APP_DIR="$CARAMBUS_BASE/${SCENARIO_NAME}"
elif [ -d "$CARAMBUS_MASTER" ]; then
    RAILS_APP_DIR="$CARAMBUS_MASTER"
else
    error "Could not find Rails application directory"
    exit 1
fi

info "Getting location MD5 hash from database..."
MD5_HASH=$(cd "$RAILS_APP_DIR" && RAILS_ENV=development bundle exec rails runner "puts Location.find($LOCATION_ID).md5" 2>/dev/null | tail -1)

if [ -z "$MD5_HASH" ] || [[ "$MD5_HASH" == *"Error"* ]]; then
    error "Failed to get MD5 hash for location $LOCATION_ID"
    exit 1
fi

# Generate scoreboard URL
SCOREBOARD_URL="http://${WEBSERVER_HOST}:${WEBSERVER_PORT}/locations/${MD5_HASH}?sb_state=welcome"

log "🎯 Raspberry Pi Multi-WLAN Table Client Setup"
log "=============================================="
log "Scenario: $SCENARIO_NAME"
log "Current IP: $CURRENT_IP"
log "Table Number: $TABLE_NUMBER"
log ""
log "Development WLAN:"
if [ -n "$DEV_PASSWORD" ]; then
    log "  SSID: $DEV_SSID"
    log "  Priority: $DEV_PRIORITY"
    log "  IP: DHCP"
else
    log "  Not configured (skip with empty password)"
fi
log ""
log "Customer WLAN:"
log "  SSID: $CUSTOMER_SSID"
log "  Priority: $CUSTOMER_PRIORITY"
log "  Static IP: $CUSTOMER_STATIC_IP"
log "  Gateway: $GATEWAY"
log ""
log "Server: ${WEBSERVER_HOST}:${WEBSERVER_PORT}"
log "Location ID: $LOCATION_ID"
log "Location MD5: $MD5_HASH"
log "Scoreboard URL: $SCOREBOARD_URL"
echo ""

# Function to execute SSH commands
execute_ssh_command() {
    local cmd="$1"
    local description="$2"
    
    if [ -n "$description" ]; then
        info "$description"
    fi
    
    if ssh -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$CURRENT_IP "$cmd" 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to upload file content
upload_file_content() {
    local content="$1"
    local remote_path="$2"
    local description="$3"
    
    if [ -n "$description" ]; then
        info "$description"
    fi
    
    echo "$content" | ssh -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$CURRENT_IP "cat > $remote_path"
}

# Test SSH connection
log "🔌 Step 1: Testing SSH Connection"
log "================================="
if execute_ssh_command "echo 'SSH OK'" "Testing SSH connection to $CURRENT_IP:$SSH_PORT"; then
    log "✅ SSH connection successful"
else
    error "SSH connection failed"
    exit 1
fi
echo ""

# Detect network management system
log "🌐 Step 2: Detecting Network Manager"
log "===================================="
NETWORK_MANAGER=$(ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP "systemctl is-active NetworkManager 2>/dev/null || echo inactive")
DHCPCD_SERVICE=$(ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP "systemctl is-active dhcpcd 2>/dev/null || echo inactive")

if [ "$NETWORK_MANAGER" = "active" ]; then
    log "✓ NetworkManager detected - using nmcli for configuration"
    USING_NETWORK_MANAGER=true
elif [ "$DHCPCD_SERVICE" = "active" ]; then
    log "✓ dhcpcd detected - using wpa_supplicant + dhcpcd.conf"
    USING_NETWORK_MANAGER=false
else
    warning "⚠️  Could not detect network manager - trying NetworkManager as default"
    USING_NETWORK_MANAGER=true
fi
echo ""

# Configure WLAN networks
log "📶 Step 3: Configuring WLAN Networks"
log "===================================="

if [ "$USING_NETWORK_MANAGER" = true ]; then
    # NetworkManager configuration
    
    # Configure development WLAN (if password provided)
    if [ -n "$DEV_PASSWORD" ]; then
        info "Configuring development WLAN: $DEV_SSID"
        
        # Delete if exists
        execute_ssh_command "sudo nmcli connection delete 'dev_wlan' 2>/dev/null || true" "Removing old dev WLAN connection"
        
        # Create new connection
        execute_ssh_command "sudo nmcli connection add \
          type wifi \
          ifname wlan0 \
          con-name 'dev_wlan' \
          ssid '$DEV_SSID' \
          wifi-sec.key-mgmt wpa-psk \
          wifi-sec.psk '$DEV_PASSWORD'" "Creating development WLAN connection"
        
        # Set priority and auto-connect
        execute_ssh_command "sudo nmcli connection modify 'dev_wlan' connection.autoconnect-priority $DEV_PRIORITY" "Setting dev WLAN priority"
        execute_ssh_command "sudo nmcli connection modify 'dev_wlan' connection.autoconnect yes" "Enabling dev WLAN auto-connect"
        execute_ssh_command "sudo nmcli connection modify 'dev_wlan' ipv4.method auto" "Setting dev WLAN to DHCP"
        
        log "✅ Development WLAN configured (DHCP, priority: $DEV_PRIORITY)"
    else
        info "Skipping development WLAN (no password provided)"
    fi
    
    # Configure customer WLAN (always required)
    info "Configuring customer WLAN: $CUSTOMER_SSID"
    
    # Delete if exists
    execute_ssh_command "sudo nmcli connection delete 'customer_wlan' 2>/dev/null || true" "Removing old customer WLAN connection"
    
    # Create new connection
    execute_ssh_command "sudo nmcli connection add \
      type wifi \
      ifname wlan0 \
      con-name 'customer_wlan' \
      ssid '$CUSTOMER_SSID' \
      wifi-sec.key-mgmt wpa-psk \
      wifi-sec.psk '$CUSTOMER_PASSWORD'" "Creating customer WLAN connection"
    
    # Set static IP
    execute_ssh_command "sudo nmcli connection modify 'customer_wlan' ipv4.addresses ${CUSTOMER_STATIC_IP}/24" "Setting static IP"
    execute_ssh_command "sudo nmcli connection modify 'customer_wlan' ipv4.gateway ${GATEWAY}" "Setting gateway"
    execute_ssh_command "sudo nmcli connection modify 'customer_wlan' ipv4.dns '8.8.8.8 1.1.1.1'" "Setting DNS"
    execute_ssh_command "sudo nmcli connection modify 'customer_wlan' ipv4.method manual" "Switching to manual IP"
    
    # Set priority and auto-connect
    execute_ssh_command "sudo nmcli connection modify 'customer_wlan' connection.autoconnect-priority $CUSTOMER_PRIORITY" "Setting customer WLAN priority"
    execute_ssh_command "sudo nmcli connection modify 'customer_wlan' connection.autoconnect yes" "Enabling customer WLAN auto-connect"
    
    log "✅ Customer WLAN configured (Static IP: $CUSTOMER_STATIC_IP, priority: $CUSTOMER_PRIORITY)"
    
    # Remove preconfigured connection if exists
    execute_ssh_command "sudo nmcli connection delete 'preconfigured' 2>/dev/null || true" "Removing preconfigured connection"
    
else
    # dhcpcd configuration (legacy)
    warning "⚠️  dhcpcd detected - this is legacy mode. Consider upgrading to newer Raspberry Pi OS with NetworkManager"
    
    # Configure wpa_supplicant with multiple networks
    WPA_SUPPLICANT_CONFIG="country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
"
    
    if [ -n "$DEV_PASSWORD" ]; then
        WPA_SUPPLICANT_CONFIG+="
# Development WLAN
network={
    ssid=\"$DEV_SSID\"
    psk=\"$DEV_PASSWORD\"
    key_mgmt=WPA-PSK
    priority=$DEV_PRIORITY
}
"
    fi
    
    WPA_SUPPLICANT_CONFIG+="
# Customer WLAN
network={
    ssid=\"$CUSTOMER_SSID\"
    psk=\"$CUSTOMER_PASSWORD\"
    key_mgmt=WPA-PSK
    priority=$CUSTOMER_PRIORITY
}
"
    
    upload_file_content "$WPA_SUPPLICANT_CONFIG" "/tmp/wpa_supplicant.conf" "Uploading wpa_supplicant configuration"
    execute_ssh_command "sudo mv /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf" "Installing wpa_supplicant configuration"
    execute_ssh_command "sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf" "Setting wpa_supplicant permissions"
    
    # Configure static IP for customer WLAN only
    DHCPCD_CONFIG="
# Static IP configuration for Table ${TABLE_NUMBER} (Customer WLAN only)
interface wlan0
# Check which SSID we're connected to
sssid $CUSTOMER_SSID
static ip_address=${CUSTOMER_STATIC_IP}/24
static routers=${GATEWAY}
static domain_name_servers=8.8.8.8 1.1.1.1
"
    
    upload_file_content "$DHCPCD_CONFIG" "/tmp/dhcpcd_static.conf" "Uploading dhcpcd configuration"
    execute_ssh_command "sudo sh -c 'cat /tmp/dhcpcd_static.conf >> /etc/dhcpcd.conf'" "Appending static IP configuration to dhcpcd.conf"
    
    log "✅ WLAN networks configured via wpa_supplicant + dhcpcd"
fi
echo ""

# Install required packages
log "📦 Step 4: Installing Required Packages"
log "======================================"
execute_ssh_command "sudo apt update" "Updating package list"
execute_ssh_command "sudo apt install -y chromium-browser wmctrl xdotool || sudo apt install -y chromium wmctrl xdotool" "Installing packages (chromium, wmctrl, xdotool)"
echo ""

# Create autostart script
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
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --no-first-run \
  --check-for-update-interval=31536000 \
  --user-data-dir=/tmp/chromium-scoreboard \
  "$SCOREBOARD_URL" &

BROWSER_PID=$!
echo "Browser started with PID: $BROWSER_PID"

# Wait for browser
wait $BROWSER_PID
'

upload_file_content "$AUTOSTART_SCRIPT" "/tmp/autostart-scoreboard.sh" "Uploading autostart script"
execute_ssh_command "sudo mv /tmp/autostart-scoreboard.sh /usr/local/bin/autostart-scoreboard.sh" "Installing autostart script"
execute_ssh_command "sudo chmod +x /usr/local/bin/autostart-scoreboard.sh" "Making autostart script executable"
log "✅ Autostart script created"
echo ""

# Create systemd service
log "⚙️  Step 6: Creating Systemd Service"
log "==================================="

SYSTEMD_SERVICE="[Unit]
Description=Carambus Scoreboard Kiosk for Table $TABLE_NUMBER
After=graphical.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
"

upload_file_content "$SYSTEMD_SERVICE" "/tmp/scoreboard-kiosk.service" "Uploading systemd service"
execute_ssh_command "sudo mv /tmp/scoreboard-kiosk.service /etc/systemd/system/scoreboard-kiosk.service" "Installing systemd service"
execute_ssh_command "sudo systemctl daemon-reload" "Reloading systemd"
execute_ssh_command "sudo systemctl enable scoreboard-kiosk.service" "Enabling scoreboard-kiosk service"
log "✅ Systemd service created and enabled"
echo ""

# Final information
log "🔄 Step 7: Next Steps"
log "===================="
warning "The Raspberry Pi needs to be rebooted to apply all changes."
warning ""
warning "After reboot, the Raspberry Pi will:"
if [ -n "$DEV_PASSWORD" ]; then
warning "  - Try to connect to: $DEV_SSID (DHCP, priority: $DEV_PRIORITY)"
fi
warning "  - Prefer to connect to: $CUSTOMER_SSID (Static IP: $CUSTOMER_STATIC_IP, priority: $CUSTOMER_PRIORITY)"
warning "  - Automatically start the scoreboard for Table $TABLE_NUMBER"
warning ""
info "To reboot now, run:"
echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP 'sudo reboot'"
warning ""
info "After reboot, the Pi will be accessible at:"
echo "  - Customer network: ssh -p $SSH_PORT $SSH_USER@$CUSTOMER_STATIC_IP"
if [ -n "$DEV_PASSWORD" ]; then
echo "  - Dev network: Check your router for DHCP-assigned IP"
fi
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
if [ -n "$DEV_PASSWORD" ]; then
log "  - Dev WLAN: $DEV_SSID (DHCP, priority: $DEV_PRIORITY)"
fi
log "  - Customer WLAN: $CUSTOMER_SSID (Static IP: $CUSTOMER_STATIC_IP, priority: $CUSTOMER_PRIORITY)"
log "  - Gateway: $GATEWAY"
log "  - Server: ${WEBSERVER_HOST}:${WEBSERVER_PORT}"
log "  - Scoreboard URL: $SCOREBOARD_URL"
log ""
log "Multi-WLAN Feature: The Pi will automatically connect to the available network"
log "with the highest priority. Perfect for development and deployment!"
