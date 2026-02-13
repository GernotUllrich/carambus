#!/bin/bash
# Install Browser Watchdog on Raspberry Pi Table Client
#
# This script installs either:
#   1. Daily restart timer (simple, reliable)
#   2. Health check watchdog (smart, only restarts when needed)
#
# Usage:
#   ./install-browser-watchdog.sh <pi_ip> [watchdog_type]
#
# Arguments:
#   pi_ip        - IP address of the Raspberry Pi
#   watchdog_type - "daily" (default) or "healthcheck"
#
# Examples:
#   ./install-browser-watchdog.sh 192.168.178.81
#   ./install-browser-watchdog.sh 192.168.178.81 daily
#   ./install-browser-watchdog.sh 192.168.178.81 healthcheck

set -euo pipefail

# Configuration
PI_IP="${1:-}"
WATCHDOG_TYPE="${2:-daily}"
SSH_USER="pj"
SSH_PORT="22"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="$(dirname "$SCRIPT_DIR")/systemd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Usage
usage() {
    cat <<EOF
Usage: $0 <pi_ip> [watchdog_type]

Arguments:
  pi_ip        - IP address of the Raspberry Pi
  watchdog_type - "daily" (default) or "healthcheck"

Examples:
  $0 192.168.178.81
  $0 192.168.178.81 daily
  $0 192.168.178.81 healthcheck

Watchdog Types:
  daily       - Restarts browser once per day at 6:00 AM (simple, reliable)
  healthcheck - Checks browser health every 5 minutes and restarts if needed (smart)
EOF
    exit 1
}

# Validate arguments
if [ -z "$PI_IP" ]; then
    error "Missing required argument: pi_ip"
    usage
fi

if [ "$WATCHDOG_TYPE" != "daily" ] && [ "$WATCHDOG_TYPE" != "healthcheck" ]; then
    error "Invalid watchdog type: $WATCHDOG_TYPE (must be 'daily' or 'healthcheck')"
    usage
fi

# Test SSH connection
info "Testing SSH connection to $PI_IP..."
if ! ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$PI_IP" "echo 'Connection successful'" >/dev/null 2>&1; then
    error "Cannot connect to $PI_IP via SSH"
    error "Please check:"
    error "  - IP address is correct"
    error "  - SSH is enabled on the Pi"
    error "  - User '$SSH_USER' exists"
    error "  - SSH keys are configured"
    exit 1
fi
success "SSH connection successful"

# Install based on watchdog type
if [ "$WATCHDOG_TYPE" = "daily" ]; then
    info "Installing DAILY RESTART watchdog..."
    
    # Upload restart script
    info "Uploading restart script..."
    scp -P "$SSH_PORT" "$SCRIPT_DIR/scoreboard-browser-restart.sh" "$SSH_USER@$PI_IP:/tmp/"
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo mv /tmp/scoreboard-browser-restart.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/scoreboard-browser-restart.sh"
    success "Restart script installed"
    
    # Upload systemd files
    info "Uploading systemd timer and service..."
    scp -P "$SSH_PORT" "$SYSTEMD_DIR/scoreboard-browser-restart.timer" "$SSH_USER@$PI_IP:/tmp/"
    scp -P "$SSH_PORT" "$SYSTEMD_DIR/scoreboard-browser-restart.service" "$SSH_USER@$PI_IP:/tmp/"
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo mv /tmp/scoreboard-browser-restart.timer /etc/systemd/system/ && sudo mv /tmp/scoreboard-browser-restart.service /etc/systemd/system/"
    success "Systemd files installed"
    
    # Reload systemd and enable timer
    info "Enabling timer..."
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo systemctl daemon-reload && sudo systemctl enable scoreboard-browser-restart.timer && sudo systemctl start scoreboard-browser-restart.timer"
    success "Timer enabled and started"
    
    # Show timer status
    info "Timer status:"
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "systemctl list-timers scoreboard-browser-restart.timer --no-pager"
    
    success "Daily restart watchdog installed successfully!"
    info "Browser will restart daily at 6:00 AM"
    info "To test manually: ssh $SSH_USER@$PI_IP 'sudo /usr/local/bin/scoreboard-browser-restart.sh'"
    
elif [ "$WATCHDOG_TYPE" = "healthcheck" ]; then
    info "Installing HEALTH CHECK watchdog..."
    
    # Upload watchdog script
    info "Uploading watchdog script..."
    scp -P "$SSH_PORT" "$SCRIPT_DIR/scoreboard-browser-watchdog.sh" "$SSH_USER@$PI_IP:/tmp/"
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo mv /tmp/scoreboard-browser-watchdog.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/scoreboard-browser-watchdog.sh"
    success "Watchdog script installed"
    
    # Upload systemd files
    info "Uploading systemd timer and service..."
    scp -P "$SSH_PORT" "$SYSTEMD_DIR/scoreboard-browser-watchdog.timer" "$SSH_USER@$PI_IP:/tmp/"
    scp -P "$SSH_PORT" "$SYSTEMD_DIR/scoreboard-browser-watchdog.service" "$SSH_USER@$PI_IP:/tmp/"
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo mv /tmp/scoreboard-browser-watchdog.timer /etc/systemd/system/ && sudo mv /tmp/scoreboard-browser-watchdog.service /etc/systemd/system/"
    success "Systemd files installed"
    
    # Reload systemd and enable timer
    info "Enabling timer..."
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "sudo systemctl daemon-reload && sudo systemctl enable scoreboard-browser-watchdog.timer && sudo systemctl start scoreboard-browser-watchdog.timer"
    success "Timer enabled and started"
    
    # Show timer status
    info "Timer status:"
    ssh -p "$SSH_PORT" "$SSH_USER@$PI_IP" "systemctl list-timers scoreboard-browser-watchdog.timer --no-pager"
    
    success "Health check watchdog installed successfully!"
    info "Browser health will be checked every 5 minutes"
    info "To test manually: ssh $SSH_USER@$PI_IP 'sudo /usr/local/bin/scoreboard-browser-watchdog.sh'"
fi

# Show log file location
info ""
info "Log files:"
if [ "$WATCHDOG_TYPE" = "daily" ]; then
    info "  - /var/log/scoreboard-browser-restart.log"
    info "  - journalctl -u scoreboard-browser-restart.service"
else
    info "  - /var/log/scoreboard-browser-watchdog.log"
    info "  - journalctl -u scoreboard-browser-watchdog.service"
fi

info ""
success "Installation complete! 🎉"
