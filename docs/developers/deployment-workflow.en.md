# Deployment Workflow - Detailed Guide

This documentation describes the complete workflow from `config.yml` through the API development database to the scenario Rails root for development, production environment preparation, and repeatable Capistrano deployment.

## Workflow Overview

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   config.yml    │───▶│ prepare_development  │───▶│  prepare_deploy     │───▶│     deploy      │
│                 │    │                      │    │                     │    │                 │
│ • Scenario Def  │    │ • Rails Root Setup   │    │ • Production Config │    │ • Capistrano    │
│ • Environments  │    │ • Development DB     │    │ • Database Transfer │    │ • Service Mgmt  │
│ • Server Config │    │ • Asset Compilation  │    │ • Server Setup      │    │ • Asset Build   │
└─────────────────┘    └──────────────────────┘    └─────────────────────┘    └─────────────────┘
```

## Phase 1: Configuration (config.yml)

### Base Setup
```yaml
# carambus_data/scenarios/carambus_location_5101/config.yml
scenario:
  name: carambus_location_5101
  description: Location 5101 Server
  location_id: 5101
  context: LOCAL                    # API, LOCAL, or NBV
  region_id: 1
  club_id: 357
  api_url: https://api.carambus.de/
  season_name: 2025/2026
  application_name: carambus
  basename: carambus_location_5101
  branch: master
  is_main: false

environments:
  development:
    webserver_host: localhost
    webserver_port: 3003
    database_name: carambus_location_5101_development
    ssl_enabled: false
    database_username: null
    database_password: null

  production:
    webserver_host: 192.168.178.107
    ssh_host: 192.168.178.107
    webserver_port: 81
    ssh_port: 8910
    database_name: carambus_location_5101_production
    ssl_enabled: false
    database_username: www_data
    database_password: toS6E7tARQafHCXz
    puma_socket_path: /var/www/carambus_location_5101/shared/sockets/puma-production.sock
    deploy_to: /var/www/carambus_location_5101
```

### What happens here?
- **Scenario Definition**: Name, Location-ID, Region, Club
- **Environment Separation**: Development vs. Production Settings
- **Server Configuration**: SSH access, ports, paths
- **Database Setup**: Names, credentials, socket paths

## Phase 2: Development Setup (prepare_development)

### Complete Flow

```bash
rake "scenario:prepare_development[carambus_location_5101,development]"
```

### Step by Step

#### 2.1 Rails Root Setup
```
/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_5101/
├── .git/                    # Git Repository (Clone from carambus_master)
├── .idea/                   # RubyMine Configuration
├── app/                     # Rails Application
├── config/                  # Rails Configuration
├── lib/                     # Library Files
└── ...
```

**What happens:**
- Git clone from `carambus_master` repository
- Copy of `.idea` configuration for RubyMine
- Correct branch setting (`master`)

#### 2.2 Development Configuration Generation
```
config/
├── database.yml             # Development Database Config
├── carambus.yml            # Scenario-specific Settings
└── cable.yml               # ActionCable Configuration
```

**Generated `database.yml`:**
```yaml
development:
  adapter: postgresql
  database: carambus_location_5101_development
  username: 
  password: 
  host: localhost
  port: 5432
```

**Generated `carambus.yml`:**
```yaml
development:
  scenario_name: carambus_location_5101
  location_id: 5101
  region_id: 1
  club_id: 357
  api_url: https://api.carambus.de/
  season_name: 2025/2026
  context: LOCAL
```

#### 2.3 Database Setup (Template Optimization)

**Source Database**: `carambus_api_development` (mother database)

**Process:**
```bash
# 1. Template-based creation (much faster than pg_dump)
createdb carambus_location_5101_development --template=carambus_api_development

# 2. Region filtering (reduces ~500MB to ~90MB)
RAILS_ENV=development REGION_SHORTNAME=NBV bundle exec rails cleanup:remove_non_region_records

# 3. Version sequence reset (prevents ID conflicts)
RAILS_ENV=development bundle exec rails runner 'Version.sequence_reset'

# 4. Settings update
RAILS_ENV=development bundle exec rails runner '
  Setting.find_or_create_by(key: "last_version_id").update(value: Version.maximum(:id).to_s)
  Setting.find_or_create_by(key: "scenario_name").update(value: "carambus_location_5101")
'
```

**Result**: `carambus_location_5101_development` (processed database)

#### 2.4 Asset Compilation
```bash
# JavaScript Assets
yarn build              # esbuild compilation

# CSS Assets  
yarn build:css          # TailwindCSS compilation

# Rails Assets
RAILS_ENV=development bundle exec rails assets:precompile
```

**Generated Assets:**
```
app/assets/builds/
├── application.js       # Compiled JavaScript
└── application.css      # Compiled CSS

public/assets/
├── application-*.js     # Fingerprinted JS
├── application-*.css    # Fingerprinted CSS
└── manifest-*.json     # Asset manifest
```

#### 2.5 Database Dump Creation
```bash
pg_dump carambus_location_5101_development | gzip > carambus_data/scenarios/carambus_location_5101/database_dumps/carambus_location_5101_production_20241216_143022.sql.gz
```

**Result**: Processed development database saved as dump

## Phase 3: Production Preparation (prepare_deploy)

### Complete Flow

```bash
rake "scenario:prepare_deploy[carambus_location_5101]"
```

### Step by Step

#### 3.1 Production Configuration Generation
```
production/
├── database.yml             # Production Database Config
├── carambus.yml            # Production Settings
├── nginx.conf              # Nginx Configuration
├── puma.rb                 # Puma Configuration
├── puma.service            # systemd Service
├── production.rb           # Rails Production Config
├── cable.yml               # ActionCable Config
├── deploy.rb               # Capistrano Config
├── deploy/
│   └── production.rb       # Capistrano Environment
└── credentials/
    ├── production.yml.enc  # Encrypted Credentials
    └── production.key      # Credentials Key
```

**Generated `nginx.conf`:**
```nginx
server {
    listen 81;
    server_name 192.168.178.107;
    
    location / {
        proxy_pass http://unix:/var/www/carambus_location_5101/shared/sockets/puma-production.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /cable {
        proxy_pass http://unix:/var/www/carambus_location_5101/shared/sockets/puma-production.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

**Generated `puma.rb`:**
```ruby
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count
port        ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "production" }
plugin :tmp_restart

bind "unix:///var/www/carambus_location_5101/shared/sockets/puma-production.sock"
pidfile "/var/www/carambus_location_5101/shared/pids/puma-production.pid"
state_path "/var/www/carambus_location_5101/shared/pids/puma-production.state"
activate_control_app
```

#### 3.2 Development Database Preparation

**Migration and Dump Creation:**
```bash
# 1. Ensure development database has all migrations applied
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_5101
RAILS_ENV=development bundle exec rails db:migrate

# 2. Create production dump from current development database
pg_dump carambus_location_5101_development | gzip > carambus_data/scenarios/carambus_location_5101/database_dumps/carambus_location_5101_production_20241216_143022.sql.gz
```

#### 3.3 Database Transfer and Setup

**Upload Process:**
```bash
# 1. Upload dump to server
scp -P 8910 carambus_location_5101_production_20241216_143022.sql.gz www-data@192.168.178.107:/tmp/

# 2. Reset production database on server
ssh -p 8910 www-data@192.168.178.107 '
  sudo rm -rf /var/www/carambus_location_5101
  sudo -u postgres psql -c "DROP DATABASE IF EXISTS carambus_location_5101_production;"
  sudo -u postgres psql -c "CREATE DATABASE carambus_location_5101_production OWNER www_data;"
'

# 3. Restore database from development dump
ssh -p 8910 www-data@192.168.178.107 '
  gunzip -c /tmp/carambus_location_5101_production_20241216_143022.sql.gz | 
  sudo -u postgres psql carambus_location_5101_production
'

# 4. Verify restoration
ssh -p 8910 www-data@192.168.178.107 '
  sudo -u postgres psql carambus_location_5101_production -c "SELECT COUNT(*) FROM regions;"
  # Expected: 19 regions
'
```

#### 3.4 Server Configuration Upload

**File Transfer:**
```bash
# Upload all config files to shared directory
scp -P 8910 production/database.yml www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/
scp -P 8910 production/carambus.yml www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/
scp -P 8910 production/nginx.conf www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/
scp -P 8910 production/puma.rb www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/
scp -P 8910 production/puma.service www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/
scp -P 8910 production/production.rb www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/environments/
scp -P 8910 production/credentials/* www-data@192.168.178.107:/var/www/carambus_location_5101/shared/config/credentials/
```

**Server Directory Structure:**
```
/var/www/carambus_location_5101/
├── shared/
│   ├── config/
│   │   ├── database.yml
│   │   ├── carambus.yml
│   │   ├── nginx.conf
│   │   ├── puma.rb
│   │   ├── puma.service
│   │   ├── environments/
│   │   │   └── production.rb
│   │   └── credentials/
│   │       ├── production.yml.enc
│   │       └── production.key
│   ├── sockets/           # Created by Capistrano
│   ├── pids/             # Created by Capistrano
│   └── logs/             # Created by Capistrano
└── releases/             # Created by Capistrano
```

## Phase 4: Deployment (deploy)

### Complete Flow

```bash
rake "scenario:deploy[carambus_location_5101]"
```

### Step by Step

#### 4.1 Capistrano Deployment

**Deploy Process:**
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_5101
cap production deploy
```

**What Capistrano Does:**
1. **Git Deployment**: Pulls latest code to `/var/www/carambus_location_5101/releases/TIMESTAMP/`
2. **Symlink Creation**: Creates `/var/www/carambus_location_5101/current` → `releases/TIMESTAMP/`
3. **Asset Compilation**:
   ```bash
   yarn install
   yarn build
   yarn build:css
   RAILS_ENV=production bundle exec rails assets:precompile
   ```
4. **Database Migration**: Runs pending migrations
5. **Service Management**: Automatic Puma restart and Nginx reload

#### 4.2 Automatic Service Management

**Puma Restart (via Capistrano):**
```ruby
# config/deploy.rb
after 'deploy:publishing', 'puma:restart'

namespace :puma do
  task :restart do
    on roles(:app) do
      within current_path do
        execute "./bin/manage-puma.sh"
      end
    end
  end
end
```

**Nginx Reload (automatic):**
```bash
sudo systemctl reload nginx
```

#### 4.3 Final Server State

**Directory Structure:**
```
/var/www/carambus_location_5101/
├── current/               # Symlink to latest release
├── shared/               # Shared configuration
├── releases/             # All releases
└── logs/                 # Application logs
```

**Services:**
```bash
sudo systemctl status puma-carambus_location_5101.service  # Active
sudo systemctl status nginx                                # Active
```

**Database:**
```bash
sudo -u postgres psql carambus_location_5101_production -c "SELECT COUNT(*) FROM regions;"
# Result: 19 regions (verified)
```

## Repeatable Deployment

### For Updates

```bash
# 1. Code changes in carambus_master
git add .
git commit -m "Feature update"
git push carambus master

# 2. Update scenario
rake "scenario:update[carambus_location_5101]"

# 3. Recompile assets (if needed)
rake "scenario:prepare_development[carambus_location_5101,development]"

# 4. Production deployment
rake "scenario:deploy[carambus_location_5101]"
```

### For Configuration Changes

```bash
# 1. Modify config.yml
# 2. Regenerate production configuration
rake "scenario:prepare_deploy[carambus_location_5101]"

# 3. Deploy
rake "scenario:deploy[carambus_location_5101]"
```

## Workflow Benefits

### ✅ Clear Separation of Responsibilities
- **Development Setup**: Local development and testing
- **Production Preparation**: Server setup and configuration
- **Deployment**: Pure Capistrano operation

### ✅ Automatic Service Management
- No manual `systemctl` commands needed
- Capistrano manages all services automatically
- Consistent service states

### ✅ Robust Asset Pipeline
- Sprockets-based asset management
- TailwindCSS integration
- JavaScript bundling with esbuild

### ✅ Intelligent Database Operations
- Template optimization for fast DB creation
- Region filtering for optimal performance
- Automatic sequence management

### ✅ Blank Server Deployment
- Complete server setup in one step
- Automatic permission correction
- No manual configuration steps

## Troubleshooting

### Common Issues

1. **Asset Precompilation Errors**
   ```bash
   cd carambus_location_5101
   rm -rf tmp/cache .sprockets-cache
   yarn build && yarn build:css && rails assets:precompile
   ```

2. **Database Sequence Conflicts**
   ```bash
   rake "scenario:prepare_development[scenario_name,development]"
   ```

3. **Service Problems**
   ```bash
   # Don't fix manually, instead:
   rake "scenario:prepare_deploy[scenario_name]"
   rake "scenario:deploy[scenario_name]"
   ```

4. **Port Conflicts**
   ```bash
   # Adjust in config.yml:
   webserver_port: 3004  # Use different port
   ```

## Best Practices

### Deployment Order
1. **Always first**: `prepare_development` for local testing
2. **Then**: `prepare_deploy` for production preparation  
3. **Finally**: `deploy` for server deployment

### Asset Development
- Use `prepare_development` for local asset testing
- Always test in development environment before production

### Database Management
- Development database is the "source of truth"
- Production is always created from development dump
- Sequence reset happens automatically

### Service Management
- Never use manual `systemctl` commands
- Capistrano manages all services automatically
- In case of problems: re-run `prepare_deploy`

## Automated Workflow with bin/deploy-scenario.sh

The `bin/deploy-scenario.sh` script automates the complete deployment workflow from configuration to running system.

### Overview

```bash
# Full workflow (deletes everything and creates fresh)
bin/deploy-scenario.sh carambus_location_5101

# With auto-confirm (no interactive prompts)
bin/deploy-scenario.sh carambus_location_5101 -y

# Production-only mode (preserves development environment)
bin/deploy-scenario.sh carambus_location_5101 --production-only

# Skip cleanup (skips deletion but recreates development)
bin/deploy-scenario.sh carambus_location_5101 --skip-cleanup
```

### Workflow Modes

#### Standard Mode (Full Workflow)

```bash
bin/deploy-scenario.sh carambus_bcw
```

**Executed steps:**

1. **Step 0: Complete Cleanup** 🧹
   - Deletes local scenario directory (`$CARAMBUS_BASE/$SCENARIO_NAME`)
   - Drops development database (except for `carambus_api`)
   - Removes Puma service on Raspberry Pi
   - Removes Nginx configuration
   - Drops production database (with safety checks for local data)
   - Deletes deployment directory (`/var/www/${SCENARIO_NAME}`)

2. **Step 1: Prepare Development** 🔧
   - Generates all configuration files
   - Creates Rails root folder
   - Syncs with `carambus_api_production` (if newer data available)
   - Creates development database from template
   - Applies region filtering
   - Sets up development environment

3. **Step 2: Prepare Deploy** 📦
   - Generates production configuration files
   - Creates production database from development dump
   - Backs up local data (ID > 50,000,000) - **automatically**
   - Restores local data after DB replacement - **automatically**
   - Copies deployment files (nginx, puma, etc.)
   - Uploads config files to server
   - Creates systemd service and Nginx configuration

4. **Step 3: Deploy** 🚀
   - Executes Capistrano deployment
   - Automatically restarts Puma service
   - Completes deployment

5. **Step 4: Prepare Client** 🍓
   - Installs required packages (chromium, wmctrl, xdotool)
   - Creates kiosk user
   - Sets up systemd service

6. **Step 5: Deploy Client** 📱
   - Uploads scoreboard URL
   - Installs autostart script
   - Enables systemd service
   - Starts kiosk mode

7. **Step 6: Final Test** 🧪
   - Tests complete functionality
   - Tests browser restart

#### Production-Only Mode (⭐ Recommended for Config Updates)

```bash
bin/deploy-scenario.sh carambus_bcw --production-only
```

**When to use:**
- Only update production configuration (e.g., new `deploy.rb`)
- Development environment should remain **unchanged**
- Preserve local modifications in development
- Faster iteration without recreating development

**What is NOT done:**
- ❌ Step 0: Cleanup is skipped
- ❌ Step 1: Development environment is **NOT REGENERATED**
  - Existing development directory remains **UNCHANGED**
  - No changes to development database
  - All local modifications are preserved

**What is done:**
- ✅ Step 2: **Only** regenerate production config
  - Generates new `config/deploy.rb` from template
  - Generates new `config/deploy/production.rb`
  - Updates production database (with local data backup)
  - Uploads new config files to server
- ✅ Step 3-7: Deploy, client setup, tests

**Example use case:**
```bash
# Template was changed in carambus_master (e.g., deploy.rb fix)
# Production config should be regenerated, but development stays
cd /path/to/carambus_master
git pull  # Fetches new templates

# Only regenerate production
bin/deploy-scenario.sh carambus_bcw --production-only -y
```

#### Skip-Cleanup Mode

```bash
bin/deploy-scenario.sh carambus_bcw --skip-cleanup
```

**When to use:**
- Iterative development
- Development database should not be dropped
- Server cleanup should be skipped

**⚠️ IMPORTANT:** Development is still **regenerated**!
- Config files will be overwritten
- Local modifications will be lost
- For config preservation, use `--production-only` instead

**What is NOT done:**
- ❌ Step 0: Cleanup is skipped

**What is done:**
- ✅ Step 1: Development **is REGENERATED** (overwrites files!)
- ✅ Step 2-7: All other steps

### Mode Comparison

| Flag | Step 0 (Cleanup) | Step 1 (Dev) | Step 2 (Prod) | Development Files | Use Case |
|------|-----------------|--------------|---------------|-------------------|----------|
| (none) | ✅ Complete | ✅ Recreate | ✅ Recreate | ⚠️ Complete fresh | Full setup |
| `--skip-cleanup` | ❌ Skipped | ✅ **Recreate** | ✅ Recreate | ⚠️ Overwritten | Iterative development |
| `--production-only` | ❌ Skipped | ❌ **Preserve** | ✅ Recreate | ✅ **Unchanged** | Production config updates |

### Practical Examples

#### Example 1: Initial Setup of New Scenario

```bash
# config.yml was created in carambus_data/scenarios/carambus_location_5101/
cd /path/to/carambus_master

# Complete setup
bin/deploy-scenario.sh carambus_location_5101 -y

# Result:
# - Development environment created
# - Production deployed
# - Client configured
# - System running
```

#### Example 2: Template Update for Existing Scenarios

```bash
# Situation: deploy.rb template was fixed in carambus_master
cd /path/to/carambus_master
git pull  # Fetches new template

# Only regenerate production config (for all scenarios)
for scenario in carambus_bcw carambus_phat carambus_pbv; do
  bin/deploy-scenario.sh $scenario --production-only -y
done

# Result:
# - New deploy.rb generated from template
# - Production deployed with new config
# - Development remains unchanged
```

#### Example 3: Code Update for Scenario

```bash
cd /path/to/carambus_bcw
git pull  # New code version

# Only deploy, no config changes
cap production deploy

# Or if assets should be forced:
FORCE_ASSETS=1 cap production deploy
```

#### Example 4: Testing After Template Change

```bash
# Only regenerate production for a test scenario
bin/deploy-scenario.sh carambus_test --production-only -y

# Test if it works
# If OK: Repeat for all other scenarios
```

### Safety Mechanisms

#### Local Data Detection

The script automatically protects against data loss:

```bash
# During cleanup, it checks:
# 1. Does production DB have local data (ID > 50,000,000)?
# 2. Is production DB version newer than development?

# If YES → Database will NOT be dropped
# If NO → Database will be dropped and recreated
```

**Automatic Backup & Restore:**
```bash
# In Step 2 (prepare_deploy):
# 1. Check: Does production have local data?
# 2. YES → Automatic backup before DB drop
# 3. New DB created from development
# 4. Automatic restore of local data
# 5. No manual intervention needed!
```

#### Confirmation Prompts

```bash
# Interactive mode (default):
bin/deploy-scenario.sh carambus_bcw
# → Asks for confirmation at each critical step

# Auto-confirm mode (for automation):
bin/deploy-scenario.sh carambus_bcw -y
# → Executes all steps automatically
```

### Error Handling

#### Development Directory Does Not Exist (--production-only)

```bash
$ bin/deploy-scenario.sh carambus_new --production-only
⏭️  Step 0: Cleanup skipped (--production-only)
⏭️  Step 1: Development preparation skipped (--production-only)
❌ Development environment not found at /path/to/carambus_new
❌ Run without --production-only first to create it

# Solution: First run complete setup
$ bin/deploy-scenario.sh carambus_new -y
```

#### Production Database Has Newer Version

```bash
$ bin/deploy-scenario.sh carambus_bcw
⚠️  Production database version (20250116120000) is higher than development (20250115100000)
✅ Production database preserved (has local data or newer version)
ℹ️  Step 2 (prepare_deploy) will handle database update with data preservation
```

#### SSH Connection Failed

```bash
# Step 0 checks SSH connection
# If not reachable → Script stops with clear error message
❌ Could not connect to SSH server bc-wedel.duckdns.org:8910
```

### Best Practices

#### 1. Separate Development and Production

```bash
# ✅ CORRECT: Update production config separately
bin/deploy-scenario.sh carambus_bcw --production-only -y

# ❌ WRONG: Full workflow for small changes
bin/deploy-scenario.sh carambus_bcw -y  # Deletes everything!
```

#### 2. Maintain Templates Centrally

```bash
# All templates are in carambus_master
cd /path/to/carambus_master

# Modify template
vim templates/deploy/deploy_rb.erb

# Commit & push
git add templates/deploy/deploy_rb.erb
git commit -m "Fix deploy.rb template"
git push

# Roll out to all scenarios
for scenario in carambus_bcw carambus_phat carambus_pbv; do
  bin/deploy-scenario.sh $scenario --production-only -y
done
```

#### 3. Preserve Local Modifications

```bash
# Development has local modifications (e.g., in config.yml)
# → Use --production-only

# ✅ Preserves development
bin/deploy-scenario.sh carambus_bcw --production-only -y

# ❌ Overwrites development
bin/deploy-scenario.sh carambus_bcw --skip-cleanup -y
```

#### 4. Iterative Code Development

```bash
# Code changes in carambus_master
cd /path/to/carambus_master
git add .
git commit -m "Feature X"
git push

# Update scenarios (code only, no config)
cd /path/to/carambus_bcw
git pull
cap production deploy

# Or if assets need to be rebuilt:
FORCE_ASSETS=1 cap production deploy
```

### Workflow Diagram with Modes

```
┌─────────────────────────────────────────────────────────────┐
│  bin/deploy-scenario.sh <scenario> [flags]                  │
└─────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌────────────────┐  ┌──────────────┐  ┌──────────────────┐
│ (no flags)     │  │ --skip-      │  │ --production-    │
│                │  │ cleanup      │  │ only             │
└────────────────┘  └──────────────┘  └──────────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌────────────────┐  ┌──────────────┐  ┌──────────────────┐
│ Step 0: ✅     │  │ Step 0: ❌   │  │ Step 0: ❌       │
│ Cleanup        │  │ Skip         │  │ Skip             │
└────────────────┘  └──────────────┘  └──────────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌────────────────┐  ┌──────────────┐  ┌──────────────────┐
│ Step 1: ✅     │  │ Step 1: ✅   │  │ Step 1: ❌       │
│ Prepare Dev    │  │ Regenerate!  │  │ Keep existing!   │
│ (fresh)        │  │ (⚠️ overwrite)│  │ (✅ preserve)    │
└────────────────┘  └──────────────┘  └──────────────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           ▼
                  ┌──────────────────┐
                  │ Step 2: ✅       │
                  │ Prepare Deploy   │
                  │ (Production)     │
                  └──────────────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │ Step 3-7: ✅     │
                  │ Deploy, Client,  │
                  │ Tests            │
                  └──────────────────┘
```

### Cheat Sheet

```bash
# Complete setup (first time)
bin/deploy-scenario.sh <scenario> -y

# Roll out template update (preserves development)
bin/deploy-scenario.sh <scenario> --production-only -y

# Only deploy code (no config changes)
cd /path/to/<scenario> && git pull && cap production deploy

# Force assets rebuild
FORCE_ASSETS=1 cap production deploy

# Update all scenarios with new template
for s in carambus_bcw carambus_phat carambus_pbv; do
  bin/deploy-scenario.sh $s --production-only -y
done
```
