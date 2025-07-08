#!/bin/bash
# Debug script to test scoreboard startup
# This will help diagnose why autostart isn't working

echo "Starting test at $(date)" >> /tmp/scoreboard-debug.log
echo "Current user: $(whoami)" >> /tmp/scoreboard-debug.log
echo "Current directory: $(pwd)" >> /tmp/scoreboard-debug.log
echo "Script location: $(dirname "$0")" >> /tmp/scoreboard-debug.log
echo "wmctrl available: $(which wmctrl)" >> /tmp/scoreboard-debug.log

# Check if config file exists and is readable
if [ -f "$(dirname "$0")/../config/scoreboard_url" ]; then
    echo "Config file exists and content: $(cat $(dirname "$0")/../config/scoreboard_url)" >> /tmp/scoreboard-debug.log
else
    echo "Config file NOT found at $(dirname "$0")/../config/scoreboard_url" >> /tmp/scoreboard-debug.log
fi

# Check if start script exists and is executable
if [ -x "$(dirname "$0")/start-scoreboard.sh" ]; then
    echo "Start script exists and is executable" >> /tmp/scoreboard-debug.log
else
    echo "Start script NOT found or NOT executable at $(dirname "$0")/start-scoreboard.sh" >> /tmp/scoreboard-debug.log
fi

# Try to run the actual startup script
echo "Attempting to run startup script..." >> /tmp/scoreboard-debug.log
$(dirname "$0")/start-scoreboard.sh

echo "Test completed at $(date)" >> /tmp/scoreboard-debug.log 