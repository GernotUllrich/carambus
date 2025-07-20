#!/bin/bash

# Start LOCAL mode server
# This script starts the Rails server in LOCAL mode on port 3001

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api"
PORT=3001
ENVIRONMENT="development-local"

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

# Check if LOCAL mode is active
if [ -f "config/carambus.yml" ]; then
    api_url=$(grep -A 1 "development:" config/carambus.yml | grep "carambus_api_url:" | head -1 | sed 's/.*carambus_api_url: *//')
    if [ -n "$api_url" ] && [ "$api_url" != "" ]; then
        warn "Current mode appears to be API, not LOCAL"
        warn "Consider running: ./bin/switch-mode.sh local"
    fi
fi

# Check if port is available
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    warn "Port $PORT is already in use"
    echo "Killing existing process on port $PORT..."
    lsof -ti:$PORT | xargs kill -9
    sleep 2
fi

# Create log directory if it doesn't exist
mkdir -p log

# Start the server
log "Starting LOCAL mode server on port $PORT..."
log "Environment: $ENVIRONMENT"
log "Database: carambus_local_development"
log "Log file: log/development-local.log"
log ""
log "Server will be available at: http://localhost:$PORT"
log "Press Ctrl+C to stop the server"
log ""

# Set environment variables
export RAILS_ENV=development
export RAILS_SERVE_STATIC_FILES=true
export RAILS_LOG_TO_STDOUT=false

# Start the server with the LOCAL environment
bundle exec rails server -p $PORT -e $ENVIRONMENT 