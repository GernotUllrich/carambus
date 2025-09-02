# 🚀 Installation Overview

## 📋 Available Installation Guides

### 🔧 Manual Installation
For all installation requirements:

- **Raspberry Pi Setup** - Detailed guide for Pi-specific installation
- **Ubuntu Server Setup** - Server-specific configuration
- **API Server Setup** - Production server installation

## 🏗️ Architecture Overview

### Production Modes
1. **API Server** (`/var/www/carambus_api`)
   - Central API for all local servers
   - Domain: newapi.carambus.de
   - Can also function as hosting server

2. **Local Server** (`/var/www/carambus`)
   - Local servers for tournaments/clubs
   - Points to API server
   - For scoreboards and local management

### Development Mode
- Both production modes can be tested in parallel
- On macOS computer
- Inter-system communication testable

## 🔑 Important Configurations

### Standard Account
- **User**: `www-data` (uid=33, gid=33)
- **Home Directory**: `/var/www`
- **SSH Port**: 8910
- **Sudo**: Via `wheel` group

### Installation Paths
- **API Server**: `/var/www/carambus_api`
- **Local Server**: `/var/www/carambus`

## 🚀 Quick Start

### 1. Choose Platform
```bash
# Raspberry Pi
./deploy.sh deploy-local

# Ubuntu Server
./deploy.sh deploy-api
```

### 2. Automatic Configuration
The deployment script automatically configures:
- Database (PostgreSQL)
- Cache (Redis)
- Web server (Rails + Puma)
- Nginx configuration
- SSL certificates (for HTTPS)

### 3. Localization (only for local servers)
- Web-based configuration
- Region-specific settings
- Scoreboard configuration

## 📖 Further Documentation

- **[Developer Guide](DEVELOPER_GUIDE.md)** - Developer documentation
- **[API Documentation](API.md)** - API reference
- **[Enhanced Mode System](enhanced_mode_system.en.md)** - Deployment configuration

## 🆘 Support

If you have problems:
1. Check the **[Installation Overview](installation_overview.md)** page
2. View logs: `tail -f /var/log/nginx/error.log`
3. Service status: `sudo systemctl status puma-carambus`
4. Restart system: `sudo reboot`

---

**🎯 Goal**: Simple, automated installation of Carambus on various platforms with consistent configuration. 