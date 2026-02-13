#!/bin/bash
# Carambus Scoreboard Browser Watchdog
# Monitors browser health and restarts if frozen/unresponsive
#
# This script checks if:
# 1. Chromium process is running
# 2. Web server is reachable
# 3. Browser can load the page (optional HTTP check)
#
# If any check fails, it restarts the browser

set -euo pipefail

# Configuration
LOG_FILE="/var/log/scoreboard-browser-watchdog.log"
MAX_LOG_SIZE=1048576  # 1MB
HEALTH_CHECK_TIMEOUT=10  # seconds
SERVER_URL="http://localhost:3131"  # Adjust based on your scenario

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

# Check if Chromium process is running
check_chromium_process() {
    if pgrep -x chromium-browser >/dev/null 2>&1 || pgrep -x chromium >/dev/null 2>&1; then
        log "✅ Chromium process is running"
        return 0
    else
        log "❌ Chromium process NOT found"
        return 1
    fi
}

# Check if server is reachable
check_server_reachable() {
    if curl --connect-timeout "$HEALTH_CHECK_TIMEOUT" -s -o /dev/null -w "%{http_code}" "$SERVER_URL" | grep -q "200\|302"; then
        log "✅ Server is reachable ($SERVER_URL)"
        return 0
    else
        log "⚠️  Server not reachable ($SERVER_URL)"
        return 1
    fi
}

# Check if browser can load page (via remote debugging port)
check_browser_responsive() {
    # Check if remote debugging port is accessible
    if curl --connect-timeout 5 -s http://localhost:9222/json/version >/dev/null 2>&1; then
        log "✅ Browser remote debugging port responsive"
        return 0
    else
        log "⚠️  Browser remote debugging port not responsive"
        return 1
    fi
}

# Restart browser service
restart_browser() {
    log "🔄 Restarting scoreboard-kiosk.service..."
    
    if sudo systemctl restart scoreboard-kiosk.service; then
        sleep 5
        if systemctl is-active --quiet scoreboard-kiosk.service; then
            log "✅ Browser restarted successfully"
            return 0
        else
            log "❌ ERROR: Service failed to start after restart"
            return 1
        fi
    else
        log "❌ ERROR: Failed to restart service"
        return 1
    fi
}

# Main health check
main() {
    rotate_log_if_needed
    log "=========================================="
    log "Running browser health check"
    
    # Check 1: Is Chromium running?
    if ! check_chromium_process; then
        log "⚠️  Health check FAILED: Chromium not running"
        restart_browser
        exit $?
    fi
    
    # Check 2: Is server reachable?
    if ! check_server_reachable; then
        log "⚠️  Health check WARNING: Server not reachable (but Chromium is running)"
        # Don't restart if server is down, not a browser issue
        exit 0
    fi
    
    # Check 3: Is browser responsive?
    if ! check_browser_responsive; then
        log "⚠️  Health check FAILED: Browser not responsive"
        restart_browser
        exit $?
    fi
    
    log "✅ All health checks passed"
    exit 0
}

# Run main function
main
