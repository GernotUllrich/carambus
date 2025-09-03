# Carambus Enhanced Mode System

## 🎯 **Übersicht**

Das **Enhanced Mode System** ermöglicht das einfache Umschalten zwischen verschiedenen Deployment-Konfigurationen für Carambus. Es verwendet **Ruby/Rake Tasks** für maximale Debugging-Unterstützung und **Unix Sockets** für effiziente Kommunikation zwischen NGINX und Puma.

## 🚀 **Schnellstart**

### **Ruby/Rake Named Parameters System**

```bash
# API Server Mode
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001

# Local Server Mode
bundle exec rails 'mode:local' MODE_SEASON_NAME='2025/2026' MODE_CONTEXT=NBV MODE_API_URL='https://newapi.carambus.de/'
```

## 📋 **Verfügbare Parameter**

### **Alle Parameter (alphabetisch)**
- `MODE_API_URL` - API URL für LOCAL Mode
- `MODE_APPLICATION_NAME` - Anwendungsname
- `MODE_BASENAME` - Deploy Basename
- `MODE_BRANCH` - Git Branch
- `MODE_CLUB_ID` - Club ID
- `MODE_CONTEXT` - Context Identifier
- `MODE_DATABASE` - Datenbankname
- `MODE_DOMAIN` - Domain Name
- `MODE_HOST` - Server Hostname
- `MODE_LOCATION_ID` - Location ID
- `MODE_NGINX_PORT` - NGINX Web Port (default: 80)
- `MODE_PORT` - Server Port
- `MODE_PUMA_SCRIPT` - Puma Management Script
- `MODE_PUMA_SOCKET` - Puma Socket Name (default: puma-{rails_env}.sock)
- `MODE_RAILS_ENV` - Rails Environment
- `MODE_SCOREBOARD_URL` - Scoreboard URL (auto-generated)
- `MODE_SEASON_NAME` - Season Identifier
- `MODE_SSL_ENABLED` - SSL aktiviert (true/false, default: false)

## 🎯 **Verwendungsbeispiele**

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

### **3. Entwicklungsumgebung**
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

## 💾 **Konfigurationen Verwalten**

### **Konfiguration Speichern**
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

### **Gespeicherte Konfigurationen Auflisten**
```bash
bundle exec rails 'mode:list'
```

### **Konfiguration Laden**
```bash
bundle exec rails 'mode:load[production_api]'
```

## 🔧 **Socket-basierte Architektur**

### **Unix Socket Vorteile**
- ✅ **Effizienter** - Keine TCP/IP Overhead
- ✅ **Sicherer** - Nur lokale Kommunikation
- ✅ **Schneller** - Direkte Kernel-Kommunikation
- ✅ **Skalierbarer** - Bessere Performance unter Last

### **Socket-Pfad Struktur**
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

## 🔧 **Automatische Template-Generierung**

### **Templates werden automatisch generiert**
Das System generiert und überträgt automatisch:

1. **NGINX Konfiguration** (`config/nginx.conf`)
   - Verwendet Unix Socket: `unix:/var/www/{basename}/shared/sockets/{puma_socket}`
   - Kopiert nach `/etc/nginx/sites-available/{basename}`
   - Erstellt Symlink in `/etc/nginx/sites-enabled/`
   - Testet Konfiguration und lädt NGINX neu

2. **Puma.rb Konfiguration** (`config/puma.rb`)
   - Bindet an Unix Socket: `unix://{shared_dir}/sockets/puma-{rails_env}.sock`
   - Erstellt Socket-Verzeichnisse automatisch
   - Setzt korrekte Socket-Berechtigungen (0666)
   - Konfiguriert PID- und State-Dateien

3. **Puma Service Konfiguration** (`config/puma.service`)
   - Kopiert nach `/etc/systemd/system/puma-{basename}.service`
   - Erstellt Socket-Verzeichnisse vor Service-Start
   - Lädt systemd daemon neu
   - Aktiviert den Service

4. **Scoreboard URL** (`config/scoreboard_url`)
   - Kopiert nach `/var/www/{basename}/shared/config/scoreboard_url`

### **Templates über Capistrano deployen**
```bash
# Alle Templates (automatisch nach Deployment)
bundle exec cap production deploy

# Einzelne Template-Tasks
bundle exec cap production deploy:nginx_config
bundle exec cap production deploy:puma_rb_config
bundle exec cap production deploy:puma_service_config
```

## 📋 **Capistrano Integration**

### **Automatische Template-Übertragung**

Die folgenden Dateien werden automatisch übertragen:
- `config/nginx.conf` → `/var/www/{basename}/shared/config/nginx.conf`
- `config/puma.rb` → `/var/www/{basename}/shared/puma.rb`
- `config/puma.service` → `/var/www/{basename}/shared/config/puma.service`
- `config/scoreboard_url` → `/var/www/{basename}/shared/config/scoreboard_url`

### **Deployment-Hooks**

```ruby
# Automatisch nach jedem Deployment
after "deploy:published", "deploy:deploy_templates"
```

### **Verfügbare Capistrano Tasks**

```bash
# Template-Deployment
cap deploy:deploy_templates              # Alle Templates deployen
cap deploy:nginx_config                  # NGINX Konfiguration deployen
cap deploy:puma_rb_config                # Puma.rb Konfiguration deployen
cap deploy:puma_service_config           # Puma Service deployen

# Puma Management
cap puma:restart                         # Puma neu starten
cap puma:stop                            # Puma stoppen
cap puma:start                           # Puma starten
cap puma:status                          # Puma Status anzeigen
```

## 🔧 **RubyMine Debugging**

### **Vollständige Debugging-Unterstützung**

Das Ruby/Rake-System bietet **perfekte RubyMine-Integration**:

#### **1. Breakpoints setzen**
```ruby
# In lib/tasks/mode.rake
def parse_named_parameters_from_env
  params = {}
  
  # Setze Breakpoint hier
  %i[season_name application_name context api_url basename database domain location_id club_id rails_env host port branch puma_script nginx_port puma_port ssl_enabled scoreboard_url puma_socket].each do |param|
    env_var = "MODE_#{param.to_s.upcase}"
    params[param] = ENV[env_var] if ENV[env_var]
  end
  
  params  # Setze Breakpoint hier
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
- **Step Into**: Gehe in Methoden hinein
- **Step Over**: Überspringe Methoden
- **Step Out**: Gehe aus Methoden heraus
- **Variables Inspector**: Sehe alle Parameter-Werte

## 🎯 **Best Practices**

### **1. RubyMine Debugging Workflow**
```bash
# 1. Setze Breakpoints in lib/tasks/mode.rake
# 2. Erstelle RubyMine Run Configuration
# 3. Debugge step-by-step
# 4. Inspiziere Variablen
# 5. Teste verschiedene Parameter-Kombinationen
```

### **2. Konfigurationen Speichern**
```bash
# Speichere häufig verwendete Konfigurationen
bundle exec rails 'mode:save[production_api]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001 MODE_NGINX_PORT=80 MODE_PUMA_SOCKET=puma-production.sock MODE_SSL_ENABLED=true
bundle exec rails 'mode:save[development_api]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_development MODE_HOST=localhost MODE_PORT=3001 MODE_NGINX_PORT=3000 MODE_PUMA_SOCKET=puma-development.sock MODE_SSL_ENABLED=false
```

### **3. Nur Änderungen Angeben**
```bash
# Nur die Parameter angeben, die sich von den Defaults unterscheiden
bundle exec rails 'mode:api' MODE_HOST=localhost MODE_PORT=3001 MODE_RAILS_ENV=development MODE_NGINX_PORT=3000 MODE_PUMA_SOCKET=puma-development.sock MODE_SSL_ENABLED=false
```

## 🗄️ **Datenbank-Management**

### **Datenbank-Synchronisation Workflow**

Das Enhanced Mode System bietet vollständige Datenbanksynchronisation zwischen lokaler Entwicklung und Produktionsumgebung:

#### **1. Lokalen Development-Dump erstellen**
```bash
# Erstellt einen Dump der lokalen carambus_api_development Datenbank
bundle exec rails mode:prepare_db_dump

# Ausgabe:
# 🗄️  Creating database dump: carambus_api_development_20250102_120000.sql.gz
# 📊 Source database: carambus_api_development
# 🎯 Target database: carambus_api_production (on server)
# ✅ Database dump created successfully: carambus_api_development_20250102_120000.sql.gz
```

#### **2. Production-Dump vom Server herunterladen**
```bash
# Erstellt einen Dump der carambus_api_production Datenbank auf dem Server und lädt ihn herunter
bundle exec rails mode:download_db_dump

# Ausgabe:
# 📥 Downloading database dump: carambus_api_production_20250102_120000.sql.gz
# 📊 Source database: carambus_api_production (on server)
# 🎯 Target database: carambus_api_development (local)
# ✅ Database dump downloaded successfully: carambus_api_production_20250102_120000.sql.gz
```

#### **3. Verfügbare Dumps auflisten**
```bash
# Zeigt alle verfügbaren Dumps mit Größe und Datum
bundle exec rails mode:list_db_dumps

# Ausgabe:
# 🗄️  Available database dumps:
# ----------------------------------------
# 📊 Development dumps (for upload to production):
#   carambus_api_development_20250102_120000.sql.gz (1234567 bytes, 2025-01-02 12:00:00)
# 🎯 Production dumps (for download to development):
#   carambus_api_production_20250102_120000.sql.gz (1234567 bytes, 2025-01-02 12:00:00)
```

#### **4. Version-Sicherheit prüfen**
```bash
# Prüft die Version-Sequenz-Nummern für sichere Synchronisation
bundle exec rails 'mode:check_version_safety[carambus_api_development_20250102_120000.sql.gz]'

# Ausgabe:
# 🔍 Checking version sequence safety...
# 📊 Highest version ID in dump: 12345
# 🎯 Current max version ID in database: 10000
# ✅ SAFE: Dump has higher version numbers - safe to import
```

#### **5. Dump zum API-Server übertragen (mit Sicherheitsprüfung)**
```bash
# Überträgt den Dump zum Server und legt ihn in /var/www/carambus_api/shared/database_dumps/ ab
bundle exec rails 'mode:deploy_db_dump[carambus_api_development_20250102_120000.sql.gz]'

# Ausgabe:
# 🚀 Deploying database dump to production server...
# 🔍 Performing safety check...
# ✅ SAFE: Dump has higher version numbers - safe to import
# ✅ Database dump deployed successfully
# 📁 Remote location: /var/www/carambus_api/shared/database_dumps/carambus_api_development_20250102_120000.sql.gz
```

#### **6. Dump auf API-Server einlesen (DROP AND REPLACE)**
```bash
# Liest den Dump in die carambus_api_production Datenbank ein (kompletter Ersatz)
bundle exec rails 'mode:restore_db_dump[carambus_api_development_20250102_120000.sql.gz]'

# Ausgabe:
# 🗄️  Restoring database from dump (DROP AND REPLACE)...
# ⚠️  WARNING: This will DROP and REPLACE the production database!
#    Are you sure? (type 'yes' to continue): yes
# ✅ Database restored successfully (drop and replace)
# 🔄 Puma service restarted
```

#### **7. Lokale Development-DB von Production-Dump wiederherstellen**
```bash
# Stellt die lokale carambus_api_development von einem Production-Dump wieder her
bundle exec rails 'mode:restore_local_db[carambus_api_production_20250102_120000.sql.gz]'

# Ausgabe:
# 🗄️  Restoring local development database from production dump...
# ⚠️  WARNING: This will DROP and REPLACE your local development database!
#    Are you sure? (type 'yes' to continue): yes
# ✅ Local development database restored successfully
# 📊 Database: carambus_api_development
```

#### **8. Lokale Änderungen sichern (ID > 50.000.000)**
```bash
# Sichert lokale Änderungen vor Datenbank-Ersetzung
bundle exec rails mode:backup_local_changes

# Ausgabe:
# 💾 Backing up local changes (ID > 50,000,000)...
# 🔍 Filtering local changes (ID > 50,000,000)...
# ✅ Filtered local changes: local_changes_filtered_20250102_120000.sql
# 📊 Only records with ID > 50,000,000 included
```

#### **9. Lokale Änderungen nach Datenbank-Ersetzung wiederherstellen**
```bash
# Stellt lokale Änderungen nach Datenbank-Ersetzung wieder her
bundle exec rails 'mode:restore_local_changes[local_changes_filtered_20250102_120000.sql]'

# Ausgabe:
# 🔄 Restoring local changes after database replacement...
# ✅ Local changes restored successfully
# 📊 Records with ID > 50,000,000 restored
```

#### **10. Lokale Development-DB mit Erhaltung lokaler Änderungen wiederherstellen**
```bash
# Stellt die lokale DB wieder her und behält lokale Änderungen
bundle exec rails 'mode:restore_local_db_with_preservation[carambus_api_production_20250102_120000.sql.gz]'

# Ausgabe:
# 🗄️  Restoring local development database with local changes preservation...
# ⚠️  WARNING: This will DROP and REPLACE your local development database!
#    Local changes (ID > 50,000,000) will be preserved and restored.
#    Are you sure? (type 'yes' to continue): yes
# 📋 Step 1: Backing up local changes...
# 📋 Step 2: Dropping and recreating database...
# 📋 Step 3: Restoring local changes...
# ✅ Local development database restored with local changes preserved
```

#### **11. Lokale Development-DB mit Region-Reduktion wiederherstellen**
```bash
# Stellt die lokale DB wieder her und reduziert auf Region-spezifische Daten
bundle exec rails 'mode:restore_local_db_with_region_reduction[carambus_api_production_20250102_120000.sql.gz]'

# Ausgabe:
# 🗄️  Restoring local development database with region reduction...
# ⚠️  WARNING: This will DROP and REPLACE your local development database!
#    The database will be reduced to region-specific data only.
#    Are you sure? (type 'yes' to continue): yes
# 📋 Step 1: Backing up local changes...
# 📋 Step 2: Dropping and recreating database...
# 📋 Step 3: Updating region taggings...
# 📋 Step 4: Reducing database to region-specific data...
# 📋 Step 5: Restoring local changes...
# ✅ Local development database restored with region reduction
# 🎯 Region-specific data only
```

### **Vollständiger Synchronisations-Workflow**

#### **Development → Production (Upload)**
```bash
# 1. Lokalen Development-Dump erstellen
bundle exec rails mode:prepare_db_dump

# 2. Version-Sicherheit prüfen
bundle exec rails 'mode:check_version_safety[carambus_api_development_20250102_120000.sql.gz]'

# 3. Dump zum API-Server übertragen (mit Sicherheitsprüfung)
bundle exec rails 'mode:deploy_db_dump[carambus_api_development_20250102_120000.sql.gz]'

# 4. Dump auf API-Server einlesen (DROP AND REPLACE)
bundle exec rails 'mode:restore_db_dump[carambus_api_development_20250102_120000.sql.gz]'
```

#### **Production → Development (Download)**
```bash
# 1. Production-Dump vom Server herunterladen
bundle exec rails mode:download_db_dump

# 2. Lokale Development-DB von Production-Dump wiederherstellen
bundle exec rails 'mode:restore_local_db[carambus_api_production_20250102_120000.sql.gz]'
```

#### **Production → Development mit Erhaltung lokaler Änderungen**
```bash
# 1. Production-Dump vom Server herunterladen
bundle exec rails mode:download_db_dump

# 2. Lokale Development-DB mit Erhaltung lokaler Änderungen wiederherstellen
bundle exec rails 'mode:restore_local_db_with_preservation[carambus_api_production_20250102_120000.sql.gz]'
```

#### **Production → Development mit Region-Reduktion**
```bash
# 1. Production-Dump vom Server herunterladen
bundle exec rails mode:download_db_dump

# 2. Lokale Development-DB mit Region-Reduktion wiederherstellen
bundle exec rails 'mode:restore_local_db_with_region_reduction[carambus_api_production_20250102_120000.sql.gz]'
```

### **Sicherheitsfeatures**

#### **Version-Sequenz-Sicherheit**
Das System verhindert versehentliches Überschreiben neuerer Daten:

```bash
# Automatische Sicherheitsprüfung vor Upload
bundle exec rails 'mode:deploy_db_dump[carambus_api_development_20250102_120000.sql.gz]'

# Manuelle Sicherheitsprüfung
bundle exec rails 'mode:check_version_safety[carambus_api_development_20250102_120000.sql.gz]'
```

**Sicherheitsregeln:**
- ✅ **SAFE**: Dump hat höhere Version-Nummern → Upload erlaubt
- ⚠️ **WARNING**: Dump hat gleiche Version-Nummern → Potentielle Konflikte
- ❌ **BLOCKED**: Dump hat niedrigere Version-Nummern → Upload blockiert

#### **Drop-and-Replace Bestätigung**
Alle kritischen Operationen erfordern explizite Bestätigung:

```bash
# Production-Datenbank ersetzen
bundle exec rails 'mode:restore_db_dump[carambus_api_development_20250102_120000.sql.gz]'
# ⚠️  WARNING: This will DROP and REPLACE the production database!
#    Are you sure? (type 'yes' to continue): yes

# Lokale Development-DB ersetzen
bundle exec rails 'mode:restore_local_db[carambus_api_production_20250102_120000.sql.gz]'
# ⚠️  WARNING: This will DROP and REPLACE your local development database!
#    Are you sure? (type 'yes' to continue): yes
```

#### **Dateinamen-Validierung**
Das System erkennt automatisch die Herkunft der Dumps:

- ✅ **carambus_api_development_*.sql.gz** → Nur für Upload zu Production
- ✅ **carambus_api_production_*.sql.gz** → Nur für Download zu Development
- ❌ **Falsche Dateinamen** → Operation blockiert

### **Region-spezifische Datenbankreduktion**

#### **Warum Datenbankreduktion?**
Lokale Server können auf eine spezifische Region reduziert werden, um nur relevante Daten zu behalten:

- ✅ **Records ohne Region-Bezug** (global_context = TRUE)
- ✅ **Records der spezifischen Region** (region_id = MODE_CONTEXT)
- ✅ **DBU-relevante Records** (Spieler, Clubs, LeagueTeams, Locations, Games, Parties, PartyGames, Seedings, GameParticipations)

#### **Automatische Datenbankreduktion**
```bash
# Datenbank auf spezifische Region reduzieren
bundle exec rails cleanup:remove_non_region_records

# Ausgabe:
# Deleting records in dependency order...
# Processing GameParticipation...
#   Before: 15000
#   After: 5000
#   Deleted: 10000
# Processing Game...
#   Before: 8000
#   After: 3000
#   Deleted: 5000
```

#### **Context-gesteuerte Synchronisation**
```bash
# Lokaler Server mit spezifischem Context
MODE_CONTEXT=NBV bundle exec rails 'mode:local'

# Nur Context-relevante Daten werden synchronisiert
# - Records der NBV-Region
# - DBU-relevante Records (global_context = TRUE)
# - Records ohne Region-Bezug
```

#### **Region-Tagging nach API-DB Import**
```bash
# Nach dem Einlesen einer API-Datenbank
bundle exec rails region_taggings:update_all_region_ids

# Aktualisiert alle region_tags in der lokalen Datenbank
# Setzt korrekte region_id für alle Modelle
```

### **Vollständiger Workflow mit Region-Reduktion**

#### **API → Local mit Region-Reduktion**
```bash
# 1. Production-Dump vom Server herunterladen
bundle exec rails mode:download_db_dump

# 2. Lokale Development-DB mit Erhaltung lokaler Änderungen wiederherstellen
bundle exec rails 'mode:restore_local_db_with_preservation[carambus_api_production_20250102_120000.sql.gz]'

# 3. Region-Tagging aktualisieren
bundle exec rails region_taggings:update_all_region_ids

# 4. Datenbank auf spezifische Region reduzieren
bundle exec rails cleanup:remove_non_region_records
```

#### **Context-spezifische Konfiguration**
```bash
# Lokaler Server für NBV-Region
MODE_CONTEXT=NBV \
MODE_BASENAME=carambus \
MODE_DOMAIN=new.carambus.de \
bundle exec rails 'mode:local'

# Führt automatisch aus:
# - Context-spezifische Datenbankreduktion
# - Region-Tagging Aktualisierung
# - Nur relevante Daten-Synchronisation
```

### **Lokale Änderungen-Management**

#### **Warum lokale Änderungen sichern?**
Bei lokalen Servern können lokale Änderungen (Records mit ID > 50.000.000) vorhanden sein, die vor dem Drop-and-Replace der Datenbank gesichert werden müssen.

#### **Automatische Erhaltung lokaler Änderungen**
```bash
# Vollständiger Workflow mit Erhaltung lokaler Änderungen
bundle exec rails 'mode:restore_local_db_with_preservation[carambus_api_production_20250102_120000.sql.gz]'

# Führt automatisch aus:
# 1. Backup lokaler Änderungen (ID > 50.000.000)
# 2. Drop und Recreate der Datenbank
# 3. Import des Production-Dumps
# 4. Wiederherstellung lokaler Änderungen
```

#### **Manuelle Erhaltung lokaler Änderungen**
```bash
# Schritt 1: Lokale Änderungen sichern
bundle exec rails mode:backup_local_changes

# Schritt 2: Datenbank ersetzen
bundle exec rails 'mode:restore_local_db[carambus_api_production_20250102_120000.sql.gz]'

# Schritt 3: Lokale Änderungen wiederherstellen
bundle exec rails 'mode:restore_local_changes[local_changes_filtered_20250102_120000.sql]'
```

#### **Verwendung der bestehenden Filter-Logik**
Das System nutzt die bewährte `carambus:filter_local_changes_from_sql_dump_new` Logik, um lokale Änderungen zu identifizieren und zu filtern.

### **Automatisierte Datenbank-Synchronisation**

#### **Mit Deployment-Script**
```bash
# Vollständiges Local Deployment inkl. Datenbanksynchronisation
./bin/deploy.sh full-local

# Führt automatisch aus:
# 1. Local Server Deployment
# 2. API-Datenbank-Dump erstellen
# 3. Dump zum Local Server übertragen
# 4. Dump auf Local Server einlesen
# 5. Post-Deploy Setup
```

#### **Manuelle Datenbank-Synchronisation**
```bash
# API-Datenbank auf Server dumpen
ssh -p 8910 www-data@carambus.de "cd /var/www/carambus_api/current && pg_dump -Uwww_data carambus_api_production | gzip > carambus_api_production.sql.gz"

# Dump lokal herunterladen
scp -P 8910 www-data@carambus.de:/var/www/carambus_api/current/carambus_api_production.sql.gz .

# Dump in lokale Entwicklungsumgebung einlesen
gunzip -c carambus_api_production.sql.gz | psql carambus_api_development
```

### **Datenbank-Versionierung**

#### **PaperTrail Integration**
```bash
# Sequence Reset nach Dump-Import
RAILS_ENV=production bundle exec rails runner "Version.sequence_reset"

# Last Version ID für API-Synchronisation setzen
LAST_VERSION_ID=$(ssh -p 8910 www-data@carambus.de "cd /var/www/carambus_api/current && RAILS_ENV=production bundle exec rails runner 'puts PaperTrail::Version.last.id'")
RAILS_ENV=production bundle exec rails runner "Setting.key_set_value('last_version_id', $LAST_VERSION_ID)"
```

#### **Datenbank-Backup Management**
```bash
# Nur die letzten 2 Dumps behalten
ls -t carambus_api_production_*.sql.gz | tail -n +3 | xargs rm -f

# Dumps komprimieren
gzip -9 carambus_api_production_*.sql

# Dumps verifizieren
gunzip -t carambus_api_production_*.sql.gz
```

## 🚀 **Deployment Workflow**

### **1. Konfiguration Vorbereiten**
```bash
# Lade gespeicherte Konfiguration
bundle exec rails 'mode:load[api_hetzner]'
```

### **2. Konfiguration Anwenden**
```bash
# Wende die geladenen Parameter an
bundle exec rails 'mode:api'
```

### **3. Konfiguration Validieren**
```bash
# Überprüfe die aktuelle Konfiguration
bundle exec rails 'mode:status'
```

### **4. Deployment Ausführen**
```bash
# Deploy mit der validierten Konfiguration
bundle exec cap production deploy
```

## 🔄 **Multi-Environment Deployment**

### **Deployment-Script Integration**
```bash
# API Server Deployment mit automatischem Pull
./bin/deploy.sh deploy-api

# Local Server Deployment mit automatischem Pull
./bin/deploy.sh deploy-local

# Full Local Deployment
./bin/deploy.sh full-local
```

### **Automatischer Repo-Pull**
Das Deployment-System führt automatisch einen `git pull` für die jeweiligen Szenario-Ordner durch, bevor das Deployment startet.

## 🔍 **Troubleshooting**

### **Socket-Berechtigungen prüfen**
```bash
# Socket-Verzeichnis prüfen
ls -la /var/www/carambus_api/shared/sockets/

# Socket-Berechtigungen prüfen
ls -la /var/www/carambus_api/shared/sockets/puma-production.sock
```

### **NGINX Socket-Konfiguration testen**
```bash
# Lokal testen
sudo nginx -t

# Auf Server testen
ssh -p 8910 www-data@newapi.carambus.de 'sudo nginx -t'
```

### **Puma Socket Status**
```bash
# Socket-Verbindung prüfen
ssh -p 8910 www-data@newapi.carambus.de 'netstat -an | grep puma'

# Service Status
ssh -p 8910 www-data@newapi.carambus.de 'sudo systemctl status puma-carambus_api.service'
```

### **Socket-Verzeichnisse erstellen**
```bash
# Manuell Socket-Verzeichnisse erstellen
ssh -p 8910 www-data@newapi.carambus.de 'sudo mkdir -p /var/www/carambus_api/shared/sockets /var/www/carambus_api/shared/pids /var/www/carambus_api/shared/log'
```

## 📁 **Dateistruktur**

### **Konfigurationsdateien**
```
config/
├── named_modes/           # Gespeicherte Named-Konfigurationen
│   ├── api_hetzner.yml
│   ├── local_hetzner.yml
│   └── development.yml
├── carambus.yml.erb      # ERB Template
├── database.yml.erb      # ERB Template
├── deploy.rb.erb         # ERB Template
├── nginx.conf.erb        # NGINX Template (Socket-basiert)
├── puma.rb.erb           # Puma.rb Template (Socket-basiert)
├── puma.service.erb      # Puma Service Template
├── scoreboard_url.erb    # Scoreboard URL Template
├── nginx.conf            # Generierte NGINX Konfiguration
├── puma.rb               # Generierte Puma.rb Konfiguration
├── puma.service          # Generierter Puma Service
├── scoreboard_url        # Generierte Scoreboard URL
└── deploy/
    └── production.rb.erb # ERB Template
```

### **Rake Tasks**
```
lib/tasks/
└── mode.rake             # Hauptsystem mit Named Parameters

lib/capistrano/tasks/
└── templates.rake        # Capistrano Template-Tasks
```

## ✅ **Vorteile des Enhanced Mode Systems**

1. **RubyMine Integration**: Perfekte Debugging-Unterstützung
2. **Type Safety**: Ruby-Typisierung und Validierung
3. **Error Handling**: Robuste Fehlerbehandlung
4. **Debugging**: Step-by-Step Debugging mit Breakpoints
5. **Variable Inspection**: Vollständige Variablen-Inspektion
6. **Call Stack**: Call Stack Navigation
7. **IDE Support**: Vollständige IDE-Unterstützung
8. **Maintainability**: Einfache Wartung und Erweiterung
9. **Socket Integration**: Vollständige Socket-basierte Architektur
10. **Template Generation**: Automatische Template-Generierung
11. **Performance**: Unix Sockets sind schneller als TCP/IP
12. **Security**: Keine Netzwerk-Exposition
13. **Efficiency**: Weniger Overhead
14. **Scalability**: Bessere Performance unter Last
15. **Automation**: Vollständige Automatisierung
16. **Multi-Environment**: Multi-Environment Support

## 🎉 **Fazit**

Das **Enhanced Mode System** mit Socket-basierter Architektur ist die **ideale Lösung** für RubyMine-Nutzer:

- ✅ **Vollständige Debugging-Unterstützung**
- ✅ **Robuste Parameter-Behandlung**
- ✅ **Einfache Wartung**
- ✅ **IDE-Integration**
- ✅ **Type Safety**
- ✅ **Socket-basierte Architektur**
- ✅ **Automatische Template-Generierung**
- ✅ **Vollständige Automatisierung**
- ✅ **Multi-Environment Support**
- ✅ **Robuste Deployment-Pipeline**

**Empfehlung**: Verwende das Enhanced Mode System für alle Carambus-Deployments.

Das System macht die Deployment-Konfiguration **debuggbar, wartbar und robust**! 🚀
