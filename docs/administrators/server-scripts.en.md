# Server Management Scripts

This documentation describes all available scripts for managing Carambus servers (Development, Production, API).

## Overview

The Server Management Scripts are located in `carambus_master/bin/` and cover the following areas:
- **Development Server**: Start/manage local development environment
- **Production Server**: Service management (Puma, Nginx)
- **Rails Console**: Database access and debugging
- **Asset Management**: Rebuild JavaScript/CSS
- **Utilities**: Setup, restart, cleanup

---

## Development Server

### `start-api-server.sh`
**Purpose**: Starts the API server (development mode)

**Usage**:
```bash
cd carambus_master
./bin/start-api-server.sh
```

**What it does**:
1. ✅ Checks if port 3000 is free
2. ✅ Starts Puma server for carambus_api
3. ✅ Loads development configuration
4. ✅ Enables live reload

**Prerequisites**:
- `carambus_api_development` database exists
- Dependencies installed (`bundle install`)
- Assets compiled

**Access**:
```
http://localhost:3000
```

---

### `start-local-server.sh`
**Purpose**: Starts a local scenario server (development mode)

**Usage**:
```bash
./bin/start-local-server.sh <scenario_name>
```

**What it does**:
1. ✅ Changes to scenario directory
2. ✅ Reads port from `config.yml`
3. ✅ Starts Puma with scenario-specific config
4. ✅ Enables StimulusReflex/ActionCable

**Examples**:
```bash
# Starts carambus_location_5101 on port 3003
./bin/start-local-server.sh carambus_location_5101

# Starts carambus_bcw on port 3007  
./bin/start-local-server.sh carambus_bcw
```

**Prerequisites**:
- Scenario prepared with `prepare_development`
- `config.yml` exists with `webserver_port`

---

### `start-both-servers.sh`
**Purpose**: Starts API server and local server simultaneously

**Usage**:
```bash
./bin/start-both-servers.sh <scenario_name>
```

**What it does**:
- Starts API server (port 3000) in background
- Starts scenario server (port from config.yml)
- Both servers run in parallel

**Use Cases**:
- Complete local testing
- API sync testing
- Development with multiple scenarios

**Example**:
```bash
./bin/start-both-servers.sh carambus_location_5101
# API available: http://localhost:3000
# Location available: http://localhost:3003
```

**Stopping**:
```bash
# Stop both servers
pkill -f puma
```

---

## Production Server Management

### `manage-puma.sh`
**Purpose**: Manages Puma service on production server

**Usage**:
```bash
# On the server:
./bin/manage-puma.sh [start|stop|restart|status]

# Remote via SSH:
ssh -p 8910 www-data@192.168.178.107 'cd /var/www/carambus_location_5101/current && ./bin/manage-puma.sh restart'
```

**Actions**:
- `start`: Starts Puma service
- `stop`: Stops Puma service cleanly
- `restart`: Stops and starts (used by Capistrano)
- `status`: Shows service status

**What it does**:
1. ✅ Checks systemd service status
2. ✅ Executes action
3. ✅ Waits for service start
4. ✅ Verifies socket/PID

**Important**: Called automatically by Capistrano, manual use rarely needed.

---

### `manage-puma-api.sh`
**Purpose**: Manages Puma service for API server

**Usage**:
```bash
./bin/manage-puma-api.sh [start|stop|restart|status]
```

**Same functionality as `manage-puma.sh`, specifically for API server**

---

### `restart-carambus.sh`
**Purpose**: Quick restart for Carambus server

**Usage**:
```bash
# Local
./bin/restart-carambus.sh

# Remote
ssh -p 8910 www-data@192.168.178.107 '/var/www/carambus_location_5101/current/bin/restart-carambus.sh'
```

**What it does**:
1. ✅ Stops Puma service
2. ✅ Cleans PIDs/sockets
3. ✅ Restarts service
4. ✅ Waits for success

**Use Cases**:
- Deploy code changes without Capistrano
- After configuration changes
- Quick restart on problems

---

## Rails Console

There is no dedicated console wrapper script. Use the standard Rails console
(`bin/rails console`) in the relevant scenario or API directory.

### Local / API console (development)

**Usage**:
```bash
# In the API checkout
cd carambus_api
bin/rails console

# In a scenario checkout
cd carambus_location_5101
bin/rails console
```

**Example Session**:
```ruby
> Player.count
=> 69082

> Version.last.id
=> 12227261

> Setting.find_by(key: 'last_version_id').value
=> "12227261"

# Check local data (records with id >= 50_000_000 are local)
> Game.where('id > 50000000').count
=> 28

> TableLocal.count
=> 10
```

### Production console

**Usage**:
```bash
# SSH to the production server, then open the console in the deployment dir
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
RAILS_ENV=production bundle exec rails console
```

**⚠️ WARNING**: Production console! Be careful with changes!

**Example**:
```ruby
> Rails.env
=> "production"

> Game.count
=> 280163
```

**Best Practice**:
- Never destructive operations without backup
- Only read operations for debugging
- For changes: Create migration

---

## Asset Management

### `rebuild_js.sh`
**Purpose**: Recompile JavaScript assets

**Usage**:
```bash
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh
```

**What it does**:
1. ✅ `yarn build` (esbuild)
2. ✅ `yarn build:css` (TailwindCSS)
3. ✅ `rails assets:precompile` (Sprockets)

**Use Cases**:
- After JavaScript changes
- After CSS changes
- Fix asset build errors

**Example**:
```bash
# JavaScript changed, rebuild
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# Restart development server
./bin/start-local-server.sh carambus_location_5101
```

---

### `cleanup_rails.sh`
**Purpose**: Clean Rails cache and temporary files

**Usage**:
```bash
./bin/cleanup_rails.sh
```

**What it does**:
- Deletes `tmp/cache/`
- Deletes `.sprockets-cache/`
- Deletes `log/*.log` (optional)
- Cleans asset cache

**Use Cases**:
- Fix asset problems
- Free disk space
- After large code changes

---

### `cleanup_versions.sh`
**Purpose**: Cleans old version entries

**Usage**:
```bash
./bin/cleanup_versions.sh [--dry-run]
```

**What it does**:
- Deletes version entries older than X days
- Keeps last N versions
- Optional: Display only (--dry-run)

**⚠️ WARNING**: Only use on local servers! Not on API server!

---

## Debug & Testing

There is no single `debug-production.sh` script. Use the dedicated diagnostic
scripts below depending on what you need to inspect.

### `diagnose-puma-carambus.sh`
**Purpose**: Detailed diagnosis of Puma socket/service connection issues

**Usage**:
```bash
./bin/diagnose-puma-carambus.sh
```

**What is checked**:
1. ✅ Puma socket path and permissions
2. ✅ Service status (Puma, Nginx)
3. ✅ Process list
4. ✅ Recent log output

### `check-database-states.sh`
**Purpose**: Inspect current database states for a scenario

**Usage**:
```bash
./bin/check-database-states.sh <scenario_name>

# Example
./bin/check-database-states.sh carambus_location_5101
```

### Other diagnostics
- `diagnose-nginx.sh` — Nginx configuration / connectivity
- `diagnose-socket-issue.sh` — Puma/Nginx socket problems
- `check-puma-logs.sh` — recent Puma log output
- `check-actioncable-status.sh` — ActionCable / WebSocket status

---

## Setup & Installation

### `carambus-install.sh`
**Purpose**: Complete Carambus installation on new server

**Usage**:
```bash
./bin/carambus-install.sh
```

**What is installed**:
1. ✅ System dependencies (Ruby, Node, PostgreSQL)
2. ✅ Nginx + SSL
3. ✅ Redis (for ActionCable)
4. ✅ Git + SSH keys
5. ✅ Deployment user (www-data)
6. ✅ Directory structure

**Prerequisites**:
- Fresh Ubuntu/Debian system
- Root access
- Internet connection

**Duration**: ~30 minutes

---

### `setup-local-dev.sh`
**Purpose**: Set up local development environment

**Usage**:
```bash
./bin/setup-local-dev.sh
```

**What it does**:
1. ✅ Checks system dependencies
2. ✅ Installs Ruby gems (`bundle install`)
3. ✅ Installs Node packages (`yarn install`)
4. ✅ Creates local database
5. ✅ Loads seed data
6. ✅ Compiles assets

---

### `generate-ssl-cert.sh`
**Purpose**: Generate SSL certificates for development/testing

**Usage**:
```bash
./bin/generate-ssl-cert.sh [domain]
```

**What it does**:
- Generates self-signed certificate
- Creates private key
- Saves in `ssl/` directory

**Use Cases**:
- Local HTTPS testing
- Development with SSL features
- Scoreboard testing with secure connection

**Example**:
```bash
# Certificate for localhost
./bin/generate-ssl-cert.sh localhost

# Certificate for custom domain
./bin/generate-ssl-cert.sh carambus.local
```

---

## Legacy/Deprecated Scripts

### `deploy.sh` ⚠️
**Status**: Obsolete (replaced by `deploy-scenario.sh`)  
**Reason**: Old deployment system without scenario support

### `deploy-to-raspberry-pi.sh` ⚠️
**Status**: Obsolete (replaced by `deploy-scenario.sh`)  
**Reason**: Integrated into new scenario system

### `puma-wrapper.sh` ⚠️
**Status**: Obsolete (replaced by `manage-puma.sh`)  
**Reason**: Outdated service management logic

### `sync-carambus-folders.sh` ⚠️
**Status**: Obsolete  
**Reason**: Replaced by Git workflow

---

## Workflow Examples

### Start Local Development Session

```bash
# 1. Prepare development environment
rake "scenario:prepare_development[carambus_location_5101,development]"

# 2. Build assets
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# 3. Start server
cd ../carambus_master
./bin/start-both-servers.sh carambus_location_5101

# API: http://localhost:3000
# Location: http://localhost:3003
```

### Deploy Code Change (Complete)

```bash
# 1. Commit code
git add .
git commit -m "Feature: XYZ"
git push carambus master

# 2. Update scenario
rake "scenario:update[carambus_location_5101]"

# 3. Rebuild assets
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# 4. Deploy
cd ../carambus_master
./bin/deploy-scenario.sh carambus_location_5101

# 5. Restart browser on RasPi
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'
```

### Quick Fix Without Complete Deployment

```bash
# 1. Commit small change
git commit -am "Fix: typo"
git push carambus master

# 2. Pull on production server
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
git pull

# 3. Restart server
./bin/restart-carambus.sh
exit

# 4. Restart browser
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'
```

### Debug Production Problem

```bash
# 1. Collect debug info
./bin/diagnose-puma-carambus.sh > debug.log
./bin/check-database-states.sh carambus_location_5101 >> debug.log

# 2. Check logs
less debug.log

# 3. Open console (if needed)
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
RAILS_ENV=production bundle exec rails console

# 4. Apply quick fix
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart puma-carambus_location_5101'
```

---

## Troubleshooting

### Puma Won't Start

```bash
# Problem: "Address already in use"
# Solution: Stop old processes
ssh -p 8910 www-data@192.168.178.107
pkill -9 puma
rm /var/www/carambus_location_5101/shared/pids/*.pid
rm /var/www/carambus_location_5101/shared/sockets/*.sock
./bin/manage-puma.sh start
```

### Assets Missing After Deployment

```bash
# Problem: "Asset not found"
# Solution: Recompile assets
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# On server:
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
RAILS_ENV=production bundle exec rails assets:precompile
./bin/restart-carambus.sh
```

### Database Connection Fails

```bash
# Problem: "could not connect to server"
# Solution: Check PostgreSQL service
ssh -p 8910 www-data@192.168.178.107
sudo systemctl status postgresql
sudo systemctl start postgresql

# Check config
cat /var/www/carambus_location_5101/shared/config/database.yml
```

### Memory Problems

```bash
# Problem: "Cannot allocate memory"
# Solution: Memory analysis and cleanup
ssh -p 8910 www-data@192.168.178.107 'free -h'

# Clean cache
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
./bin/cleanup_rails.sh

# Restart services
sudo systemctl restart puma-carambus_location_5101
```

---

## Best Practices

### Development
1. ✅ Always start both servers for complete testing
2. ✅ Run `rebuild_js.sh` after asset changes
3. ✅ Use console for quick database checks
4. ✅ Regularly run `cleanup_rails.sh`

### Production
1. ✅ Never manually start/stop Puma (use Capistrano)
2. ✅ Console only for debugging, not for data changes
3. ✅ On problems: First run `diagnose-puma-carambus.sh` / `check-database-states.sh`
4. ✅ Check logs regularly

### Deployment
1. ✅ Complete deployment: `deploy-scenario.sh`
2. ✅ Quick fixes: Only in emergencies
3. ✅ After deployment: Restart browser on RasPi
4. ✅ Before deployment: Local testing

---

## Monitoring & Maintenance

### Daily Checks

```bash
# Service status
ssh -p 8910 www-data@192.168.178.107 'systemctl status puma-carambus_location_5101'

# Disk space
ssh -p 8910 www-data@192.168.178.107 'df -h'

# Logs (errors)
ssh -p 8910 www-data@192.168.178.107 'tail -100 /var/www/carambus_location_5101/current/log/production.log | grep ERROR'
```

### Weekly Maintenance

```bash
# 1. Clean Rails cache
ssh -p 8910 www-data@192.168.178.107 'cd /var/www/carambus_location_5101/current && ./bin/cleanup_rails.sh'

# 2. Rotate logs
ssh -p 8910 www-data@192.168.178.107 'sudo logrotate -f /etc/logrotate.d/carambus'

# 3. Check disk space
ssh -p 8910 www-data@192.168.178.107 'df -h'
```

### Monthly Maintenance

```bash
# 1. System updates
ssh -p 8910 www-data@192.168.178.107
sudo apt update && sudo apt upgrade -y

# 2. Update Ruby/Node/Gems
cd /var/www/carambus_location_5101/current
bundle update
yarn upgrade

# 3. Restart services
sudo systemctl restart puma-carambus_location_5101
sudo systemctl restart nginx
```

---

## See Also

- [Deployment Workflow](../developers/deployment-workflow.md) - Complete deployment process
- [Scenario Management](../developers/scenario-management.md) - Scenario system overview  
- [Raspberry Pi Scripts](raspberry_pi_scripts.md) - RasPi client management
- [Database Syncing](../developers/database-partitioning.md) - Database synchronization





