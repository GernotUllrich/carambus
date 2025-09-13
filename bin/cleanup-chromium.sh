#!/bin/bash

# Chromium cleanup script for scoreboard
# This script cleans up chromium data to prevent disk space issues

echo "Cleaning up Chromium data..."

# Stop chromium browser if running (use -f to match full command line)
pkill -f chromium-browser 2>/dev/null || true
sleep 3

# Remove chromium data directory (requires sudo)
if [ -d "/tmp/chromium-scoreboard" ]; then
    echo "Removing /tmp/chromium-scoreboard..."
    sudo rm -rf /tmp/chromium-scoreboard
    echo "Chromium data cleaned up successfully."
else
    echo "No chromium data directory found."
fi

# Clean up other temporary files
echo "Cleaning up other temporary files..."
sudo rm -rf /tmp/.X* 2>/dev/null || true
sudo rm -rf /tmp/chromium* 2>/dev/null || true

# Show disk usage
echo "Current disk usage:"
df -h /

echo "Cleanup completed."
