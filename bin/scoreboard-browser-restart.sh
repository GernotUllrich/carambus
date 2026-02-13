#!/bin/bash
# Carambus Scoreboard Browser Restart Script
# Restarts the browser to prevent frozen displays after TV standby
#
# Usage:
#   - Run manually: ./scoreboard-browser-restart.sh
#   - Run via cron: Add to crontab for automatic daily restart
#   - Run via systemd timer: Use scoreboard-browser-restart.timer

set -euo pipefail

# Configuration
LOG_FILE="/var/log/scoreboard-browser-restart.log"
MAX_LOG_SIZE=1048576  # 1MB

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Rotate log if too large
rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        log "Log rotated"
    fi
}

# Main restart function
restart_browser() {
    log "=========================================="
    log "Starting browser restart process"
    
    # Check if scoreboard-kiosk service exists
    if ! systemctl list-unit-files | grep -q "scoreboard-kiosk.service"; then
        log "ERROR: scoreboard-kiosk.service not found"
        return 1
    fi
    
    # Check if service is active
    if ! systemctl is-active --quiet scoreboard-kiosk.service; then
        log "WARNING: scoreboard-kiosk.service is not active, starting it..."
        sudo systemctl start scoreboard-kiosk.service
        log "Service started"
        return 0
    fi
    
    # Get current status
    log "Current service status:"
    systemctl status scoreboard-kiosk.service --no-pager -l | head -20 | tee -a "$LOG_FILE"
    
    # Restart the service
    log "Restarting scoreboard-kiosk.service..."
    sudo systemctl restart scoreboard-kiosk.service
    
    # Wait for service to be ready
    sleep 5
    
    # Verify service is running
    if systemctl is-active --quiet scoreboard-kiosk.service; then
        log "✅ Browser restarted successfully"
        return 0
    else
        log "❌ ERROR: Service failed to start after restart"
        systemctl status scoreboard-kiosk.service --no-pager -l | tee -a "$LOG_FILE"
        return 1
    fi
}

# Main execution
main() {
    rotate_log_if_needed
    
    if restart_browser; then
        log "Browser restart completed successfully"
        exit 0
    else
        log "Browser restart failed"
        exit 1
    fi
}

# Run main function
main
