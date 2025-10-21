#!/bin/bash
# Simplified Raspberry Pi Table Client Setup with Multi-WLAN Support
# Usage: ./bin/setup-table-raspi.sh <scenario_name> <current_ip> <table_name>
#
# Configuration sources:
#   - Club WLAN: scenarios/<scenario>/config.yml (production.network.club_wlan)
#   - Dev WLAN: ~/.carambus_config (CARAMBUS_DEV_WLAN_*)
#   - Table IP: Database query (table_locals.ip_address)

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

# Show usage
show_usage() {
    echo "Usage: $0 <scenario_name> <current_ip> <table_name>"
    echo ""
    echo "Arguments:"
    echo "  scenario_name    Name of the scenario (e.g., carambus_bcw)"
    echo "  current_ip       Current IP of the Raspberry Pi (e.g., 192.168.178.81)"
    echo "  table_name       Name of the table (e.g., 'Tisch 2' or 'Table 2')"
    echo ""
    echo "Configuration Sources:"
    echo "  Club WLAN:  scenarios/<scenario>/config.yml → production.network.club_wlan"
    echo "  Dev WLAN:   ~/.carambus_config → CARAMBUS_DEV_WLAN_*"
    echo "  Static IP:  Database → table_locals.ip_address for the table"
    echo ""
    echo "Example:"
    echo "  $0 carambus_bcw 192.168.178.81 \"Tisch 2\""
    echo ""
    echo "Before running, ensure:"
    echo "  1. ~/.carambus_config has DEV_WLAN settings (if using dev WLAN)"
    echo "  2. config.yml has club_wlan settings"
    echo "  3. Table exists in database with ip_address in table_local"
}

# Parse arguments
if [ $# -lt 3 ]; then
    error "Missing required arguments"
    show_usage
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

SCENARIO_NAME="$1"
CURRENT_IP="$2"
TABLE_NAME="$3"
SSH_PORT="${4:-22}"
SSH_USER="${5:-pi}"

# Validate CARAMBUS_BASE is set
if [ -z "$CARAMBUS_BASE" ]; then
    error "CARAMBUS_BASE not set. Please configure ~/.carambus_config"
    exit 1
fi

# Load scenario configuration
SCENARIO_CONFIG="$SCENARIOS_PATH/$SCENARIO_NAME/config.yml"
if [ ! -f "$SCENARIO_CONFIG" ]; then
    error "Scenario configuration not found: $SCENARIO_CONFIG"
    exit 1
fi

log "🚀 Raspberry Pi Table Client Setup"
log "=================================="
log "Scenario: $SCENARIO_NAME"
log "Current IP: $CURRENT_IP"
log "Table: $TABLE_NAME"
echo ""

# Step 1: Load configuration from various sources
log "📋 Step 1: Loading Configuration"
log "==============================="

# 1a. Load from ~/.carambus_config (dev WLAN)
if [ -f "$HOME/.carambus_config" ]; then
    source "$HOME/.carambus_config"
    if [ -n "$CARAMBUS_DEV_WLAN_SSID" ]; then
        DEV_WLAN_SSID="$CARAMBUS_DEV_WLAN_SSID"
        DEV_WLAN_PASSWORD="$CARAMBUS_DEV_WLAN_PASSWORD"
        DEV_WLAN_PRIORITY="${CARAMBUS_DEV_WLAN_PRIORITY:-10}"
        log "✓ Dev WLAN loaded from ~/.carambus_config: $DEV_WLAN_SSID"
    else
        warning "Dev WLAN not configured in ~/.carambus_config (optional)"
        DEV_WLAN_SSID=""
    fi
else
    warning "~/.carambus_config not found (dev WLAN will not be configured)"
    DEV_WLAN_SSID=""
fi

# 1b. Load from config.yml (club WLAN) using Ruby
CLUB_WLAN_SSID=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'network', 'club_wlan', 'ssid') || ''
")

CLUB_WLAN_PASSWORD=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'network', 'club_wlan', 'password') || ''
")

CLUB_WLAN_PRIORITY=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'network', 'club_wlan', 'priority') || '20'
")

CLUB_GATEWAY=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'network', 'club_wlan', 'gateway') || '192.168.2.1'
")

if [ -n "$CLUB_WLAN_SSID" ]; then
    log "✓ Club WLAN loaded from config.yml: $CLUB_WLAN_SSID"
else
    error "Club WLAN not configured in config.yml"
    exit 1
fi

# 1c. Get table IP from database
info "Querying database for table IP address..."
LOCATION_ID=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('scenario', 'location_id')
")

TABLE_IP=$(cd "$RAILS_APP_DIR" && RAILS_ENV=development bundle exec rails runner "
location = Location.find($LOCATION_ID)
table = location.tables.where('name LIKE ?', '%$TABLE_NAME%').or(
  location.tables.where(name: '$TABLE_NAME')
).first

if table && table.table_local && table.table_local.ip_address.present?
  puts table.table_local.ip_address
else
  puts 'NOT_FOUND'
end
" 2>/dev/null | tail -1)

if [ "$TABLE_IP" = "NOT_FOUND" ] || [ -z "$TABLE_IP" ]; then
    error "Table '$TABLE_NAME' not found or has no IP address in table_local"
    error "Please ensure the table exists in the database with ip_address set"
    exit 1
fi

log "✓ Table IP from database: $TABLE_IP"

# 1d. Extract other config
WEBSERVER_HOST=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'webserver_host')
")

WEBSERVER_PORT=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'webserver_port')
")

log "✓ Server: $WEBSERVER_HOST:$WEBSERVER_PORT"
echo ""

# Step 2: Test SSH connection
log "🔌 Step 2: Testing SSH Connection"
log "================================"

info "Testing SSH connection to $SSH_USER@$CURRENT_IP:$SSH_PORT..."
if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$CURRENT_IP" "echo 'SSH OK'" 2>/dev/null; then
    log "✅ SSH connection successful"
else
    error "❌ SSH connection failed"
    exit 1
fi
echo ""

# Step 3: Configure Multi-WLAN
log "📡 Step 3: Configuring Multi-WLAN"
log "================================"

# Build wpa_supplicant.conf with multiple networks
WPA_SUPPLICANT_CONFIG="ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=DE
"

# Add dev WLAN if configured (DHCP)
if [ -n "$DEV_WLAN_SSID" ]; then
    info "Adding Dev WLAN: $DEV_WLAN_SSID (DHCP, priority $DEV_WLAN_PRIORITY)"
    WPA_SUPPLICANT_CONFIG+="
# Development WLAN (DHCP)
network={
    ssid=\"$DEV_WLAN_SSID\"
    psk=\"$DEV_WLAN_PASSWORD\"
    key_mgmt=WPA-PSK
    priority=$DEV_WLAN_PRIORITY
}
"
fi

# Add club WLAN (static IP will be configured separately)
info "Adding Club WLAN: $CLUB_WLAN_SSID (Static IP: $TABLE_IP, priority $CLUB_WLAN_PRIORITY)"
WPA_SUPPLICANT_CONFIG+="
# Club WLAN (Static IP)
network={
    ssid=\"$CLUB_WLAN_SSID\"
    psk=\"$CLUB_WLAN_PASSWORD\"
    key_mgmt=WPA-PSK
    priority=$CLUB_WLAN_PRIORITY
}
"

# Upload wpa_supplicant.conf
echo "$WPA_SUPPLICANT_CONFIG" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/wpa_supplicant.conf" 2>/dev/null
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf" 2>/dev/null
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf" 2>/dev/null
log "✅ Multi-WLAN configuration uploaded"
echo ""

# Step 4: Configure Static IP for Club WLAN
log "🌐 Step 4: Configuring Static IP"
log "==============================="

# Detect network management system
info "Detecting network management system..."
NETWORK_MANAGER=$(ssh -p $SSH_PORT "$SSH_USER@$CURRENT_IP" "systemctl is-active NetworkManager 2>/dev/null || echo inactive")

if [ "$NETWORK_MANAGER" = "active" ]; then
    log "✓ NetworkManager detected - using nmcli"
    
    # Create or modify connection for club WLAN
    info "Configuring static IP for club WLAN: $CLUB_WLAN_SSID"
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "
        # Check if connection already exists
        if sudo nmcli connection show '$CLUB_WLAN_SSID' >/dev/null 2>&1; then
            echo 'Modifying existing connection'
            sudo nmcli connection modify '$CLUB_WLAN_SSID' ipv4.addresses ${TABLE_IP}/24
            sudo nmcli connection modify '$CLUB_WLAN_SSID' ipv4.gateway $CLUB_GATEWAY
            sudo nmcli connection modify '$CLUB_WLAN_SSID' ipv4.dns '8.8.8.8 1.1.1.1'
            sudo nmcli connection modify '$CLUB_WLAN_SSID' ipv4.method manual
        else
            echo 'Creating new connection'
            sudo nmcli connection add \
                type wifi \
                con-name '$CLUB_WLAN_SSID' \
                ifname wlan0 \
                ssid '$CLUB_WLAN_SSID' \
                wifi-sec.key-mgmt wpa-psk \
                wifi-sec.psk '$CLUB_WLAN_PASSWORD' \
                ipv4.addresses ${TABLE_IP}/24 \
                ipv4.gateway $CLUB_GATEWAY \
                ipv4.dns '8.8.8.8 1.1.1.1' \
                ipv4.method manual
        fi
        
        # Configure dev WLAN with DHCP (if provided)
        if [ -n '$DEV_WLAN_SSID' ]; then
            if sudo nmcli connection show '$DEV_WLAN_SSID' >/dev/null 2>&1; then
                echo 'Dev WLAN connection exists'
            else
                echo 'Creating dev WLAN connection with DHCP'
                sudo nmcli connection add \
                    type wifi \
                    con-name '$DEV_WLAN_SSID' \
                    ifname wlan0 \
                    ssid '$DEV_WLAN_SSID' \
                    wifi-sec.key-mgmt wpa-psk \
                    wifi-sec.psk '$DEV_WLAN_PASSWORD' \
                    ipv4.method auto
            fi
        fi
    " 2>/dev/null
    
    log "✅ NetworkManager configuration complete"
else
    # dhcpcd configuration
    log "✓ dhcpcd detected - using dhcpcd.conf"
    
    # For dhcpcd, we use SSID-specific configuration via wpa_cli hooks
    # Static IP is applied when connected to club SSID
    DHCPCD_HOOK="#!/bin/bash
# DHCP hook for SSID-specific configuration

if [ \"\$interface\" = \"wlan0\" ] && [ \"\$reason\" = \"BOUND\" ]; then
    CURRENT_SSID=\$(iwgetid -r)
    
    if [ \"\$CURRENT_SSID\" = \"$CLUB_WLAN_SSID\" ]; then
        # Club WLAN - apply static IP
        echo \"Applying static IP for club WLAN: $TABLE_IP\"
        sudo ip addr flush dev wlan0
        sudo ip addr add ${TABLE_IP}/24 dev wlan0
        sudo ip route add default via $CLUB_GATEWAY
        echo \"nameserver 8.8.8.8\" | sudo tee /etc/resolv.conf > /dev/null
    fi
fi
"
    echo "$DHCPCD_HOOK" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/dhcp-ssid-hook" 2>/dev/null
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/dhcp-ssid-hook /etc/dhcpcd.exit-hook && sudo chmod +x /etc/dhcpcd.exit-hook" 2>/dev/null
    
    log "✅ dhcpcd configuration complete"
fi
echo ""

# Step 5: Install scoreboard client
log "📦 Step 5: Installing Scoreboard Client"
log "======================================"

info "Installing required packages..."
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo apt-get update -qq && sudo apt-get install -y chromium wmctrl xdotool 2>&1 | grep -E '(upgraded|installed)'" 2>/dev/null || true
log "✅ Packages installed"
echo ""

# Step 6: Get Location MD5 and create autostart script
log "🔧 Step 6: Creating Autostart Configuration"
log "=========================================="

info "Getting location MD5 hash from database..."
LOCATION_MD5=$(cd "$RAILS_APP_DIR" && RAILS_ENV=development bundle exec rails runner "
location = Location.find($LOCATION_ID)
puts location.md5
" 2>/dev/null | tail -1)

if [ -z "$LOCATION_MD5" ]; then
    error "Failed to get location MD5 hash"
    exit 1
fi

log "✓ Location MD5: $LOCATION_MD5"

# Create autostart script
SCOREBOARD_URL="http://$WEBSERVER_HOST:$WEBSERVER_PORT/locations/$LOCATION_MD5/scoreboard?sb_state=welcome"
info "Scoreboard URL: $SCOREBOARD_URL"

AUTOSTART_SCRIPT='#!/bin/bash
# Carambus Scoreboard Autostart for Table Client
export DISPLAY=:0

# Find X authority
for auth_file in /home/pi/.Xauthority /home/*/. Xauthority /run/user/*/gdm/Xauthority /run/user/1000/.Xauthority; do
    if [ -f "$auth_file" ]; then
        export XAUTHORITY="$auth_file"
        echo "Using X11 authority: $auth_file"
        break
    fi
done

xhost +local: 2>/dev/null || true

# Wait for display
sleep 5

# Hide panels
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Short wait for remote server
echo "Remote server mode - starting browser"
sleep 2

SCOREBOARD_URL="'"$SCOREBOARD_URL"'"
echo "Loading: $SCOREBOARD_URL"

# Clean browser profile
CHROMIUM_USER_DIR="/tmp/chromium-scoreboard-$USER"
rm -rf "$CHROMIUM_USER_DIR" 2>/dev/null || true
mkdir -p "$CHROMIUM_USER_DIR"
chmod 755 "$CHROMIUM_USER_DIR"

# Detect chromium command
BROWSER_CMD=""
if command -v chromium >/dev/null 2>&1; then
  BROWSER_CMD="chromium"
elif command -v chromium-browser >/dev/null 2>&1; then
  BROWSER_CMD="chromium-browser"
else
  echo "❌ Chromium not found!"
  exit 1
fi

echo "Starting: $BROWSER_CMD"
$BROWSER_CMD \
  --start-fullscreen \
  --app="$SCOREBOARD_URL" \
  --disable-restore-session-state \
  --user-data-dir="$CHROMIUM_USER_DIR" \
  --disable-features=VizDisplayCompositor,TranslateUI \
  --disable-dev-shm-usage \
  --disable-setuid-sandbox \
  --disable-gpu \
  --disable-infobars \
  --noerrdialogs \
  --no-first-run \
  --disable-session-crashed-bubble \
  --check-for-update-interval=31536000 \
  --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \
  >>/tmp/chromium-kiosk.log 2>&1 &

BROWSER_PID=$!
echo "Browser started (PID: $BROWSER_PID)"

# Ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true

# Keep running
while true; do
  sleep 1
done
'

# Upload autostart script
echo "$AUTOSTART_SCRIPT" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/autostart-scoreboard.sh" 2>/dev/null
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/autostart-scoreboard.sh /usr/local/bin/autostart-scoreboard.sh && sudo chmod +x /usr/local/bin/autostart-scoreboard.sh" 2>/dev/null
log "✅ Autostart script installed"
echo ""

# Step 7: Create systemd service
log "⚙️  Step 7: Setting up Systemd Service"
log "====================================="

SYSTEMD_SERVICE="[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SSH_USER
Environment=\"DISPLAY=:0\"
ExecStart=/usr/local/bin/autostart-scoreboard.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
"

echo "$SYSTEMD_SERVICE" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/scoreboard-kiosk.service" 2>/dev/null
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/scoreboard-kiosk.service /etc/systemd/system/scoreboard-kiosk.service" 2>/dev/null
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo systemctl daemon-reload && sudo systemctl enable scoreboard-kiosk && sudo systemctl start scoreboard-kiosk" 2>/dev/null
log "✅ Systemd service enabled and started"
echo ""

# Step 8: Summary and next steps
log "🎉 SETUP COMPLETED!"
log "=================="
log ""
log "Configuration Summary:"
log "  Scenario: $SCENARIO_NAME"
log "  Table: $TABLE_NAME"
log "  Current IP: $CURRENT_IP"
log "  Club Static IP: $TABLE_IP"
if [ -n "$DEV_WLAN_SSID" ]; then
log "  Dev WLAN: $DEV_WLAN_SSID (DHCP, priority $DEV_WLAN_PRIORITY)"
fi
log "  Club WLAN: $CLUB_WLAN_SSID (Static, priority $CLUB_WLAN_PRIORITY)"
log "  Server: $WEBSERVER_HOST:$WEBSERVER_PORT"
log ""
warning "⚠️  IMPORTANT: To test in club, the Raspberry Pi needs to be rebooted"
warning "    After reboot, it will connect to the available WLAN automatically:"
warning "    - In office: $DEV_WLAN_SSID with DHCP"
warning "    - In club: $CLUB_WLAN_SSID with static IP $TABLE_IP"
echo ""
info "To reboot now:"
echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP 'sudo reboot'"
echo ""
info "To verify after reboot:"
echo "  ping $TABLE_IP"
echo "  ssh -p $SSH_PORT $SSH_USER@$TABLE_IP 'sudo systemctl status scoreboard-kiosk'"
echo ""

log "✅ Multi-WLAN table client ready for deployment!"

