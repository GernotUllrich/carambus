# 🚀 Installation Overview

## 📋 Available Installation Guides

### 🎯 Scenario Management (Recommended)
**[Scenario Management](../developers/scenario-management.en.md)** - Modern deployment system for various Carambus environments.

**Supported Scenarios:**
- **carambus** - Main production environment
- **carambus_location_5101** - Local server instance for location 5101
- **carambus_location_2459** - Local server instance for location 2459
- **carambus_location_2460** - Local server instance for location 2460

**Advantages of Scenario Management:**
- ✅ Automated deployments
- ✅ Consistent configuration
- ✅ Integrated SSL management
- ✅ Automatic sequence management
- ✅ Scalable architecture

### 🔧 Manual Installation
For special requirements or legacy systems:

- **Raspberry Pi Setup** - Detailed guide for Pi-specific installation
- **Ubuntu Server Setup** - Server-specific configuration
- **API Server Setup** - Production server installation

## 🏗️ Architecture Overview

### Production Scenarios
1. **API Server** (`carambus`)
   - Central API for all local servers
   - Domain: newapi.carambus.de
   - Can also function as hosting server

2. **Local Server** (`carambus_location_*`)
   - Local servers for tournaments/clubs
   - Points to API server
   - For scoreboards and local management

### Development Mode
- All scenarios can be tested in parallel
- Automatic configuration via Scenario Management
- Inter-system communication testable

## 🔑 Important Configurations

### Standard Account
- **User**: `www-data` (uid=33, gid=33)
- **Home Directory**: `/var/www`
- **SSH Port**: 8910
- **Sudo**: Via `wheel` group

### Installation Paths
- **API Server**: `/var/www/carambus`
- **Local Server**: `/var/www/carambus_location_*`

## 🚀 Quick Start

### 1. Create Scenario
```bash
# Create new scenario
rake "scenario:create[carambus_location_5101]"

# Create Rails root
rake "scenario:create_rails_root[carambus_location_5101]"
```

### 2. Development Setup
```bash
# Setup development environment
rake "scenario:setup[carambus_location_5101,development]"
```

### 3. Production Deployment
```bash
# Full production deployment
rake "scenario:deploy[carambus_location_5101]"
```

### 4. Automatic Configuration
Scenario Management automatically configures:
- Database (PostgreSQL)
- Cache (Redis)
- Web server (Rails + Puma)
- Nginx configuration
- SSL certificates (for HTTPS)
- Sequence management

## 📖 Further Documentation

- **[Scenario Management](../developers/scenario-management.en.md)** - Complete deployment guide
- **[Developer Guide](../developers/developer-guide.en.md)** - Developer documentation
- **[API Documentation](../reference/API.en.md)** - API reference

## 🆘 Support

If you have problems:
1. Check the **[Scenario Management](../developers/scenario-management.en.md)** page
2. View logs: `tail -f log/production.log`
3. Service status: `systemctl status puma-carambus`
4. Restart system: `sudo reboot`

---

**🎯 Goal**: Simple, automated installation of Carambus on various platforms with consistent configuration via the Scenario Management System. 