#!/bin/bash

# Scoreboard exit script
# This script kills the browser and shows the panel again

# Kill browser
pkill chromium-browser
sleep 2

# Show panel again
wmctrl -r "panel" -b remove,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b remove,hidden 2>/dev/null || true

# Start desktop environment
pcmanfm --desktop & 
