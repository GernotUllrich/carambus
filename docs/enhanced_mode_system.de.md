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
# 🗄️  Creating database dump: carambus_api_production_20250102_120000.sql.gz
# 📊 Source database: carambus_api_development
# 🎯 Target database: carambus_api_production (on server)
# ✅ Database dump created successfully: carambus_api_production_20250102_120000.sql.gz
```

#### **2. Verfügbare Dumps auflisten**
```bash
# Zeigt alle verfügbaren Dumps mit Größe und Datum
bundle exec rails mode:list_db_dumps

# Ausgabe:
# 🗄️  Available database dumps:
# ----------------------------------------
# carambus_api_production_20250102_120000.sql.gz (1234567 bytes, 2025-01-02 12:00:00)
# carambus_api_production_20250101_150000.sql.gz (1234567 bytes, 2025-01-01 15:00:00)
```

#### **3. Dump zum API-Server übertragen**
```bash
# Überträgt den Dump zum Server und legt ihn in /var/www/carambus_api/shared/database_dumps/ ab
bundle exec rails 'mode:deploy_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# Ausgabe:
# 🚀 Deploying database dump to production server...
# Dump file: carambus_api_production_20250102_120000.sql.gz
# Server: carambus.de:8910
# ✅ Database dump deployed successfully
# 📁 Remote location: /var/www/carambus_api/shared/database_dumps/carambus_api_production_20250102_120000.sql.gz
```

#### **4. Dump auf API-Server einlesen (als www-data)**
```bash
# Liest den Dump in die carambus_api_production Datenbank ein
bundle exec rails 'mode:restore_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# Ausgabe:
# 🗄️  Restoring database from dump...
# Dump file: carambus_api_production_20250102_120000.sql.gz
# Server: carambus.de:8910
# ✅ Database restored successfully
```

### **Vollständiger Synchronisations-Workflow**

```bash
# 1. Lokalen Development-Dump erstellen
bundle exec rails mode:prepare_db_dump

# 2. Dump zum API-Server übertragen
bundle exec rails 'mode:deploy_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# 3. Dump auf API-Server einlesen (als www-data)
bundle exec rails 'mode:restore_db_dump[carambus_api_production_20250102_120000.sql.gz]'

# 4. Puma Service neu starten
bundle exec cap production puma:restart
```

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
