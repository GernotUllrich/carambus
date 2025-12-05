#!/bin/bash
# Quick fix script to configure Postfix sender address for GMX relay
# This fixes the "Sender address is not allowed" error

set -e

SSH_HOST="bc-wedel.duckdns.org"
SSH_PORT="8910"
SSH_USER="www-data"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log "🔧 Fixing Postfix sender address configuration"
log "=============================================="
echo ""

read -p "Enter your GMX email address (e.g., gernot.ullrich@gmx.de): " GMX_EMAIL

if [ -z "$GMX_EMAIL" ]; then
    echo "ERROR: GMX email address is required"
    exit 1
fi

log "Configuring Postfix to use ${GMX_EMAIL} as sender address..."

ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << ENDSSH
    set -e
    
    # Configure generic maps to rewrite sender addresses
    sudo postconf -e "smtp_generic_maps = hash:/etc/postfix/generic"
    
    # Create generic maps file
    echo "@raspberrypi.bc-wedel.duckdns.org    ${GMX_EMAIL}" | sudo tee /etc/postfix/generic
    echo "@bc-wedel.duckdns.org    ${GMX_EMAIL}" | sudo tee -a /etc/postfix/generic
    echo "www-data@raspberrypi    ${GMX_EMAIL}" | sudo tee -a /etc/postfix/generic
    echo "www-data@raspberrypi.bc-wedel.duckdns.org    ${GMX_EMAIL}" | sudo tee -a /etc/postfix/generic
    echo "root@raspberrypi    ${GMX_EMAIL}" | sudo tee -a /etc/postfix/generic
    echo "root@raspberrypi.bc-wedel.duckdns.org    ${GMX_EMAIL}" | sudo tee -a /etc/postfix/generic
    
    sudo chmod 600 /etc/postfix/generic
    sudo postmap /etc/postfix/generic
    
    # Test configuration
    sudo postfix check
    
    # Reload Postfix
    sudo systemctl reload postfix
    
    echo "Sender address configuration updated"
ENDSSH

log "✅ Postfix sender address configured"
log ""
log "All emails will now be sent from: ${GMX_EMAIL}"
log ""
log "To test:"
log "  ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} 'echo \"Test\" | mail -s \"Test\" your@email.com'"

