#!/bin/bash

# Start API mode console
# This script starts the Rails console in API mode

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
ENVIRONMENT="development-api"

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

# Check if API mode is active
if [ -f "config/carambus.yml" ]; then
    api_url=$(grep -A 1 "development:" config/carambus.yml | grep "carambus_api_url:" | head -1 | sed 's/.*carambus_api_url: *//')
    if [ -z "$api_url" ] || [ "$api_url" = "" ]; then
        warn "Current mode appears to be LOCAL, not API"
        warn "Consider running: bundle exec rails mode:api"
    fi
fi

# Start the console
log "Starting API mode console..."
log "Environment: $ENVIRONMENT"
log "Database: carambus_api_development"
log ""

# Set environment variables
export RAILS_ENV=development

# Start the console with the API environment
bundle exec rails console -e $ENVIRONMENT 