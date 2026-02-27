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
2. **Prepare Development Database**:
   - **Run Migrations**: Ensures development database is up-to-date
   - **Create Production Dump**: Creates dump from current development database
3. **Database Setup on Server**:
   - **🔍 Automatic Local Data Detection**: Checks for records with ID > 50,000,000
   - **💾 Automatic Backup (if local data exists)**:
     - Automatically deletes: `versions`, games with nil data, orphaned records
     - Reduces backup size from ~1.2 GB to ~116 KB (99.99% reduction!)
   - **Upload and Load Database Dump**: Transfers development dump to server
   - **Database Reset**: Removes old application folders, creates new production DB
   - **Dump Restoration**: Loads processed development database into production
   - **🔄 Automatic Restore (if backup exists)**: Restores local data after DB update
   - **Verification**: Checks correct restoration (19 regions)
4. **Server Configuration**:
   - **File Transfers**: Upload all configuration files to `/var/www/scenario/shared/config/` (respects `.lock` files)
   - **Directory Setup**: Creates deployment directories with correct permissions
   - **Service Preparation**: Prepares systemd and Nginx
   
   **Note**: Configuration files with a `.lock` file are skipped during upload. See [CONFIG_LOCK_FILES.md](../reference/config-lock-files.en.md) for details.

**Perfect for**: Complete deployment preparation, blank server setup, **season start with many DB changes**

**💡 Config Lock Files**: Configuration files can be protected from being overwritten on the server by creating a `.lock` file. Example: `/var/www/[basename]/shared/config/carambus.yml.lock` prevents `carambus.yml` from being updated during deployment. This is useful for preserving server-specific settings. See [CONFIG_LOCK_FILES.md](../reference/config-lock-files.en.md) for details.

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

### Bootstrap: When carambus_api_development Doesn't Exist

When neither `carambus_api_development` nor `carambus_api_production` exist locally, the system automatically performs a **bootstrap**:

```
┌─────────────────────────────────────────────────────────────┐
│ BOOTSTRAP (automatic during prepare_development)            │
│                                                             │
│ 1. Check: Does carambus_api_development exist locally?      │
│    → NO: Bootstrap required                                 │
│                                                             │
│ 2. Check API server (via SSH):                              │
│    a) carambus_api_development Version.last.id              │
│    b) carambus_api_production Version.last.id               │
│                                                             │
│ 3. Choose source with higher Version.last.id (= newer)      │
│    → Higher ID = more recent data                           │
│                                                             │
│ 4. Create local carambus_api_development:                   │
│    ssh ... 'pg_dump [source_db]' | psql carambus_api_dev    │
│                                                             │
│ 5. ✅ Bootstrap complete - continue with normal flow        │
└─────────────────────────────────────────────────────────────┘
```

**Example output:**
```
🔄 Step 6: Checking for newer carambus_api_production data...
   ⚠️  carambus_api_development not found locally - BOOTSTRAP required!
   
   🔄 Bootstrap: Creating carambus_api_development from API server...
   🔍 Determining best source database on API server...
   📊 Remote carambus_api_development Version.last.id: 12345678
   📊 Remote carambus_api_production Version.last.id: 12350000
   🎯 Using carambus_api_production (Version.last.id: 12350000 > 12345678)
   
   📥 Creating local carambus_api_development from remote carambus_api_production...
   ⏳ This may take several minutes depending on database size and network speed...
   ✅ Successfully created local carambus_api_development from carambus_api_production
   📊 Version.last.id: 12350000
```

**Important:** The bootstrap is a one-time operation. Afterwards, the system automatically syncs with `carambus_api_production` when newer data is available there.

### Source → Development → Production

```
carambus_api_development (mother database)
         ↑
    ┌────┴────────────────────────────────┐
    │ Bootstrap (if not present)          │
    │ → Choose newer: api_dev vs api_prod │
    │ → Download via SSH + pg_dump        │
    └─────────────────────────────────────┘
         ↑
    ┌────┴────────────────────────────────┐
    │ Sync (if api_prod is newer)         │
    │ → Compare Version.last.id           │
    │ → Update if production is newer     │
    └─────────────────────────────────────┘
                    ↓
    ┌─────────────────────────────────────┐
    │ prepare_development                 │
    │ 1. Template: --template=api_dev     │
    │ 2. Region-Filtering (NBV only)      │
    │ 3. Set last_version_id              │
    │ 4. Reset version sequence (50000000+)│
    │ 5. Remove old versions (keep last)  │
    │ 6. Create dump                      │
    └─────────────────────────────────────┘
                    ↓
carambus_scenarioname_development (processed)
                    ↓
    ┌─────────────────────────────────────┐
    │ prepare_deploy                     │
    │ 1. Run migrations on dev DB         │
    │ 2. Create production dump           │
    │ 3. Upload dump to server            │
    │ 4. Reset production database        │
    │ 5. Restore from development dump    │
    │ 6. Verify (19 regions)              │
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
# Mirror production database to local development environment (Pull & Restore in one step)
rake "scenario:sync_production_db[carambus_api]"

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

### Local Data Management (ID > 50,000,000)

**New in 2024**: Fully automated local data management during deployments.

#### Automatic Mode (Default)

```bash
# Normal deployment - local data is automatically backed up/restored!
rake "scenario:prepare_deploy[carambus_location_5101]"

# Or via deployment script
./bin/deploy-scenario.sh carambus_location_5101
```

**What happens automatically:**
1. ✅ Detects local data (ID > 50,000,000) in production DB
2. ✅ Creates backup with automatic cleanup:
   - Deletes ~273,885 `versions` (not needed on local servers)
   - Deletes ~5,019 games with `data IS NULL` (incomplete/corrupted)
   - Deletes ~10,038 orphaned `game_participations`
   - Deletes ~25 orphaned `table_monitors`
   - Deletes orphaned `seedings`
3. ✅ Updates database with new schema/data
4. ✅ Restores local data
5. ✅ Done! (99.95% success rate, 15,185 / 15,193 records)

**Backup size**: ~116 KB instead of ~1.2 GB (99.99% reduction!)

#### Manual Mode (Special Cases)

```bash
# Manual backup of local data
rake "scenario:backup_local_data[carambus_location_5101]"
# Result: scenarios/carambus_location_5101/local_data_backups/local_data_TIMESTAMP.sql

# Manual restore of local data
rake "scenario:restore_local_data[carambus_location_5101,/path/to/backup.sql]"
```

**Use cases for manual mode:**
- Emergency backup before risky operation
- Testing DB changes with fallback option
- Migration between different schemas

#### Detection Logic

```sql
-- Fast check for local data
SELECT COUNT(*) 
FROM (SELECT 1 FROM games WHERE id > 50000000 LIMIT 1) AS t;

-- Result 1: Local data exists → Automatic backup
-- Result 0: No local data → Clean deployment
```

#### What Gets Cleaned Up?

| Data Type | Criteria | Typical Count | Reason |
|-----------|----------|---------------|--------|
| `versions` | id > 50000000 | ~273,885 | Not needed on local servers |
| `games` | id > 50000000 AND data IS NULL | ~5,019 | Incomplete/corrupted |
| `game_participations` | Orphaned (game not found) | ~10,038 | Related to deleted games |
| `table_monitors` | Orphaned (game not found) | ~25 | Related to deleted games |
| `seedings` | Orphaned (tournament not found) | Variable | Related to deleted tournaments |

#### Backup Location

```bash
# Backups are stored here
scenarios/<scenario_name>/local_data_backups/
└── local_data_YYYYMMDD_HHMMSS.sql

# Example
scenarios/carambus_location_5101/local_data_backups/
└── local_data_20241008_223119.sql (116 KB)
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

## Carambus2 Migration

**New as of October 2025**: Automatic schema migration for servers running the old Carambus2 version.

### Overview

The system automatically detects old Carambus2 databases and migrates them to the current schema. Migration happens **transparently during `prepare_development`** - no manual steps required!

### What Gets Migrated?

| Schema Change | Action | Value |
|--------------|--------|-------|
| Missing `region_id` column | Add column + set value | `1` (for local data) |
| Missing `global_context` column | Add column + set value | `false` (for local data) |
| `users.role` is TEXT | Convert to INTEGER | `0` (player) |

**Affected Tables:**
- `clubs`, `locations`, `players`, `tournaments`, `tournament_locals`
- `users`, `tables`, `table_locals`, `settings`
- `games`, `game_participations`, `seedings`, `versions`

### Automatic Workflow

```
prepare_development[scenario_name,development]
        ↓
  Step 6.5: Schema Migration
    ├─ Download old production DB
    ├─ Create temp local database
    ├─ Detect schema mismatches
    ├─ Add missing columns
    ├─ Update local records (id > 50M)
    └─ Extract migrated data
        ↓
  Step 8: Restore to Development
    ├─ Load migrated data
    └─ Ready for testing!
        ↓
  Development DB now contains:
    ✅ Official data (id < 50M)
    ✅ Migrated local data (id > 50M)
```

### Practical Example

```bash
# One-time migration from Carambus2 → Current
rake "scenario:prepare_development[carambus_bcw,development]"

# What happens automatically:
# 1. Download old production database
# 2. Detect old schema (missing region_id, global_context columns)
# 3. Add missing columns to temp database
# 4. Update local records: region_id=1, global_context=false
# 5. Extract local data with NEW schema
# 6. Load into development database
# 7. Backup stored: local_data_20251021_204254.sql

# Verify result:
psql carambus_bcw_development -c "
  SELECT COUNT(*) FROM players WHERE id > 50000000 AND region_id = 1;
  -- Should show all migrated players
"
```

### Migration Backup

The migrated backup is saved and referenced in `config.yml`:

```yaml
last_local_backup: "/path/to/scenarios/scenario_name/local_data_backups/local_data_TIMESTAMP.sql"
```

This backup is **schema-compatible** and can be reused anytime!

### Troubleshooting

**Problem**: Migration doesn't detect old schema
```bash
# Solution: Check manually
psql old_database -c "
  SELECT column_name 
  FROM information_schema.columns 
  WHERE table_name='players' AND column_name='region_id';
"
# Empty = old schema → Migration will be performed
```

**Problem**: Migration fails
```bash
# Solution: Backup already exists
ls scenarios/scenario_name/local_data_backups/
# Use existing backup for restore
```

### Important Notes

⚠️ **One-time Migration**: This feature is intended for the **first migration** from Carambus2 → Current.  
✅ **Backward Compatible**: Also works with already migrated databases.  
✅ **Non-Destructive**: Creates temporary database, doesn't touch production.

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
- ✅ **Automatic Local Data Management (2024)** - Fully automated backup/restore of local data
  - ✅ Automatic detection (ID > 50,000,000)
  - ✅ Intelligent cleanup (99.99% size reduction: 1.2 GB → 116 KB)
  - ✅ 99.95% restoration success rate (15,185 / 15,193 records)
  - ✅ New rake tasks: `backup_local_data`, `restore_local_data`
  - ✅ Integration in `prepare_deploy` and `bin/deploy-scenario.sh`
  - ✅ Manual control available when needed
- ✅ **Carambus2 Migration (October 2025)** - Automatic schema migration
  - ✅ Automatic detection of old Carambus2 schemas
  - ✅ Transparent migration during `prepare_development`
  - ✅ Adds missing columns (region_id, global_context)
  - ✅ Converts users.role from TEXT to INTEGER
  - ✅ Non-destructive (uses temporary database)
  - ✅ Schema-compatible backup for reuse
- ✅ **Multi-WLAN Table Client Setup (October 2025)** - Simplified Raspberry Pi setup
  - ✅ Automatic Multi-WLAN with priority-based failover
  - ✅ Dev-WLAN with DHCP (office testing)
  - ✅ Club-WLAN with static IP from database
  - ✅ Simplified invocation (only scenario, IP, table name)
  - ✅ WLAN credentials from config.yml and ~/.carambus_config
  - ✅ NetworkManager + dhcpcd support
  - ✅ Fast startup (~18s instead of ~45s)
  - ✅ Optimized Chromium flags (no sandbox warning)
  - ✅ Sidebar automatically collapsed for scoreboard URLs

🔄 **In progress**:
- Additional location scenarios

📋 **Planned**:
- Automated tests
- Performance monitoring

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