# Docker Fresh Install Guide - Carambus

## Overview
This guide provides step-by-step instructions for setting up Carambus on a fresh Raspberry Pi SD card using Docker.

## Prerequisites

### Hardware Requirements
- Raspberry Pi 4 (4GB RAM recommended)
- 32GB+ SD card
- Network connection

### Required Files (from working server)
- Database dump: `carambus_production_20250805_224054.sql.gz`
- Rails credentials: `production.key` and `production.yml.enc`
- REVISION file with current Git hash

## Step 1: Prepare Fresh SD Card

### 1.1 Flash Raspberry Pi OS
```bash
# Download Raspberry Pi OS Lite (64-bit recommended)
# Use Raspberry Pi Imager to flash to SD card
# Enable SSH during setup
```

### 1.2 Initial Setup
```bash
# Connect to Pi via SSH
ssh pi@192.168.178.53

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add pi user to docker group
sudo usermod -aG docker pi

# Logout and login again for group changes
exit
ssh pi@192.168.178.53

# Install Docker Compose
sudo apt install docker-compose-plugin -y
```

## Step 2: Prepare Application Files

### 2.1 Clone Repository
```bash
# On the Pi
cd /home/pi
git clone https://github.com/your-repo/carambus.git
cd carambus
git checkout master
```

### 2.2 Create Required Directories
```bash
# Create directories for production data
mkdir -p doc/doc-local/docker/shared/config/credentials
mkdir -p tmp/pids tmp/cache tmp/sockets
mkdir -p log storage
```

### 2.3 Copy Production Data
```bash
# Copy from working server (bvbw) to local machine, then to Pi
# Database dump
scp bvbw:/var/www/carambus/shared/db/carambus_production_20250805_224054.sql.gz pi@192.168.178.53:/home/pi/carambus/doc/doc-local/docker/

# Rails credentials
scp bvbw:/var/www/carambus/shared/config/credentials/production.* pi@192.168.178.53:/home/pi/carambus/doc/doc-local/docker/shared/config/credentials/

# REVISION file
scp bvbw:/var/www/carambus/current/REVISION pi@192.168.178.53:/home/pi/carambus/
```

### 2.4 Set Permissions
```bash
# Set proper permissions
chmod -R 777 tmp log storage
chmod 600 doc/doc-local/docker/shared/config/credentials/production.key
```

## Step 3: Build and Start Services

### 3.1 Build Images
```bash
# Build all services
docker-compose build --no-cache
```

### 3.2 Start Services
```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### 3.3 Verify Database
```bash
# Check if database is populated
docker-compose exec postgres psql -U www_data -d carambus_production -c "SELECT COUNT(*) FROM users;"
```

## Step 4: Test Application

### 4.1 Test Web Application
```bash
# Test from local machine
curl -I http://192.168.178.53:3000

# Test login page
curl http://192.168.178.53:3000/login
```

### 4.2 Test Cron Jobs
```bash
# Check cron service status
docker-compose ps cron

# Test manual rake task
docker-compose exec cron bundle exec rake mode:backup

# Check crontab
docker-compose exec cron crontab -l
```

### 4.3 Test Asset Pipeline
```bash
# Check if CSS and JS are loading
curl http://192.168.178.53:3000/login | grep -E "(stylesheet|script)"
```

## Step 5: Verification Checklist

### ✅ System Setup
- [ ] Docker installed and working
- [ ] Docker Compose installed
- [ ] User added to docker group

### ✅ Application Files
- [ ] Repository cloned
- [ ] Production data copied
- [ ] Permissions set correctly

### ✅ Database
- [ ] PostgreSQL container running
- [ ] Database populated with data
- [ ] Rails can connect to database

### ✅ Web Application
- [ ] Rails application responding
- [ ] CSS and JavaScript loading
- [ ] Login page accessible

### ✅ Cron Jobs
- [ ] Cron service running
- [ ] Crontab loaded
- [ ] Rake tasks executing

### ✅ Logs
- [ ] Application logs accessible
- [ ] Cron logs being written
- [ ] No critical errors

## Step 6: Troubleshooting

### Common Issues

#### Database Connection Issues
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Check database connectivity
docker-compose exec web bundle exec rails console
```

#### Asset Pipeline Issues
```bash
# Rebuild assets
docker-compose exec web bundle exec rails assets:precompile

# Check asset files
docker-compose exec web ls -la /app/public/assets/
```

#### Credential Issues
```bash
# Check credentials in cron container
docker-compose exec cron ls -la /app/config/credentials/

# Manually copy if needed
docker cp carambus_web:/app/config/credentials/production.* ./ && docker cp ./production.* carambus-cron-1:/app/config/credentials/
```

#### Permission Issues
```bash
# Fix permissions
chmod -R 777 tmp log storage
chmod 600 doc/doc-local/docker/shared/config/credentials/production.key
```

## Step 7: Final Verification

### 7.1 Complete System Test
```bash
# Test all services
docker-compose ps

# Test web application
curl -s http://192.168.178.53:3000/login | grep -q "Carambus" && echo "✅ Web app working" || echo "❌ Web app failed"

# Test cron
docker-compose exec cron bundle exec rake mode:backup && echo "✅ Cron working" || echo "❌ Cron failed"
```

### 7.2 Performance Check
```bash
# Check resource usage
docker stats --no-stream

# Check disk space
df -h
```

## Step 8: Documentation

### 8.1 Create Local Documentation
```bash
# Copy documentation files
cp DOCKER_CRON_README.md /home/pi/carambus/
cp DOCKER_README.md /home/pi/carambus/
```

### 8.2 Update Configuration
```bash
# Note any custom configurations
# Document any manual steps required
# Create maintenance procedures
```

## Success Criteria

The installation is successful when:
1. ✅ Web application responds on port 3000
2. ✅ Database contains production data
3. ✅ CSS and JavaScript load correctly
4. ✅ Cron jobs are scheduled and working
5. ✅ All services show as "healthy" in `docker-compose ps`
6. ✅ No critical errors in logs

## Next Steps

After successful installation:
1. Set up monitoring and alerting
2. Configure backups
3. Set up SSL/TLS certificates
4. Configure firewall rules
5. Set up log rotation
6. Create maintenance procedures

## Rollback Plan

If issues occur:
1. Stop all services: `docker-compose down`
2. Remove volumes: `docker-compose down -v`
3. Start fresh: Follow this guide from Step 1 