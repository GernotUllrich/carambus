#!/bin/bash
# Script zum Testen der ClubCloud Login-Funktion auf dem Server
# Verwendung: ./bin/test-cc-login.sh [server]
# Beispiel: ./bin/test-cc-login.sh bc-wedel.duckdns.org

set -e

SSH_HOST="${1:-bc-wedel.duckdns.org}"
SSH_PORT="8910"
SSH_USER="www-data"
RAILS_ROOT="/var/www/carambus_bcw/current"

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

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Test SSH connection
test_ssh_connection() {
    log "Testing SSH connection to ${SSH_USER}@${SSH_HOST}:${SSH_PORT}..."
    if ! ssh -p "$SSH_PORT" -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "echo 'Connection successful'" > /dev/null 2>&1; then
        error "Cannot connect to server. Please check:"
        error "  - Server is reachable: ${SSH_HOST}"
        error "  - SSH port is correct: ${SSH_PORT}"
        error "  - User has access: ${SSH_USER}"
        exit 1
    fi
    log "✅ SSH connection successful"
}

# Test login function
test_login() {
    log "Testing ClubCloud login function..."
    info "Running: Setting.login_to_cc"
    
    ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << 'ENDSSH'
cd /var/www/carambus_bcw/current
bundle exec rails runner "
begin
  puts 'Starte Login-Test...'
  puts 'Prüfe RegionCc-Daten...'
  
  opts = RegionCcAction.get_base_opts_from_environment
  region = Region.find_by(shortname: opts[:context].upcase)
  
  if region.nil?
    puts '✗ Region nicht gefunden für context: ' + opts[:context].to_s
    exit 1
  end
  
  region_cc = region.region_cc
  if region_cc.nil?
    puts '✗ RegionCc nicht gefunden für Region: ' + region.shortname
    exit 1
  end
  
  puts 'RegionCc-Daten:'
  puts '  base_url: ' + (region_cc.base_url || '(nil)')
  puts '  username: ' + (region_cc.username || '(nil)')
  puts '  userpw: ' + (region_cc.userpw.present? ? '***' : '(nil)')
  puts ''
  
  if region_cc.base_url.blank? || region_cc.username.blank? || region_cc.userpw.blank?
    puts '✗ RegionCc-Daten unvollständig! Bitte base_url, username und userpw setzen.'
    exit 1
  end
  
  puts 'Versuche Login...'
  session_id = Setting.login_to_cc
  
  puts ''
  puts '✓ Login erfolgreich!'
  puts '  Session-ID: ' + session_id
  puts '  Gespeicherte Session-ID: ' + (Setting.key_get_value('session_id') || '(nil)')
  
rescue => e
  puts ''
  puts '✗ Fehler: ' + e.class.to_s + ': ' + e.message
  puts ''
  puts 'Stack-Trace:'
  e.backtrace.first(10).each { |line| puts '  ' + line }
  exit 1
end
"
ENDSSH
}

# Test logoff function
test_logoff() {
    log "Testing ClubCloud logoff function..."
    info "Running: Setting.logoff_from_cc"
    
    ssh -p "$SSH_PORT" "${SSH_USER}@${SSH_HOST}" << 'ENDSSH'
cd /var/www/carambus_bcw/current
bundle exec rails runner "
begin
  puts 'Starte Logoff-Test...'
  Setting.logoff_from_cc
  puts '✓ Logoff erfolgreich!'
  puts '  Session-ID gelöscht: ' + (Setting.key_get_value('session_id') || '(nil)')
rescue => e
  puts ''
  puts '✗ Fehler: ' + e.class.to_s + ': ' + e.message
  puts ''
  puts 'Stack-Trace:'
  e.backtrace.first(5).each { |line| puts '  ' + line }
  exit 1
end
"
ENDSSH
}

# Main
main() {
    log "ClubCloud Login/Logoff Test Script"
    log "Server: ${SSH_HOST}:${SSH_PORT}"
    log "User: ${SSH_USER}"
    log "Rails Root: ${RAILS_ROOT}"
    echo ""
    
    test_ssh_connection
    echo ""
    
    # Test login
    if test_login; then
        echo ""
        log "✅ Login-Test erfolgreich!"
        echo ""
        
        # Ask if user wants to test logoff
        read -p "Möchten Sie auch den Logoff testen? (j/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Jj]$ ]]; then
            test_logoff
            echo ""
            log "✅ Logoff-Test erfolgreich!"
        fi
    else
        error "Login-Test fehlgeschlagen!"
        exit 1
    fi
}

main





