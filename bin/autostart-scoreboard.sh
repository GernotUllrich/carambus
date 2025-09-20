#!/bin/bash
# Carambus Scoreboard Autostart Script
# This script is designed to be called from systemd or LXDE autostart

# Set display environment
export DISPLAY=:0

# Set up X11 authentication for user pj
if [ "$USER" = "pj" ]; then
    # Allow user pj to access X11
    xhost +local:pj 2>/dev/null || true
    
    # Try to get X11 authentication
    if [ -f /home/pj/.Xauthority ]; then
        export XAUTHORITY=/home/pj/.Xauthority
    fi
fi

# Wait for display to be ready
sleep 5

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Wait for Puma to be ready before starting scoreboard
echo "Waiting for Puma server to be ready..."

# Try to detect the Puma service name dynamically
PUMA_SERVICE=""
for service in puma-carambus_bcw.service puma-carambus.service puma.service; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        PUMA_SERVICE=$service
        break
    fi
done

if [ -n "$PUMA_SERVICE" ]; then
    PUMA_MASTER_PID=$(systemctl show -p MainPID $PUMA_SERVICE --value 2>/dev/null)
    
    if [ -n "$PUMA_MASTER_PID" ] && [ "$PUMA_MASTER_PID" != "0" ]; then
        # Check the number of worker processes (wait for at least 2)
        while [ $(pgrep -P $PUMA_MASTER_PID | wc -l) -lt 2 ]; do
            echo "Waiting for Puma server workers to start..."
            sleep 5
        done
        echo "Puma server is ready!"
    else
        echo "Puma service found but no master PID, waiting 30 seconds..."
        sleep 30
    fi
else
    echo "No Puma service found, waiting 30 seconds..."
    sleep 30
fi

# Additional wait to ensure Rails is fully loaded
sleep 10

# Get scoreboard URL - try multiple methods
SCOREBOARD_URL=""

# Method 1: Try to read from config file
if [ -f "$(dirname "$0")/../config/scoreboard_url" ]; then
    SCOREBOARD_URL=$(cat "$(dirname "$0")/../config/scoreboard_url")
fi

# Method 2: Try to detect from running services
if [ -z "$SCOREBOARD_URL" ]; then
    # Look for running carambus services to determine the correct URL
    if systemctl is-active --quiet puma-carambus_bcw.service 2>/dev/null; then
        SCOREBOARD_URL="http://192.168.178.107:3131/locations/0819bf0d7893e629200c20497ef9cfff?sb_state=welcome"
    elif systemctl is-active --quiet puma-carambus.service 2>/dev/null; then
        SCOREBOARD_URL="http://192.168.178.107:3131/locations/0819bf0d7893e629200c20497ef9cfff?sb_state=welcome"
    fi
fi

# Method 3: Default fallback
if [ -z "$SCOREBOARD_URL" ]; then
    SCOREBOARD_URL="http://192.168.178.107:3131/locations/0819bf0d7893e629200c20497ef9cfff?sb_state=welcome"
fi

echo "Using scoreboard URL: $SCOREBOARD_URL"

# Ensure chromium data directory has correct permissions for current user
if [ -d /tmp/chromium-scoreboard ]; then
    chmod 755 /tmp/chromium-scoreboard 2>/dev/null || true
fi

# Start browser in fullscreen with additional flags to handle display issues
# Note: Removed sudo - runs as current user (pj) for proper X11 access
/usr/bin/chromium-browser \
  --start-fullscreen \
  --disable-restore-session-state \
  --user-data-dir=/tmp/chromium-scoreboard \
  --disable-features=VizDisplayCompositor \
  --disable-dev-shm-usage \
  --app="$SCOREBOARD_URL" \
  --no-sandbox \
  >/dev/null 2>&1 &

# Wait and ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true

# Keep the script running to prevent systemd from restarting it
while true; do
  sleep 1
done

