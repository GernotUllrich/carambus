#!/bin/bash

# Debug Production Console
# This script starts the Rails console in PRODUCTION mode with enhanced debugging

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
warn "You are about to start a PRODUCTION DEBUG console!"
warn "This will connect to the PRODUCTION database!"
warn "All database operations will be logged to stdout!"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Aborted by user"
    exit 0
fi

# Start the console
log "Starting PRODUCTION DEBUG console..."
log "Environment: $ENVIRONMENT"
log "Database: carambus_production"
log "Logger: STDOUT with enhanced debugging"
log ""

# Set environment variables
export RAILS_ENV=production
export RAILS_LOG_TO_STDOUT=true
export RAILS_LOG_LEVEL=debug

# Create a temporary debug script
cat > /tmp/debug_console.rb << 'EOF'
# Debug helper methods for production console
puts "=== PRODUCTION DEBUG CONSOLE ==="
puts "Available debug methods:"
puts "  debug_db_operations    - Enable SQL query logging"
puts "  stop_debug_db         - Disable SQL query logging"
puts "  debug_model(model)    - Add logging to specific model"
puts "  show_queries          - Show recent queries"
puts ""

def debug_db_operations
  ActiveRecord::Base.logger = Logger.new($stdout)
  ActiveRecord::Base.logger.level = Logger::DEBUG
  puts "✅ Database operations will now be logged to stdout"
end

def stop_debug_db
  ActiveRecord::Base.logger = nil
  puts "✅ Database logging disabled"
end

def debug_model(model_class)
  model_class.class_eval do
    after_find do |record|
      Rails.logger.info "🔍 Found #{self.class.name}: #{record.id}"
    end
    
    after_save do |record|
      Rails.logger.info "💾 Saved #{self.class.name}: #{record.id}"
    end
    
    after_destroy do |record|
      Rails.logger.info "🗑️  Destroyed #{self.class.name}: #{record.id}"
    end
  end
  puts "✅ Added logging to #{model_class.name}"
end

def show_queries
  if defined?(ActiveRecord::Base.connection.query_cache)
    puts "Recent queries:"
    ActiveRecord::Base.connection.query_cache.each_with_index do |query, index|
      puts "#{index + 1}. #{query}"
    end
  else
    puts "No query cache available"
  end
end

# Enable basic logging
Rails.logger.level = Logger::DEBUG
puts "✅ Debug logging enabled"
puts "✅ Use 'debug_db_operations' to see SQL queries"
puts ""
EOF

# Start the console with the debug script
bundle exec rails console -e $ENVIRONMENT -r /tmp/debug_console.rb 