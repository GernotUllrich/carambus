# Deployment Workflow - Detaillierte Anleitung

Diese Dokumentation beschreibt den vollständigen Workflow vom `config.yml` über die API-Development-Datenbank bis zum Scenario Rails Root für Development, der Vorbereitung der Production-Umgebung und dem wiederholbaren Capistrano-Deployment.

## Workflow-Übersicht

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   config.yml    │───▶│ prepare_development  │───▶│  prepare_deploy     │───▶│     deploy      │
│                 │    │                      │    │                     │    │                 │
│ • Scenario Def  │    │ • Rails Root Setup   │    │ • Production Config │    │ • Capistrano    │
│ • Environments  │    │ • Development DB     │    │ • Database Transfer │    │ • Service Mgmt  │
│ • Server Config │    │ • Asset Compilation  │    │ • Server Setup      │    │ • Asset Build   │
└─────────────────┘    └──────────────────────┘    └─────────────────────┘    └─────────────────┘
```

## Phase 1: Konfiguration (config.yml)

### Basis-Setup
```yaml
# carambus_data/scenarios/carambus_location_5101/config.yml
scenario:
  name: carambus_location_5101
  description: Location 5101 Server
  location_id: 5101
  context: LOCAL                    # API, LOCAL, oder NBV
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

### Was passiert hier?
- **Scenario-Definition**: Name, Location-ID, Region, Club
- **Environment-Separation**: Development vs. Production Settings
- **Server-Konfiguration**: SSH-Zugang, Ports, Pfade
- **Database-Setup**: Namen, Credentials, Socket-Pfade

## Phase 2: Development Setup (prepare_development)

### Kompletter Flow

```bash
rake "scenario:prepare_development[carambus_location_5101,development]"
```

### Schritt-für-Schritt

#### 2.1 Rails Root Setup
```
/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_location_5101/
├── .git/                    # Git Repository (Clone von carambus_master)
├── .idea/                   # RubyMine-Konfiguration
├── app/                     # Rails Application
├── config/                  # Rails Configuration
├── lib/                     # Library Files
└── ...
```

**Was passiert:**
- Git Clone von `carambus_master` Repository
- Kopie der `.idea`-Konfiguration für RubyMine
- Korrekte Branch-Einstellung (`master`)

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
  api_url: https://newapi.carambus.de/
  season_name: 2025/2026
  context: LOCAL
```

#### 2.3 Database Setup (Template-Optimierung)

**Source Database**: `carambus_api_development` (mother database)

**Process:**
```bash
# 1. Template-basierte Erstellung (viel schneller als pg_dump)
createdb carambus_location_5101_development --template=carambus_api_development

# 2. Region-Filtering (reduziert ~500MB auf ~90MB)
RAILS_ENV=development REGION_SHORTNAME=NBV bundle exec rails cleanup:remove_non_region_records

# 3. Version-Sequenz-Reset (verhindert ID-Konflikte)
RAILS_ENV=development bundle exec rails runner 'Version.sequence_reset'

# 4. Settings-Update
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

### Kompletter Flow

```bash
rake "scenario:prepare_deploy[carambus_location_5101]"
```

### Schritt-für-Schritt

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

#### 3.2 Database Transfer and Setup

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

#### 3.3 Server Configuration Upload

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

### Kompletter Flow

```bash
rake "scenario:deploy[carambus_location_5101]"
```

### Schritt-für-Schritt

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

## Wiederholbares Deployment

### Für Updates

```bash
# 1. Code-Änderungen in carambus_master
git add .
git commit -m "Feature update"
git push carambus master

# 2. Scenario aktualisieren
rake "scenario:update[carambus_location_5101]"

# 3. Assets neu kompilieren (falls nötig)
rake "scenario:prepare_development[carambus_location_5101,development]"

# 4. Production-Deployment
rake "scenario:deploy[carambus_location_5101]"
```

### Für Konfigurationsänderungen

```bash
# 1. config.yml anpassen
# 2. Production-Konfiguration neu generieren
rake "scenario:prepare_deploy[carambus_location_5101]"

# 3. Deployment
rake "scenario:deploy[carambus_location_5101]"
```

## Vorteile des Workflows

### ✅ Klare Trennung der Verantwortlichkeiten
- **Development Setup**: Lokale Entwicklung und Testing
- **Production Preparation**: Server-Setup und Konfiguration
- **Deployment**: Reine Capistrano-Operation

### ✅ Automatisches Service-Management
- Keine manuellen `systemctl`-Befehle nötig
- Capistrano verwaltet alle Services automatisch
- Konsistente Service-Zustände

### ✅ Robuste Asset-Pipeline
- Sprockets-basierte Asset-Verwaltung
- TailwindCSS-Integration
- JavaScript-Bundling mit esbuild

### ✅ Intelligente Datenbank-Operationen
- Template-Optimierung für schnelle DB-Erstellung
- Region-Filtering für optimale Performance
- Automatische Sequence-Verwaltung

### ✅ Blank-Server-Deployment
- Vollständige Server-Einrichtung in einem Schritt
- Automatische Berechtigungs-Korrektur
- Keine manuellen Konfigurationsschritte

## Fehlerbehebung

### Häufige Probleme

1. **Asset-Precompilation-Fehler**
   ```bash
   cd carambus_location_5101
   rm -rf tmp/cache .sprockets-cache
   yarn build && yarn build:css && rails assets:precompile
   ```

2. **Database Sequence Conflicts**
   ```bash
   rake "scenario:prepare_development[scenario_name,development]"
   ```

3. **Service-Probleme**
   ```bash
   # Nicht manuell beheben, sondern:
   rake "scenario:prepare_deploy[scenario_name]"
   rake "scenario:deploy[scenario_name]"
   ```

4. **Port-Konflikte**
   ```bash
   # In config.yml anpassen:
   webserver_port: 3004  # Anderen Port verwenden
   ```

## Best Practices

### Deployment-Reihenfolge
1. **Immer zuerst**: `prepare_development` für lokale Tests
2. **Dann**: `prepare_deploy` für Production-Vorbereitung  
3. **Schließlich**: `deploy` für Server-Deployment

### Asset-Entwicklung
- Verwende `prepare_development` für lokale Asset-Tests
- Teste immer in Development-Umgebung vor Production

### Datenbank-Management
- Development-Datenbank ist die "Quelle der Wahrheit"
- Production wird immer aus Development-Dump erstellt
- Sequence-Reset erfolgt automatisch

### Service-Management
- Verwende nie manuelle `systemctl`-Befehle
- Capistrano verwaltet alle Services automatisch
- Bei Problemen: `prepare_deploy` erneut ausführen
