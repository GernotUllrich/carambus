# Carambus Enhanced Mode System - Socket-Based Deployment Integration

## 🎯 **Overview**

The enhanced mode system uses **Unix Sockets** for efficient communication between NGINX and Puma, based on the proven carambus2 architecture.

## 🚀 **Socket-Based Deployment**

### **Template Generation and Transfer**

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

### **Deployment Workflow**

```bash
# 1. Configure mode (generates socket-based templates)
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_HOST=newapi.carambus.de MODE_NGINX_PORT=80 MODE_PUMA_SOCKET=puma-production.sock MODE_SSL_ENABLED=true

# 2. Templates are automatically generated
# 3. Execute deployment (transfers socket templates automatically)
bundle exec cap production deploy
```

## 🔧 **Socket-Based Configuration**

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

## 🔧 **Automatic Template Management**

### **Templates are automatically generated**
```bash
# Templates are automatically generated on every mode change
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_NGINX_PORT=80 MODE_PUMA_SOCKET=puma-production.sock
```

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

## 🎛️ **Configuration Parameters**

### **NGINX Parameters**
- `MODE_NGINX_PORT` - Web port (default: 80)
- `MODE_SSL_ENABLED` - SSL enabled (true/false, default: false)
- `MODE_DOMAIN` - Domain name

### **Puma Socket Parameters**
- `MODE_PUMA_SOCKET` - Socket name (default: puma-{rails_env}.sock)
- `MODE_RAILS_ENV` - Rails environment

### **Scoreboard Parameters**
- `MODE_LOCATION_ID` - Location ID for URL generation
- `MODE_SCOREBOARD_URL` - Manual scoreboard URL

## 🔄 **Deployment Workflow Example**

### **In-house Server (Raspberry Pi)**
```bash
# 1. Configure mode
bundle exec rails 'mode:local' \
  MODE_HOST=192.168.1.100 \
  MODE_PORT=22 \
  MODE_NGINX_PORT=3131 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=false

# 2. Templates are automatically generated
# 3. Deployment
bundle exec cap production deploy
```

### **Production Server (Hetzner)**
```bash
# 1. Configure mode
bundle exec rails 'mode:api' \
  MODE_BASENAME=carambus_api \
  MODE_HOST=newapi.carambus.de \
  MODE_PORT=8910 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=true \
  MODE_NGINX_PORT=80

# 2. Templates are automatically generated
# 3. Deployment
bundle exec cap production deploy
```

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

```
config/
├── nginx.conf.erb          # NGINX template (socket-based)
├── puma.rb.erb             # Puma.rb template (socket-based)
├── puma.service.erb        # Puma service template
├── scoreboard_url.erb      # Scoreboard URL template
├── nginx.conf              # Generated NGINX configuration
├── puma.rb                 # Generated Puma.rb configuration
├── puma.service            # Generated Puma service
└── scoreboard_url          # Generated scoreboard URL

lib/capistrano/tasks/
└── templates.rake          # Capistrano template tasks
```

## ✅ **Advantages of Socket-Based Architecture**

1. **Performance** - Unix sockets are faster than TCP/IP
2. **Security** - No network exposure
3. **Efficiency** - Less overhead
4. **Scalability** - Better performance under load
5. **Compatibility** - Proven carambus2 architecture
6. **Automation** - Complete template generation
7. **Debugging** - Complete RubyMine integration
8. **Maintainability** - Central socket management

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

## 🎉 **Conclusion**

The **Enhanced Mode System** with socket-based architecture provides:

- ✅ **Complete automation**
- ✅ **Socket-based performance**
- ✅ **RubyMine integration**
- ✅ **Multi-environment support**
- ✅ **Automatic template generation**
- ✅ **Robust deployment pipeline**

**Recommendation**: Use the Enhanced Mode System for all Carambus deployments.

The system makes deployment **fast, secure and maintainable**! 🚀
