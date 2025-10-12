#!/bin/bash

# Start both LOCAL and API servers simultaneously
# This script opens two terminal windows, one for each server

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# Load Carambus environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/carambus_env.sh" ]; then
    source "$SCRIPT_DIR/lib/carambus_env.sh"
else
    echo "ERROR: carambus_env.sh not found"
    exit 1
fi

PROJECT_ROOT="${PROJECT_ROOT:-$CARAMBUS_API}"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "$PROJECT_ROOT/Gemfile" ]; then
    echo "Error: Not in a Rails project directory"
    exit 1
fi

cd "$PROJECT_ROOT"

# Check if we're on macOS (for osascript)
if [[ "$OSTYPE" == "darwin"* ]]; then
    log "Starting both servers on macOS..."
    
    # Start LOCAL server in new terminal
    log "Starting LOCAL server (port 3001) in new terminal..."
    osascript -e "
    tell application \"Terminal\"
        do script \"cd $PROJECT_ROOT && ./bin/start-local-server.sh\"
        set custom title of front window to \"Carambus LOCAL Server (3001)\"
    end tell
    "
    
    # Wait a moment
    sleep 2
    
    # Start API server in new terminal
    log "Starting API server (port 3000) in new terminal..."
    osascript -e "
    tell application \"Terminal\"
        do script \"cd $PROJECT_ROOT && ./bin/start-api-server.sh\"
        set custom title of front window to \"Carambus API Server (3000)\"
    end tell
    "
    
    log "Both servers started!"
    log "LOCAL server: http://localhost:3001"
    log "API server: http://localhost:3000"
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    log "Starting both servers on Linux..."
    
    # Check if gnome-terminal is available
    if command -v gnome-terminal &> /dev/null; then
        # Start LOCAL server
        log "Starting LOCAL server (port 3001)..."
        gnome-terminal --title="Carambus LOCAL Server (3001)" -- bash -c "cd $PROJECT_ROOT && ./bin/start-local-server.sh; exec bash"
        
        # Wait a moment
        sleep 2
        
        # Start API server
        log "Starting API server (port 3000)..."
        gnome-terminal --title="Carambus API Server (3000)" -- bash -c "cd $PROJECT_ROOT && ./bin/start-api-server.sh; exec bash"
        
        log "Both servers started!"
        log "LOCAL server: http://localhost:3001"
        log "API server: http://localhost:3000"
        
    else
        warn "gnome-terminal not found. Starting servers in background..."
        log "Starting LOCAL server in background..."
        nohup ./bin/start-local-server.sh > log/local-server.log 2>&1 &
        LOCAL_PID=$!
        
        log "Starting API server in background..."
        nohup ./bin/start-api-server.sh > log/api-server.log 2>&1 &
        API_PID=$!
        
        log "Both servers started in background!"
        log "LOCAL server PID: $LOCAL_PID (port 3001)"
        log "API server PID: $API_PID (port 3000)"
        log "Check logs: tail -f log/local-server.log or tail -f log/api-server.log"
    fi
    
else
    warn "Unsupported OS. Starting servers in background..."
    log "Starting LOCAL server in background..."
    nohup ./bin/start-local-server.sh > log/local-server.log 2>&1 &
    LOCAL_PID=$!
    
    log "Starting API server in background..."
    nohup ./bin/start-api-server.sh > log/api-server.log 2>&1 &
    API_PID=$!
    
    log "Both servers started in background!"
    log "LOCAL server PID: $LOCAL_PID (port 3001)"
    log "API server PID: $API_PID (port 3000)"
    log "Check logs: tail -f log/local-server.log or tail -f log/api-server.log"
fi

log ""
log "To stop servers:"
log "  - Press Ctrl+C in each terminal window, or"
log "  - Run: pkill -f 'rails server'"
log ""
log "To view logs:"
log "  - LOCAL: tail -f log/development-local.log"
log "  - API: tail -f log/development-api.log" 