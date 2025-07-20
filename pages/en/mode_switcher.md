# Carambus Mode Switcher

The Carambus Mode Switcher allows you to easily switch between **LOCAL** and **API** modes using a single development folder, eliminating the need to maintain two separate folders.

## 🎯 **Overview**

Instead of having separate `carambus` and `carambus_api` folders, you can now use a single folder with a mode switcher that automatically updates the necessary configuration files.

## 🔄 **Mode Differences**

### **LOCAL Mode**
- **carambus_api_url**: Empty (nil)
- **Database**: `carambus_local_development`
- **Deploy Server**: Local testing server (`192.168.178.81`)
- **Deploy Basename**: `carambus_local`
- **Log File**: `development-local.log` (symbolic link)
- **Server Port**: 3001
- **Environment**: `development-local`
- **Context**: `LOCAL`
- **Purpose**: Testing `local_server?` functionality

### **API Mode**
- **carambus_api_url**: `https://api.carambus.de/`
- **Database**: `carambus_api_development`
- **Deploy Server**: Production server (`carambus.de`)
- **Deploy Basename**: `carambus_api`
- **Log File**: `development-api.log` (symbolic link)
- **Server Port**: 3000
- **Environment**: `development-api`
- **Context**: `API`
- **Purpose**: Normal API development

## 🚀 **Usage**

### **Mode Switching**

```bash
# Switch to LOCAL mode
./bin/switch-mode.sh local

# Switch to API mode
./bin/switch-mode.sh api

# Check current mode
./bin/switch-mode.sh status

# Create backup
./bin/switch-mode.sh backup
```

### **Rake Tasks**

```bash
# Switch to LOCAL mode
bundle exec rails mode:local

# Switch to API mode
bundle exec rails mode:api

# Check current mode
bundle exec rails mode:status

# Create backup
bundle exec rails mode:backup
```

### **Multi-Server Development**

```bash
# Start LOCAL server only (port 3001)
./bin/start-local-server.sh

# Start API server only (port 3000)
./bin/start-api-server.sh

# Start both servers simultaneously
./bin/start-both-servers.sh

# Start LOCAL console
./bin/console-local.sh

# Start API console
./bin/console-api.sh
```

### **Manual Server Startup**

```bash
# LOCAL mode server
bundle exec rails server -p 3001 -e development-local

# API mode server
bundle exec rails server -p 3000 -e development-api

# LOCAL mode console
bundle exec rails console -e development-local

# API mode console
bundle exec rails console -e development-api
```

## 📁 **Files Modified**

The mode switcher updates these configuration files:

1. **`config/carambus.yml`**
   - `carambus_api_url` value
   - `context` value
   - `no_local_protection` setting

2. **`config/database.yml`**
   - Development database name

3. **`config/deploy/production.rb`**
   - Deployment server configuration

4. **`config/deploy.rb`**
   - Deploy basename (fixes folder name dependency)

5. **`log/development.log`**
   - Symbolic link to mode-specific log file
   - `development-local.log` for LOCAL mode
   - `development-api.log` for API mode

## 🛡️ **Safety Features**

### **Automatic Backups**
- Creates timestamped backups before switching modes
- Backups stored in `tmp/mode_backups/`
- Easy restoration if needed

### **Status Checking**
- Shows current configuration before switching
- Displays mode differences clearly
- Validates configuration files

## 🎨 **Visual Indicators**

### **Mode Helper**
Use the `ModeHelper` in your views to display the current mode:

```erb
<!-- Simple mode badge -->
<%= render_mode_indicator %>

<!-- Mode badge with tooltip -->
<%= render_mode_tooltip %>
```

### **Available Methods**
- `current_mode` - Returns 'LOCAL' or 'API'
- `mode_badge_class` - CSS classes for styling
- `mode_icon` - Emoji icon (🏠 for LOCAL, 🌐 for API)
- `mode_description` - Human-readable description

## 🔧 **Configuration**

### **Customizing Server Addresses**
Edit the script files to change server addresses:

- **LOCAL mode server**: `192.168.178.81` (in `bin/switch-mode.sh`)
- **API mode server**: `carambus.de` (in `bin/switch-mode.sh`)

### **Customizing Database Names**
Edit the database names in both script files:

- **LOCAL database**: `carambus_local_development`
- **API database**: `carambus_api_development`

## 📋 **Workflow Examples**

### **Testing Local Server Functionality**
```bash
# Start LOCAL server (automatically uses correct environment)
./bin/start-local-server.sh

# Or manually:
bundle exec rails server -p 3001 -e development-local

# Test local_server? functionality
# The application will now behave as if it's running locally
```

### **Normal API Development**
```bash
# Start API server (automatically uses correct environment)
./bin/start-api-server.sh

# Or manually:
bundle exec rails server -p 3000 -e development-api

# Normal API development with production API connection
```

### **Running Both Environments Simultaneously**
```bash
# Start both servers at once
./bin/start-both-servers.sh

# This opens two terminal windows:
# - LOCAL server on http://localhost:3001
# - API server on http://localhost:3000

# You can now test both environments side by side!
```

### **Quick Mode Check**
```bash
# Check current mode before making changes
bundle exec rails mode:status

# Output example:
# Current Configuration:
#   API URL: empty
#   Context: LOCAL
#   Database: carambus_local_development
#   Deploy Basename: carambus_local
#   Log File: development-local.log
# Current Mode: LOCAL
```

## 🚨 **Important Notes**

1. **Database Creation**: You need to create both databases:
   ```bash
   bundle exec rails db:create RAILS_ENV=development
   # Then switch modes and create the other database
   ```

2. **Environment Variables**: The mode switcher preserves your existing environment variable configuration.

3. **Git Integration**: Configuration changes are not automatically committed. Commit mode changes when appropriate.

4. **Backup Restoration**: To restore from backup:
   ```bash
   cp tmp/mode_backups/config_backup_TIMESTAMP/* config/
   ```

## 🔍 **Troubleshooting**

### **Common Issues**

1. **Permission Denied**: Make the script executable:
   ```bash
   chmod +x bin/switch-mode.sh
   ```

2. **Database Connection Errors**: Ensure both databases exist:
   ```bash
   bundle exec rails db:create RAILS_ENV=development
   ```

3. **Configuration Not Updated**: Check file permissions and try running with `sudo` if needed.

### **Verification**
After switching modes, verify the changes:

```bash
# Check carambus.yml
grep -A 5 "development:" config/carambus.yml

# Check database.yml
grep -A 3 "development:" config/database.yml

# Check production.rb
grep "server '" config/deploy/production.rb

# Check deploy.rb basename
grep "set :basename," config/deploy.rb

# Check log file link
ls -la log/development.log
```

---

*This mode switcher eliminates the complexity of managing two separate development folders while maintaining clear separation between local testing and API development modes.* 