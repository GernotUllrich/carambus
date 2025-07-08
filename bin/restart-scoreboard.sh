#!/bin/bash

# Scoreboard restart script
# This script kills desktop apps and restarts the scoreboard

# Kill desktop apps
pkill pcmanfm 2>/dev/null || true

# Restart scoreboard
$(dirname "$0")/start-scoreboard.sh 
