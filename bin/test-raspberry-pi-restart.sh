#!/bin/bash
# Test script for Raspberry Pi client restart functionality

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

# Test SSH connection
test_ssh_connection() {
    local ip="$1"
    local user="$2"
    local password="$3"
    
    log "Testing SSH connection to $user@$ip..."
    
    if sshpass -p "$password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$ip" 'echo "SSH connection successful"' 2>/dev/null; then
        log "✅ SSH connection successful"
        return 0
    else
        error "❌ SSH connection failed"
        return 1
    fi
}

# Test browser restart command
test_browser_restart() {
    local ip="$1"
    local user="$2"
    local password="$3"
    local restart_command="$4"
    
    log "Testing browser restart command: $restart_command"
    
    if sshpass -p "$password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$ip" "$restart_command" 2>/dev/null; then
        log "✅ Browser restart command executed successfully"
        return 0
    else
        error "❌ Browser restart command failed"
        return 1
    fi
}

# Test browser process
test_browser_process() {
    local ip="$1"
    local user="$2"
    local password="$3"
    
    log "Testing browser process..."
    
    # Wait a bit for browser to start
    sleep 5
    
    if sshpass -p "$password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$ip" 'pgrep chromium-browser' 2>/dev/null; then
        log "✅ Browser process is running"
        return 0
    else
        warning "⚠️  Browser process not found (may be starting up)"
        return 1
    fi
}

# Test systemd service
test_systemd_service() {
    local ip="$1"
    local user="$2"
    local password="$3"
    
    log "Testing systemd service..."
    
    if sshpass -p "$password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$user@$ip" 'sudo systemctl is-active scoreboard-kiosk' 2>/dev/null; then
        log "✅ Systemd service is active"
        return 0
    else
        warning "⚠️  Systemd service is not active"
        return 1
    fi
}

# Main test function
main() {
    local scenario_name="$1"
    
    if [ -z "$scenario_name" ]; then
        error "Usage: $0 <scenario_name>"
        error "Example: $0 carambus_location_2459"
        exit 1
    fi
    
    log "Testing Raspberry Pi client restart functionality for $scenario_name"
    
    # Load scenario configuration
    local config_file="../carambus_data/scenarios/$scenario_name/config.yml"
    
    if [ ! -f "$config_file" ]; then
        error "Scenario configuration not found: $config_file"
        exit 1
    fi
    
    # Extract configuration values (simplified parsing)
    local pi_ip=$(grep -A 20 "raspberry_pi_client:" "$config_file" | grep "ip_address:" | cut -d'"' -f2)
    local ssh_user=$(grep -A 20 "raspberry_pi_client:" "$config_file" | grep "ssh_user:" | cut -d'"' -f2)
    local ssh_password=$(grep -A 20 "raspberry_pi_client:" "$config_file" | grep "ssh_password:" | cut -d'"' -f2)
    local restart_command=$(grep -A 20 "raspberry_pi_client:" "$config_file" | grep "browser_restart_command:" | cut -d'"' -f2)
    
    if [ -z "$pi_ip" ] || [ -z "$ssh_user" ] || [ -z "$ssh_password" ]; then
        error "Missing Raspberry Pi client configuration"
        exit 1
    fi
    
    # Set default restart command if not specified
    if [ -z "$restart_command" ]; then
        restart_command="sudo systemctl restart scoreboard-kiosk"
    fi
    
    info "Configuration:"
    info "  IP: $pi_ip"
    info "  User: $ssh_user"
    info "  Restart Command: $restart_command"
    
    # Run tests
    local test_results=()
    
    # Test 1: SSH connection
    if test_ssh_connection "$pi_ip" "$ssh_user" "$ssh_password"; then
        test_results+=("SSH: ✅")
    else
        test_results+=("SSH: ❌")
    fi
    
    # Test 2: Systemd service
    if test_systemd_service "$pi_ip" "$ssh_user" "$ssh_password"; then
        test_results+=("Service: ✅")
    else
        test_results+=("Service: ❌")
    fi
    
    # Test 3: Browser restart
    if test_browser_restart "$pi_ip" "$ssh_user" "$ssh_password" "$restart_command"; then
        test_results+=("Restart: ✅")
    else
        test_results+=("Restart: ❌")
    fi
    
    # Test 4: Browser process
    if test_browser_process "$pi_ip" "$ssh_user" "$ssh_password"; then
        test_results+=("Browser: ✅")
    else
        test_results+=("Browser: ❌")
    fi
    
    # Summary
    log "Test Results:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    
    # Check if all tests passed
    local failed_tests=$(echo "${test_results[@]}" | grep -c "❌" || true)
    
    if [ "$failed_tests" -eq 0 ]; then
        log "🎉 All tests passed! Raspberry Pi client restart functionality is working correctly."
    else
        warning "⚠️  $failed_tests test(s) failed. Please check the configuration and Raspberry Pi setup."
    fi
}

# Check dependencies
if ! command -v sshpass &> /dev/null; then
    error "sshpass is required but not installed. Please install it:"
    error "  macOS: brew install hudochenkov/sshpass/sshpass"
    error "  Ubuntu: sudo apt install sshpass"
    exit 1
fi

# Run main function
main "$@"
