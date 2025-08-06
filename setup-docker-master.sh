#!/bin/bash

# Carambus Docker Setup Script for Master Branch
# This script sets up the Docker environment with production data

set -e

echo "🚀 Setting up Carambus Docker environment (Master Branch)..."

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if production files exist
if [ ! -f "docker-production-data/carambus_production_20250805_224054.sql.gz" ]; then
    echo "❌ Production database dump not found: docker-production-data/carambus_production_20250805_224054.sql.gz"
    exit 1
fi

if [ ! -f "docker-production-data/shared/config/credentials/production.yml.enc" ]; then
    echo "❌ Production credentials not found: docker-production-data/shared/config/credentials/production.yml.enc"
    exit 1
fi

echo "✅ Production files found"

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p storage log tmp/cache/assets

# Set proper permissions
echo "🔐 Setting permissions..."
chmod -R 755 storage log tmp

# Build and start containers
echo "🔨 Building Docker containers..."
docker-compose build --no-cache

echo "🚀 Starting services..."
docker-compose up -d postgres redis

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker-compose exec -T postgres pg_isready -U carambus -d carambus_production; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done

echo "✅ PostgreSQL is ready"

# Import production database
echo "📊 Importing production database..."
docker-compose exec -T postgres gunzip -c /docker-entrypoint-initdb.d/carambus_production.sql.gz | docker-compose exec -T postgres psql -U carambus -d carambus_production

echo "✅ Database imported successfully"

# Start the Rails application
echo "🌐 Starting Rails application..."
docker-compose up -d web

# Wait for Rails to be ready
echo "⏳ Waiting for Rails application to be ready..."
until curl -f http://localhost:3000/health 2>/dev/null; do
    echo "Waiting for Rails application..."
    sleep 5
done

echo "✅ Rails application is ready"

# Start nginx
echo "🌐 Starting nginx..."
docker-compose up -d nginx

echo "🎉 Carambus Docker setup complete!"
echo ""
echo "📋 Services:"
echo "  - Web application: http://localhost:3000"
echo "  - Nginx proxy: http://localhost:80"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379"
echo ""
echo "🔧 Useful commands:"
echo "  - View logs: docker-compose logs -f"
echo "  - Stop services: docker-compose down"
echo "  - Restart services: docker-compose restart"
echo "  - Access Rails console: docker-compose exec web bundle exec rails console"
echo "" 