# Scenario-System Implementation - Dokumentation

## Übersicht

Das Scenario-System wurde entwickelt, um die komplexe Test- und Deployment-Architektur zu vereinfachen. Es ersetzt das bisherige Mode-Switch-System durch eine klare, template-basierte Konfiguration.

## Architektur

### 1. Repository-Struktur

```
/Volumes/EXT2TB/gullrich/DEV/carambus/
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

#### `scenario:deploy[scenario_name]`
Deployt ein Scenario zu Production mit Konflikt-Analyse:

1. **Server-Analyse**: 
   - Prüft existierende `/var/www` Verzeichnisse
   - Analysiert Nginx-Konfiguration auf Port-Konflikte
   - Prüft existierende Puma-Services

2. **Konflikt-Auflösung**:
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
   - Uploads shared Konfigurationsdateien auf Server
   - Führt Capistrano-Deployment aus
   - Konfiguriert SSL-Zertifikate (Let's Encrypt)
   - Setzt Nginx-Konfiguration für Unix-Sockets
   - Konfiguriert Puma-Service für Unix-Sockets

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
- **Production**: new.carambus.de:80
- **SSH**: new.carambus.de:8910
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
mkdir -p /Volumes/EXT2TB/gullrich/DEV/projects/carambus_data/scenarios/new_scenario
# config.yml manuell erstellen

# Rails-Root-Folder und Setup
rake "scenario:setup_with_rails_root[new_scenario,development]"
```

### 2. Scenario deployen
```bash
# Deployment mit Konflikt-Analyse
rake "scenario:deploy[carambus_location_2459]"
```

### 3. Konfigurationen aktualisieren
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

### Deployment-Workflow
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
