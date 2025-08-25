# Carambus Mode Switcher

The Carambus Mode Switcher allows you to easily switch between **LOCAL** and **API** modes using a single development folder, eliminating the need to maintain two separate folders.

## 🎯 **Overview**

Instead of having separate `carambus` and `carambus_api` folders, you can now use a single folder with a mode switcher that automatically updates the necessary configuration files using ERB templates.

## 🔄 **Mode Differences**

### **LOCAL Mode**
- **carambus_api_url**: `https://newapi.carambus.de/`
- **Database**: `carambus_development`
- **Deploy Server**: Local testing server (`192.168.178.81`)
- **Deploy Basename**: `carambus`
- **Log File**: `development-local.log` (symbolic link)
- **Server Port**: 3001
- **Environment**: `development-local`
- **Context**: `NBV`
- **Purpose**: Testing `local_server?` functionality

### **API Mode**
- **carambus_api_url**: Empty (nil)
- **Database**: `carambus_api_development`
- **Deploy Server**: Production server (`carambus.de`)
- **Deploy Basename**: `carambus_api`
- **Log File**: `development-api.log` (symbolic link)
- **Server Port**: 3000
- **Environment**: `development-api`
- **Context**: Empty (nil)
- **Purpose**: Normal API development

## 🚀 **Usage**

### **Rake Tasks (Primary Method)**

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

The mode switcher uses ERB templates to generate these configuration files:

1. **`config/carambus.yml`** (generated from `config/carambus.yml.erb`)
   - `carambus_api_url` value
   - `context` value
   - `basename` value
   - `carambus_domain` value
   - `location_id` value
   - `application_name` value
   - `club_id` value

2. **`config/database.yml`** (generated from `config/database.yml.erb`)
   - Development database name

3. **`config/deploy.rb`** (generated from `config/deploy.rb.erb`)
   - Deploy basename (fixes folder name dependency)

4. **`log/development.log`**
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

### **Template Validation**
- Checks for required ERB template files
- Provides clear error messages if templates are missing
- Ensures proper template substitution

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

### **ERB Templates**
The mode switcher uses these ERB template files:

- **`config/carambus.yml.erb`** - Main configuration template
- **`config/database.yml.erb`** - Database configuration template  
- **`config/deploy.rb.erb`** - Deployment configuration template

### **Template Variables**
The templates use these variables that get substituted during mode switching:

- `<%= carambus_api_url %>` - API URL for the mode
- `<%= database %>` - Database name for the mode
- `<%= basename %>` - Deploy basename for the mode
- `<%= context %>` - Context identifier for the mode
- `<%= carambus_domain %>` - Domain for the mode
- `<%= location_id %>` - Location ID for the mode
- `<%= application_name %>` - Application name
- `<%= club_id %>` - Club ID for the mode

## 📋 **Workflow Examples**

### **Testing Local Server Functionality**
```bash
# Switch to LOCAL mode
bundle exec rails mode:local

# Start LOCAL server
bundle exec rails server -p 3001 -e development-local

# Test local_server? functionality
# The application will now behave as if it's running locally
```

### **Normal API Development**
```bash
# Switch to API mode
bundle exec rails mode:api

# Start API server
bundle exec rails server -p 3000 -e development-api

# Normal API development with production API connection
```

### **Running Both Environments Simultaneously**
```bash
# Terminal 1: Start LOCAL server
bundle exec rails mode:local
bundle exec rails server -p 3001 -e development-local

# Terminal 2: Start API server  
bundle exec rails mode:api
bundle exec rails server -p 3000 -e development-api

# You can now test both environments side by side!
```

### **Quick Mode Check**
```bash
# Check current mode before making changes
bundle exec rails mode:status

# Output example:
# Current Configuration:
#   API URL: https://newapi.carambus.de/
#   Context: NBV
#   Database: carambus_development
#   Deploy Basename: carambus
#   Log File: development-local.log
# Current Mode: LOCAL
```

## 🚨 **Important Notes**

1. **Database Creation**: You need to create both databases:
   ```bash
   # Option 1: Import existing database dump (recommended)
   createdb carambus_development
   psql -d carambus_development -f /path/to/your/dump.sql
   
   # Option 2: Create fresh database (if no dump available)
   bundle exec rails db:create RAILS_ENV=development
   # Then switch modes and create the other database
   ```

2. **ERB Templates**: Ensure all required ERB template files exist:
   - `config/carambus.yml.erb`
   - `config/database.yml.erb`
   - `config/deploy.rb.erb`

3. **Environment Variables**: The mode switcher preserves your existing environment variable configuration.

4. **Git Integration**: Configuration changes are not automatically committed. Commit mode changes when appropriate.

5. **Backup Restoration**: To restore from backup:
   ```bash
   cp tmp/mode_backups/config_backup_TIMESTAMP/* config/
   ```

## 🔍 **Troubleshooting**

### **Common Issues**

1. **Missing ERB Templates**: Ensure all template files exist:
   ```bash
   ls -la config/*.erb
   ```

2. **Database Connection Errors**: Ensure both databases exist:
   ```bash
   # Option 1: Import existing database dump (recommended)
   createdb carambus_development
   psql -d carambus_development -f /path/to/your/dump.sql
   
   # Option 2: Create fresh database (if no dump available)
   bundle exec rails db:create RAILS_ENV=development
   ```

3. **Configuration Not Updated**: Check file permissions and try running with `sudo` if needed.

4. **Template Substitution Errors**: Verify ERB syntax in template files.

### **Verification**
After switching modes, verify the changes:

```bash
# Check carambus.yml
grep -A 5 "development:" config/carambus.yml

# Check database.yml
grep -A 3 "development:" config/database.yml

# Check deploy.rb basename
grep "set :basename," config/deploy.rb

# Check log file link
ls -la log/development.log
```

### **Template Debugging**
To debug template issues:

```bash
# Check template content
cat config/carambus.yml.erb
cat config/database.yml.erb
cat config/deploy.rb.erb

# Verify template variables are properly formatted
grep -n "<%=" config/*.erb
```

---

*This enhanced mode switcher uses ERB templates for better maintainability and eliminates the complexity of managing two separate development folders while maintaining clear separation between local testing and API development modes.* 
