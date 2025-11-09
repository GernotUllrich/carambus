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
    echo "Usage: $0 <scenario_name> <current_ip> <table_name|server>"
    echo ""
    echo "Arguments:"
    echo "  scenario_name    Name of the scenario (e.g., carambus_bcw)"
    echo "  current_ip       Current IP of the Raspberry Pi (e.g., 192.168.178.81)"
    echo "  table_name       Name of the table (e.g., 'Tisch 2' or 'Table 2')"
    echo "                   Use 'server' for server deployment (club WLAN uses DHCP)"
    echo ""
    echo "Configuration Sources:"
    echo "  Club WLAN:  scenarios/<scenario>/config.yml → production.network.club_wlan"
    echo "  Dev WLAN:   ~/.carambus_config → CARAMBUS_DEV_WLAN_*"
    echo "  Static IP:  Database → table_locals.ip_address for the table"
    echo "              (Not used for server mode - uses DHCP)"
    echo ""
    echo "Examples:"
    echo "  # Table client with static IP:"
    echo "  $0 carambus_bcw 192.168.178.81 \"Tisch 2\""
    echo ""
    echo "  # Server deployment with DHCP:"
    echo "  $0 carambus_phat 192.168.178.63 server"
    echo ""
    echo "Before running, ensure:"
    echo "  1. ~/.carambus_config has DEV_WLAN settings (if using dev WLAN)"
    echo "  2. config.yml has club_wlan settings"
    echo "  3. For table clients: Table exists in database with ip_address in table_local"
    echo "  4. For servers: config.yml has raspberry_pi_client.local_server_enabled: true"
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
SSH_PORT_ARG="${4:-}"
SSH_USER_ARG="${5:-}"
KIOSK=""

# Set defaults (will be overridden from config.yml for server mode)
SSH_PORT="${SSH_PORT_ARG:-22}"
SSH_USER="${SSH_USER_ARG:-pi}"

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

# 1c. Check if this is a server setup (not a table client)
LOCATION_ID=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('scenario', 'location_id')
")

IS_SERVER=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'raspberry_pi_client', 'local_server_enabled') == true ? 'yes' : 'no'
" 2>/dev/null || echo "no")

# Check if table_name is "server" or empty (server mode)
if [ "$TABLE_NAME" = "server" ] || [ -z "$TABLE_NAME" ] || [ "$IS_SERVER" = "yes" ]; then
    SERVER_MODE=true
    log "✓ Server mode detected - club WLAN will use DHCP"
    TABLE_IP=""  # No static IP for server
    
    # Get SSH port from config.yml for server mode (if not explicitly provided)
    if [ -z "$SSH_PORT_ARG" ]; then
        CONFIG_SSH_PORT=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'raspberry_pi_client', 'ssh_port') || config.dig('environments', 'production', 'ssh_port') || '22'
" 2>/dev/null || echo "22")
        SSH_PORT="$CONFIG_SSH_PORT"
        if [ "$CONFIG_SSH_PORT" != "22" ]; then
            log "✓ SSH port from config.yml: $SSH_PORT"
        fi
    fi
    
    # Get SSH user from config.yml for server mode (if not explicitly provided)
    if [ -z "$SSH_USER_ARG" ]; then
        CONFIG_SSH_USER=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'raspberry_pi_client', 'ssh_user') || 'pi'
" 2>/dev/null || echo "pi")
        SSH_USER="$CONFIG_SSH_USER"
        if [ "$CONFIG_SSH_USER" != "pi" ]; then
            log "✓ SSH user from config.yml: $SSH_USER"
        fi
    fi
    
    # Get kiosk user from config.yml (for desktop operations)
    KIOSK_USER=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'raspberry_pi_client', 'kiosk_user') || 'pi'
" 2>/dev/null || echo "pi")
    if [ "$KIOSK_USER" != "pi" ]; then
        log "✓ Kiosk user from config.yml: $KIOSK_USER"
    fi
else
    SERVER_MODE=false
    # Get kiosk user from config.yml (for desktop operations, default to pi)
    KIOSK_USER="pi"
    
    # Get table IP from database
    info "Querying database for table IP address..."
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
fi

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

# Step 3: Detect network management system
log "🌐 Step 3: Detecting Network Management System"
log "=============================================="

info "Detecting network management system..."
NETWORK_MANAGER=$(ssh -p $SSH_PORT "$SSH_USER@$CURRENT_IP" "systemctl is-active NetworkManager 2>/dev/null || echo inactive")

if [ "$NETWORK_MANAGER" = "active" ]; then
    log "✓ NetworkManager detected - using nmcli"
    USING_NETWORK_MANAGER=true
else
    log "✓ dhcpcd detected - using wpa_supplicant + dhcpcd.conf"
    USING_NETWORK_MANAGER=false
fi
echo ""

# Step 4: Configure Multi-WLAN
log "📡 Step 4: Configuring Multi-WLAN"
log "================================"

if [ "$USING_NETWORK_MANAGER" = true ]; then
    # NetworkManager configuration
    
    # Disable/remove old preconfigured connection
    info "Removing old 'preconfigured' connection..."
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection delete 'preconfigured' 2>/dev/null || sudo nmcli connection down 'preconfigured' 2>/dev/null || true"
    
    # Configure club WLAN
    if [ "$SERVER_MODE" = true ]; then
        # Server mode: Use DHCP for club WLAN
        info "Configuring club WLAN: $CLUB_WLAN_SSID (DHCP - Server Mode)"
        
        # Delete existing connection if it exists
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection delete '$CLUB_WLAN_SSID' 2>/dev/null || true"
        
        # Create club WLAN connection with DHCP
        CLUB_CONN_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection add type wifi con-name '$CLUB_WLAN_SSID' ifname wlan0 ssid '$CLUB_WLAN_SSID' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '$CLUB_WLAN_PASSWORD' ipv4.method auto connection.autoconnect no connection.autoconnect-priority ${CLUB_WLAN_PRIORITY} 2>&1")
        CLUB_CONN_EXIT_CODE=$?
    else
        # Table client mode: Use static IP for club WLAN
        info "Configuring club WLAN: $CLUB_WLAN_SSID (Static IP: $TABLE_IP)"
        
        # Delete existing connection if it exists (by SSID or connection name)
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection delete '$CLUB_WLAN_SSID' 2>/dev/null || true"
        
        # Create club WLAN connection with static IP
        CLUB_CONN_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection add type wifi con-name '$CLUB_WLAN_SSID' ifname wlan0 ssid '$CLUB_WLAN_SSID' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '$CLUB_WLAN_PASSWORD' ipv4.addresses ${TABLE_IP}/24 ipv4.gateway ${CLUB_GATEWAY} ipv4.dns '8.8.8.8 1.1.1.1' ipv4.method manual connection.autoconnect no connection.autoconnect-priority ${CLUB_WLAN_PRIORITY} 2>&1")
        CLUB_CONN_EXIT_CODE=$?
    fi
    
    if [ $CLUB_CONN_EXIT_CODE -eq 0 ]; then
        log "✅ Club WLAN connection created (autoconnect disabled during setup)"
        
        # Small delay to let NetworkManager register the connection
        sleep 1
        
        # CRITICAL: Explicitly prevent NetworkManager from activating this connection during setup
        # This prevents IP change that would break SSH connection
        info "Preventing automatic activation of club WLAN connection..."
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection down '$CLUB_WLAN_SSID' 2>/dev/null || true"
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection modify '$CLUB_WLAN_SSID' connection.autoconnect no" 2>/dev/null
        
        # Ensure current connection stays active
        CURRENT_CONN=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "nmcli -t -f NAME connection show --active | head -1" 2>/dev/null || echo "")
        if [ -n "$CURRENT_CONN" ] && [ "$CURRENT_CONN" != "$CLUB_WLAN_SSID" ]; then
            info "Ensuring current connection '$CURRENT_CONN' stays active..."
            ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection up '$CURRENT_CONN' 2>/dev/null || true"
        fi
    else
        error "Failed to create club WLAN connection: $CLUB_CONN_OUTPUT"
        exit 1
    fi
    
    # Configure dev WLAN with DHCP (if provided)
    if [ -n "$DEV_WLAN_SSID" ]; then
        info "Configuring dev WLAN: $DEV_WLAN_SSID (DHCP)"
        
        # Delete existing connection if it exists
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection delete '$DEV_WLAN_SSID' 2>/dev/null || true"
        
        # Create dev WLAN connection with autoconnect=no initially
        DEV_CONN_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection add type wifi con-name '$DEV_WLAN_SSID' ifname wlan0 ssid '$DEV_WLAN_SSID' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '$DEV_WLAN_PASSWORD' ipv4.method auto connection.autoconnect no connection.autoconnect-priority ${DEV_WLAN_PRIORITY} 2>&1")
        
        if [ $? -eq 0 ]; then
            log "✅ Dev WLAN connection created (autoconnect disabled during setup)"
        else
            warning "Failed to create dev WLAN connection: $DEV_CONN_OUTPUT"
        fi
    fi
    
    # Verify connections were created (with retries for NetworkManager registration)
    info "Verifying connections..."
    CLUB_EXISTS="no"
    for i in 1 2 3; do
        # Check if connection exists by looking in the connection list (more reliable)
        CLUB_EXISTS=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli -t -f NAME connection show 2>/dev/null | grep -q '^$CLUB_WLAN_SSID$' && echo 'yes' || echo 'no'")
        if [ "$CLUB_EXISTS" = "yes" ]; then
            break
        fi
        if [ $i -lt 3 ]; then
            info "Connection not found yet, retrying in 1 second... (attempt $i/3)"
            sleep 1
        fi
    done
    
    if [ "$CLUB_EXISTS" = "yes" ]; then
        log "✓ Club WLAN connection verified"
        # Show connection details
        if [ "$SERVER_MODE" = true ]; then
            ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection show '$CLUB_WLAN_SSID' 2>/dev/null | grep -E '(ipv4.method|802-11-wireless.ssid|connection.autoconnect|connection.autoconnect-priority)'" || true
        else
            ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection show '$CLUB_WLAN_SSID' 2>/dev/null | grep -E '(ipv4.addresses|ipv4.gateway|802-11-wireless.ssid|connection.autoconnect|connection.autoconnect-priority)'" || true
        fi
    else
        error "Club WLAN connection not found after creation!"
        error "Output from creation: $CLUB_CONN_OUTPUT"
        error "Trying to list all connections for debugging..."
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection show" || true
        warning "Connection creation succeeded but verification failed - continuing anyway..."
        warning "The connection should be available after reboot"
    fi
    
    log "✅ NetworkManager configuration complete (connections will auto-connect on reboot)"
else
    # dhcpcd/wpa_supplicant configuration (legacy)
    
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

    # Add club WLAN
    if [ "$SERVER_MODE" = true ]; then
        info "Adding Club WLAN: $CLUB_WLAN_SSID (DHCP - Server Mode, priority $CLUB_WLAN_PRIORITY)"
        WPA_SUPPLICANT_CONFIG+="
# Club WLAN (DHCP - Server Mode)
network={
    ssid=\"$CLUB_WLAN_SSID\"
    psk=\"$CLUB_WLAN_PASSWORD\"
    key_mgmt=WPA-PSK
    priority=$CLUB_WLAN_PRIORITY
}
"
    else
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
    fi

    # Upload wpa_supplicant.conf
    echo "$WPA_SUPPLICANT_CONFIG" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/wpa_supplicant.conf" 2>/dev/null
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf" 2>/dev/null
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf" 2>/dev/null
    
    # Configure static IP for club WLAN via dhcpcd hook (only for table clients, not servers)
    if [ "$SERVER_MODE" != true ]; then
        DHCPCD_HOOK="#!/bin/bash
# DHCP hook for SSID-specific configuration

if [ \"\$interface\" = \"wlan0\" ] && [ \"\$reason\" = \"BOUND\" ]; then
    CURRENT_SSID=\$(iwgetid -r)

    if [ \"\$CURRENT_SSID\" = \"$CLUB_WLAN_SSID\" ]; then
        # Club WLAN - apply static IP
        echo \"Applying static IP for club WLAN: $TABLE_IP\"
        sudo ip addr flush dev wlan0
        sudo ip addr add ${TABLE_IP}/24 dev wlan0
        sudo ip route add default via ${CLUB_GATEWAY}
        echo \"nameserver 8.8.8.8\" | sudo tee /etc/resolv.conf > /dev/null
    fi
fi
"
        echo "$DHCPCD_HOOK" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/dhcp-ssid-hook" 2>/dev/null
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/dhcp-ssid-hook /etc/dhcpcd.exit-hook && sudo chmod +x /etc/dhcpcd.exit-hook" 2>/dev/null
        log "✅ Static IP hook configured for club WLAN"
    else
        log "✅ Server mode - using DHCP (no static IP hook needed)"
    fi
    
    log "✅ wpa_supplicant + dhcpcd configuration complete"
fi
echo ""

# Step 5: Install scoreboard client
log "📦 Step 5: Installing Scoreboard Client"
log "======================================"

info "Installing required packages..."
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo apt-get update -qq && sudo apt-get install -y chromium wmctrl xdotool 2>&1 | grep -E '(upgraded|installed)'" 2>/dev/null || true
log "✅ Packages installed"
echo ""

# Step 6: Setup virtual keyboard
log "⌨️  Step 6: Setting up Virtual Keyboard"
log "======================================"

if [ -f "$SCRIPT_DIR/lib/setup-virtual-keyboard.sh" ]; then
    bash "$SCRIPT_DIR/lib/setup-virtual-keyboard.sh" "$SSH_USER" "$SSH_PORT" "$CURRENT_IP"
else
    error "setup-virtual-keyboard.sh not found in $SCRIPT_DIR/lib/"
    exit 1
fi
echo ""

# Step 7: Get Location MD5 and create autostart script
log "🔧 Step 7: Creating Autostart Configuration"
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
SCOREBOARD_URL="http://$WEBSERVER_HOST:$WEBSERVER_PORT/locations/$LOCATION_MD5/scoreboard?sb_state=welcome&locale=de"
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



if [ -z "$KIOSK" ]; then
$BROWSER_CMD \
  --start-fullscreen \
  --disable-restore-session-state \
  --user-data-dir="$CHROMIUM_USER_DIR" \
  --disable-features=VizDisplayCompositor,TranslateUI \
  --disable-translate \
  --disable-dev-shm-usage \
  --app="$SCOREBOARD_URL" \
  # --no-sandbox \
  --disable-gpu \
  >>/tmp/chromium-kiosk.log 2>&1 &
else
# Start browser in fullscreen
$BROWSER_CMD \
  --kiosk \
  "$SCOREBOARD_URL" \
  --disable-restore-session-state \
  --user-data-dir="$CHROMIUM_USER_DIR" \
  --disable-features=VizDisplayCompositor,TranslateUI \
  --disable-translate \
  --disable-dev-shm-usage \
  --disable-setuid-sandbox \
  --disable-gpu \
  --disable-infobars \
  --noerrdialogs \
  --no-first-run \
  --disable-session-crashed-bubble \
  --check-for-update-interval=31536000 \
  >>/tmp/chromium-kiosk.log 2>&1 &
fi

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

# Step 8: Create systemd service
log "⚙️  Step 8: Setting up Systemd Service"
log "====================================="

# Ensure KIOSK_USER is set (default to pi if not set)
KIOSK_USER="${KIOSK_USER:-pi}"

SYSTEMD_SERVICE="[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$KIOSK_USER
Environment=\"DISPLAY=:0\"
Environment=\"XAUTHORITY=/home/$KIOSK_USER/.Xauthority\"
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

# Step 9: Create desktop shortcut for scoreboard restart
log "🖥️  Step 9: Creating Desktop Shortcut"
log "===================================="

info "Creating desktop shortcut for scoreboard restart..."
DESKTOP_SHORTCUT="[Desktop Entry]
Name=Restart Scoreboard
Comment=Restart the Carambus scoreboard kiosk
Exec=sudo systemctl restart scoreboard-kiosk
Icon=view-refresh
Terminal=false
Type=Application
Categories=System;Utility;
"

# Determine which desktop path to use (use KIOSK_USER for desktop, not SSH_USER)
DESKTOP_PATH=""
KIOSK_USER="${KIOSK_USER:-pi}"  # Default to pi if not set

info "DEBUG: SSH_USER=$SSH_USER, KIOSK_USER=$KIOSK_USER"

# Try kiosk user's desktop first (use sudo for directory check when SSH_USER != KIOSK_USER)
info "DEBUG: Checking /home/$KIOSK_USER/Desktop..."
DIR_CHECK_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo test -d /home/$KIOSK_USER/Desktop 2>&1 || sudo mkdir -p /home/$KIOSK_USER/Desktop 2>&1" 2>&1)
DIR_CHECK_EXIT=$?

if [ $DIR_CHECK_EXIT -eq 0 ]; then
    DESKTOP_PATH="/home/$KIOSK_USER/Desktop"
    info "DEBUG: Desktop path set to $DESKTOP_PATH"
    # Ensure correct ownership
    OWNERSHIP_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/Desktop 2>&1" 2>&1)
    OWNERSHIP_EXIT=$?
    if [ $OWNERSHIP_EXIT -eq 0 ]; then
        info "DEBUG: Ownership set successfully"
    else
        warning "DEBUG: Ownership setting failed (exit code: $OWNERSHIP_EXIT)"
        warning "DEBUG: Ownership output: $OWNERSHIP_OUTPUT"
    fi
else
    warning "DEBUG: Failed to check/create /home/$KIOSK_USER/Desktop (exit code: $DIR_CHECK_EXIT)"
    warning "DEBUG: Directory check output: $DIR_CHECK_OUTPUT"
fi

# Fallback to pi user's desktop
if [ -z "$DESKTOP_PATH" ]; then
    info "DEBUG: Trying fallback /home/pi/Desktop..."
    FALLBACK_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo test -d /home/pi/Desktop 2>&1 || sudo mkdir -p /home/pi/Desktop 2>&1" 2>&1)
    FALLBACK_EXIT=$?
    
    if [ $FALLBACK_EXIT -eq 0 ]; then
        DESKTOP_PATH="/home/pi/Desktop"
        info "DEBUG: Desktop path set to $DESKTOP_PATH (fallback)"
        # Ensure correct ownership
        FALLBACK_OWNER_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo chown pi:pi /home/pi/Desktop 2>&1" 2>&1)
        FALLBACK_OWNER_EXIT=$?
        if [ $FALLBACK_OWNER_EXIT -eq 0 ]; then
            info "DEBUG: Ownership set successfully (fallback)"
        else
            warning "DEBUG: Ownership setting failed (exit code: $FALLBACK_OWNER_EXIT)"
            warning "DEBUG: Ownership output: $FALLBACK_OWNER_OUTPUT"
        fi
    else
        warning "DEBUG: Failed to check/create /home/pi/Desktop (exit code: $FALLBACK_EXIT)"
        warning "DEBUG: Fallback output: $FALLBACK_OUTPUT"
    fi
fi

if [ -z "$DESKTOP_PATH" ]; then
    error "DEBUG: No desktop path could be determined!"
fi

DESKTOP_SHORTCUT_CREATED=false
if [ -n "$DESKTOP_PATH" ]; then
    info "Creating shortcut in $DESKTOP_PATH..."
    info "DEBUG: Desktop shortcut content length: ${#DESKTOP_SHORTCUT} characters"
    
    # Create the desktop file using tee with sudo (more reliable than piping)
    info "DEBUG: Attempting to create file with sudo tee..."
    TEE_OUTPUT=$(echo "$DESKTOP_SHORTCUT" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo tee '$DESKTOP_PATH/restart-scoreboard.desktop' > /dev/null 2>&1" 2>&1)
    TEE_EXIT_CODE=$?
    
    if [ $TEE_EXIT_CODE -eq 0 ]; then
        info "DEBUG: File created successfully with tee (exit code: $TEE_EXIT_CODE)"
        
        # Set permissions and ownership
        info "DEBUG: Setting permissions and ownership..."
        PERM_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo chmod +x '$DESKTOP_PATH/restart-scoreboard.desktop' && sudo chown $KIOSK_USER:$KIOSK_USER '$DESKTOP_PATH/restart-scoreboard.desktop' 2>&1" 2>&1)
        PERM_EXIT_CODE=$?
        
        if [ $PERM_EXIT_CODE -eq 0 ]; then
            info "DEBUG: Permissions set successfully (exit code: $PERM_EXIT_CODE)"
            
            # Verify it was created
            info "DEBUG: Verifying file exists and is executable..."
            VERIFY_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo test -f '$DESKTOP_PATH/restart-scoreboard.desktop' && sudo test -x '$DESKTOP_PATH/restart-scoreboard.desktop' && sudo ls -la '$DESKTOP_PATH/restart-scoreboard.desktop' 2>&1" 2>&1)
            VERIFY_EXIT_CODE=$?
            
            if [ $VERIFY_EXIT_CODE -eq 0 ]; then
                log "✅ Desktop shortcut created at $DESKTOP_PATH/restart-scoreboard.desktop"
                info "DEBUG: Verification output: $VERIFY_OUTPUT"
                
                # Mark desktop file as trusted (so it appears as clickable icon, not just a file)
                info "DEBUG: Marking desktop file as trusted..."
                TRUST_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo -u $KIOSK_USER dbus-launch gio set '$DESKTOP_PATH/restart-scoreboard.desktop' metadata::trusted true 2>&1" 2>&1 || ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo -u $KIOSK_USER xdg-mime default restart-scoreboard.desktop application/x-desktop 2>&1" 2>&1 || true)
                if [ -z "$TRUST_OUTPUT" ] || echo "$TRUST_OUTPUT" | grep -q "trusted\|success\|No error"; then
                    info "DEBUG: Desktop file marked as trusted"
                else
                    warning "DEBUG: Could not mark as trusted automatically: $TRUST_OUTPUT"
                    info "DEBUG: User may need to right-click and select 'Allow Launching' on the Pi"
                fi
                
                DESKTOP_SHORTCUT_CREATED=true
            else
                warning "File creation succeeded but verification failed (exit code: $VERIFY_EXIT_CODE)"
                warning "DEBUG: Verification output: $VERIFY_OUTPUT"
            fi
        else
            warning "Failed to set permissions/ownership on desktop file (exit code: $PERM_EXIT_CODE)"
            warning "DEBUG: Permission output: $PERM_OUTPUT"
        fi
    else
        warning "Failed to create desktop file via SSH (exit code: $TEE_EXIT_CODE)"
        warning "DEBUG: Tee output: $TEE_OUTPUT"
    fi
else
    error "DEBUG: Cannot create shortcut - DESKTOP_PATH is empty!"
fi

# Fallback: Create in /usr/share/applications and symlink to desktop
if [ "$DESKTOP_SHORTCUT_CREATED" = false ]; then
    info "Trying alternative method: creating application entry..."
    info "DEBUG: Fallback method - creating in /usr/share/applications..."
    
    if echo "$DESKTOP_SHORTCUT" | ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat > /tmp/restart-scoreboard.desktop" 2>&1; then
        info "DEBUG: Temporary file created in /tmp"
        # Check if file was created
        if ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "test -f /tmp/restart-scoreboard.desktop && test -s /tmp/restart-scoreboard.desktop" 2>&1; then
            info "DEBUG: Temporary file exists and is not empty"
            # Create in applications directory
            APP_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mv /tmp/restart-scoreboard.desktop /usr/share/applications/restart-scoreboard.desktop && sudo chmod +x /usr/share/applications/restart-scoreboard.desktop 2>&1" 2>&1)
            APP_EXIT_CODE=$?
            
            if [ $APP_EXIT_CODE -eq 0 ]; then
                log "✅ Application entry created at /usr/share/applications/restart-scoreboard.desktop"
                info "DEBUG: Application entry created successfully"
                
                # Try to create symlink on desktop (use sudo when needed)
                for SYMLINK_PATH in "/home/$KIOSK_USER/Desktop" "/home/pi/Desktop"; do
                    info "DEBUG: Trying to create symlink in $SYMLINK_PATH..."
                    SYMLINK_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo mkdir -p '$SYMLINK_PATH' 2>&1 && sudo ln -sf /usr/share/applications/restart-scoreboard.desktop '$SYMLINK_PATH/restart-scoreboard.desktop' 2>&1 && sudo test -L '$SYMLINK_PATH/restart-scoreboard.desktop' 2>&1 && sudo chown $KIOSK_USER:$KIOSK_USER '$SYMLINK_PATH/restart-scoreboard.desktop' 2>&1" 2>&1)
                    SYMLINK_EXIT_CODE=$?
                    
                    if [ $SYMLINK_EXIT_CODE -eq 0 ]; then
                        log "✅ Desktop symlink created at $SYMLINK_PATH/restart-scoreboard.desktop"
                        info "DEBUG: Symlink created successfully: $SYMLINK_OUTPUT"
                        DESKTOP_SHORTCUT_CREATED=true
                        break
                    else
                        warning "DEBUG: Symlink creation failed in $SYMLINK_PATH (exit code: $SYMLINK_EXIT_CODE)"
                        warning "DEBUG: Symlink output: $SYMLINK_OUTPUT"
                    fi
                done
            else
                warning "Failed to move file to /usr/share/applications (exit code: $APP_EXIT_CODE)"
                warning "DEBUG: Application output: $APP_OUTPUT"
            fi
        else
            warning "Temporary file was not created or is empty"
            info "DEBUG: File check output: $(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "ls -la /tmp/restart-scoreboard.desktop 2>&1" 2>&1)"
        fi
    else
        warning "Failed to create temporary file via SSH"
    fi
fi

if [ "$DESKTOP_SHORTCUT_CREATED" = true ]; then
    log "✅ Desktop shortcut ready - double-click to restart scoreboard"
else
    warning "Desktop shortcut could not be created automatically"
    info "You can manually create it by running on the Pi:"
    echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP \"cat > ~/Desktop/restart-scoreboard.desktop << 'EOF'\""
    echo "$DESKTOP_SHORTCUT"
    echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP \"EOF\""
    echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP \"chmod +x ~/Desktop/restart-scoreboard.desktop\""
fi
echo ""

# Step 10: Enable autoconnect for WLAN connections (after all config is done)
if [ "$USING_NETWORK_MANAGER" = true ]; then
    log "🔌 Step 10: Enabling WLAN Auto-Connect"
    log "===================================="
    
    # Verify SSH connection is still alive before enabling autoconnect
    info "Verifying SSH connection is still active..."
    if ! ssh -p "$SSH_PORT" -o ConnectTimeout=5 "$SSH_USER@$CURRENT_IP" "echo 'SSH still connected'" 2>/dev/null; then
        error "SSH connection lost! Cannot safely enable autoconnect."
        error "Please reconnect and manually enable autoconnect with:"
        echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP 'sudo nmcli connection modify \"$CLUB_WLAN_SSID\" connection.autoconnect yes'"
        exit 1
    fi
    
    # Small delay to ensure NetworkManager has settled
    sleep 2
    
    info "Enabling autoconnect for club WLAN..."
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection modify '$CLUB_WLAN_SSID' connection.autoconnect yes" 2>/dev/null
    
    if [ -n "$DEV_WLAN_SSID" ]; then
        info "Enabling autoconnect for dev WLAN..."
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection modify '$DEV_WLAN_SSID' connection.autoconnect yes" 2>/dev/null
    fi
    
    # Final verification that we're still connected
    if ssh -p "$SSH_PORT" -o ConnectTimeout=5 "$SSH_USER@$CURRENT_IP" "echo 'SSH still connected'" 2>/dev/null; then
        log "✅ Auto-connect enabled (will activate on reboot)"
    else
        warning "⚠️  SSH connection lost after enabling autoconnect"
        warning "   This is normal if club WLAN is in range and activated"
        warning "   Configuration is complete - connections will work after reboot"
    fi
    echo ""
fi

# Step 11: Summary and next steps
log "🎉 SETUP COMPLETED!"
log "=================="
log ""
log "Configuration Summary:"
log "  Scenario: $SCENARIO_NAME"
if [ "$SERVER_MODE" = true ]; then
    log "  Mode: Server (club WLAN uses DHCP)"
    log "  Current IP: $CURRENT_IP"
else
    log "  Table: $TABLE_NAME"
    log "  Current IP: $CURRENT_IP"
    log "  Club Static IP: $TABLE_IP"
fi
if [ -n "$DEV_WLAN_SSID" ]; then
log "  Dev WLAN: $DEV_WLAN_SSID (DHCP, priority $DEV_WLAN_PRIORITY)"
fi
if [ "$SERVER_MODE" = true ]; then
    log "  Club WLAN: $CLUB_WLAN_SSID (DHCP, priority $CLUB_WLAN_PRIORITY)"
else
    log "  Club WLAN: $CLUB_WLAN_SSID (Static IP, priority $CLUB_WLAN_PRIORITY)"
fi
log "  Server: $WEBSERVER_HOST:$WEBSERVER_PORT"
log ""
warning "⚠️  IMPORTANT: To test in club, the Raspberry Pi needs to be rebooted"
warning "    After reboot, it will connect to the available WLAN automatically:"
if [ -n "$DEV_WLAN_SSID" ]; then
    warning "    - In office: $DEV_WLAN_SSID with DHCP"
fi
if [ "$SERVER_MODE" = true ]; then
    warning "    - In club: $CLUB_WLAN_SSID with DHCP"
else
    warning "    - In club: $CLUB_WLAN_SSID with static IP $TABLE_IP"
fi
echo ""
info "To reboot now:"
echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP 'sudo reboot'"
echo ""
info "To verify after reboot:"
if [ "$SERVER_MODE" = true ]; then
    echo "  # Check DHCP-assigned IP on club network"
    echo "  ssh -p $SSH_PORT $SSH_USER@<new_ip> 'sudo systemctl status scoreboard-kiosk'"
else
    echo "  ping $TABLE_IP"
    echo "  ssh -p $SSH_PORT $SSH_USER@$TABLE_IP 'sudo systemctl status scoreboard-kiosk'"
fi
echo ""

if [ "$SERVER_MODE" = true ]; then
    log "✅ Multi-WLAN server configuration ready for deployment!"
else
    log "✅ Multi-WLAN table client ready for deployment!"
fi

