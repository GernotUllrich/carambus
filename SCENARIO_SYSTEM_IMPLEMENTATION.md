# Scenario-System Implementation - Dokumentation

## Übersicht

Das Scenario-System wurde entwickelt, um die komplexe Test- und Deployment-Architektur zu vereinfachen. Es ersetzt das bisherige Mode-Switch-System durch eine klare, template-basierte Konfiguration.

## Architektur

### 1. Repository-Struktur

```
/Volumes/EXT2TB/gullrich/DEV/projects/
├── carambus_api/                    # Haupt-Repository (Code)
│   ├── lib/tasks/scenarios.rake    # Scenario-Management Tasks
│   └── ...
├── carambus_data/                   # Konfigurations-Repository
│   ├── scenarios/                   # Scenario-Konfigurationen
│   │   ├── carambus_api/
│   │   ├── carambus_location_2459/
│   │   └── carambus_location_2460/
│   └── templates/                   # ERB-Templates
│       ├── database/
│       ├── carambus/
│       └── deploy/
└── carambus_location_2459/          # Generierte Rails-Root-Folders
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
  context: NBV
  region_id: 1
  club_id: 357
  api_url: https://newapi.carambus.de/
  season_name: 2025/2026
  application_name: carambus
  basename: carambus_carambus_location_2459
  branch: master

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
    database_username: www-data
    database_password: toS6E7tARQafHCXz
    puma_socket_path: /tmp/puma.sock
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
   - Erstellt Production-Datenbank-Dump
   - Führt Capistrano-Deployment aus

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

### 3. Deploy Template (`deploy.rb.erb`)
```erb
# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "#{scenario['application_name']}"
set :repo_url, "git@github.com:gullrich/carambus_api.git"
set :basename, "#{scenario['basename']}"
# ... weitere Capistrano-Konfiguration
```

## Verfügbare Scenarios

### 1. carambus_api
- **Beschreibung**: Haupt-API-Server
- **Context**: API
- **Production**: newapi.carambus.de:80
- **SSH**: newapi.carambus.de:22
- **Status**: ✅ Erstellt und getestet (2 User-Records)

### 2. carambus_location_2459
- **Beschreibung**: PHAT Consulting Location
- **Context**: NBV
- **Production**: 192.168.178.107:81 (parallel deployment)
- **SSH**: 192.168.178.107:8910

### 3. carambus_location_2460
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
- Datenbank-Dump-Management
- Deployment mit Konflikt-Analyse
- Interaktive Konflikt-Auflösung
- carambus_api Scenario (erstellt und getestet)

🔄 **In Arbeit**:
- GitHub-Zugriff für Raspberry Pi
- Production-Datenbank-Setup

📋 **Geplant**:
- Mode-Switch-System deaktivieren
- Dokumentation vervollständigen
- Automatisierte Tests
