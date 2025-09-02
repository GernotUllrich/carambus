# Carambus Enhanced Mode System

## 🎯 **Overview**

The **Enhanced Mode System** enables easy switching between different deployment configurations for Carambus. It uses **Ruby/Rake Tasks** for maximum debugging support and robustness.

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
└── deploy/
    └── production.rb.erb # ERB template
```

### **Rake Tasks**
```
lib/tasks/
└── mode.rake             # Main system with named parameters
```

## ✅ **Advantages of the Ruby/Rake System**

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

## 🎉 **Conclusion**

The **Ruby Named Parameters System** is the **ideal solution** for RubyMine users:

- ✅ **Complete debugging support**
- ✅ **Robust parameter handling**
- ✅ **Easy maintenance**
- ✅ **IDE integration**
- ✅ **Type safety**
- ✅ **Socket-based architecture**
- ✅ **Automatic template generation**

**Recommendation**: Use the Ruby/Rake system for all new developments.

The Ruby/Rake system makes deployment configuration **debuggable, maintainable and robust**! 🚀

**Further documentation**: `docs/enhanced_deployment_system.md`
