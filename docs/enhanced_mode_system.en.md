# Carambus Enhanced Mode System

## 🎯 **Overview**

The **Enhanced Mode System** enables easy switching between different deployment configurations for Carambus. It uses **Ruby/Rake Tasks** for maximum debugging support and **Unix Sockets** for efficient communication between NGINX and Puma.

## 🚀 **Quick Start**

### **Ruby/Rake Named Parameters System**

```bash
# API Server Mode
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001

# Local Server Mode
bundle exec rails 'mode:local' MODE_SEASON_NAME='2025/2026' MODE_CONTEXT=NBV MODE_API_URL='https://newapi.carambus.de/'
```

## 📋 **Available Parameters**

### **All Parameters (alphabetically)**
- `MODE_API_URL` - API URL for LOCAL mode
- `MODE_APPLICATION_NAME` - Application name
- `MODE_BASENAME` - Deploy basename
- `MODE_BRANCH` - Git branch
- `MODE_CLUB_ID` - Club ID
- `MODE_CONTEXT` - Context identifier
- `MODE_DATABASE` - Database name
- `MODE_DOMAIN` - Domain name
- `MODE_HOST` - Server hostname
- `MODE_LOCATION_ID` - Location ID
- `MODE_NGINX_PORT` - NGINX web port (default: 80)
- `MODE_PORT` - Server port
- `MODE_PUMA_SCRIPT` - Puma management script
- `MODE_PUMA_SOCKET` - Puma socket name (default: puma-{rails_env}.sock)
- `MODE_RAILS_ENV` - Rails environment
- `MODE_SCOREBOARD_URL` - Scoreboard URL (auto-generated)
- `MODE_SEASON_NAME` - Season identifier
- `MODE_SSL_ENABLED` - SSL enabled (true/false, default: false)

## 🎯 **Usage Examples**

### **1. API Server Deployment**
```bash
bundle exec rails 'mode:api' \
  MODE_BASENAME=carambus_api \
  MODE_DATABASE=carambus_api_production \
  MODE_HOST=newapi.carambus.de \
  MODE_PORT=3001 \
  MODE_DOMAIN=api.carambus.de \
  MODE_RAILS_ENV=production \
  MODE_BRANCH=master \
  MODE_PUMA_SCRIPT=manage-puma-api.sh \
  MODE_NGINX_PORT=80 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=true
```

### **2. Local Server Deployment**
```bash
bundle exec rails 'mode:local' \
  MODE_SEASON_NAME='2025/2026' \
  MODE_APPLICATION_NAME=carambus \
  MODE_CONTEXT=NBV \
  MODE_API_URL='https://newapi.carambus.de/' \
  MODE_BASENAME=carambus \
  MODE_DATABASE=carambus_api_development \
  MODE_DOMAIN=carambus.de \
  MODE_LOCATION_ID=1 \
  MODE_CLUB_ID=357 \
  MODE_HOST=new.carambus.de \
  MODE_RAILS_ENV=production \
  MODE_NGINX_PORT=80 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=false
```

### **3. Development Environment**
```bash
bundle exec rails 'mode:api' \
  MODE_BASENAME=carambus_api \
  MODE_DATABASE=carambus_api_development \
  MODE_HOST=localhost \
  MODE_PORT=3001 \
  MODE_RAILS_ENV=development \
  MODE_NGINX_PORT=3000 \
  MODE_PUMA_SOCKET=puma-development.sock \
  MODE_SSL_ENABLED=false
```

## 💾 **Managing Configurations**

### **Save Configuration**
```bash
bundle exec rails 'mode:save[production_api]' \
  MODE_BASENAME=carambus_api \
  MODE_DATABASE=carambus_api_production \
  MODE_HOST=newapi.carambus.de \
  MODE_PORT=3001 \
  MODE_NGINX_PORT=80 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=true
```

### **List Saved Configurations**
```bash
bundle exec rails 'mode:list'
```

### **Load Configuration**
```bash
bundle exec rails 'mode:load[production_api]'
```

## 🔧 **Socket-Based Architecture**

### **Unix Socket Advantages**
- ✅ **More Efficient** - No TCP/IP overhead
- ✅ **More Secure** - Local communication only
- ✅ **Faster** - Direct kernel communication
- ✅ **More Scalable** - Better performance under load

### **Socket Path Structure**
```
/var/www/{basename}/shared/
├── sockets/
│   └── puma-{rails_env}.sock    # Unix Socket
├── pids/
│   ├── puma-{rails_env}.pid     # Process ID
│   └── puma-{rails_env}.state   # State File
└── log/
    ├── puma.stdout.log          # Standard Output
    └── puma.stderr.log          # Standard Error
```

## 🔧 **Automatic Template Generation**

### **Templates are automatically generated**
The system automatically generates and transfers:

1. **NGINX Configuration** (`config/nginx.conf`)
   - Uses Unix Socket: `unix:/var/www/{basename}/shared/sockets/{puma_socket}`
   - Copies to `/etc/nginx/sites-available/{basename}`
   - Creates symlink in `/etc/nginx/sites-enabled/`
   - Tests configuration and reloads NGINX

2. **Puma.rb Configuration** (`config/puma.rb`)
   - Binds to Unix Socket: `unix://{shared_dir}/sockets/puma-{rails_env}.sock`
   - Creates socket directories automatically
   - Sets correct socket permissions (0666)
   - Configures PID and state files

3. **Puma Service Configuration** (`config/puma.service`)
   - Copies to `/etc/systemd/system/puma-{basename}.service`
   - Creates socket directories before service start
   - Reloads systemd daemon
   - Enables the service

4. **Scoreboard URL** (`config/scoreboard_url`)
   - Copies to `/var/www/{basename}/shared/config/scoreboard_url`

### **Deploy templates via Capistrano**
```bash
# All templates (automatically after deployment)
bundle exec cap production deploy

# Individual template tasks
bundle exec cap production deploy:nginx_config
bundle exec cap production deploy:puma_rb_config
bundle exec cap production deploy:puma_service_config
```

## 📋 **Capistrano Integration**

### **Automatic Template Transfer**

The following files are automatically transferred:
- `config/nginx.conf` → `/var/www/{basename}/shared/config/nginx.conf`
- `config/puma.rb` → `/var/www/{basename}/shared/puma.rb`
- `config/puma.service` → `/var/www/{basename}/shared/config/puma.service`
- `config/scoreboard_url` → `/var/www/{basename}/shared/config/scoreboard_url`

### **Deployment Hooks**

```ruby
# Automatically after each deployment
after "deploy:published", "deploy:deploy_templates"
```

### **Available Capistrano Tasks**

```bash
# Template deployment
cap deploy:deploy_templates              # Deploy all templates
cap deploy:nginx_config                  # Deploy NGINX configuration
cap deploy:puma_rb_config                # Deploy Puma.rb configuration
cap deploy:puma_service_config           # Deploy Puma service

# Puma management
cap puma:restart                         # Restart Puma
cap puma:stop                            # Stop Puma
cap puma:start                           # Start Puma
cap puma:status                          # Show Puma status
```

## 🔧 **RubyMine Debugging**

### **Complete Debugging Support**

The Ruby/Rake system provides **perfect RubyMine integration**:

#### **1. Set Breakpoints**
```ruby
# In lib/tasks/mode.rake
def parse_named_parameters_from_env
  params = {}
  
  # Set breakpoint here
  %i[season_name application_name context api_url basename database domain location_id club_id rails_env host port branch puma_script nginx_port puma_port ssl_enabled scoreboard_url puma_socket].each do |param|
    env_var = "MODE_#{param.to_s.upcase}"
    params[param] = ENV[env_var] if ENV[env_var]
  end
  
  params  # Set breakpoint here
end
```

#### **2. RubyMine Run Configuration**
```
Run -> Edit Configurations -> Rake
Task: mode:api
Environment Variables:
  MODE_BASENAME=carambus_api
  MODE_DATABASE=carambus_api_production
  MODE_HOST=newapi.carambus.de
  MODE_PORT=3001
  MODE_NGINX_PORT=80
  MODE_PUMA_SOCKET=puma-production.sock
  MODE_SSL_ENABLED=true
```

#### **3. Step-by-Step Debugging**
- **Step Into**: Go into methods
- **Step Over**: Skip methods
- **Step Out**: Exit methods
- **Variables Inspector**: See all parameter values

## 🎯 **Best Practices**

### **1. RubyMine Debugging Workflow**
```bash
# 1. Set breakpoints in lib/tasks/mode.rake
# 2. Create RubyMine Run Configuration
# 3. Debug step-by-step
# 4. Inspect variables
# 5. Test different parameter combinations
```

### **2. Save Configurations**
```bash
# Save frequently used configurations
bundle exec rails 'mode:save[production_api]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001 MODE_NGINX_PORT=80 MODE_PUMA_SOCKET=puma-production.sock MODE_SSL_ENABLED=true
bundle exec rails 'mode:save[development_api]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_development MODE_HOST=localhost MODE_PORT=3001 MODE_NGINX_PORT=3000 MODE_PUMA_SOCKET=puma-development.sock MODE_SSL_ENABLED=false
```

### **3. Specify Only Changes**
```bash
# Only specify parameters that differ from defaults
bundle exec rails 'mode:api' MODE_HOST=localhost MODE_PORT=3001 MODE_RAILS_ENV=development MODE_NGINX_PORT=3000 MODE_PUMA_SOCKET=puma-development.sock MODE_SSL_ENABLED=false
```

## 🗄️ **Database Management**

### **Database Synchronization Workflow**

The Enhanced Mode System provides complete database synchronization between local development and production environment:

#### **1. Create Local Development Dump**
```bash
# Creates a dump of the local carambus_api_development database
bundle exec rails mode:prepare_db_dump

# Output:
# 🗄️  Creating database dump: carambus_api_production_20250102_120000.sql.gz
# 📊 Source database: carambus_api_development
# 🎯 Target database: carambus_api_production (on server)
# ✅ Database dump created successfully: carambus_api_production_20250102_120000.sql.gz
```

#### **2. List Available Dumps**
```bash
# Shows all available dumps with size and date
bundle exec rails mode:list_db_dumps

# Output:
# 🗄️  Available database dumps:
# ----------------------------------------
# carambus_api_production_20250102_120000.sql.gz (1234567 bytes, 2025-01-02 12:00:00)
# carambus_api_production_20250101_150000.sql.gz (1234567 bytes, 2025-01-01 15:00:00)
```

#### **3. Deploy Dump to API Server**
```bash
# Transfers the dump to the server and places it in /var/www/carambus_api/shared/database_dumps/
bundle exec rails 'mode:deploy_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# Output:
# 🚀 Deploying database dump to production server...
# Dump file: carambus_api_production_20250102_120000.sql.gz
# Server: carambus.de:8910
# ✅ Database dump deployed successfully
# 📁 Remote location: /var/www/carambus_api/shared/database_dumps/carambus_api_production_20250102_120000.sql.gz
```

#### **4. Restore Dump on API Server (as www-data)**
```bash
# Reads the dump into the carambus_api_production database
bundle exec rails 'mode:restore_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# Output:
# 🗄️  Restoring database from dump...
# Dump file: carambus_api_production_20250102_120000.sql.gz
# Server: carambus.de:8910
# ✅ Database restored successfully
```

### **Complete Synchronization Workflow**

```bash
# 1. Create local development dump
bundle exec rails mode:prepare_db_dump

# 2. Deploy dump to API server
bundle exec rails 'mode:deploy_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# 3. Restore dump on API server (as www-data)
bundle exec rails 'mode:restore_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# 4. Restart Puma service
bundle exec cap production puma:restart
```

### **Automated Database Synchronization**

#### **With Deployment Script**
```bash
# Complete local deployment including database synchronization
./bin/deploy.sh full-local

# Automatically executes:
# 1. Local server deployment
# 2. API database dump creation
# 3. Dump transfer to local server
# 4. Dump restoration on local server
# 5. Post-deploy setup
```

#### **Manual Database Synchronization**
```bash
# Dump API database on server
ssh -p 8910 www-data@carambus.de "cd /var/www/carambus_api/current && pg_dump -Uwww_data carambus_api_production | gzip > carambus_api_production.sql.gz"

# Download dump locally
scp -P 8910 www-data@carambus.de:/var/www/carambus_api/current/carambus_api_production.sql.gz .

# Import dump into local development environment
gunzip -c carambus_api_production.sql.gz | psql carambus_api_development
```

### **Database Versioning**

#### **PaperTrail Integration**
```bash
# Sequence reset after dump import
RAILS_ENV=production bundle exec rails runner "Version.sequence_reset"

# Set last version ID for API synchronization
LAST_VERSION_ID=$(ssh -p 8910 www-data@carambus.de "cd /var/www/carambus_api/current && RAILS_ENV=production bundle exec rails runner 'puts PaperTrail::Version.last.id'")
RAILS_ENV=production bundle exec rails runner "Setting.key_set_value('last_version_id', $LAST_VERSION_ID)"
```

#### **Database Backup Management**
```bash
# Keep only the last 2 dumps
ls -t carambus_api_production_*.sql.gz | tail -n +3 | xargs rm -f

# Compress dumps
gzip -9 carambus_api_production_*.sql

# Verify dumps
gunzip -t carambus_api_production_*.sql.gz
```

## 🚀 **Deployment Workflow**

### **1. Prepare Configuration**
```bash
# Load saved configuration
bundle exec rails 'mode:load[api_hetzner]'
```

### **2. Apply Configuration**
```bash
# Apply the loaded parameters
bundle exec rails 'mode:api'
```

### **3. Validate Configuration**
```bash
# Check current configuration
bundle exec rails 'mode:status'
```

### **4. Execute Deployment**
```bash
# Deploy with validated configuration
bundle exec cap production deploy
```

## 🔄 **Multi-Environment Deployment**

### **Deployment Script Integration**
```bash
# API server deployment with automatic pull
./bin/deploy.sh deploy-api

# Local server deployment with automatic pull
./bin/deploy.sh deploy-local

# Full local deployment
./bin/deploy.sh full-local
```

### **Automatic Repo Pull**
The deployment system automatically performs a `git pull` for the respective scenario folders before the deployment starts.

## 🔍 **Troubleshooting**

### **Check socket permissions**
```bash
# Check socket directory
ls -la /var/www/carambus_api/shared/sockets/

# Check socket permissions
ls -la /var/www/carambus_api/shared/sockets/puma-production.sock
```

### **Test NGINX socket configuration**
```bash
# Test locally
sudo nginx -t

# Test on server
ssh -p 8910 www-data@newapi.carambus.de 'sudo nginx -t'
```

### **Puma socket status**
```bash
# Check socket connection
ssh -p 8910 www-data@newapi.carambus.de 'netstat -an | grep puma'

# Service status
ssh -p 8910 www-data@newapi.carambus.de 'sudo systemctl status puma-carambus_api.service'
```

### **Create socket directories**
```bash
# Manually create socket directories
ssh -p 8910 www-data@newapi.carambus.de 'sudo mkdir -p /var/www/carambus_api/shared/sockets /var/www/carambus_api/shared/pids /var/www/carambus_api/shared/log'
```

## 📁 **File Structure**

### **Configuration Files**
```
config/
├── named_modes/           # Saved named configurations
│   ├── api_hetzner.yml
│   ├── local_hetzner.yml
│   └── development.yml
├── carambus.yml.erb      # ERB template
├── database.yml.erb      # ERB template
├── deploy.rb.erb         # ERB template
├── nginx.conf.erb        # NGINX template (socket-based)
├── puma.rb.erb           # Puma.rb template (socket-based)
├── puma.service.erb      # Puma service template
├── scoreboard_url.erb    # Scoreboard URL template
├── nginx.conf            # Generated NGINX configuration
├── puma.rb               # Generated Puma.rb configuration
├── puma.service          # Generated Puma service
├── scoreboard_url        # Generated scoreboard URL
└── deploy/
    └── production.rb.erb # ERB template
```

### **Rake Tasks**
```
lib/tasks/
└── mode.rake             # Main system with named parameters

lib/capistrano/tasks/
└── templates.rake        # Capistrano template tasks
```

## ✅ **Advantages of the Enhanced Mode System**

1. **RubyMine Integration**: Perfect debugging support
2. **Type Safety**: Ruby typing and validation
3. **Error Handling**: Robust error handling
4. **Debugging**: Step-by-step debugging with breakpoints
5. **Variable Inspection**: Complete variable inspection
6. **Call Stack**: Call stack navigation
7. **IDE Support**: Complete IDE support
8. **Maintainability**: Easy maintenance and extension
9. **Socket Integration**: Complete socket-based architecture
10. **Template Generation**: Automatic template generation
11. **Performance**: Unix sockets are faster than TCP/IP
12. **Security**: No network exposure
13. **Efficiency**: Less overhead
14. **Scalability**: Better performance under load
15. **Automation**: Complete automation
16. **Multi-Environment**: Multi-environment support

## 🎉 **Conclusion**

The **Enhanced Mode System** with socket-based architecture is the **ideal solution** for RubyMine users:

- ✅ **Complete debugging support**
- ✅ **Robust parameter handling**
- ✅ **Easy maintenance**
- ✅ **IDE integration**
- ✅ **Type safety**
- ✅ **Socket-based architecture**
- ✅ **Automatic template generation**
- ✅ **Complete automation**
- ✅ **Multi-environment support**
- ✅ **Robust deployment pipeline**

**Recommendation**: Use the Enhanced Mode System for all Carambus deployments.

The system makes deployment configuration **debuggable, maintainable and robust**! 🚀
