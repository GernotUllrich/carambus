# 🐳 Docker Installation for Carambus

## 📋 Overview

This document describes the automated processes for:
1. **Fresh installation** of a Carambus server on various platforms
2. **Migration** of existing installations to new major versions
3. **Development environment** for local development on a computer with macOS

The goal is to simplify these processes so that a local system manager without deep technical knowledge can perform these tasks.

## 🏗️ Architecture Overview

### Production Modes (2 different systems)

#### 1. **API Server** (newapi.carambus.de)
- **Purpose**: Central API for all local servers
- **Features**: Is the central API server
- **Usage**: Production API server
- **Domain**: newapi.carambus.de
- **Installation path**: `/var/www/carambus_api`

#### 2. **Local Server** (local installations)
- **Purpose**: Local servers for tournaments/clubs
- **Features**: Has a Carambus API URL that points to the API server
- **Usage**: Raspberry Pi scoreboards, local servers
- **Domain**: localhost or local IP
- **API-URL**: Points to newapi.carambus.de
- **Installation path**: `/var/www/carambus`

#### 3. **Combined Installation** (API Server + Local Server)
- **Purpose**: API server with additional local server for hosting
- **Usage**: For locations without their own server
- **Installation paths**: 
  - API Server: `/var/www/carambus_api`
  - Local Server: `/var/www/carambus`
- **Advantage**: Central management with local hosting functionality

**Note**: Both server types can run on the same hardware. The API server can also function as a hosting server for local Carambus instances that don't have their own server.

### Development Mode (overarching)
- **Purpose**: Both production modes can be tested in development mode
- **Platform**: Computer with macOS for local development
- **Advantage**: Parallel testing of both modes possible
- **Usage**: Inter-system communication testing (Local Server ↔ API Server)

## 🚀 Installation Types

### Docker-based Installation (Recommended)

#### Advantages
- ✅ Consistent environment
- ✅ Easy migration
- ✅ Minimal technical effort
- ✅ Reproducible installations
- ✅ Automatic updates

#### Process
1. **Automatic configuration** on first boot
2. **Web-based localization** (only for local servers)
3. **Automatic scoreboard startup** (only for local servers)

## 📋 Installation Process (Docker-based)

### Phase 1: Preparation

#### 1.1 Platform-specific Prerequisites

**Raspberry Pi:**
- Raspberry Pi Imager with custom image
- Optional: SSH configuration with standard account
- Optional: WiFi connection with fixed IP in router

**Ubuntu Server (e.g., Hetzner):**
- Base installation already completed by hosting provider
- Network configuration already completed by hosting provider
- SSH access via standard port 22

#### 1.2 www-data Account Configuration

**Important**: All Carambus installations use the standard `www-data` account (uid=33, gid=33), which is already defined in both operating systems:

```bash
# The www-data user already exists:
# www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin

# Activate shell for SSH access (home directory remains /var/www)
sudo chsh -s /bin/bash www-data

# Create wheel group (if not present)
sudo groupadd wheel

# Configure wheel group for passwordless sudo
echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

# Add www-data to wheel group
sudo usermod -aG wheel www-data

# Set up SSH keys for passwordless access
sudo mkdir -p /var/www/.ssh
sudo chown www-data:www-data /var/www/.ssh
sudo chmod 700 /var/www/.ssh
# Copy public key from development system
```

#### 1.3 SSH Configuration

**Development system scripts** always assume the following SSH configuration:

```bash
# Standard SSH access for all scripts
ssh -p 8910 www-data@host

# No direct root access possible
# No passwordless root access possible
# From www-data, use sudo su if needed
```

**SSH configuration on target system:**

```bash
# /etc/ssh/sshd_config
Port 8910
PermitRootLogin no
# PasswordAuthentication no  # Commented out for initial configuration
PubkeyAuthentication yes
AllowUsers www-data
```

**Note**: This configuration corresponds to the Ansible rules used for deployment. The `wheel` group enables passwordless sudo for the `www-data` user.

### Phase 2: Automatic Configuration

#### 2.1 Network Configuration

**Note**: Network connection already occurs when loading the base OS:
- **Raspberry Pi**: Optional SSH configuration and WiFi connection (preferably fixed IP in router)
- **Ubuntu Server**: Via hosting provider administration

For Docker installation, a `www-data` account is always present, through which the Rails application also runs.

#### 2.2 Localization

**Important**: Only local servers have regionalization (region_id or context) for setting the data filter.

```yaml
# config/localization.yml
location:
  id: "{location_id}"
  name: "{location_name}"
  timezone: "Europe/Berlin"
  region_id: "{region_id}"  # Only relevant for local servers
```

**Localization is only necessary for scoreboards**, as these are assigned to a location so that the corresponding table selection can be made for the location.

**Note**: There were problems with `assets:precompile` that required a `location_id` to be specified. This needs to be reviewed and eliminated.

#### 2.3 Carambus API URL Configuration

```yaml
# config/api.yml
carambus_api:
  url: "https://newapi.carambus.de"
  timeout: 30
  retry_attempts: 3
```

#### 2.4 Language Configuration

**German is always the default locale**. Users can select their own locale (DE or EN) through their profile. Switching is possible in the webapp and is irrelevant for installation.

```yaml
# config/application.yml
default_locale: "de"
available_locales: ["de", "en"]
```

### Phase 3: Scoreboard Setup (only for local servers)

**Note**: Desktop configurations need to be reviewed separately. We focus on passive installation from a headless server.

## 🔧 Development Environment (Computer with macOS)

### Local Development
```bash
# Start single system
docker-compose -f docker-compose.development.local-server.yml up

# Start all systems in parallel (for inter-system testing)
./start-development-parallel.sh
```

### Parallel Systems (Development Mode)
```bash
# All three systems simultaneously on macOS computer
docker-compose -f docker-compose.development.parallel.yml up

# Ports:
# - API Server: 3001 (PostgreSQL: 5433, Redis: 6380)
# - Local Server: 3000 (PostgreSQL: 5432, Redis: 6379)
# - Web Client: 3002 (PostgreSQL: 5434, Redis: 6381)

# Installation paths:
# - API Server: /var/www/carambus_api
# - Local Server: /var/www/carambus
```

### Inter-System Communication Testing
```bash
# Local server communicates with API server via Carambus API URL
# For region filter tests
# For synchronization tests
# Local server has API URL that points to API server
```

## 📊 Monitoring and Maintenance

### System Monitoring
```bash
# Container status
docker compose ps

# Resource consumption
docker stats

# System resources
htop
```

### Automatic Updates
```bash
# Crontab for automatic updates
crontab -e

# Update daily at 2:00 AM
# For Local Server:
0 2 * * * cd /var/www/carambus && git pull && docker compose up -d --build
# For API Server:
# 0 2 * * * cd /var/www/carambus_api && git pull && docker compose up -d --build
```

### Backup System
```bash
# Automatic localization backup
#!/bin/bash
# backup-localization.sh

LOCATION_ID=$(grep "LOCATION_ID" .env | cut -d'=' -f2)
BACKUP_DIR="/backup/localization"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
tar -czf "$BACKUP_DIR/localization_${LOCATION_ID}_${DATE}.tar.gz" \
  config/localization.yml \
  .env \
  storage/

# For combined installations (API Server + Local Server):
# Backup both directories
# tar -czf "$BACKUP_DIR/carambus_combined_${DATE}.tar.gz" \
#   /var/www/carambus_api \
#   /var/www/carambus
```

## 🚨 Troubleshooting

### Common Problems

#### Container won't start
```bash
# Check Docker status
sudo systemctl status docker

# View logs
docker compose logs

# Restart container
docker compose restart
```

#### Scoreboard won't start (only for local servers)
```bash
# Clear browser cache
rm -rf ~/.cache/chromium

# Restart browser
pkill chromium
chromium-browser --start-fullscreen --app=http://localhost:3000/scoreboard
```

#### Network problems
```bash
# Check IP address
ip addr show

# Restart network
sudo systemctl restart networking
```

### Log Analysis
```bash
# All logs
docker compose logs -f

# Only Rails logs
docker compose logs -f web

# Only database logs
docker compose logs -f postgres
```

## 🔄 Migration from Existing Installations

### Step 1: Create Backup
```bash
# Backup localization
tar -czf localization_backup.tar.gz config/localization.yml .env

# Backup database
docker compose exec postgres pg_dump -U www_data carambus > carambus_backup.sql
```

### Step 2: New Installation
```bash
# Execute new deployment
# For Local Server:
./deploy-docker.sh carambus_raspberry www-data@192.168.178.53:8910 /var/www/carambus
# For API Server:
# ./deploy-docker.sh carambus_api_server www-data@newapi.carambus.de:8910 /var/www/carambus_api
```

### Step 3: Restore Data
```bash
# Restore localization
tar -xzf localization_backup.tar.gz

# Restore database
docker compose exec -T postgres psql -U www_data carambus < carambus_backup.sql
```

## 📖 Further Documentation

- **[Installation Overview](installation_overview.md)** - Installation overview
- **[Developer Guide](DEVELOPER_GUIDE.md)** - Developer documentation
- **[API Documentation](API.md)** - API reference

## 🆘 Support

If you have problems:
1. Check the **[Installation Overview](installation_overview.md)** page
2. View logs: `docker compose logs`
3. Container status: `docker compose ps`
4. Restart system: `sudo reboot`

---

**🎉 That's it! With this guide, you can easily install and manage Carambus.**

**💡 Tip**: For development, use the parallel Docker systems on the macOS computer to test inter-system communication!

**🏗️ Architecture**: 2 production modes - API server (central) and local server (with Carambus API URL), both testable in development mode!

**🔑 Important**: All installations use the standard `www-data` account and are accessible via SSH port 8910. Localization is only relevant for local servers with scoreboards. API server and local server can run on the same hardware with different installation paths (`/var/www/carambus_api` and `/var/www/carambus`).

**📝 Note**: All deploy scripts and documentation have been updated accordingly. Please use the updated commands with `www-data@` and the correct paths. 