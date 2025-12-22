# Rake Tasks & Debugging Guide for Developers

**Target Audience:** Developers  
**Purpose:** Cross-reference between shell scripts and Rake tasks, debugging strategies with breakpoints and variable inspection

---

## Overview

While shell scripts are ideal for automated deployments, **Rake tasks** offer decisive advantages when developing and debugging:

✅ **Set breakpoints** with `binding.pry` or `debugger`  
✅ **Variable inspection** in real-time  
✅ **Single-step execution**  
✅ **Direct access** to Rails models and ActiveRecord  
✅ **Unit testing** of logic possible

---

## Script → Rake Task Mapping

### 1. Scenario Management

| Shell Script | Rake Task | Debug Advantage |
|-------------|-----------|-----------------|
| `bin/deploy-scenario.sh` | `scenario:deploy[name]` | Breakpoints in deploy logic, inspect DB status |
| `bin/check_database_sync.sh` | *No direct task* | Could be implemented as `scenario:check_sync[name]` |
| `bin/setup-raspberry-pi-client.sh` | `scenario:setup_raspberry_pi_client[name]` | Debug table/location assignments |
| - | `scenario:backup_local_data[name]` | Test filter logic for local data (id > 50M) |
| - | `scenario:restore_local_data[name,file]` | Step through restore process |
| - | `scenario:create[name,location_id,context]` | Inspect config generation |
| - | `scenario:generate_configs[name,env]` | Debug template rendering |

**Recommendation:** For complex scenario operations, test with Rake task first, then use script.

---

### 2. Database Operations

| Shell Script | Rake Task | Debug Advantage |
|-------------|-----------|-----------------|
| `bin/api2_dev_from_api2_db.sh` | ~~`mode:restore_local_db_with_preservation[dump_file]`~~ ❌ OBSOLETE | Inspect backup/restore filters |
| `bin/dev_from_api_dev.sh` | ~~`mode:restore_local_db[dump_file]`~~ ❌ OBSOLETE | Step through SQL dump process |
| - | `carambus:filter_local_changes_from_sql_dump` | Debug **ID bump logic** (TableLocal/TournamentLocal) |
| - | `carambus:filter_local_changes_from_sql_dump_new` | Test new filter implementation |
| - | ~~`mode:backup_local_changes`~~ ❌ OBSOLETE | Validate filter for id > 50000000 |
| - | ~~`mode:check_version_safety[dump_file]`~~ ❌ OBSOLETE | Check version sequences |

> ⚠️ **Note:** The `mode:*` tasks are **obsolete** and have been replaced by the Scenario Management System. See [lib/tasks/obsolete/README.md](../../lib/tasks/obsolete/README.md).

**Debugging Tip:**  
```ruby
# In carambus.rake, before ID bump:
binding.pry
puts "Before Bump: #{TableLocal.where('id < 50000000').count}"
# Execute SQL
puts "After Bump: #{TableLocal.where('id < 50000000').count}"
```

---

### 3. Raspberry Pi Management

| Shell Script | Rake Task | Debug Advantage |
|-------------|-----------|-----------------|
| `bin/setup-raspberry-pi-client.sh` | `scenario:setup_raspberry_pi_client[name]` | Debug SSH connection/config transfer |
| `bin/test-raspberry-pi-client.sh` | `scenario:test_raspberry_pi_client[name]` | Test table-scoreboard assignments |
| `bin/restart-table-scoreboard.sh` | `scenario:restart_table_scoreboard[name,table]` | Inspect systemctl commands |
| `bin/restart-raspberry-pi-client.sh` | `scenario:restart_raspberry_pi_client[name]` | Debug service restart logic |
| - | `scenario:list_table_scoreboards[name]` | Parse and validate config.yml |
| - | `scenario:preview_autostart_script[name]` | Test autostart script generation |

---

### 4. Server Configuration

| Shell Script | Rake Task | Debug Advantage |
|-------------|-----------|-----------------|
| - | ~~`mode:api`~~ ❌ OBSOLETE | Debug config generation for API mode |
| - | ~~`mode:local`~~ ❌ OBSOLETE | Debug config generation for LOCAL mode |
| - | ~~`mode:status[detailed,source]`~~ ❌ OBSOLETE | Test config extraction from prod server |
| - | ~~`mode:generate_templates`~~ ❌ OBSOLETE | Inspect NGINX/Puma templates |
| - | ~~`mode:prepare_db_dump`~~ ❌ OBSOLETE | Validate pg_dump commands |
| - | ~~`mode:deploy_templates`~~ ❌ OBSOLETE | Debug SCP/SSH transfers |

> ⚠️ **Note:** All `mode:*` tasks are **obsolete** and replaced by the Scenario Management System. For config management use `scenario:*` tasks. See [lib/tasks/obsolete/README.md](../../lib/tasks/obsolete/README.md).

---

### 5. Data Cleanup & Maintenance

| Shell Script | Rake Task | Debug Advantage |
|-------------|-----------|-----------------|
| *N/A* | `cleanup:remove_non_region_records` | Test region filter logic |
| *N/A* | `cleanup:remove_duplicate_games` | Debug duplicate detection |
| *N/A* | `cleanup:cleanup_paper_trail_versions` | Step through PaperTrail cleanup |
| *N/A* | `version_cleanup:stats` | Analyze version inconsistencies |
| *N/A* | `version_cleanup:verify` | Check version integrity |

---

## Debugging Strategies

### Strategy 1: Breakpoints with Pry

```ruby
# lib/tasks/scenarios.rake
task :my_debug_task => :environment do
  require 'pry'
  
  # Before critical operation
  binding.pry
  
  # Now in terminal:
  # - Inspect variables: `ls`, `show-source`
  # - Call methods: `TableLocal.count`
  # - See SQL: `ActiveRecord::Base.logger = Logger.new(STDOUT)`
  # - Continue: `exit` or `continue`
end
```

**Usage:**
```bash
cd carambus_bcw
bundle exec rake my_debug_task
# Pry session opens automatically
```

---

### Strategy 2: Inspect SQL Queries

```ruby
# In lib/tasks/carambus.rake
task filter_local_changes_from_sql_dump: :environment do
  # Enable logging
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  
  # Before ID bump
  puts "=== BEFORE BUMP ==="
  puts "TableLocal < 50M: #{TableLocal.where('id < 50000000').pluck(:id)}"
  
  # Execute SQL
  ActiveRecord::Base.connection.execute <<~SQL
    UPDATE public.table_locals SET id = id + 50000000 WHERE id < 50000000;
  SQL
  
  # After ID bump
  puts "=== AFTER BUMP ==="
  puts "TableLocal < 50M: #{TableLocal.where('id < 50000000').count}"
  puts "TableLocal > 50M: #{TableLocal.where('id >= 50000000').pluck(:id)}"
end
```

---

### Strategy 3: Step-by-Step with `puts`

```ruby
# In lib/tasks/scenarios.rake
def backup_local_data_from_production(...)
  puts "🔍 DEBUG: Starting backup..."
  puts "🔍 Tables to backup: #{tables.inspect}"
  
  tables.each do |table|
    puts "🔍 Processing table: #{table}"
    # ... filter logic
    puts "🔍 Rows after filter: #{filtered_count}"
  end
end
```

---

### Strategy 4: Dry-Run Mode

```ruby
# lib/tasks/scenarios.rake
task :deploy_with_dry_run, [:scenario_name] => :environment do |t, args|
  ENV['DRY_RUN'] = 'true'
  Rake::Task['scenario:deploy'].invoke(args.scenario_name)
end

# In deploy logic:
def drop_database(db_name)
  if ENV['DRY_RUN'] == 'true'
    puts "DRY-RUN: Would drop database #{db_name}"
    return
  end
  system("sudo -u postgres dropdb #{db_name}")
end
```

---

## Practical Debugging Workflows

### Workflow 1: Debug TableLocal ID Bump

**Problem:** TableLocal data loss after deployment.

```bash
cd carambus_bcw
bundle exec rails console

# 1. Status before change
TableLocal.where('id < 50000000').pluck(:id, :table_id)
TournamentLocal.where('id < 50000000').pluck(:id, :tournament_id)

# 2. Call Rake task with breakpoint
# In lib/tasks/carambus.rake, before ID bump:
require 'pry'; binding.pry

bundle exec rake carambus:filter_local_changes_from_sql_dump

# 3. In Pry session:
> TableLocal.where('id < 50000000').count
=> 10

# 4. Execute SQL manually and verify
> ActiveRecord::Base.connection.execute("UPDATE public.table_locals SET id = id + 50000000 WHERE id < 50000000")
> TableLocal.where('id < 50000000').count
=> 0  # ✅ Success!
```

---

### Workflow 2: Scenario Deploy Step-by-Step

```ruby
# Create new debug task:
# lib/tasks/scenarios.rake
namespace :scenario do
  task :deploy_debug, [:scenario_name] => :environment do |t, args|
    require 'pry'
    
    scenario_name = args.scenario_name
    puts "🔍 DEBUG: Deploying #{scenario_name}"
    
    # Step 1: Load config
    config = load_scenario_config(scenario_name)
    binding.pry  # Breakpoint 1
    
    # Step 2: Database Operations
    production_db = "#{scenario_name}_production"
    binding.pry  # Breakpoint 2
    
    # Step 3: Local Data Backup
    backup_local_data_from_production(scenario_name, production_db)
    binding.pry  # Breakpoint 3
  end
end
```

**Usage:**
```bash
bundle exec rake "scenario:deploy_debug[carambus_bcw]"
# At each breakpoint inspect:
> config
> production_db
> TableLocal.count
```

---

### Workflow 3: Test SQL Filters

```ruby
# lib/tasks/test_filters.rake
namespace :test do
  task :table_local_filters => :environment do
    puts "=== Testing TableLocal Filters ==="
    
    # Test 1: ID Range
    puts "Current IDs: #{TableLocal.pluck(:id).inspect}"
    
    # Test 2: Filter < 50M
    puts "IDs < 50M: #{TableLocal.where('id < 50000000').pluck(:id)}"
    
    # Test 3: Filter >= 50M
    puts "IDs >= 50M: #{TableLocal.where('id >= 50000000').pluck(:id)}"
    
    # Test 4: SQL COPY simulation
    sql = "COPY (SELECT * FROM table_locals) TO STDOUT"
    result = ActiveRecord::Base.connection.execute(sql)
    puts "SQL COPY result: #{result.to_a.inspect}"
  end
end
```

---

## Task Categories and Obsolescence Analysis

### Scenario Management (Core - Current)

| Task | Status | Usage |
|------|--------|-------|
| `scenario:create` | ✅ Core | Frequent, well documented |
| `scenario:deploy` | ✅ Core | Daily via `bin/deploy-scenario.sh` |
| `scenario:backup_local_data` | ✅ Core | Automatic during deploy |
| `scenario:restore_local_data` | ✅ Core | For rollback/recovery |
| `scenario:setup_raspberry_pi_client` | ✅ Core | For new RasPi clients |
| `scenario:test_raspberry_pi_client` | ✅ Core | After RasPi setup |

### Mode Management (Legacy/Obsolete?)

| Task | Status | Note |
|------|--------|------|
| ~~`mode:*` (all)~~ | ❌ **OBSOLETE** | **Mode system completely removed** - use `scenario:*` tasks |

**Note:** The entire `lib/tasks/mode.rake` (2,132 lines) has been moved to `lib/tasks/obsolete/`. All Mode Management functionality is now part of the Scenario Management System. Details: [lib/tasks/obsolete/README.md](../../lib/tasks/obsolete/README.md)

### Database Operations (Core)

| Task | Status | Usage |
|------|--------|-------|
| `carambus:filter_local_changes_from_sql_dump` | ✅ Core | Critical for local-data extraction |
| `carambus:filter_local_changes_from_sql_dump_new` | ⚠️ New | Successor to `filter_local_changes`? |
| `carambus:create_local_seed` | ✅ Core | Seed generation |
| ~~`mode:backup_local_changes`~~ | ❌ OBSOLETE | Before DB replace |
| ~~`mode:restore_local_changes`~~ | ❌ OBSOLETE | After DB replace |

**Recommendation:** Clarify `_new` suffix in `filter_local_changes_from_sql_dump_new` - is the old one obsolete?

### Cleanup (Maintenance)

| Task | Status | Usage |
|------|--------|-------|
| `cleanup:remove_non_region_records` | ✅ Active | After Prod→Dev sync |
| `cleanup:remove_duplicate_games` | ⚠️ Rare | For data quality issues |
| `cleanup:cleanup_paper_trail_versions` | ✅ Active | Monthly |
| `version_cleanup:stats` | ✅ Active | Monitoring |
| `version_cleanup:verify` | ✅ Active | After version problems |

### Adhoc (Development/Testing)

| Task | Status | Usage |
|------|--------|-------|
| `adhoc:test` | ⚠️ Temp | Should be cleaned regularly |
| `adhoc:player_cc_matching` | ❓ | One-time migration? |
| `adhoc:scrape_*` | ❓ | One-time data imports? |

**Recommendation:** `adhoc:*` tasks should be reviewed annually for relevance and deleted.

### Installation (Setup)

| Task | Status | Usage |
|------|--------|-------|
| `carambus:installation:check_prerequisites` | ✅ Core | When setting up new servers |
| `carambus:installation:setup_localization` | ✅ Core | Initial setup |
| `carambus:installation:validate_localization` | ✅ Core | Health check |
| `carambus:installation:export_localization` | ✅ Core | Backup/migration |
| `carambus:installation:import_localization` | ✅ Core | Restore/migration |

---

## Obsolescence Candidates

### To Review/Delete:

1. ~~**`mode:*` (all tasks)**~~ - ✅ **DONE** - Moved to `lib/tasks/obsolete/mode.rake` (2025-10-12)
2. **`carambus:filter_local_changes_from_sql_dump`** - Will `_new` become standard?
3. **`adhoc:test`, `adhoc:test_old`** - Clean up old test tasks

### To Document:

1. **`scenario:*`** - Fully document all core tasks
2. **`carambus:installation:*`** - Complete setup guide
3. **`cleanup:*` / `version_cleanup:*`** - Document maintenance workflow

---

## Best Practices

### 1. Task Development

```ruby
# ✅ GOOD: Breakpoint-friendly
task :my_task => :environment do
  config = load_config
  require 'pry'; binding.pry if ENV['DEBUG']
  process(config)
end

# ❌ BAD: Shell commands without error checking
task :bad_task do
  system("rm -rf /important/data")  # No rollback possible!
end
```

### 2. Dry-Run Support

```ruby
task :dangerous_operation => :environment do
  if ENV['DRY_RUN']
    puts "DRY-RUN: Would delete #{Record.count} records"
    return
  end
  Record.delete_all
end
```

### 3. Logging

```ruby
task :complex_task => :environment do
  logger = Logger.new("#{Rails.root}/log/rake_tasks.log")
  logger.info "Starting complex_task at #{Time.current}"
  # ...
  logger.info "Finished complex_task at #{Time.current}"
end
```

---

## Further Documentation

- [Scenario Management Workflow](./scenario-system-workflow.md)
- [Database Partitioning & Sync](./database_syncing.md)
- [Raspberry Pi Scripts Reference](./raspberry_pi_scripts.md) *(to be translated)*
- [Server Management Scripts](./server_management_scripts.md) *(to be translated)*

---

**Last Updated:** 2025-10-12  
**Maintainer:** Development Team



