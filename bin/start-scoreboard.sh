#!/bin/bash

# Scoreboard startup script
# This script hides the panel and starts Chromium in fullscreen mode

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Start browser in fullscreen
/usr/bin/chromium-browser --start-fullscreen --disable-restore-session-state --app="$(cat $(dirname "$0")/../config/scoreboard_url)" &

# Wait and ensure fullscreen
sleep 3
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true 
