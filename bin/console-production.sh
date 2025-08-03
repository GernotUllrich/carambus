#!/bin/bash

# Start PRODUCTION mode console
# This script starts the Rails console in PRODUCTION mode

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/Volumes/EXT2TB/gullrich/DEV/projects/carambus_api"
ENVIRONMENT="production"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "$PROJECT_ROOT/Gemfile" ]; then
    echo "Error: Not in a Rails project directory"
    exit 1
fi

cd "$PROJECT_ROOT"

# Safety check for production environment
warn "You are about to start a PRODUCTION console!"
warn "This will connect to the PRODUCTION database!"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Aborted by user"
    exit 0
fi

# Start the console
log "Starting PRODUCTION mode console..."
log "Environment: $ENVIRONMENT"
log "Database: carambus_production"
log "Logger: STDOUT (as configured in production.rb)"
log ""

# Set environment variables
export RAILS_ENV=production
export RAILS_LOG_TO_STDOUT=true

# Start the console with the PRODUCTION environment
bundle exec rails console -e $ENVIRONMENT 