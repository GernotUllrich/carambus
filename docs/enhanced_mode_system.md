# Enhanced Carambus Mode System with Puma Integration

## 🎯 **Overview**

The enhanced Carambus Mode System now includes integrated Puma management, making it easier to deploy and manage different server configurations with the correct Puma restart scripts. This system eliminates the need to manually remember complex parameter strings and ensures consistent deployment across different environments.

## 🚀 **Quick Start**

### **Using the Mode Parameters Manager (Recommended)**

```bash
# List available modes
./bin/mode-params.sh list

# Switch to LOCAL mode for Hetzner server
./bin/mode-params.sh local local_hetzner

# Switch to API mode for Hetzner server
./bin/mode-params.sh api api_hetzner

# Check current status
./bin/mode-params.sh status
```

### **Using Named Parameters (Recommended)**

```bash
# API Mode with named parameters (robust and self-documenting)
./bin/mode-named.sh api --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001

# LOCAL Mode with named parameters
./bin/mode-named.sh local --season-name='2025/2026' --context=NBV --api-url='https://newapi.carambus.de/' --basename=carambus --database=carambus_api_development
```

### **Using Rake Tasks Directly (Legacy)**

```bash
# Your original deployment command (now enhanced with Puma integration)
bundle exec rails "mode:local[2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_api_development,carambus.de,1,357,production,new.carambus.de,,master,manage-puma.sh]"

# API mode with Puma integration
bundle exec rails "mode:api[2025/2026,carambus_api,,,carambus_api,carambus_api_production,api.carambus.de,,,production,newapi.carambus.de,3001,master,manage-puma-api.sh]"
```

## 🔧 **Enhanced Parameters**

The mode system now includes a **14th parameter** for Puma script configuration:

### **Parameter Order:**
1. `season_name` - Season identifier (e.g., "2025/2026")
2. `application_name` - Application name (e.g., "carambus", "carambus_api")
3. `context` - Context identifier (e.g., "NBV", "")
4. `api_url` - API URL for LOCAL mode (e.g., "https://newapi.carambus.de/", "")
5. `basename` - Deploy basename (e.g., "carambus", "carambus_api")
6. `database` - Database name (e.g., "carambus_api_development", "carambus_api_production")
7. `domain` - Domain name (e.g., "carambus.de", "api.carambus.de")
8. `location_id` - Location ID (e.g., "1", "")
9. `club_id` - Club ID (e.g., "357", "")
10. `rails_env` - Rails environment (e.g., "production", "development")
11. `host` - Server ssh hostname or ip-address (e.g., "new.carambus.de", "localhost")
12. `port` - Server ssh port (e.g., "", "8910")
13. `branch` - Git branch (e.g., "master")
14. `puma_script` - **NEW**: Puma management script (e.g., "manage-puma.sh", "manage-puma-api.sh")

## 📋 **Pre-configured Modes**

### **Default Modes Available:**

#### **local_hetzner** (Local Server on Hetzner)
```bash
Parameters: 2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_api_development,carambus.de,1,357,production,new.carambus.de,,master,manage-puma.sh
```

#### **api_hetzner** (API Server on Hetzner)
```bash
Parameters: 2025/2026,carambus_api,,,carambus_api,carambus_api_production,api.carambus.de,,,production,newapi.carambus.de,3001,master,manage-puma-api.sh
```

#### **local_dev** (Local Development)
```bash
Parameters: 2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_api_development,carambus.de,1,357,development,localhost,3000,master,manage-puma.sh
```

#### **api_dev** (API Development)
```bash
Parameters: 2025/2026,carambus_api,,,carambus_api,carambus_api_development,api.carambus.de,,,development,localhost,3001,master,manage-puma-api.sh
```

## 🛠️ **Mode Parameters Manager**

### **Named Parameters System (Recommended)**

The new named parameters system eliminates the error-prone positional parameter ordering:

```bash
# API Mode with named parameters (robust and self-documenting)
./bin/mode-named.sh api --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001

# LOCAL Mode with named parameters
./bin/mode-named.sh local --season-name='2025/2026' --context=NBV --api-url='https://newapi.carambus.de/' --basename=carambus --database=carambus_api_development

# Save configurations
./bin/mode-named.sh save api_hetzner --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001

# Load saved configurations
./bin/mode-named.sh load api_hetzner

# List saved configurations
./bin/mode-named.sh list
```

**Benefits:**
- ✅ Self-documenting parameters
- ✅ Order-independent
- ✅ Only specify needed parameters
- ✅ Robust against errors
- ✅ Easy to read and understand

### **Legacy Positional Parameters Manager**

### **Commands:**

```bash
# List all available modes
./bin/mode-params.sh list

# Show parameters for a specific mode
./bin/mode-params.sh show local_hetzner

# Save custom parameters for a mode
./bin/mode-params.sh save my_custom_local "2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_api_development,carambus.de,1,357,production,new.carambus.de,,master,manage-puma.sh"

# Switch to LOCAL mode using saved/default parameters
./bin/mode-params.sh local local_hetzner

# Switch to API mode using saved/default parameters
./bin/mode-params.sh api api_hetzner

# Check current mode status
./bin/mode-params.sh status

# Create backup of current configuration
./bin/mode-params.sh backup
```

### **Custom Mode Management:**

```bash
# Save your current deployment parameters
./bin/mode-params.sh save my_hetzner_local "2025/2026,carambus,NBV,https://newapi.carambus.de/,carambus,carambus_api_development,carambus.de,1,357,production,new.carambus.de,,master,manage-puma.sh"

# Use your saved mode
./bin/mode-params.sh local my_hetzner_local
```

## 🔄 **Puma Integration**

### **What's New:**

1. **Automatic Puma Script Selection**: The system now automatically configures the correct Puma management script based on the mode
2. **Enhanced Deploy Configuration**: The `deploy.rb` file is automatically updated with the correct Puma restart configuration
3. **Mode-specific Puma Scripts**: 
   - LOCAL mode uses `manage-puma.sh` (generic script)
   - API mode uses `manage-puma-api.sh` (API-specific script)

### **Puma Management Commands:**

After switching modes, you can use these Capistrano commands:

```bash
# Restart Puma (uses the configured script)
bundle exec cap production puma:restart

# Check Puma status
bundle exec cap production puma:status

# Start Puma manually
bundle exec cap production puma:start

# Stop Puma manually
bundle exec cap production puma:stop
```

## 📁 **Files Modified by Mode System**

### **Configuration Files:**
1. **`config/carambus.yml`** - Application configuration
2. **`config/database.yml`** - Database configuration
3. **`config/deploy.rb`** - Deployment configuration (now includes Puma settings)
4. **`config/deploy/production.rb`** - Production-specific deployment settings
5. **`log/development.log`** - Symbolic link to mode-specific log file

### **Puma Scripts:**
1. **`bin/manage-puma.sh`** - Generic Puma management script
2. **`bin/manage-puma-api.sh`** - API-specific Puma management script

## 🎯 **Workflow Examples**

### **Deploying to Hetzner Local Server:**

```bash
# 1. Switch to LOCAL mode for Hetzner
./bin/mode-params.sh local local_hetzner

# 2. Deploy the application
bundle exec cap production deploy

# 3. Check Puma status
bundle exec cap production puma:status

# 4. Restart Puma if needed
bundle exec cap production puma:restart
```

### **Deploying to Hetzner API Server:**

```bash
# 1. Switch to API mode for Hetzner
./bin/mode-params.sh api api_hetzner

# 2. Deploy the application
bundle exec cap production deploy

# 3. Check Puma status
bundle exec cap production puma:status

# 4. Restart Puma if needed
bundle exec cap production puma:restart
```

### **Development Workflow:**

```bash
# 1. Switch to development mode
./bin/mode-params.sh local local_dev

# 2. Start development server
bundle exec rails server -p 3000 -e development-local

# 3. Switch to API development mode
./bin/mode-params.sh api api_dev

# 4. Start API development server
bundle exec rails server -p 3001 -e development-api
```

## 🔍 **Status and Monitoring**

### **Basic Status:**
The basic status command shows a summary of the current configuration.

### **Pre-Deployment Validation Workflow:**

The system now supports a complete deployment validation workflow:

#### **1. Pre-Deployment Validation:**
```bash
# Check what will be deployed (local configuration)
bundle exec rails "mode:pre_deploy_status[detailed]"
# or
./bin/mode-params.sh pre_deploy detailed
```

This shows the configuration that will be deployed to production, allowing you to:
- Validate all parameters before deployment
- Ensure correct database names, domains, etc.
- Verify Puma script selection
- Check that all required parameters are configured

#### **2. Post-Deployment Verification:**
```bash
# Verify what was actually deployed (production configuration)
bundle exec rails "mode:post_deploy_status[detailed]"
# or
./bin/mode-params.sh post_deploy detailed
```

This shows the actual configuration deployed on the production server, allowing you to:
- Verify that deployment was successful
- Confirm all parameters were deployed correctly
- Detect any deployment issues or missing configurations
- Compare pre-deployment vs post-deployment settings

#### **3. Complete Workflow Example:**
```bash
# 1. Set up your configuration
bundle exec rails "mode:api[2025/2026,carambus,NBV,,carambus,carambus2_api_production,carambus.de,1,357,production,192.168.178.48,8910,master,manage-puma-api.sh]"

# 2. Validate before deployment
./bin/mode-params.sh pre_deploy detailed

# 3. Deploy to production
bundle exec cap production deploy

# 4. Verify after deployment
./bin/mode-params.sh post_deploy detailed
```

### **Detailed Status:**
The detailed status command provides a comprehensive breakdown of all 14 parameters, making it easy to:
- See exactly what each parameter is set to
- Copy the complete parameter string for reuse
- Identify any missing or misconfigured parameters
- Get ready-to-use commands for switching modes or saving configurations
- **Read from production server**: Shows actual deployed configuration, not local development config

#### **Configuration Sources:**
The system can read from different sources:

**Local Deployment Configuration:**
- **carambus.yml**: Read from `config/carambus.yml` (production section)
- **database.yml**: Read from `config/database.yml` (production section)
- **deploy.rb**: Read from local config to determine server connection details
- **production.rb**: Read from local config to determine host and port

**Production Server Configuration:**
- **carambus.yml**: Read from `/var/www/{basename}/shared/config/carambus.yml`
- **database.yml**: Read from `/var/www/{basename}/shared/config/database.yml`
- **deploy.rb**: Read from local config to determine server connection details
- **production.rb**: Read from local config to determine host and port

This ensures you can validate **what will be deployed** and verify **what was actually deployed**.

### **Check Current Configuration:**

```bash
# Show current mode status
./bin/mode-params.sh status

# Show detailed parameter breakdown
./bin/mode-params.sh status detailed

# Or use the rake task directly
bundle exec rails mode:status
bundle exec rails "mode:status[detailed]"
```

### **Example Output:**

#### **Basic Status:**
```
Current Configuration:
  API URL: https://newapi.carambus.de/
  Context: NBV
  Database: carambus_production
  Deploy Basename: carambus
  Log File: development-local.log
  Puma Script: manage-puma.sh
Current Mode: LOCAL
```

#### **Detailed Status:**
```
Current Configuration:
  API URL: empty
  Context: NBV
  Database: carambus_production
  Deploy Basename: carambus
  Log File: development-api.log
  Puma Script: manage-puma-api.sh
Current Mode: API

📡 CONFIGURATION SOURCE:
----------------------------------------
Reading from production server: 192.168.178.48:8910
Deploy path: /var/www/carambus/shared/config/

============================================================
DETAILED PARAMETER BREAKDOWN
============================================================

📋 PARAMETER DETAILS:
----------------------------------------
1.  season_name:     2025/2026
2.  application_name: carambus
3.  context:         NBV
4.  api_url:         ❌ Not configured
5.  basename:        carambus
6.  database:        carambus2_api_production
7.  domain:          carambus.de
8.  location_id:     1
9.  club_id:         357
10. rails_env:       production
11. host:            192.168.178.48
12. port:            8910
13. branch:          master
14. puma_script:     manage-puma-api.sh

🔄 COMPLETE PARAMETER STRING:
----------------------------------------
✅ All parameters configured
2025/2026,carambus,NBV,,carambus,carambus2_api_production,carambus.de,1,357,production,192.168.178.48,8910,master,manage-puma-api.sh

📝 USAGE:
----------------------------------------
To switch to this exact configuration:
bundle exec rails "mode:api[2025/2026,carambus,NBV,,carambus,carambus2_api_production,carambus.de,1,357,production,192.168.178.48,8910,master,manage-puma-api.sh]"

Or save this configuration:
./bin/mode-params.sh save my_current_config "2025/2026,carambus,NBV,,carambus,carambus2_api_production,carambus.de,1,357,production,192.168.178.48,8910,master,manage-puma-api.sh"
```

## 🛡️ **Backup and Recovery**

### **Create Backup:**

```bash
# Create backup of current configuration
./bin/mode-params.sh backup

# Or use the rake task directly
bundle exec rails mode:backup
```

### **Restore from Backup:**

```bash
# Restore from a specific backup
cp tmp/mode_backups/config_backup_TIMESTAMP/* config/
```

## ⚠️ **Important Notes**

1. **Puma Script Compatibility**: Ensure the Puma scripts (`manage-puma.sh`, `manage-puma-api.sh`) are compatible with your server configuration
2. **Systemd Services**: The Puma management assumes systemd services named `puma-{basename}.service`
3. **SSH Access**: Ensure SSH access is configured for the target servers
4. **Database Setup**: Create the required databases before switching modes
5. **ERB Templates**: Ensure all required ERB template files exist

## 🔧 **Troubleshooting**

### **Common Issues:**

1. **Puma Script Not Found**: Ensure the Puma scripts exist in the `bin/` directory
2. **Systemd Service Not Found**: Check that the systemd service exists on the target server
3. **SSH Connection Issues**: Verify SSH configuration and host key acceptance
4. **Database Connection Errors**: Ensure the target database exists and is accessible

### **Debugging Commands:**

```bash
# Check Puma script content
cat bin/manage-puma.sh
cat bin/manage-puma-api.sh

# Check deploy.rb configuration
grep -A 10 "namespace :puma" config/deploy.rb

# Check systemd service status (on server)
sudo systemctl status puma-carambus.service

# Test SSH connection
ssh -p 8910 www-data@new.carambus.de "echo 'SSH connection successful'"
```

## 🎉 **Benefits of Enhanced System**

1. **Simplified Deployment**: No need to remember complex parameter strings
2. **Consistent Configuration**: Pre-configured modes ensure consistency
3. **Integrated Puma Management**: Automatic Puma script configuration
4. **Easy Mode Switching**: Simple commands to switch between environments
5. **Backup and Recovery**: Automatic backup system for configuration changes
6. **Development Support**: Separate development and production configurations
7. **Documentation**: Clear documentation and examples for all use cases

## 🆚 **System Comparison**

### **Named Parameters vs Positional Parameters**

#### **Named Parameters (Recommended)**
```bash
./bin/mode-named.sh api --basename=carambus_api --database=carambus_api_production --host=newapi.carambus.de --port=3001
```

**Advantages:**
- ✅ Self-documenting
- ✅ Order-independent
- ✅ Only specify needed parameters
- ✅ Robust against errors
- ✅ Easy to read and understand
- ✅ Configuration saving/loading

#### **Positional Parameters (Legacy)**
```bash
bundle exec rails "mode:api[2025/2026,carambus_api,,,carambus_api,carambus_api_production,api.carambus.de,,,production,newapi.carambus.de,3001,master,manage-puma-api.sh]"
```

**Disadvantages:**
- ❌ Error-prone ordering
- ❌ Hard to read and understand
- ❌ Must specify all parameters
- ❌ Fragile to changes
- ❌ No self-documentation

### **Migration Path**

You can use both systems in parallel:
- **New**: `./bin/mode-named.sh api --basename=carambus_api --host=newapi.carambus.de`
- **Legacy**: `./bin/mode-params.sh api api_hetzner`

## 📚 **Documentation**

- **Named Parameters**: `docs/named_parameters_system.md`
- **Enhanced Mode System**: `docs/enhanced_mode_system.md` (this file)

---

*This enhanced mode system integrates the Puma management improvements while maintaining backward compatibility with your existing deployment workflow. The new named parameters system provides a more robust and user-friendly alternative.*
