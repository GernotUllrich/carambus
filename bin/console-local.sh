#!/bin/bash

# Start LOCAL mode console
# This script starts the Rails console in LOCAL mode

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api"
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

# Start the console
log "Starting LOCAL mode console..."
log "Environment: $ENVIRONMENT"
log "Database: carambus_local_development"
log ""

# Set environment variables
export RAILS_ENV=development

# Start the console with the LOCAL environment
bundle exec rails console -e $ENVIRONMENT 