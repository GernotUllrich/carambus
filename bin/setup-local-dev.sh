#!/bin/bash

# Local development script for carambus_local_hetzner
# This script sets up the local environment for testing the local server

set -e

echo "🚀 Setting up local development environment for carambus_local_hetzner..."

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
    echo "❌ Error: Not in a Rails project directory"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
bundle install
yarn install

# Compile assets
echo "🎨 Compiling assets..."
yarn build && yarn build:css

# Use development database config
echo "🗄️  Using development database configuration..."
cp config/database.development.yml config/database.yml

# Create database
echo "🗄️  Creating development database..."
RAILS_ENV=development bundle exec rails db:create

# Run migrations
echo "🔄 Running migrations..."
RAILS_ENV=development bundle exec rails db:migrate || echo "⚠️  Some migrations failed (this is normal for development)"

# Seed database (if needed)
echo "🌱 Seeding database..."
RAILS_ENV=development bundle exec rails db:seed || echo "⚠️  Seeding failed (this is normal for development)"

echo "✅ Local development environment ready!"
echo ""
echo "🎯 Next steps:"
echo "  1. Start the server: bundle exec rails server"
echo "  2. Open browser: http://localhost:3000"
echo "  3. To reset database: bundle exec rails db:reset"
echo ""
echo "📝 Note: This uses the LOCAL mode configuration"
echo "   - Database: carambus_local_development"
echo "   - User: gullrich"
echo "   - Mode: Local server (filtered data)"
