#!/bin/bash
# Script to configure Postfix relay host for carambus_bcw
# Use this when your server IP is blocklisted and you need to relay through an SMTP server

set -e

SSH_HOST="bc-wedel.duckdns.org"
SSH_PORT="8910"
SSH_USER="www-data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Main configuration
main() {
    log "🔧 Configuring Postfix Relay Host"
    log "=================================="
    echo ""
    
    info "Your server IP is blocklisted by GMX. You need to configure a relay host."
    echo ""
    info "Common relay host options:"
    info "  1. GMX SMTP: mail.gmx.net:587 (requires GMX account)"
    info "  2. Gmail SMTP: smtp.gmail.com:587 (requires Gmail app password)"
    info "  3. ISP SMTP: Check with your internet provider"
    echo ""
    
    read -p "Enter relay host (e.g., [mail.gmx.net]:587 or [smtp.gmail.com]:587): " RELAY_HOST
    
    if [ -z "$RELAY_HOST" ]; then
        error "Relay host is required"
        exit 1
    fi
    
    # Remove brackets if present for display
    RELAY_DISPLAY=$(echo "$RELAY_HOST" | sed 's/[][]//g')
    
    read -p "Does this relay require authentication? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter SMTP username (email address): " SMTP_USER
        read -sp "Enter SMTP password: " SMTP_PASS
        echo ""
        
        if [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASS" ]; then
            error "Username and password are required for authenticated relay"
            exit 1
        fi
        
        log "Configuring authenticated relay host..."
        
        ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << ENDSSH
            set -e
            
            # Create SASL password file
            echo "${RELAY_HOST}    ${SMTP_USER}:${SMTP_PASS}" | sudo tee /etc/postfix/sasl_passwd > /dev/null
            sudo chmod 600 /etc/postfix/sasl_passwd
            sudo postmap /etc/postfix/sasl_passwd
            
            # Update main.cf with relay and SASL settings
            sudo postconf -e "relayhost = ${RELAY_HOST}"
            sudo postconf -e "smtp_sasl_auth_enable = yes"
            sudo postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
            sudo postconf -e "smtp_sasl_security_options = noanonymous"
            sudo postconf -e "smtp_tls_security_level = encrypt"
            sudo postconf -e "smtp_tls_note_starttls_offer = yes"
            
            # Configure sender address to match authenticated account
            # This ensures the envelope sender matches the authenticated GMX account
            sudo postconf -e "smtp_generic_maps = hash:/etc/postfix/generic"
            
            # Create generic maps to rewrite sender addresses
            # Rewrite any local sender to the authenticated GMX address
            echo "@raspberrypi.bc-wedel.duckdns.org    ${SMTP_USER}" | sudo tee /etc/postfix/generic
            echo "@bc-wedel.duckdns.org    ${SMTP_USER}" | sudo tee -a /etc/postfix/generic
            echo "www-data@raspberrypi    ${SMTP_USER}" | sudo tee -a /etc/postfix/generic
            echo "www-data@raspberrypi.bc-wedel.duckdns.org    ${SMTP_USER}" | sudo tee -a /etc/postfix/generic
            sudo chmod 600 /etc/postfix/generic
            sudo postmap /etc/postfix/generic
            
            # Test configuration
            sudo postfix check
            
            # Reload Postfix
            sudo systemctl reload postfix
            
            echo "Relay host configured with authentication"
ENDSSH
        
        log "✅ Authenticated relay host configured"
    else
        log "Configuring unauthenticated relay host..."
        
        ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << ENDSSH
            set -e
            
            # Update main.cf with relay host
            sudo postconf -e "relayhost = ${RELAY_HOST}"
            
            # Test configuration
            sudo postfix check
            
            # Reload Postfix
            sudo systemctl reload postfix
            
            echo "Relay host configured"
ENDSSH
        
        log "✅ Relay host configured"
    fi
    
    echo ""
    log "Configuration complete!"
    log ""
    log "To test email sending:"
    log "  ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} 'echo \"Test\" | mail -s \"Test\" your@email.com'"
    log ""
    log "To check mail logs:"
    log "  ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} 'sudo tail -f /var/log/mail.log'"
}

main "$@"

