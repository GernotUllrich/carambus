# Rake Tasks & Debugging Guide für Entwickler

**Zielgruppe:** Entwickler  
**Zweck:** Cross-Referenz zwischen Shell-Scripts und Rake Tasks, Debugging-Strategien mit Breakpoints und Variable Inspection

---

## Überblick

Während Shell-Scripts ideal für automatisierte Deployments sind, bieten **Rake Tasks** entscheidende Vorteile beim Entwickeln und Debuggen:

✅ **Breakpoints setzen** mit `binding.pry` oder `debugger`  
✅ **Variable Inspection** in Echtzeit  
✅ **Single-Step Execution**  
✅ **Direkter Zugriff** auf Rails-Modelle und ActiveRecord  
✅ **Unit-Testing** der Logik möglich

---

## Script → Rake Task Mapping

### 1. Scenario Management

| Shell Script | Rake Task | Debug-Vorteil |
|-------------|-----------|---------------|
| `bin/deploy-scenario.sh` | `scenario:deploy[name]` | Breakpoints in Deploy-Logik, DB-Status inspizieren |
| `bin/check_database_sync.sh` | *Kein direktes Task* | Könnte als `scenario:check_sync[name]` implementiert werden |
| `bin/setup-raspberry-pi-client.sh` | `scenario:setup_raspberry_pi_client[name]` | Table/Location-Zuordnungen debuggen |
| - | `scenario:backup_local_data[name]` | Filter-Logik für lokale Daten (id > 50M) testen |
| - | `scenario:restore_local_data[name,file]` | Restore-Prozess Step-by-Step durchgehen |
| - | `scenario:create[name,location_id,context]` | Config-Generation inspizieren |
| - | `scenario:generate_configs[name,env]` | Template-Rendering debuggen |

**Empfehlung:** Für komplexe Scenario-Operationen zuerst mit Rake Task testen, dann Script nutzen.

---

### 2. Database Operations

| Shell Script | Rake Task | Debug-Vorteil |
|-------------|-----------|---------------|
| `bin/api2_dev_from_api2_db.sh` | ~~`mode:restore_local_db_with_preservation[dump_file]`~~ ❌ OBSOLETE | Backup/Restore-Filter inspizieren |
| `bin/dev_from_api_dev.sh` | ~~`mode:restore_local_db[dump_file]`~~ ❌ OBSOLETE | SQL-Dump-Prozess Step-by-Step |
| - | `carambus:filter_local_changes_from_sql_dump` | **ID-Bump-Logik** debuggen (TableLocal/TournamentLocal) |
| - | `carambus:filter_local_changes_from_sql_dump_new` | Neue Filter-Implementierung testen |
| - | ~~`mode:backup_local_changes`~~ ❌ OBSOLETE | Filter für id > 50000000 validieren |
| - | ~~`mode:check_version_safety[dump_file]`~~ ❌ OBSOLETE | Version-Sequenzen prüfen |

> ⚠️ **Hinweis:** Die `mode:*` Tasks sind **obsolet** und wurden durch das Scenario Management System ersetzt. Siehe `lib/tasks/obsolete/README.md` im Projekt-Repository.

**Debugging-Tipp:**  
```ruby
# In carambus.rake, vor dem ID-Bump:
binding.pry
puts "Vor Bump: #{TableLocal.where('id < 50000000').count}"
# SQL ausführen
puts "Nach Bump: #{TableLocal.where('id < 50000000').count}"
```

---

### 3. Raspberry Pi Management

| Shell Script | Rake Task | Debug-Vorteil |
|-------------|-----------|---------------|
| `bin/setup-raspberry-pi-client.sh` | `scenario:setup_raspberry_pi_client[name]` | SSH-Verbindung/Config-Transfer debuggen |
| `bin/test-raspberry-pi-client.sh` | `scenario:test_raspberry_pi_client[name]` | Table-Scoreboard-Zuordnungen testen |
| `bin/restart-table-scoreboard.sh` | `scenario:restart_table_scoreboard[name,table]` | Systemctl-Commands inspizieren |
| `bin/restart-raspberry-pi-client.sh` | `scenario:restart_raspberry_pi_client[name]` | Service-Restart-Logik debuggen |
| - | `scenario:list_table_scoreboards[name]` | Config.yml parsen und validieren |
| - | `scenario:preview_autostart_script[name]` | Autostart-Script-Generation testen |

---

### 4. Server Configuration

| Shell Script | Rake Task | Debug-Vorteil |
|-------------|-----------|---------------|
| - | ~~`mode:api`~~ ❌ OBSOLETE | Config-Generierung für API-Modus debuggen |
| - | ~~`mode:local`~~ ❌ OBSOLETE | Config-Generierung für LOCAL-Modus debuggen |
| - | ~~`mode:status[detailed,source]`~~ ❌ OBSOLETE | Config-Extraktion aus Prod-Server testen |

> ⚠️ **Hinweis:** Alle `mode:*` Tasks sind **obsolet** und durch das Scenario Management System ersetzt. Für Config-Management nutze `scenario:*` Tasks. Siehe `lib/tasks/obsolete/README.md` im Projekt-Repository.
| - | ~~`mode:generate_templates`~~ ❌ OBSOLETE | NGINX/Puma-Templates inspizieren |
| - | ~~`mode:prepare_db_dump`~~ ❌ OBSOLETE | pg_dump-Kommandos validieren |
| - | ~~`mode:deploy_templates`~~ ❌ OBSOLETE | SCP/SSH-Transfers debuggen |

---

### 5. Data Cleanup & Maintenance

| Shell Script | Rake Task | Debug-Vorteil |
|-------------|-----------|---------------|
| *N/A* | `cleanup:remove_non_region_records` | Region-Filter-Logik testen |
| *N/A* | `cleanup:remove_duplicate_games` | Duplikat-Erkennung debuggen |
| *N/A* | `cleanup:cleanup_paper_trail_versions` | PaperTrail-Bereinigung Step-by-Step |
| *N/A* | `version_cleanup:stats` | Version-Inkonsistenzen analysieren |
| *N/A* | `version_cleanup:verify` | Version-Integrität prüfen |

---

## Debugging-Strategien

### Strategy 1: Breakpoints mit Pry

```ruby
# lib/tasks/scenarios.rake
task :my_debug_task => :environment do
  require 'pry'
  
  # Vor kritischer Operation
  binding.pry
  
  # Jetzt im Terminal:
  # - Variablen inspizieren: `ls`, `show-source`
  # - Methoden aufrufen: `TableLocal.count`
  # - SQL sehen: `ActiveRecord::Base.logger = Logger.new(STDOUT)`
  # - Weiter: `exit` oder `continue`
end
```

**Verwendung:**
```bash
cd carambus_bcw
bundle exec rake my_debug_task
# Pry-Session öffnet sich automatisch
```

---

### Strategy 2: SQL-Queries inspizieren

```ruby
# In lib/tasks/carambus.rake
task filter_local_changes_from_sql_dump: :environment do
  # Logging aktivieren
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  
  # Vor ID-Bump
  puts "=== BEFORE BUMP ==="
  puts "TableLocal < 50M: #{TableLocal.where('id < 50000000').pluck(:id)}"
  
  # SQL ausführen
  ActiveRecord::Base.connection.execute <<~SQL
    UPDATE public.table_locals SET id = id + 50000000 WHERE id < 50000000;
  SQL
  
  # Nach ID-Bump
  puts "=== AFTER BUMP ==="
  puts "TableLocal < 50M: #{TableLocal.where('id < 50000000').count}"
  puts "TableLocal > 50M: #{TableLocal.where('id >= 50000000').pluck(:id)}"
end
```

---

### Strategy 3: Step-by-Step mit `puts`

```ruby
# In lib/tasks/scenarios.rake
def backup_local_data_from_production(...)
  puts "🔍 DEBUG: Starting backup..."
  puts "🔍 Tables to backup: #{tables.inspect}"
  
  tables.each do |table|
    puts "🔍 Processing table: #{table}"
    # ... Filter-Logik
    puts "🔍 Rows after filter: #{filtered_count}"
  end
end
```

---

### Strategy 4: Dry-Run Modus

```ruby
# lib/tasks/scenarios.rake
task :deploy_with_dry_run, [:scenario_name] => :environment do |t, args|
  ENV['DRY_RUN'] = 'true'
  Rake::Task['scenario:deploy'].invoke(args.scenario_name)
end

# In der Deploy-Logik:
def drop_database(db_name)
  if ENV['DRY_RUN'] == 'true'
    puts "DRY-RUN: Would drop database #{db_name}"
    return
  end
  system("sudo -u postgres dropdb #{db_name}")
end
```

---

## Praktische Debugging-Workflows

### Workflow 1: TableLocal ID-Bump debuggen

**Problem:** TableLocal-Datenverlust nach Deployment.

```bash
cd carambus_bcw
bundle exec rails console

# 1. Status vor Änderung
TableLocal.where('id < 50000000').pluck(:id, :table_id)
TournamentLocal.where('id < 50000000').pluck(:id, :tournament_id)

# 2. Rake Task mit Breakpoint aufrufen
# In lib/tasks/carambus.rake, vor ID-Bump:
require 'pry'; binding.pry

bundle exec rake carambus:filter_local_changes_from_sql_dump

# 3. In Pry-Session:
> TableLocal.where('id < 50000000').count
=> 10

# 4. SQL manuell ausführen und prüfen
> ActiveRecord::Base.connection.execute("UPDATE public.table_locals SET id = id + 50000000 WHERE id < 50000000")
> TableLocal.where('id < 50000000').count
=> 0  # ✅ Erfolgreich!
```

---

### Workflow 2: Scenario Deploy Step-by-Step

```ruby
# Neuen Debug-Task erstellen:
# lib/tasks/scenarios.rake
namespace :scenario do
  task :deploy_debug, [:scenario_name] => :environment do |t, args|
    require 'pry'
    
    scenario_name = args.scenario_name
    puts "🔍 DEBUG: Deploying #{scenario_name}"
    
    # Step 1: Config laden
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

**Verwendung:**
```bash
bundle exec rake "scenario:deploy_debug[carambus_bcw]"
# Bei jedem Breakpoint inspizieren:
> config
> production_db
> TableLocal.count
```

---

### Workflow 3: SQL-Filter testen

```ruby
# lib/tasks/test_filters.rake
namespace :test do
  task :table_local_filters => :environment do
    puts "=== Testing TableLocal Filters ==="
    
    # Test 1: ID-Range
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

## Task-Kategorien und Obsoleszenz-Analyse

### Scenario Management (Core - Aktuell)

| Task | Status | Nutzung |
|------|--------|---------|
| `scenario:create` | ✅ Core | Häufig, gut dokumentiert |
| `scenario:deploy` | ✅ Core | Täglich via `bin/deploy-scenario.sh` |
| `scenario:backup_local_data` | ✅ Core | Automatisch bei Deploy |
| `scenario:restore_local_data` | ✅ Core | Bei Rollback/Recovery |
| `scenario:setup_raspberry_pi_client` | ✅ Core | Bei neuen RasPi-Clients |
| `scenario:test_raspberry_pi_client` | ✅ Core | Nach RasPi-Setup |

### Mode Management (Legacy/Obsolet?)

| Task | Status | Notiz |
|------|--------|-------|
| ~~`mode:*` (alle)~~ | ❌ **OBSOLETE** | **Mode-System vollständig entfernt** - nutze `scenario:*` Tasks |

**Hinweis:** Die gesamte `lib/tasks/mode.rake` (2.132 Zeilen) wurde nach `lib/tasks/obsolete/` verschoben. Alle Mode-Management-Funktionen sind jetzt Teil des Scenario Management Systems. Details: `lib/tasks/obsolete/README.md` im Projekt-Repository.

**Empfehlung:** `mode:*` Tasks sollten auf Duplikate/Obsoleszenz geprüft werden.

### Database Operations (Core)

| Task | Status | Nutzung |
|------|--------|---------|
| `carambus:filter_local_changes_from_sql_dump` | ✅ Core | Critical für Local-Data-Extraction |
| `carambus:filter_local_changes_from_sql_dump_new` | ⚠️ Neu | Nachfolger von `filter_local_changes`? |
| `carambus:create_local_seed` | ✅ Core | Seed-Generierung |
| `mode:backup_local_changes` | ✅ Core | Vor DB-Replace |
| `mode:restore_local_changes` | ✅ Core | Nach DB-Replace |

**Empfehlung:** `_new` Suffix bei `filter_local_changes_from_sql_dump_new` klären - ist die alte obsolet?

### Cleanup (Maintenance)

| Task | Status | Nutzung |
|------|--------|---------|
| `cleanup:remove_non_region_records` | ✅ Aktiv | Nach Prod→Dev Sync |
| `cleanup:remove_duplicate_games` | ⚠️ Selten | Bei Data-Quality-Issues |
| `cleanup:cleanup_paper_trail_versions` | ✅ Aktiv | Monatlich |
| `version_cleanup:stats` | ✅ Aktiv | Monitoring |
| `version_cleanup:verify` | ✅ Aktiv | Nach Version-Problemen |

### Adhoc (Development/Testing)

| Task | Status | Nutzung |
|------|--------|---------|
| `adhoc:test` | ⚠️ Temp | Sollte regelmäßig aufgeräumt werden |
| `adhoc:player_cc_matching` | ❓ | Einmalige Migration? |
| `adhoc:scrape_*` | ❓ | Einmalige Daten-Imports? |

**Empfehlung:** `adhoc:*` Tasks sollten jährlich auf Relevanz geprüft und gelöscht werden.

### Installation (Setup)

| Task | Status | Nutzung |
|------|--------|---------|
| `carambus:installation:check_prerequisites` | ✅ Core | Bei Setup neuer Server |
| `carambus:installation:setup_localization` | ✅ Core | Initial Setup |
| `carambus:installation:validate_localization` | ✅ Core | Health-Check |
| `carambus:installation:export_localization` | ✅ Core | Backup/Migration |
| `carambus:installation:import_localization` | ✅ Core | Restore/Migration |

---

## Obsoleszenz-Kandidaten

### Zu Prüfen/Löschen:

1. **`mode:full_deploy`** - Niemals production-genutzt, Duplikat von Scenario-System
2. **`mode:deploy_templates`** - Überschneidung mit `scenario:generate_configs`
3. **`mode:save/load`** - Named Configs: Wird das noch genutzt?
4. **`carambus:filter_local_changes_from_sql_dump`** - Wird `_new` zum Standard?
5. **`adhoc:test`, `adhoc:test_old`** - Alte Test-Tasks aufräumen

### Zu Dokumentieren:

1. **`scenario:*`** - Alle Core-Tasks vollständig dokumentieren
2. **`carambus:installation:*`** - Setup-Guide vervollständigen
3. **`cleanup:*` / `version_cleanup:*`** - Maintenance-Workflow dokumentieren

---

## Best Practices

### 1. Task-Entwicklung

```ruby
# ✅ GOOD: Breakpoint-freundlich
task :my_task => :environment do
  config = load_config
  require 'pry'; binding.pry if ENV['DEBUG']
  process(config)
end

# ❌ BAD: Shell-Befehle ohne Fehlerprüfung
task :bad_task do
  system("rm -rf /important/data")  # Kein Rollback möglich!
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

## Weiterführende Dokumentation

- [Scenario Management Workflow](./scenario-workflow.md)
- [Database Partitioning & Sync](database-partitioning.md)
- [Raspberry Pi Scripts Reference](../administrators/raspberry_pi_scripts.md)
- [Server Management Scripts](../administrators/server-scripts.md)

---

**Letzte Aktualisierung:** 2025-10-12  
**Maintainer:** Development Team



