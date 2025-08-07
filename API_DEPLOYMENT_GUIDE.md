# API Server Docker Deployment Guide

## Overview
This guide covers deploying the Carambus API server to newapi.carambus.de using Docker.

## Prerequisites

### Server Access
- SSH access: `ssh api` or `ssh -p 8910 www-data@carambus.de`
- Domain: newapi.carambus.de
- SSL certificates for carambus.de

### Required Files
- Database dump: `carambus_api_production.sql.gz`
- Rails credentials: `production.key` and `production.yml.enc`
- SSL certificates: `carambus.de.crt` and `carambus.de.key`

## Deployment Steps

### 1. Prepare Server Environment

```bash
# Connect to server
ssh api

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add www-data to docker group
sudo usermod -aG docker www-data

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Logout and login again
exit
ssh api
```

### 2. Prepare Application Directory

```bash
# Create application directory
sudo mkdir -p /var/www/carambus_api
sudo chown www-data:www-data /var/www/carambus_api
cd /var/www/carambus_api

# Clone repository (if not already present)
git clone https://github.com/your-repo/carambus_api.git .
git checkout master

# Create required directories
mkdir -p shared/config/credentials
mkdir -p ssl
mkdir -p log storage tmp
```

### 3. Copy Production Data

```bash
# Copy database dump (from local machine)
scp carambus_api_production.sql.gz www-data@carambus.de:/var/www/carambus_api/

# Copy Rails credentials
scp production.* www-data@carambus.de:/var/www/carambus_api/shared/config/credentials/

# Copy SSL certificates
scp carambus.de.crt carambus.de.key www-data@carambus.de:/var/www/carambus_api/ssl/
```

### 4. Configure Application

```bash
# Set proper permissions
chmod 600 shared/config/credentials/production.key
chmod 644 ssl/*

# Create .env file for environment variables
cat > .env << EOF
RAILS_ENV=production
DATABASE_URL=postgresql://www_data:toS6E7tARQafHCXz@postgres:5432/carambus_api_production
REDIS_URL=redis://redis:6379/0
EOF
```

### 5. Build and Deploy

```bash
# Build images
docker-compose -f docker-compose.api.yml build --no-cache

# Start services
docker-compose -f docker-compose.api.yml up -d

# Check status
docker-compose -f docker-compose.api.yml ps
```

### 6. Initialize Database

```bash
# Wait for PostgreSQL to start
sleep 30

# Run database migrations
docker-compose -f docker-compose.api.yml exec web bundle exec rails db:migrate

# Check database connection
docker-compose -f docker-compose.api.yml exec postgres psql -U www_data -d carambus_api_production -c "SELECT COUNT(*) FROM users;"
```

### 7. Test Deployment

```bash
# Test API endpoints
curl -k https://newapi.carambus.de/health
curl -k https://newapi.carambus.de/api/v1/status

# Check logs
docker-compose -f docker-compose.api.yml logs web
```

## Configuration Files

### Dockerfile.api
- Simplified Rails application setup
- No Carambus-specific configuration
- Production-optimized

### docker-compose.api.yml
- PostgreSQL database
- Redis cache
- Rails API server
- Nginx reverse proxy with SSL

### nginx.api.conf
- SSL termination
- API proxy configuration
- Security headers
- Health check endpoint

## Monitoring and Maintenance

### Health Checks
```bash
# Check service status
docker-compose -f docker-compose.api.yml ps

# Check logs
docker-compose -f docker-compose.api.yml logs -f

# Monitor resources
docker stats
```

### Backup
```bash
# Backup database
docker-compose -f docker-compose.api.yml exec postgres pg_dump -U www_data carambus_api_production > backup.sql

# Backup configuration
tar -czf config_backup.tar.gz shared/config/credentials ssl/
```

### Updates
```bash
# Pull latest code
git pull origin master

# Rebuild and restart
docker-compose -f docker-compose.api.yml down
docker-compose -f docker-compose.api.yml build --no-cache
docker-compose -f docker-compose.api.yml up -d
```

## Troubleshooting

### Common Issues

#### Database Connection
```bash
# Check PostgreSQL logs
docker-compose -f docker-compose.api.yml logs postgres

# Test connection
docker-compose -f docker-compose.api.yml exec web bundle exec rails console
```

#### SSL Issues
```bash
# Check SSL certificate
openssl x509 -in ssl/carambus.de.crt -text -noout

# Test SSL connection
curl -v https://newapi.carambus.de/health
```

#### API Errors
```bash
# Check Rails logs
docker-compose -f docker-compose.api.yml logs web

# Test API directly
curl -H "Content-Type: application/json" https://newapi.carambus.de/api/v1/endpoint
```

## Success Criteria

✅ **Deployment Complete When:**
1. All Docker services show "Up" status
2. Database contains production data
3. API responds on https://newapi.carambus.de
4. SSL certificate working correctly
5. Health check endpoint returns "healthy"
6. No critical errors in logs

## Rollback Plan

If deployment fails:
1. Stop services: `docker-compose -f docker-compose.api.yml down`
2. Remove volumes: `docker-compose -f docker-compose.api.yml down -v`
3. Restore from backup or redeploy from previous version 