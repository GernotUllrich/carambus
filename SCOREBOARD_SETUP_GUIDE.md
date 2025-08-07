# Carambus Scoreboard Setup Guide

## Overview

This guide provides step-by-step instructions for setting up a Carambus scoreboard on a Raspberry Pi 4 using Docker. The scoreboard will run the full Carambus application in a browser with auto-start and fullscreen capabilities.

## Prerequisites

### Hardware Requirements
- Raspberry Pi 4 (4GB RAM recommended)
- 32GB+ microSD card
- Monitor/display for scoreboard interface
- Network connection
- Power supply (5V/3A recommended)

### Software Requirements
- Raspberry Pi OS Desktop (64-bit)
- Docker and Docker Compose
- Git with SSH access
- Production data from working server

## Installation Steps

### Phase 1: System Setup

#### 1. Flash Raspberry Pi OS
```bash
# Download Raspberry Pi OS Desktop (64-bit)
# Flash to microSD card using Raspberry Pi Imager
# Enable SSH during setup
# Enable VNC if needed for remote desktop access
```

#### 2. Initial Configuration
```bash
# Connect via SSH
ssh pi@192.168.178.53

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker pi

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Logout and login again
exit
ssh pi@192.168.178.53
```

#### 3. Configure Desktop for Scoreboard
```bash
# Enable auto-login (optional)
sudo raspi-config
# Navigate to: System Options > Boot / Auto Login > Desktop Autologin

# Configure display settings
# - Set appropriate resolution for your monitor
# - Disable screen saver
# - Configure for landscape orientation if needed
```

### Phase 2: GitHub SSH Setup

#### 1. Generate SSH Key
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""
```

#### 2. Configure SSH Agent
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

#### 3. Add GitHub to Known Hosts
```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

#### 4. Add Key to GitHub
```bash
# Display public key
cat ~/.ssh/id_ed25519.pub

# Copy this key and add it to your GitHub repository:
# - Go to GitHub repository settings
# - Navigate to Deploy keys
# - Add the SSH key with write access
```

#### 5. Test GitHub Connection
```bash
ssh -T git@github.com
# Should show: "Hi username! You've successfully authenticated..."
```

### Phase 3: Application Setup

#### 1. Clone Repository
```bash
cd /home/pi
git clone git@github.com:GernotUllrich/carambus.git
cd carambus
git checkout master
```

#### 2. Create Required Directories
```bash
mkdir -p doc/doc-local/docker/shared/config/credentials
mkdir -p tmp/pids tmp/cache tmp/sockets
mkdir -p log storage
chmod -R 777 tmp log storage
```

#### 3. Copy Production Data
```bash
# From your local machine, copy production data:
scp docker-production-data/carambus_production_20250805_224054.sql.gz pi@192.168.178.53:/home/pi/carambus/doc/doc-local/docker/
scp doc/doc-local/docker/shared/config/credentials/production.* pi@192.168.178.53:/home/pi/carambus/doc/doc-local/docker/shared/config/credentials/

# Create REVISION file
git rev-parse HEAD > REVISION
scp REVISION pi@192.168.178.53:/home/pi/carambus/

# Set proper permissions
chmod 600 doc/doc-local/docker/shared/config/credentials/production.key
```

### Phase 4: Database Configuration

#### 1. Fix Database Dump
```bash
# Fix user references in database dump
gunzip -c doc/doc-local/docker/carambus_production_20250805_224054.sql.gz | \
sed 's/OWNER TO gullrich/OWNER TO www_data/g' | \
sed 's/OWNER TO \"gullrich\"/OWNER TO \"www_data\"/g' | \
gzip > doc/doc-local/docker/carambus_production_fixed.sql.gz
```

#### 2. Update Docker Compose Configuration
```bash
# Update database user and password
sed -i 's/POSTGRES_USER: carambus/POSTGRES_USER: www_data/g' docker-compose.yml
sed -i 's/POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-carambus_password}/POSTGRES_PASSWORD: toS6E7tARQafHCXz/g' docker-compose.yml

# Update database dump filename
sed -i 's/carambus_production_20250805_224054.sql.gz/carambus_production_fixed.sql.gz/g' docker-compose.yml

# Remove obsolete version attribute
sed -i '/^version:/d' docker-compose.yml
```

### Phase 5: Build and Deploy

#### 1. Build Docker Images
```bash
docker compose build --no-cache
```

#### 2. Start Services
```bash
docker compose up -d
```

#### 3. Wait for Startup
```bash
sleep 30
docker compose ps
```

### Phase 6: Asset Pipeline Configuration

#### 1. Fix Asset Manifest
```bash
docker compose exec -u root web bash -c 'cat > /app/app/assets/config/manifest.js << EOF
//= link_tree ../builds
//= link_tree ../images
//= link rails-ujs.js
//= link application.js
//= link application.css
EOF'
```

#### 2. Fix CSS Configuration
```bash
docker compose exec -u root web bash -c 'cat > /app/app/assets/stylesheets/application.css << EOF
@import "application.tailwind";
/* Scoreboard menu styles */
.scoreboard-menu {
  gap: 0.5rem !important;
}
.scoreboard-menu-btn {
  background: transparent;
  border: none;
  padding: 0.2em 0.2em;
  border-radius: 0.5em;
  transition: background 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}
.scoreboard-menu-btn:active, .scoreboard-menu-btn-active {
  background: #2d3748;
  outline: 2px solid #e53e3e;
}
.scoreboard-menu-icon,
.scoreboard-menu-text {
  color: inherit;
}
.scoreboard-menu-text {
  font-size: 0.875rem;
  font-weight: 500;
}
.scoreboard-menu-btn:hover {
  background: rgba(255, 255, 255, 0.1);
}
.scoreboard-menu-btn:focus {
  outline: 2px solid #e53e3e;
  outline-offset: 2px;
}
EOF'
```

#### 3. Disable SSL for Testing
```bash
docker compose exec -u root web sed -i 's/config.force_ssl = true/# config.force_ssl = true/' /app/config/environments/production.rb
```

#### 4. Build Assets
```bash
# Build JavaScript and CSS
docker compose exec web yarn build
docker compose exec web yarn build:css

# Precompile assets
docker compose exec web bundle exec rails assets:precompile

# Restart web service
docker compose restart web
```

### Phase 7: Scoreboard Configuration

#### 1. Create Auto-Start Script
```bash
# Create scoreboard startup script
cat > ~/scoreboard-start.sh << 'EOF'
#!/bin/bash

# Wait for network
sleep 10

# Start browser in kiosk mode
chromium-browser --kiosk --disable-web-security --user-data-dir=/tmp/chrome-data http://localhost:3000/scoreboard

# Alternative: Use Firefox
# firefox --kiosk http://localhost:3000/scoreboard
EOF

chmod +x ~/scoreboard-start.sh
```

#### 2. Configure Auto-Start
```bash
# Add to autostart
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/scoreboard.desktop << EOF
[Desktop Entry]
Type=Application
Name=Carambus Scoreboard
Exec=/home/pi/scoreboard-start.sh
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
```

#### 3. Configure Display Settings
```bash
# Disable screen saver
xset s off
xset -dpms

# Add to ~/.bashrc for persistence
echo 'xset s off' >> ~/.bashrc
echo 'xset -dpms' >> ~/.bashrc
```

### Phase 8: Testing and Verification

#### 1. Test Application
```bash
# Test web application
curl -I http://localhost:3000/login

# Test external access
curl -I http://192.168.178.53:3000/login

# Test asset pipeline
curl -s http://localhost:3000/login | grep -E "(stylesheet|script)"
```

#### 2. Test Scoreboard Interface
```bash
# Open browser manually first
chromium-browser http://localhost:3000/scoreboard

# Test fullscreen mode (F11)
# Test scoreboard menu navigation
# Test real-time updates
```

#### 3. Run Comprehensive Test
```bash
./test-docker-setup.sh
```

## Troubleshooting

### GitHub SSH Issues
```bash
# Check SSH key
ls -la ~/.ssh/id_ed25519*

# Test connection
ssh -T git@github.com

# Add to known hosts if needed
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

### Database Issues
```bash
# Check PostgreSQL logs
docker compose logs postgres

# Check database connection
docker compose exec postgres psql -U www_data -d carambus_production -c "SELECT COUNT(*) FROM users;"

# Recreate database if needed
docker compose down -v
docker compose up -d postgres
```

### Asset Pipeline Issues
```bash
# Check manifest.js
docker compose exec web cat /app/app/assets/config/manifest.js

# Check application.css
docker compose exec web cat /app/app/assets/stylesheets/application.css

# Rebuild assets
docker compose exec web yarn build
docker compose exec web yarn build:css
docker compose exec web bundle exec rails assets:clobber
docker compose exec web bundle exec rails assets:precompile

# Check asset files
docker compose exec web ls -la /app/public/assets/ | grep application
```

### Browser Issues
```bash
# Check if browser is installed
which chromium-browser || which firefox

# Test localhost access
curl -I http://localhost:3000

# Check display settings
xrandr --listmonitors
```

### Scoreboard Display Issues
```bash
# Test browser in kiosk mode
chromium-browser --kiosk http://localhost:3000/scoreboard

# Check for display errors
journalctl -u display-manager

# Test fullscreen manually
# Press F11 in browser
```

## Maintenance

### Regular Updates
```bash
# Update application
cd /home/pi/carambus
git pull origin master
docker compose build --no-cache
docker compose up -d

# Rebuild assets if needed
docker compose exec web yarn build
docker compose exec web yarn build:css
docker compose exec web bundle exec rails assets:precompile
```

### Log Monitoring
```bash
# Check application logs
docker compose logs -f web

# Check database logs
docker compose logs -f postgres

# Check system logs
journalctl -f
```

### Backup
```bash
# Backup database
docker compose exec postgres pg_dump -U www_data carambus_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup configuration
tar -czf config_backup_$(date +%Y%m%d_%H%M%S).tar.gz doc/doc-local/docker/shared/config/
```

## Emergency Recovery

### If Scoreboard Won't Start
```bash
# Restart Docker services
docker compose restart

# Check service status
docker compose ps

# Check logs
docker compose logs
```

### If Display Issues
```bash
# Restart display manager
sudo systemctl restart display-manager

# Check display configuration
xrandr --listmonitors
```

### If Network Issues
```bash
# Check network connectivity
ping 8.8.8.8

# Restart network
sudo systemctl restart networking
```

## Success Criteria

### ✅ System Level
- [ ] Docker installed and running
- [ ] All services (postgres, redis, web) show "Up" status
- [ ] No critical errors in logs

### ✅ Application Level
- [ ] Web application accessible at http://192.168.178.53:3000
- [ ] Database contains production data
- [ ] All assets (CSS/JS) loading correctly
- [ ] Scoreboard interface accessible

### ✅ Scoreboard Level
- [ ] Browser auto-starts in kiosk mode
- [ ] Scoreboard interface displays correctly
- [ ] Fullscreen mode functional
- [ ] Real-time updates working
- [ ] Menu navigation responsive

## Conclusion

This setup provides a complete Carambus scoreboard solution on Raspberry Pi with Docker. The scoreboard will automatically start in fullscreen mode and display real-time tournament information.

**Key Features:**
- ✅ Full Carambus application in Docker
- ✅ Auto-start browser in kiosk mode
- ✅ Real-time updates via ActionCable
- ✅ Responsive scoreboard interface
- ✅ Easy maintenance and updates 