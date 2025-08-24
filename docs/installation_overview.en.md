# 🚀 Installation Overview

## 📋 Available Installation Guides

### 🐳 Docker Installation (Recommended)
**[Docker Installation](docker_installation.md)** - Complete guide for Docker-based installation of Carambus on various platforms.

**Supported Platforms:**
- **Raspberry Pi** - For local scoreboards and tournaments
- **Ubuntu Server** - For professional hosting environments (e.g., Hetzner)
- **Combined Installation** - API server + local server on the same hardware

**Advantages of Docker Installation:**
- ✅ Consistent environment
- ✅ Easy migration
- ✅ Minimal technical effort
- ✅ Reproducible installations
- ✅ Automatic updates

### 🔧 Manual Installation
For special requirements or when Docker is not available:

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
- On macOS computer with Docker
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
./deploy-docker.sh carambus_raspberry www-data@192.168.178.53:8910 /var/www/carambus

# Ubuntu Server
./deploy-docker.sh carambus_newapi www-data@carambus.de:8910 /var/www/carambus_api
```

### 2. Automatic Configuration
The deployment script automatically configures:
- Docker containers
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

- **[Docker Installation](docker_installation.md)** - Complete Docker guide
- **[Developer Guide](DEVELOPER_GUIDE.md)** - Developer documentation
- **[API Documentation](API.md)** - API reference

## 🆘 Support

If you have problems:
1. Check the **[Docker Installation](docker_installation.md)** page
2. View logs: `docker compose logs`
3. Container status: `docker compose ps`
4. Restart system: `sudo reboot`

---

**🎯 Goal**: Simple, automated installation of Carambus on various platforms with consistent configuration. 