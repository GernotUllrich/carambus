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

CLUB_DNS=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'network', 'club_wlan', 'dns') || '8.8.8.8'
")

CLUB_SUBNET=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
subnet = config.dig('environments', 'production', 'network', 'club_wlan', 'subnet') || '24'
# Extract just the number if format is like '172.2.24/24'
puts subnet.to_s.split('/').last
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

# Check if table_name is "server" (explicit server mode)
# Note: Table clients always use pi/22 for SSH, servers use config.yml SSH settings
if [ "$TABLE_NAME" = "server" ] || [ -z "$TABLE_NAME" ]; then
    SERVER_MODE=true
    
    # Check if server has a static IP configured in config.yml
    SERVER_STATIC_IP=$(cd "$RAILS_APP_DIR" && bundle exec ruby -ryaml -e "
config = YAML.load_file('$SCENARIO_CONFIG')
puts config.dig('environments', 'production', 'network', 'club_wlan', 'static_ip') || ''
" 2>/dev/null || echo "")
    
    if [ -n "$SERVER_STATIC_IP" ]; then
        TABLE_IP="$SERVER_STATIC_IP"
        log "✓ Server mode detected - using static IP from config.yml: $TABLE_IP"
    else
        TABLE_IP=""
        log "✓ Server mode detected - club WLAN will use DHCP"
    fi
    
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
    # Table clients always use pi/22 for SSH (don't read from config)
    SSH_PORT="${SSH_PORT_ARG:-22}"
    SSH_USER="${SSH_USER_ARG:-pi}"
    
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

# Step 2.5: Check system performance compatibility
log "🔍 Step 2.5: Checking System Performance Compatibility"
log "====================================================="

# Detect Raspberry Pi model
PI_MODEL=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'Unknown'" 2>/dev/null || echo "Unknown")

# Detect RAM amount (in MB)
RAM_MB=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "free -m | awk '/^Mem:/ {print \$2}'" 2>/dev/null || echo "0")

# Detect OS architecture
OS_ARCH=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "uname -m" 2>/dev/null || echo "unknown")

# Detect if it's Raspberry Pi 3
IS_PI3=false
if echo "$PI_MODEL" | grep -qi "Raspberry Pi 3"; then
    IS_PI3=true
fi

# Show detected information
info "Detected system:"
info "  Model: $PI_MODEL"
info "  RAM: ${RAM_MB}MB"
info "  Architecture: $OS_ARCH"

# Check current memory usage
MEM_USED=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "free -m | awk '/^Mem:/ {print \$3}'" 2>/dev/null || echo "0")
MEM_AVAIL=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "free -m | awk '/^Mem:/ {print \$7}'" 2>/dev/null || echo "0")
MEM_PERCENT=$((MEM_USED * 100 / RAM_MB))

# Check swap configuration
SWAP_SIZE=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "free -m | awk '/^Swap:/ {print \$2}'" 2>/dev/null || echo "0")
SWAP_USED=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "free -m | awk '/^Swap:/ {print \$3}'" 2>/dev/null || echo "0")

# Check for unnecessary services that can be disabled
UNNECESSARY_SERVICES=""
SERVICES_TO_CHECK="bluetooth avahi-daemon cups cups-browsed"

for service in $SERVICES_TO_CHECK; do
    if ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "systemctl is-enabled $service 2>/dev/null | grep -q enabled" 2>/dev/null; then
        if [ -z "$UNNECESSARY_SERVICES" ]; then
            UNNECESSARY_SERVICES="$service"
        else
            UNNECESSARY_SERVICES="$UNNECESSARY_SERVICES, $service"
        fi
    fi
done

# Check for memory-heavy packages
HEAVY_PACKAGES=""
PACKAGES_TO_CHECK="libreoffice wolfram-engine minecraft-pi scratch nuscratch sonic-pi"

for package in $PACKAGES_TO_CHECK; do
    if ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "dpkg -l | grep -q \"^ii.*$package\"" 2>/dev/null; then
        if [ -z "$HEAVY_PACKAGES" ]; then
            HEAVY_PACKAGES="$package"
        else
            HEAVY_PACKAGES="$HEAVY_PACKAGES, $package"
        fi
    fi
done

# Check if zram is installed/configured
ZRAM_INSTALLED=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "dpkg -l | grep -q zram-tools && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")

# Show system status
info "Current memory usage: ${MEM_USED}MB used, ${MEM_AVAIL}MB available (${MEM_PERCENT}% used)"
if [ "$SWAP_SIZE" -gt 0 ]; then
    info "Swap: ${SWAP_SIZE}MB total, ${SWAP_USED}MB used"
fi

# Performance recommendations - check if any issues exist
PERFORMANCE_ISSUES=false

if [ "$RAM_MB" -le 1024 ] && [ "$OS_ARCH" = "aarch64" ]; then
    PERFORMANCE_ISSUES=true
fi

if [ "$MEM_PERCENT" -gt 80 ]; then
    PERFORMANCE_ISSUES=true
fi

if [ "$SWAP_USED" -gt 100 ]; then
    PERFORMANCE_ISSUES=true
fi

if [ -n "$UNNECESSARY_SERVICES" ]; then
    PERFORMANCE_ISSUES=true
fi

if [ -n "$HEAVY_PACKAGES" ]; then
    PERFORMANCE_ISSUES=true
fi

if [ "$RAM_MB" -le 1024 ] && [ "$SWAP_SIZE" -lt 1024 ]; then
    PERFORMANCE_ISSUES=true
fi

if [ "$RAM_MB" -le 1024 ] && [ "$ZRAM_INSTALLED" = "no" ]; then
    PERFORMANCE_ISSUES=true
fi

# Show warnings and recommendations
if [ "$PERFORMANCE_ISSUES" = true ]; then
    warning ""
    warning "⚠️  PERFORMANCE OPTIMIZATION RECOMMENDATIONS ⚠️"
    warning "=============================================="
    
    if [ "$IS_PI3" = true ] && [ "$RAM_MB" -le 1024 ] && [ "$OS_ARCH" = "aarch64" ]; then
        warning "Critical: Raspberry Pi 3 with 1GB RAM running 64-bit OS"
        warning "This configuration will cause performance issues!"
        warning ""
    fi
    
    warning "Recommendations to improve performance:"
    
    # Check for performance issue: Pi 3 with 1GB RAM running 64-bit
    if [ "$IS_PI3" = true ] && [ "$RAM_MB" -le 1024 ] && [ "$OS_ARCH" = "aarch64" ]; then
        warning "  • Switch to Raspberry Pi OS (32-bit) for better memory efficiency"
    elif [ "$RAM_MB" -le 1024 ] && [ "$OS_ARCH" = "aarch64" ]; then
        warning "  • Consider using 32-bit OS for better performance"
    fi
    
    # Check memory usage
    if [ "$MEM_PERCENT" -gt 80 ]; then
        warning "  • High memory usage (${MEM_PERCENT}%) - system may be slow"
    fi
    
    # Check swap usage
    if [ "$SWAP_USED" -gt 100 ]; then
        warning "  • High swap usage (${SWAP_USED}MB) - SD card swapping is slow"
    fi
    
    # Check for unnecessary services
    if [ -n "$UNNECESSARY_SERVICES" ]; then
        warning "  • Disable unnecessary services: $UNNECESSARY_SERVICES"
        warning "    Run: sudo systemctl disable $UNNECESSARY_SERVICES"
    fi
    
    # Check for heavy packages
    if [ -n "$HEAVY_PACKAGES" ]; then
        warning "  • Remove unused heavy packages: $HEAVY_PACKAGES"
        warning "    Run: sudo apt remove $HEAVY_PACKAGES"
    fi
    
    # Check swap size for low-RAM systems
    if [ "$RAM_MB" -le 1024 ] && [ "$SWAP_SIZE" -lt 1024 ]; then
        warning "  • Increase swap size to 2GB for better stability"
        warning "    Edit /etc/dphys-swapfile and set CONF_SWAPSIZE=2048"
    fi
    
    # Check for zram (compressed RAM swap - better than SD card swap)
    if [ "$RAM_MB" -le 1024 ] && [ "$ZRAM_INSTALLED" = "no" ]; then
        warning "  • Install zram-tools for faster compressed RAM swap"
        warning "    Run: sudo apt install zram-tools"
    fi
    
    warning ""
    warning "The setup will continue, but applying these recommendations"
    warning "will significantly improve scoreboard performance."
    warning ""
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
    
    # Configure club WLAN
    # CRITICAL: Create connection WITHOUT ifname to prevent immediate activation
    # This is the standard approach for preparing SD cards for use on different networks
    # The connection will be created but NOT activated until autoconnect is enabled
    # IMPORTANT: We preserve the existing "preconfigured" connection (user's dev WLAN)
    # so passwordless SSH access remains available
    
    # Determine IP configuration based on mode and config
    if [ -n "$TABLE_IP" ]; then
        # Static IP mode (either table client or server with static_ip configured)
        if [ "$SERVER_MODE" = true ]; then
            info "Configuring club WLAN: $CLUB_WLAN_SSID (Static IP: $TABLE_IP - Server Mode)"
        else
            info "Configuring club WLAN: $CLUB_WLAN_SSID (Static IP: $TABLE_IP - Table Client)"
        fi
        
        # Delete existing connection if it exists
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection delete '$CLUB_WLAN_SSID' 2>/dev/null || true"
        
        # Create club WLAN connection with static IP
        # NOTE: Omitting 'ifname' prevents NetworkManager from immediately activating the connection
        CLUB_CONN_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection add type wifi con-name '$CLUB_WLAN_SSID' ssid '$CLUB_WLAN_SSID' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '$CLUB_WLAN_PASSWORD' ipv4.addresses ${TABLE_IP}/${CLUB_SUBNET} ipv4.gateway ${CLUB_GATEWAY} ipv4.dns '${CLUB_DNS} 1.1.1.1' ipv4.method manual connection.autoconnect no connection.autoconnect-priority 0 2>&1")
        CLUB_CONN_EXIT_CODE=$?
    else
        # DHCP mode (server without static_ip)
        info "Configuring club WLAN: $CLUB_WLAN_SSID (DHCP - Server Mode)"
        
        # Delete existing connection if it exists
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection delete '$CLUB_WLAN_SSID' 2>/dev/null || true"
        
        # Create club WLAN connection with DHCP
        # NOTE: Omitting 'ifname' prevents NetworkManager from immediately activating the connection
        CLUB_CONN_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection add type wifi con-name '$CLUB_WLAN_SSID' ssid '$CLUB_WLAN_SSID' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '$CLUB_WLAN_PASSWORD' ipv4.method auto connection.autoconnect no connection.autoconnect-priority 0 2>&1")
        CLUB_CONN_EXIT_CODE=$?
    fi
    
    if [ $CLUB_CONN_EXIT_CODE -eq 0 ]; then
        log "✅ Club WLAN connection created (not activated - will connect on reboot)"
        
        # Verify connection was created but not activated
        CLUB_ACTIVE=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "nmcli -t -f NAME connection show --active 2>/dev/null | grep -q '^$CLUB_WLAN_SSID$' && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")
        if [ "$CLUB_ACTIVE" = "yes" ]; then
            warning "Club WLAN connection was activated unexpectedly - bringing it down..."
            ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection down '$CLUB_WLAN_SSID' && sudo nmcli connection modify '$CLUB_WLAN_SSID' connection.autoconnect no connection.autoconnect-priority 0" 2>/dev/null || true
        fi
        
        # Preserve the existing "preconfigured" connection (user's dev WLAN from Raspberry Pi Imager)
        # This ensures passwordless SSH access remains available
        info "Preserving existing development WLAN connection..."
        PRECONFIGURED_EXISTS=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "nmcli -t -f NAME connection show 2>/dev/null | grep -q '^preconfigured$' && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")
        if [ "$PRECONFIGURED_EXISTS" = "yes" ]; then
            # If dev WLAN is configured, we can optionally rename/update preconfigured to match
            # But we keep it regardless to preserve SSH access
            if [ -n "$DEV_WLAN_SSID" ]; then
                PRECONFIGURED_SSID=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "nmcli -t -f 802-11-wireless.ssid connection show 'preconfigured' 2>/dev/null | cut -d: -f2" 2>/dev/null || echo "")
                if [ "$PRECONFIGURED_SSID" != "$DEV_WLAN_SSID" ]; then
                    info "Existing 'preconfigured' connection uses different SSID - keeping both connections"
                fi
            fi
            log "✓ Preserved 'preconfigured' connection (dev WLAN remains available)"
        else
            info "No 'preconfigured' connection found (may have been removed previously)"
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
        # NOTE: Omitting 'ifname' prevents NetworkManager from immediately activating the connection
        DEV_CONN_OUTPUT=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection add type wifi con-name '$DEV_WLAN_SSID' ssid '$DEV_WLAN_SSID' wifi-sec.key-mgmt wpa-psk wifi-sec.psk '$DEV_WLAN_PASSWORD' ipv4.method auto connection.autoconnect no connection.autoconnect-priority ${DEV_WLAN_PRIORITY} 2>&1")
        
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
        if [ -n "$TABLE_IP" ]; then
            # Static IP - show addresses
            ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection show '$CLUB_WLAN_SSID' 2>/dev/null | grep -E '(ipv4.method|ipv4.addresses|ipv4.gateway|ipv4.dns|802-11-wireless.ssid|connection.autoconnect|connection.autoconnect-priority)'" || true
        else
            # DHCP - no addresses to show
            ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection show '$CLUB_WLAN_SSID' 2>/dev/null | grep -E '(ipv4.method|802-11-wireless.ssid|connection.autoconnect|connection.autoconnect-priority)'" || true
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
ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo apt-get update -qq && sudo apt-get install -y chromium wmctrl xdotool wvkbd 2>&1 | grep -E '(upgraded|installed)'" 2>/dev/null || true
log "✅ Packages installed (including wvkbd virtual keyboard)"
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

# Determine if this is a local server (client and server on same Pi)
if [ "$SERVER_MODE" = true ]; then
    IS_LOCAL_SERVER="true"
    info "Local server mode detected - will wait for Puma service"
else
    IS_LOCAL_SERVER="false"
    info "Remote server mode detected - minimal wait"
fi

AUTOSTART_SCRIPT='#!/bin/bash
# Carambus Scoreboard Autostart
export DISPLAY=:0
IS_LOCAL_SERVER="'"$IS_LOCAL_SERVER"'"

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

SCOREBOARD_URL="'"$SCOREBOARD_URL"'"

# Wait for web server to be ready
if [ "$IS_LOCAL_SERVER" = "true" ]; then
    # Local server mode: Wait longer for Puma to start
    echo "Local server mode - waiting for Puma service to be ready..."
    MAX_WAIT=120  # Maximum 2 minutes
    WAIT_INTERVAL=5
else
    # Remote server mode: Short wait (server should already be running)
    echo "Remote server mode - checking server availability..."
    MAX_WAIT=30  # Maximum 30 seconds
    WAIT_INTERVAL=3
fi

WAITED=0
SERVER_READY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    # Try to connect to the server
    if curl -s -f -o /dev/null --connect-timeout 2 "$SCOREBOARD_URL" 2>/dev/null; then
        SERVER_READY=true
        echo "✓ Server is ready after ${WAITED}s"
        break
    fi
    
    # Also check if just the port is responding (even with 502)
    if curl -s --connect-timeout 2 "http://'"$WEBSERVER_HOST"':'"$WEBSERVER_PORT"'/" >/dev/null 2>&1; then
        if [ "$IS_LOCAL_SERVER" = "true" ]; then
            echo "  Port responding but Puma not ready yet (possibly 502)..."
        else
            echo "  Port responding but server not ready yet..."
        fi
    else
        if [ "$IS_LOCAL_SERVER" = "true" ]; then
            echo "  Waiting for Puma service to start..."
        else
            echo "  Server not responding yet..."
        fi
    fi
    
    sleep $WAIT_INTERVAL
    WAITED=$((WAITED + WAIT_INTERVAL))
done

if [ "$SERVER_READY" = false ]; then
    if [ "$IS_LOCAL_SERVER" = "true" ]; then
        echo "⚠️  Warning: Local Puma service did not respond after ${MAX_WAIT}s - starting browser anyway"
    else
        echo "⚠️  Warning: Remote server did not respond after ${MAX_WAIT}s - starting browser anyway"
    fi
fi

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
  --disable-gpu \
  --app="$SCOREBOARD_URL" \
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

# Start virtual keyboard (if available)
# Try wvkbd-mobintl first (modern, works well), fallback to florence, onboard, matchbox
if command -v wvkbd-mobintl >/dev/null 2>&1; then
    echo "Starting wvkbd-mobintl virtual keyboard..."
    # Set XDG_RUNTIME_DIR if not set (required for wvkbd)
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
    wvkbd-mobintl &
    echo "wvkbd-mobintl virtual keyboard started"
elif command -v florence >/dev/null 2>&1; then
    echo "Starting florence virtual keyboard..."
    florence --focus &
    echo "Florence virtual keyboard started"
elif command -v onboard >/dev/null 2>&1; then
    echo "Starting onboard virtual keyboard..."
    onboard &
    echo "Onboard virtual keyboard started"
elif command -v matchbox-keyboard >/dev/null 2>&1; then
    echo "Starting matchbox-keyboard (wvkbd/florence/onboard not available)..."
    matchbox-keyboard &
    echo "matchbox-keyboard started"
else
    echo "No virtual keyboard available (skipping)"
fi

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

# Determine systemd dependencies based on mode
if [ "$SERVER_MODE" = true ]; then
    # Server mode: Wait for local Puma service
    PUMA_SERVICE_NAME="puma-${SCENARIO_NAME}.service"
    SYSTEMD_SERVICE="[Unit]
Description=Carambus Scoreboard Kiosk
After=graphical.target network-online.target ${PUMA_SERVICE_NAME}
Wants=network-online.target ${PUMA_SERVICE_NAME}

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
else
    # Client mode: Only wait for network
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
fi

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
    # Enable autoconnect with correct priority (connection was created with autoconnect=no)
    ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection modify '$CLUB_WLAN_SSID' connection.autoconnect yes connection.autoconnect-priority ${CLUB_WLAN_PRIORITY}" 2>/dev/null
    
    # Ensure "preconfigured" connection (dev WLAN) has lower priority than club WLAN
    # This way club WLAN is preferred when available, but dev WLAN still works
    PRECONFIGURED_EXISTS=$(ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "nmcli -t -f NAME connection show 2>/dev/null | grep -q '^preconfigured$' && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")
    if [ "$PRECONFIGURED_EXISTS" = "yes" ]; then
        info "Setting priority for 'preconfigured' connection (dev WLAN) to lower than club WLAN..."
        # Set priority to 1 less than club WLAN priority, but at least 1
        PRECONFIGURED_PRIORITY=$((CLUB_WLAN_PRIORITY - 1))
        if [ $PRECONFIGURED_PRIORITY -lt 1 ]; then
            PRECONFIGURED_PRIORITY=1
        fi
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection modify 'preconfigured' connection.autoconnect yes connection.autoconnect-priority ${PRECONFIGURED_PRIORITY}" 2>/dev/null
        log "✓ 'preconfigured' connection will autoconnect with priority ${PRECONFIGURED_PRIORITY} (club WLAN priority: ${CLUB_WLAN_PRIORITY})"
    fi
    
    if [ -n "$DEV_WLAN_SSID" ]; then
        info "Enabling autoconnect for dev WLAN..."
        ssh -p "$SSH_PORT" "$SSH_USER@$CURRENT_IP" "sudo nmcli connection modify '$DEV_WLAN_SSID' connection.autoconnect yes connection.autoconnect-priority ${DEV_WLAN_PRIORITY}" 2>/dev/null
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
    if [ -n "$TABLE_IP" ]; then
        log "  Mode: Server (club WLAN uses Static IP)"
        log "  Current IP: $CURRENT_IP"
        log "  Club Static IP: $TABLE_IP"
    else
        log "  Mode: Server (club WLAN uses DHCP)"
        log "  Current IP: $CURRENT_IP"
    fi
else
    log "  Table: $TABLE_NAME"
    log "  Current IP: $CURRENT_IP"
    log "  Club Static IP: $TABLE_IP"
fi
if [ -n "$DEV_WLAN_SSID" ]; then
log "  Dev WLAN: $DEV_WLAN_SSID (DHCP, priority $DEV_WLAN_PRIORITY)"
fi
if [ -n "$TABLE_IP" ]; then
    log "  Club WLAN: $CLUB_WLAN_SSID (Static IP: $TABLE_IP, priority $CLUB_WLAN_PRIORITY)"
else
    log "  Club WLAN: $CLUB_WLAN_SSID (DHCP, priority $CLUB_WLAN_PRIORITY)"
fi
log "  Server: $WEBSERVER_HOST:$WEBSERVER_PORT"
log ""
warning "⚠️  IMPORTANT: To test in club, the Raspberry Pi needs to be rebooted"
warning "    After reboot, it will connect to the available WLAN automatically:"
if [ -n "$DEV_WLAN_SSID" ]; then
    warning "    - In office: $DEV_WLAN_SSID with DHCP"
fi
if [ -n "$TABLE_IP" ]; then
    warning "    - In club: $CLUB_WLAN_SSID with static IP $TABLE_IP"
else
    warning "    - In club: $CLUB_WLAN_SSID with DHCP"
fi
echo ""
info "To reboot now:"
echo "  ssh -p $SSH_PORT $SSH_USER@$CURRENT_IP 'sudo reboot'"
echo ""
info "To verify after reboot:"
if [ -n "$TABLE_IP" ]; then
    echo "  ping $TABLE_IP"
    echo "  ssh -p $SSH_PORT $SSH_USER@$TABLE_IP 'sudo systemctl status scoreboard-kiosk'"
else
    echo "  # Check DHCP-assigned IP on club network"
    echo "  ssh -p $SSH_PORT $SSH_USER@<new_ip> 'sudo systemctl status scoreboard-kiosk'"
fi
echo ""

if [ "$SERVER_MODE" = true ]; then
    if [ -n "$TABLE_IP" ]; then
        log "✅ Multi-WLAN server configuration ready for deployment (with static IP)!"
    else
        log "✅ Multi-WLAN server configuration ready for deployment (with DHCP)!"
    fi
else
    log "✅ Multi-WLAN table client ready for deployment!"
fi

