# Scenario-System Implementation - Dokumentation

## Übersicht

Das Scenario-System wurde entwickelt, um die komplexe Test- und Deployment-Architektur zu vereinfachen. Es ersetzt das bisherige Mode-Switch-System durch eine klare, template-basierte Konfiguration.

## Architektur

### 1. Repository-Struktur

```
/Users/gullrich/DEV/carambus/
├── carambus_master/                 # Haupt-Repository (Code + Templates)
│   ├── lib/tasks/scenarios.rake    # Scenario-Management Tasks
│   ├── templates/                   # ERB-Templates (verschoben von carambus_data)
│   │   ├── database/
│   │   ├── carambus/
│   │   ├── deploy/
│   │   ├── nginx/
│   │   └── puma/
│   └── ...
├── carambus_data/                   # Konfigurations-Repository
│   └── scenarios/                   # Scenario-Konfigurationen
│       ├── carambus_api/
│       ├── carambus/                # Lokaler Server
│       ├── carambus_location_2459/
│       └── carambus_location_2460/
├── carambus_api/                    # Generierte Rails-Root-Folders
├── carambus/                        # Generierte Rails-Root-Folders
├── carambus_location_2459/          # Generierte Rails-Root-Folders
└── carambus_location_2460/
```

### 2. Scenario-Konfiguration (config.yml)

Jedes Scenario hat eine `config.yml` mit folgender Struktur:

```yaml
---
scenario:
  name: carambus_location_2459
  description: PHAT Consulting Location
  location_id: 2459
  context: NBV                    # API, LOCAL, oder NBV
  region_id: 1
  club_id: 357
  api_url: https://newapi.carambus.de/  # null für API-Server
  season_name: 2025/2026
  application_name: carambus
  basename: carambus_carambus_location_2459
  branch: master
  is_main: false                 # true nur für Haupt-API-Server

environments:
  development:
    webserver_host: localhost
    webserver_port: 3000
    database_name: carambus_location_2459_development
    ssl_enabled: false
    database_username: null
    database_password: null

  production:
    webserver_host: 192.168.178.107
    ssh_host: 192.168.178.107
    webserver_port: 81
    ssh_port: 8910
    database_name: carambus_location_2459_production
    ssl_enabled: false
    database_username: www_data    # Mit Unterstrich (PostgreSQL-kompatibel)
    database_password: toS6E7tARQafHCXz
    puma_socket_path: /tmp/puma.sock
    deploy_to: /var/www/carambus_location_2459  # Unix Socket Pfad
```

## Implementierte Rake Tasks

### 1. Scenario-Management

#### `scenario:list`
Listet alle verfügbaren Scenarios auf.

### 2. Konfigurations-Generierung

#### `scenario:generate_configs[scenario_name,environment]`
Generiert Konfigurationsdateien für ein Scenario und Environment:
- `database.yml`
- `carambus.yml`
- `deploy.rb` und `deploy/production.rb` (nur für development)

#### `scenario:setup[scenario_name,environment]`
Komplettes Setup eines Scenarios:
1. Generiert Konfigurationsdateien
2. Erstellt/Stellt Datenbank wieder her
3. Kopiert Dateien in Rails-Root-Folder

### 3. Rails-Root-Folder Management

#### `scenario:create_rails_root[scenario_name]`
Erstellt einen neuen Rails-Root-Folder für ein Scenario:
- **Git Clone**: Klont das Repository von `git@github.com:GernotUllrich/carambus.git`
- **RubyMine-Integration**: Kopiert `.idea` Konfiguration für sofortige Entwicklungsumgebung
- **Verzeichnisse**: Erstellt `log`, `tmp`, `storage` Verzeichnisse
- **Vollständige Rails-Struktur**: Inklusive aller Migrations und Dateien

#### `scenario:setup_with_rails_root[scenario_name,environment]`
Komplettes Setup mit Rails-Root-Folder:
1. Erstellt Rails-Root-Folder
2. Stellt Datenbank wieder her
3. Kopiert generierte Konfigurationsdateien

### 4. Datenbank-Management

#### `scenario:create_database_dump[scenario_name,environment]`
Erstellt einen komprimierten Datenbank-Dump.

**Spezielle Transformation für carambus-Scenario:**
- Generiert `carambus_development` aus `carambus_api_development`
- Reset der Version-Sequenz: `setval('versions_id_seq', 1, false)`
- Aktualisierung der Settings-JSON-Daten:
  - `last_version_id` auf 1 setzen
  - `scenario_name` auf "carambus" setzen
- Temporäre Datenbank für Transformation wird automatisch bereinigt

#### `scenario:restore_database_dump[scenario_name,environment]`
Stellt einen Datenbank-Dump wieder her.

### 5. Deployment

#### `scenario:prepare_development[scenario_name,environment]`
Prepares a scenario for local development:
1. Generates configuration files for the specified environment
2. Restores database dump (with region filtering for location scenarios)
3. Ensures Rails root folder exists (creates if needed)
4. Copies basic config files (database.yml, carambus.yml)

**Perfect for**: Local development setup, testing scenarios locally.

#### `scenario:prepare_deploy[scenario_name]`
Prepares a scenario for deployment with all deployment preparation steps except server deployment:
1. Generates production configuration files
2. Creates database dump from development (with region filtering)
3. Ensures Rails root folder exists (creates if needed)
4. Copies all production configuration files (nginx.conf, puma.rb, puma.service)
5. Copies credentials and master.key
6. Copies deployment files (deploy.rb, deploy/production.rb)

**Perfect for**: Local preparation before deployment, testing deployment configuration, or when you want to prepare everything locally before deploying to production.

**💡 Config Lock Files**: Configuration files can be protected from being overwritten on the server by creating a `.lock` file. For example, create `/var/www/[basename]/shared/config/carambus.yml.lock` on the server to prevent `carambus.yml` from being updated during deployment. This is useful for preserving server-specific settings. See [CONFIG_LOCK_FILES.md](../../../docs/CONFIG_LOCK_FILES.md) for details.

#### `scenario:deploy[scenario_name]`
Deployt ein Scenario zu Production mit Konflikt-Analyse:

1. **Server-Analyse**: 
   - Prüft existierende `/var/www` Verzeichnisse
   - Analysiert Nginx-Konfiguration auf Port-Konflikte
   - Prüft existierende Puma-Services

2. **Konflikt-Auflösung**:

#### `scenario:quick_deploy[scenario_name]`
**NEW**: Schnelles Deployment für iterative Entwicklung ohne Scenario-Regenerierung:

**Verwendung**: Für Code-Änderungen ohne Konfigurationsänderungen (Controller, Views, JavaScript, CSS, Models, Routes)

**Vorraussetzungen**:
- Scenario muss bereits deployed sein (`scenario:deploy` einmal ausgeführt)
- Keine Änderungen an `config.yml` oder Scenario-Konfiguration
- Änderungen sollten committed und gepusht sein

**Ablauf**:
1. **Validierung**: Prüft Scenario-Konfiguration und Rails-Root
2. **Git-Status**: Warnt vor uncommitted Changes
3. **Git-Pull**: Holt neueste Änderungen aus Repository
4. **Asset-Build**: Kompiliert Frontend-Assets (yarn install && yarn build)
5. **Capistrano-Deployment**: Standard Rails-Deployment
6. **Service-Restart**: Startet Puma-Service neu
7. **Verifikation**: Testet Application-Response

**Performance**: 30-60 Sekunden (vs. 5-10 Minuten für vollständiges Deployment)

**Perfekt für**: Iterative Entwicklung, Code-Änderungen, Frontend-Updates, Hotfixes

**Vollständige Dokumentation**: Siehe `ITERATIVE_DEVELOPMENT_WORKFLOW.md`
   - Fragt Benutzer nach Auflösungsstrategie:
     - Existierendes Deployment ersetzen
     - Paralleles Deployment erstellen
     - Deployment abbrechen

3. **Paralleles Deployment**:
   - Modifiziert `basename` (z.B. `carambus_carambus_location_2459`)
   - Inkrementiert `webserver_port` (z.B. 80 → 81)
   - Speichert aktualisierte `config.yml`

4. **Deployment-Ausführung**:
   - Generiert Production-Konfigurationen
   - Erstellt Production-Datenbank-Dump (mit Transformation für carambus-Scenario)
   - Kopiert Konfigurationsdateien in Rails-Root-Folder
   - Uploads shared Konfigurationsdateien auf Server (respektiert `.lock` Dateien)
   - Führt Capistrano-Deployment aus
   - Konfiguriert SSL-Zertifikate (Let's Encrypt)
   - Setzt Nginx-Konfiguration für Unix-Sockets
   - Konfiguriert Puma-Service für Unix-Sockets

   **Hinweis**: Konfigurationsdateien mit einer `.lock` Datei werden beim Upload übersprungen. Siehe [CONFIG_LOCK_FILES.md](../../../docs/CONFIG_LOCK_FILES.md).

## Templates

### 1. Database Template (`database.yml.erb`)
```erb
---
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

<%= @environment %>:
  <<: *default
  database: <%= @config["database_name"] %>
  <% if @config["database_username"] %>
  username: <%= @config["database_username"] %>
  <% end %>
  <% if @config["database_password"] %>
  password: <%= @config["database_password"] %>
  <% end %>
```

### 2. Carambus Template (`carambus.yml.erb`)
```erb
---
default:
  carambus_api_url: <%= @scenario['api_url'] %>
  location_id: <%= @scenario['location_id'] %>
  application_name: <%= @scenario['application_name'] %>
  basename: <%= @scenario['basename'] %>
  # ... weitere Standard-Parameter

<%= @environment %>:
  carambus_api_url: <%= @scenario['api_url'] %>
  location_id: <%= @scenario['location_id'] %>
  application_name: <%= @scenario['application_name'] %>
  basename: <%= @scenario['basename'] %>
  context: <%= @scenario['context'] %>
  # ... weitere Environment-spezifische Parameter
```

### 4. Puma Template (`puma_rb.erb`)
```erb
# Puma Configuration for <%= @scenario['application_name'] %> (<%= @environment %>)

# Generated by Carambus Scenario System

threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV") { "<%= @environment %>" }
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
preload_app!

before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

plugin :tmp_restart

<% if @environment == 'production' %>
# Production: Use Unix socket for better performance and security
bind "unix://<%= @production_config['deploy_to'] %>/shared/sockets/puma-<%= @environment %>.sock"
<% else %>
# Development: Use standard port instead of Unix socket
port ENV.fetch("PORT") { 3000 }
<% end %>
```

## Verfügbare Scenarios

### 1. carambus_api
- **Beschreibung**: Haupt-API-Server
- **Context**: API
- **Production**: newapi.carambus.de:80
- **SSH**: newapi.carambus.de:8910
- **Status**: ✅ Erstellt und getestet mit Unix-Sockets

### 2. carambus
- **Beschreibung**: Lokaler Server (verbindet sich mit API Server)
- **Context**: LOCAL
- **API URL**: https://newapi.carambus.de
- **Production**: carambus.de:80
- **SSH**: carambus.de:8910
- **Status**: ✅ Erstellt und getestet mit Unix-Sockets
- **Besonderheit**: Spezielle Datenbank-Transformation (Version-Sequenz-Reset)

### 3. carambus_location_2459
- **Beschreibung**: PHAT Consulting Location
- **Context**: NBV
- **Production**: 192.168.178.107:81 (parallel deployment)
- **SSH**: 192.168.178.107:8910

### 4. carambus_location_2460
- **Beschreibung**: Weitere Location (Test-Szenario)
- **Context**: NBV
- **Status**: ✅ Rails-Root-Folder erstellt mit RubyMine-Integration

## Verwendung

### 1. Neues Scenario erstellen
```bash
# Scenario-Konfiguration erstellen
mkdir -p /Users/gullrich/DEV/projects/carambus_data/scenarios/new_scenario
# config.yml manuell erstellen

# Rails-Root-Folder und Setup
rake "scenario:setup_with_rails_root[new_scenario,development]"
```

### 2. Scenario für Development vorbereiten
```bash
# Lokale Development-Umgebung einrichten
rake "scenario:prepare_development[carambus_location_2459,development]"
```

### 3. Scenario für Deployment vorbereiten
```bash
# Alle Deployment-Schritte außer Server-Deployment
rake "scenario:prepare_deploy[carambus_location_2459]"
```

### 4. Scenario deployen
```bash
# Vollständiges Deployment (für neue Scenarios oder Konfigurationsänderungen)
rake "scenario:deploy[carambus_location_2459]"

# Schnelles Deployment (für Code-Änderungen ohne Konfigurationsänderungen)
rake "scenario:quick_deploy[carambus_location_2459]"
```

### 5. Konfigurationen aktualisieren
```bash
# Nur Konfigurationsdateien neu generieren
rake "scenario:generate_configs[carambus_location_2459,development]"
```

## Migration vom Mode-Switch-System

### 1. Parameter-Extraktion
Das alte Mode-Switch-System wurde analysiert und die Parameter in die neue `config.yml`-Struktur überführt.

### 2. Vorteile der neuen Architektur
- **Klare Trennung**: Code (carambus_api) vs. Konfiguration (carambus_data)
- **Idempotente Operationen**: Tasks können wiederholt ausgeführt werden
- **Template-basiert**: Konfigurationen werden aus ERB-Templates generiert
- **Konflikt-Auflösung**: Automatische Erkennung und interaktive Auflösung
- **Parallele Deployments**: Mehrere Scenarios auf demselben Server

### 3. Nächste Schritte
- [ ] Mode-Switch-System deaktivieren
- [ ] Dokumentation für Migration erstellen
- [ ] GitHub-Repository-Zugriff für Raspberry Pi konfigurieren
- [ ] Production-Datenbank-Erstellung automatisieren

## Technische Details

### SSH-Konfiguration
```bash
# ~/.ssh/config
Host location_2459
    HostName 192.168.178.107
    Port 8910
    User www-data
```

### Datenbank-Dumps
- **Format**: `.sql.gz` (komprimiert)
- **Speicherort**: `carambus_data/scenarios/{scenario}/database_dumps/`
- **Naming**: `{database_name}_{timestamp}.sql.gz`

### Capistrano-Integration
- **Version**: 3.19.2
- **Repository**: git@github.com:gullrich/carambus_api.git
- **Deployment-Pfad**: `/var/www/{basename}`
- **Service-Name**: `puma-{basename}.service`

## Deployment-Automatisierung

### Vollständige Automatisierung
Das Deployment-System wurde vollständig automatisiert und umfasst:

#### 1. **Konfigurationsgenerierung**
- `database.yml` (Production)
- `carambus.yml` (Production)
- `nginx.conf` (SSL-konfiguriert)
- `puma.rb` (Unix-Socket-konfiguriert)
- `puma.service` (Systemd-Service)

#### 2. **Unix-Socket-Konfiguration**
- Puma konfiguriert für Unix-Sockets in Production
- Nginx-Proxy zu Unix-Sockets statt TCP-Ports
- Verbesserte Performance und Sicherheit
- Automatische Socket-Verzeichnis-Erstellung

#### 3. **SSL-Zertifikat-Management**
- Automatische Prüfung vorhandener Zertifikate
- Certbot-Integration für neue Zertifikate
- Nginx-SSL-Konfiguration

#### 4. **Service-Konfiguration**
- Puma-Service mit korrekten ERB-Variablen
- Automatische Systemd-Integration
- Service-Restart nach Konfigurationsänderungen
- Ruby 3.2.1 rbenv-Konfiguration

#### 5. **Nginx-Management**
- Automatische Konfigurationskopie
- Sites-available/Sites-enabled-Setup
- Unix-Socket-Proxy-Konfiguration
- Konfigurationstest und Reload

### Deployment-Workflows

#### Vollständiges Deployment (`scenario:deploy`)
```bash
rake "scenario:deploy[scenario_name]"
```

**Führt automatisch aus:**
1. Konfigurationsgenerierung (production)
2. Datenbank-Dump-Erstellung (mit Transformation für carambus-Scenario)
3. Konfigurationsdateien kopieren
4. Deployment-Dateien kopieren
5. Shared Konfigurationsdateien auf Server uploaden
6. Capistrano-Deployment ausführen
7. SSL-Zertifikat-Setup (Let's Encrypt)
8. Puma-Service-Konfiguration (Unix-Sockets)
9. Nginx-Konfiguration-Update (Unix-Socket-Proxy)

**Verwendung**: Neue Scenarios, Konfigurationsänderungen, SSL-Updates

#### Schnelles Deployment (`scenario:quick_deploy`)
```bash
rake "scenario:quick_deploy[scenario_name]"
```

**Führt automatisch aus:**
1. Git-Status-Prüfung und Pull
2. Frontend-Asset-Build (yarn install && yarn build)
3. Capistrano-Deployment
4. Puma-Service-Restart
5. Nginx-Reload
6. Application-Response-Verifikation

**Verwendung**: Code-Änderungen, Frontend-Updates, iterative Entwicklung

#### Workflow-Vergleich

| Operation | Vollständiges Deployment | Schnelles Deployment |
|-----------|-------------------------|---------------------|
| **Verwendung** | Neue Scenarios, Config-Änderungen | Code-Änderungen nur |
| **Zeit** | 5-10 Minuten | 30-60 Sekunden |
| **Regeneriert Configs** | ✅ Ja | ❌ Nein |
| **Baut Assets** | ✅ Ja | ✅ Ja |
| **Datenbank-Operationen** | ✅ Ja | ❌ Nein |
| **Service-Restarts** | ✅ Alle | ✅ Puma nur |
| **SSL-Setup** | ✅ Ja | ❌ Nein |

## Fehlerbehebung

### Häufige Probleme

1. **GitHub-Zugriff von Raspberry Pi**
   - Lösung: SSH-Key bei GitHub eintragen

2. **Datenbank existiert nicht**
   - Lösung: Production-Datenbank erstellen vor Deployment

3. **Port-Konflikte**
   - Lösung: Automatische Erkennung und Auflösung implementiert

4. **Service-Konflikte**
   - Lösung: Interaktive Auflösung mit Optionen

## Status

✅ **Implementiert**:
- Scenario-Konfigurations-System
- Template-basierte Generierung
- Rails-Root-Folder-Management (Git Clone)
- RubyMine-Integration (.idea Konfiguration)
- Datenbank-Dump-Management mit Transformation
- Deployment mit Konflikt-Analyse
- Interaktive Konflikt-Auflösung
- **carambus_api Scenario** (API-Server, Unix-Sockets)
- **carambus Scenario** (Lokaler Server, Unix-Sockets)
- **Vollständige Deployment-Automatisierung**
- **Unix-Socket-Konfiguration** (Puma ↔ Nginx)
- **SSL-Zertifikat-Management** (Let's Encrypt)
- **Puma-Service-Konfiguration** (Ruby 3.2.1)
- **Nginx-Konfiguration-Management** (Unix-Socket-Proxy)
- **Template-System für alle Konfigurationsdateien**
- **Spezielle Datenbank-Transformation** (Version-Sequenz-Reset)
- **Capistrano-Integration** (Vollständig automatisiert)

🔄 **In Arbeit**:
- GitHub-Zugriff für Raspberry Pi
- Production-Datenbank-Setup

📋 **Geplant**:
- Mode-Switch-System deaktivieren
- Automatisierte Tests
- Weitere Location-Scenarios
