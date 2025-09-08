#!/bin/bash
# Quick SSH enable script for Phillip's Table Raspberry Pi

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

PI_IP="192.168.178.107"
PI_USER="pi"
PI_PASSWORD="raspberry"

log "Phillip's Table Raspberry Pi SSH Setup"
log "======================================"

# Check if Raspberry Pi is reachable
log "Checking Raspberry Pi connectivity..."
if ping -c 1 "$PI_IP" > /dev/null 2>&1; then
    log "✅ Raspberry Pi is reachable at $PI_IP"
else
    error "❌ Raspberry Pi is not reachable at $PI_IP"
    exit 1
fi

# Check current SSH status
log "Checking SSH service status..."
if nmap -p 22 "$PI_IP" | grep -q "open"; then
    log "✅ SSH is already enabled and running"
    info "You can now proceed with the automated setup:"
    info "  rake scenario:setup_raspberry_pi_client[carambus_location_5101]"
    exit 0
else
    warning "⚠️  SSH is not enabled on the Raspberry Pi"
fi

# Check if we can access port 8910 (local server)
log "Checking local server access..."
if nmap -p 8910 "$PI_IP" | grep -q "open"; then
    log "✅ Local server is running on port 8910"
    info "This suggests the Carambus application is already deployed"
else
    warning "⚠️  Local server not detected on port 8910"
fi

# Provide manual setup instructions
log "Manual SSH Setup Required"
log "========================"
echo ""
info "Since SSH is not enabled, you need to enable it manually on the Raspberry Pi:"
echo ""
info "Option 1: Using Raspberry Pi Desktop (if accessible)"
info "  1. Connect keyboard and mouse to the Raspberry Pi"
info "  2. Open Terminal"
info "  3. Run: sudo systemctl enable ssh && sudo systemctl start ssh"
info "  4. Verify: sudo systemctl status ssh"
echo ""
info "Option 2: Using SD Card"
info "  1. Remove SD card from Raspberry Pi"
info "  2. Insert into computer"
info "  3. Navigate to /boot partition"
info "  4. Create empty file named 'ssh' (no extension)"
info "  5. Safely eject and reinsert SD card"
info "  6. Reboot Raspberry Pi"
echo ""
info "Option 3: Using raspi-config"
info "  1. Connect keyboard and mouse to Raspberry Pi"
info "  2. Run: sudo raspi-config"
info "  3. Navigate to 'Interfacing Options' → 'SSH'"
info "  4. Select 'Yes' to enable SSH"
info "  5. Reboot if prompted"
echo ""

# Test SSH after manual setup
log "After enabling SSH, test the connection:"
info "  ssh $PI_USER@$PI_IP"
info "  Default password: $PI_PASSWORD"
echo ""

log "Then run the automated setup:"
info "  rake scenario:setup_raspberry_pi_client[carambus_location_5101]"
info "  rake scenario:deploy_raspberry_pi_client[carambus_location_5101]"
info "  rake scenario:test_raspberry_pi_client[carambus_location_5101]"
echo ""

log "Expected Scoreboard URL for location 5101:"
info "  http://$PI_IP:82/locations/{md5_hash_of_5101}?sb_state=welcome"
