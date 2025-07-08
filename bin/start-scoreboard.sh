#!/bin/bash

# Scoreboard startup script
# This script hides the panel and starts Chromium in fullscreen mode

# Set display environment
export DISPLAY=:0

# Wait for display to be ready
sleep 2

# Hide panel
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Start browser in fullscreen with additional flags to handle display issues
/usr/bin/chromium-browser \
  --start-fullscreen \
  --disable-restore-session-state \
  --user-data-dir=/tmp/chromium-scoreboard \
  --disable-features=VizDisplayCompositor \
  --disable-dev-shm-usage \
  --app="$(cat $(dirname "$0")/../config/scoreboard_url)" \
  >/dev/null 2>&1 &

# Wait and ensure fullscreen
sleep 5
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true 
