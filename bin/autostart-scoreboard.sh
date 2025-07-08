#!/bin/bash
# Autostart wrapper for scoreboard
# This script is designed to be called from LXDE autostart

# Create log file with timestamp
echo "=== Autostart script started at $(date) ===" >> /tmp/scoreboard-autostart.log

# Set proper environment
export DISPLAY=:0
export XAUTHORITY=/home/pj/.Xauthority

# Log environment
echo "DISPLAY: $DISPLAY" >> /tmp/scoreboard-autostart.log
echo "USER: $(whoami)" >> /tmp/scoreboard-autostart.log
echo "PWD: $(pwd)" >> /tmp/scoreboard-autostart.log

# Wait for display system to be ready
echo "Waiting for display..." >> /tmp/scoreboard-autostart.log
sleep 5

# Wait for Rails server (Puma) to be ready
echo "Waiting for Rails server to start..." >> /tmp/scoreboard-autostart.log
PUMA_MASTER_PID=$(systemctl show -p MainPID puma.service --value 2>/dev/null)

if [ -n "$PUMA_MASTER_PID" ]; then
    # check the number of worker processes
    while [ $(pgrep -P $PUMA_MASTER_PID | wc -l) -ne 4 ]; do
        echo "Waiting for Puma server workers to start..." >> /tmp/scoreboard-autostart.log
        sleep 5
    done
    echo "Puma server is ready" >> /tmp/scoreboard-autostart.log
else
    echo "Puma service not found, waiting 30 seconds..." >> /tmp/scoreboard-autostart.log
    sleep 30
fi

# Check if we're in a graphical session
if [ -z "$DISPLAY" ]; then
    echo "ERROR: No display available, exiting" >> /tmp/scoreboard-autostart.log
    exit 1
fi

# Check if wmctrl is available
if ! command -v wmctrl &> /dev/null; then
    echo "wmctrl not found, installing..." >> /tmp/scoreboard-autostart.log
    sudo apt update && sudo apt install -y wmctrl
fi

# Check if the startup script exists
if [ ! -f "$(dirname "$0")/start-scoreboard.sh" ]; then
    echo "ERROR: start-scoreboard.sh not found at $(dirname "$0")/start-scoreboard.sh" >> /tmp/scoreboard-autostart.log
    exit 1
fi

# Check if config file exists
if [ ! -f "$(dirname "$0")/../config/scoreboard_url" ]; then
    echo "ERROR: config/scoreboard_url not found" >> /tmp/scoreboard-autostart.log
    exit 1
fi

# Run the actual startup script
echo "Starting scoreboard at $(date)" >> /tmp/scoreboard-autostart.log
$(dirname "$0")/start-scoreboard.sh

echo "Autostart completed at $(date)" >> /tmp/scoreboard-autostart.log

