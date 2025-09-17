# Scenario Management System

The Scenario Management System allows managing and automatically deploying different deployment environments (scenarios) for Carambus.

## Overview

The system supports various scenarios such as:
- **carambus**: Main production environment
- **carambus_api**: API server
- **carambus_location_5101**: Local server instance for location 5101
- **carambus_location_2459**: Local server instance for location 2459
- **carambus_location_2460**: Local server instance for location 2460

## Improved Deployment Workflow (2024)

The system has been completely redesigned and now offers clean separation of responsibilities:

### Workflow Overview

```
config.yml → prepare_development → prepare_deploy → deploy
     ↓              ↓                   ↓            ↓
   Basis      Development        Production      Server
   Setup        Setup            Preparation    Deployment
```

## Main Workflow

### 1. `scenario:prepare_development[scenario_name,environment]`
**Purpose**: Set up local development environment

**Complete Flow**:
1. **Load Configuration**: Reads `config.yml` for scenario-specific settings
2. **Create Rails Root**: Git clone + .idea configuration (if not exists)
3. **Generate Development Configuration**: 
   - `database.yml` for development environment
   - `carambus.yml` with scenario-specific settings
   - `cable.yml` for ActionCable
4. **Database Setup**:
   - Creates `carambus_scenarioname_development` from template `carambus_api_development`
   - Applies region filtering (reduces ~500MB to ~90MB)
   - Sets `last_version_id` for sync tracking
   - Resets version sequence to 50,000,000+ (prevents ID conflicts)
5. **Asset Compilation**:
   - `yarn build` (JavaScript)
   - `yarn build:css` (TailwindCSS)
   - `rails assets:precompile` (Sprockets)
6. **Create Database Dump**: Saves processed development database

**Perfect for**: Local development, scenario testing, asset development

### 2. `scenario:prepare_deploy[scenario_name]`
**Purpose**: Complete production deployment preparation

**Complete Flow**:
1. **Generate Production Configuration**:
   - `database.yml` for production
   - `carambus.yml` with production settings
   - `nginx.conf` with correct host/port settings
   - `puma.rb` with Unix socket configuration
   - `puma.service` for systemd
   - `production.rb` with ActionCable configuration
   - `cable.yml` for ActionCable PubSub
   - `deploy.rb` for Capistrano
   - `credentials/` with production keys
2. **Database Setup**:
   - **Upload and Load Database Dump**: Transfers development dump to server
   - **Database Reset**: Removes old application folders, creates new production DB
   - **Dump Restoration**: Loads processed development database into production
   - **Verification**: Checks correct restoration (19 regions)
3. **Server Configuration**:
   - **File Transfers**: Upload all configuration files to `/var/www/scenario/shared/config/`
   - **Directory Setup**: Creates deployment directories with correct permissions
   - **Service Preparation**: Prepares systemd and Nginx

**Perfect for**: Complete deployment preparation, blank server setup

### 3. `scenario:deploy[scenario_name]`
**Purpose**: Pure Capistrano deployment with automatic service management

**Complete Flow**:
1. **Database & Config Ready**: Uses already prepared database and configuration
2. **Capistrano Deployment**:
   - Git deployment with asset precompilation
   - `yarn install`, `yarn build`, `yarn build:css`
   - `rails assets:precompile`
   - **Automatic Puma Restart** via Capistrano hooks
   - **Automatic Nginx Reload** via Capistrano
3. **Service Management**: All services are automatically managed by Capistrano

**Perfect for**: Production deployment, repeatable deployments

## Database Flow Explanation

### Source → Development → Production

```
carambus_api_development (mother database)
                    ↓
    ┌─────────────────────────────────────┐
    │ prepare_development                 │
    │ 1. Template: --template=api_dev     │
    │ 2. Region-Filtering (NBV only)      │
    │ 3. Set last_version_id              │
    │ 4. Reset version sequence (50000000+)│
    │ 5. Create dump                      │
    └─────────────────────────────────────┘
                    ↓
carambus_scenarioname_development (processed)
                    ↓
    ┌─────────────────────────────────────┐
    │ prepare_deploy                     │
    │ 1. Upload dump to server            │
    │ 2. Reset production database        │
    │ 3. Restore from development dump    │
    │ 4. Verify (19 regions)              │
    └─────────────────────────────────────┘
                    ↓
carambus_scenarioname_production (on server)
                    ↓
    ┌─────────────────────────────────────┐
    │ deploy                             │
    │ 1. Capistrano deployment            │
    │ 2. Automatic service restarts       │
    │ 3. Asset compilation                │
    └─────────────────────────────────────┘
```

**Key Insight**: The development database is the "processed" version (template + filtering + sequences), and production is created from this processed version.

## Benefits of the Improved Workflow

### ✅ Perfect Separation of Responsibilities
- **`prepare_development`**: Development setup, asset compilation, database processing
- **`prepare_deploy`**: Production preparation, server setup, database transfer
- **`deploy`**: Pure Capistrano deployment with automatic service management

### ✅ Automatic Service Management
- **Puma Restart**: Automatic via Capistrano hooks (`after 'deploy:publishing', 'puma:restart'`)
- **Nginx Reload**: Automatic via Capistrano
- **No Manual Intervention**: Everything is managed by Capistrano

### ✅ Robust Asset Pipeline
- **Sprockets-based**: Consistent asset management in development and production
- **TailwindCSS Integration**: Correct CSS compilation
- **JavaScript Bundling**: esbuild for optimized assets

### ✅ Intelligent Database Operations
- **Template Optimization**: `createdb --template` instead of `pg_dump | psql`
- **Region Filtering**: Automatic database size reduction
- **Sequence Management**: Automatic ID conflict prevention
- **Verification**: Automatic database integrity checking

### ✅ Blank Server Ready
- **Complete Preparation**: `prepare_deploy` sets up everything on the server
- **No Manual Steps**: Automatic creation of services and configurations
- **Permissions**: Automatic directory permission correction

## Quick Start

```bash
# 1. Set up development environment
rake "scenario:prepare_development[carambus_location_5101,development]"

# 2. Production preparation (Database + Config + Server Setup)
rake "scenario:prepare_deploy[carambus_location_5101]"

# 3. Execute deployment (pure Capistrano operation)
rake "scenario:deploy[carambus_location_5101]"
```

## Advanced Usage

### Granular Control

```bash
# Only regenerate configuration files
rake "scenario:generate_configs[carambus_location_5101,development]"

# Only create database dump
rake "scenario:create_database_dump[carambus_location_5101,development]"

# Only restore database dump
rake "scenario:restore_database_dump[carambus_location_5101,development]"

# Only create Rails root folder
rake "scenario:create_rails_root[carambus_location_5101]"
```

### Scenario Update

```bash
# Update scenario with git (preserves local changes)
rake "scenario:update[carambus_location_5101]"
```

## Scenario Configuration

Each scenario is defined by a `config.yml` file:

```yaml
scenario:
  name: carambus_location_5101
  description: Location 5101 Server
  location_id: 5101
  context: LOCAL                    # API, LOCAL, or NBV
  region_id: 1
  club_id: 357
  api_url: https://newapi.carambus.de/
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

## Technical Details

### Asset Pipeline (Sprockets)

The system uses the Sprockets asset pipeline:

```bash
# Development Asset Compilation
yarn build          # JavaScript (esbuild)
yarn build:css      # TailwindCSS
rails assets:precompile  # Sprockets (Development)
```

### ActionCable Configuration

Automatic ActionCable configuration for StimulusReflex:

```yaml
# config/cable.yml
development:
  adapter: async
production:
  adapter: async
```

### Capistrano Integration

Automatic service management via Capistrano:

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

### Database Transformations

#### carambus Scenario
- **Template Optimization**: `createdb --template=carambus_api_development`
- **Version Sequence Reset**: `setval('versions_id_seq', 1, false)`
- **Settings Update**: 
  - Set `last_version_id` to 1
  - Set `scenario_name` to "carambus"

#### Location Scenarios
- **Region Filtering**: `cleanup:remove_non_region_records` with `ENV['REGION_SHORTNAME'] = 'NBV'`
- **Optimized Dump Size**: Reduces from ~500MB to ~90MB
- **Temporary DB**: Creates temp DB, applies filtering, creates dump, cleans up

## Troubleshooting

### Common Issues

1. **Asset Precompilation Errors**
   ```bash
   # Solution: Run complete asset pipeline
   cd carambus_location_5101
   yarn build && yarn build:css && rails assets:precompile
   ```

2. **StimulusReflex Not Working**
   ```bash
   # Solution: Check ActionCable configuration
   # cable.yml must be created with async adapter
   ```

3. **Database Sequence Conflicts**
   ```bash
   # Solution: Recreate development database
   rake "scenario:prepare_development[scenario_name,development]"
   ```

4. **Port Conflicts**
   ```bash
   # Solution: Use different port in config.yml
   webserver_port: 3004
   ```

## Status

✅ **Fully implemented**:
- ✅ Improved deployment workflow with clear separation
- ✅ Automatic service management via Capistrano
- ✅ Robust asset pipeline (Sprockets + TailwindCSS)
- ✅ ActionCable configuration for StimulusReflex
- ✅ Intelligent database operations
- ✅ Blank server deployment
- ✅ Template system for all configuration files
- ✅ Unix socket configuration (Puma ↔ Nginx)
- ✅ SSL certificate management (Let's Encrypt)
- ✅ Refactored task system (2024) - Eliminated code duplication

🔄 **In progress**:
- GitHub access for Raspberry Pi
- Production database setup

📋 **Planned**:
- Mode switch system deactivation
- Automated tests
- Additional location scenarios

## Best Practices

### Deployment Order
1. **Always first**: `prepare_development` for local testing
2. **Then**: `prepare_deploy` for production preparation
3. **Finally**: `deploy` for server deployment

### Asset Development
- Use `prepare_development` for local asset testing
- Always test in development environment before production deployment

### Database Management
- Development database is the "source of truth"
- Production is always created from development dump
- Sequence reset happens automatically

### Service Management
- Never use manual `systemctl` commands
- Capistrano manages all services automatically
- In case of problems: re-run `prepare_deploy`

## Integration with Existing Systems

The Scenario Management System replaces:
- ❌ Manual Docker configuration
- ❌ Manual mode switching
- ❌ Manual SSL setup
- ❌ Manual database management

**Advantages:**
- ✅ Automated deployments
- ✅ Consistent configuration
- ✅ Easy maintenance
- ✅ Scalable architecture