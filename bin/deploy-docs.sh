#!/bin/bash

# Deploy MkDocs Documentation Script
# This script builds and deploys the MkDocs documentation to the Rails public directory

set -e

# Load Carambus environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/carambus_env.sh" ]; then
    source "$SCRIPT_DIR/lib/carambus_env.sh"
else
    echo "ERROR: carambus_env.sh not found"
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration - use CARAMBUS_API from environment
PROJECT_ROOT="${PROJECT_ROOT:-$CARAMBUS_API}"

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
    error "Not in a Rails project directory"
    exit 1
fi

cd "$PROJECT_ROOT"

# Check if mkdocs is available
if ! command -v mkdocs &> /dev/null; then
    error "mkdocs is not installed. Please install it first:"
    echo "  pip install mkdocs-material mkdocs-static-i18n pymdown-extensions"
    exit 1
fi

# Check if mkdocs.yml exists
if [ ! -f "mkdocs.yml" ]; then
    error "mkdocs.yml not found in current directory"
    exit 1
fi

log "Starting MkDocs documentation deployment..."

# Clean previous builds
log "Cleaning previous builds..."
bundle exec rake mkdocs:clean

# Build documentation
log "Building MkDocs documentation..."
bundle exec rake mkdocs:build

# Check if build was successful
if [ $? -eq 0 ]; then
    log "Documentation built successfully!"
    log "Documentation is now available at:"
    echo "  - Local: http://localhost:3000/docs/"
    echo "  - German: http://localhost:3000/docs/de/"
    echo "  - English: http://localhost:3000/docs/en/"
    echo ""
    
    # Check if Rails server is running
    if curl -s http://localhost:3000/ > /dev/null 2>&1; then
        log "Rails server is running. Documentation is accessible!"
    else
        warn "Rails server is not running on port 3000"
        echo "To start the Rails server, run:"
        echo "  bundle exec rails server"
        echo "  or"
        echo "  ./bin/start-local-server.sh"
        echo ""
        log "Documentation files are ready in public/docs/"
    fi
    
    log "Deployment completed successfully!"
else
    error "Failed to build documentation"
    exit 1
fi 