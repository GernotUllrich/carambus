# Scenario Management System

Das Scenario Management System ermöglicht es, verschiedene Deployment-Umgebungen (Scenarios) für Carambus zu verwalten und automatisch zu deployen.

## Überblick

Das System unterstützt verschiedene Szenarien wie:
- **carambus**: Hauptproduktionsumgebung
- **carambus_api**: API-Server
- **carambus_location_5101**: Lokale Server-Instanz für Standort 5101
- **carambus_location_2459**: Lokale Server-Instanz für Standort 2459
- **carambus_location_2460**: Lokale Server-Instanz für Standort 2460

## Verbesserter Deployment-Workflow (2024)

Das System wurde vollständig überarbeitet und bietet jetzt eine saubere Trennung der Verantwortlichkeiten:

### Workflow-Übersicht

```
config.yml → prepare_development → prepare_deploy → deploy
     ↓              ↓                   ↓            ↓
   Basis      Development        Production      Server
   Setup        Setup            Vorbereitung    Deployment
```

## Haupt-Workflow

### 1. `scenario:prepare_development[scenario_name,environment]`
**Zweck**: Lokale Development-Umgebung einrichten

**Kompletter Flow**:
1. **Konfiguration laden**: Liest `config.yml` für Scenario-spezifische Einstellungen
2. **Rails Root erstellen**: Git Clone + .idea-Konfiguration (falls nicht vorhanden)
3. **Development-Konfiguration generieren**: 
   - `database.yml` für Development-Umgebung
   - `carambus.yml` mit Scenario-spezifischen Einstellungen
   - `cable.yml` für ActionCable
4. **Datenbank-Setup**:
   - Erstellt `carambus_scenarioname_development` aus Template `carambus_api_development`
   - Wendet Region-Filtering an (reduziert ~500MB auf ~90MB)
   - Setzt `last_version_id` für Sync-Tracking
   - Reset Version-Sequenz auf 50,000,000+ (verhindert ID-Konflikte)
5. **Asset-Compilation**:
   - `yarn build` (JavaScript)
   - `yarn build:css` (TailwindCSS)
   - `rails assets:precompile` (Sprockets)
6. **Database Dump erstellen**: Speichert verarbeitete Development-Datenbank

**Perfekt für**: Lokale Entwicklung, Scenario-Testing, Asset-Entwicklung

### 2. `scenario:prepare_deploy[scenario_name]`
**Zweck**: Vollständige Production-Deployment-Vorbereitung

**Kompletter Flow**:
1. **Production-Konfiguration generieren**:
   - `database.yml` für Production
   - `carambus.yml` mit Production-Einstellungen
   - `nginx.conf` mit korrekten Host/Port-Einstellungen
   - `puma.rb` mit Unix-Socket-Konfiguration
   - `puma.service` für systemd
   - `production.rb` mit ActionCable-Konfiguration
   - `cable.yml` für ActionCable PubSub
   - `deploy.rb` für Capistrano
   - `credentials/` mit Production-Keys
2. **Datenbank-Setup**:
   - **Upload und Load Database Dump**: Überträgt Development-Dump zum Server
   - **Database Reset**: Entfernt alte Anwendungsordner, erstellt neue Production-DB
   - **Dump Restoration**: Lädt verarbeitete Development-Datenbank in Production
   - **Verification**: Überprüft korrekte Wiederherstellung (19 Regionen)
3. **Server-Konfiguration**:
   - **File Transfers**: Upload aller Konfigurationsdateien zu `/var/www/scenario/shared/config/`
   - **Directory Setup**: Erstellt Deployment-Verzeichnisse mit korrekten Berechtigungen
   - **Service Preparation**: Bereitet systemd und Nginx vor

**Perfekt für**: Vollständige Deployment-Vorbereitung, Blank-Server-Setup

### 3. `scenario:deploy[scenario_name]`
**Zweck**: Reine Capistrano-Deployment mit automatischem Service-Management

**Kompletter Flow**:
1. **Database & Config Ready**: Nutzt bereits vorbereitete Datenbank und Konfiguration
2. **Capistrano Deployment**:
   - Git-Deployment mit Asset-Precompilation
   - `yarn install`, `yarn build`, `yarn build:css`
   - `rails assets:precompile`
   - **Automatischer Puma-Restart** via Capistrano-Hooks
   - **Automatischer Nginx-Reload** via Capistrano
3. **Service Management**: Alle Services werden automatisch von Capistrano verwaltet

**Perfekt für**: Production-Deployment, Wiederholbare Deployments

## Datenbank-Flow-Erklärung

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

**Key Insight**: Die Development-Datenbank ist die "verarbeitete" Version (Template + Filtering + Sequences), und Production wird aus dieser verarbeiteten Version erstellt.

## Vorteile des verbesserten Workflows

### ✅ Perfekte Trennung der Verantwortlichkeiten
- **`prepare_development`**: Development-Setup, Asset-Compilation, Datenbank-Verarbeitung
- **`prepare_deploy`**: Production-Vorbereitung, Server-Setup, Datenbank-Transfer
- **`deploy`**: Reine Capistrano-Deployment mit automatischem Service-Management

### ✅ Automatisches Service-Management
- **Puma-Restart**: Automatisch via Capistrano-Hooks (`after 'deploy:publishing', 'puma:restart'`)
- **Nginx-Reload**: Automatisch via Capistrano
- **Keine manuellen Eingriffe**: Alles wird von Capistrano verwaltet

### ✅ Robuste Asset-Pipeline
- **Sprockets-basiert**: Konsistente Asset-Verwaltung in Development und Production
- **TailwindCSS-Integration**: Korrekte CSS-Compilation
- **JavaScript-Bundling**: esbuild für optimierte Assets

### ✅ Intelligente Datenbank-Operationen
- **Template-Optimierung**: `createdb --template` statt `pg_dump | psql`
- **Region-Filtering**: Automatische Reduzierung der Datenbankgröße
- **Sequence-Management**: Automatische ID-Konflikt-Vermeidung
- **Verification**: Automatische Überprüfung der Datenbankintegrität

### ✅ Blank-Server-Ready
- **Vollständige Vorbereitung**: `prepare_deploy` richtet alles auf dem Server ein
- **Keine manuellen Schritte**: Automatische Erstellung von Services und Konfigurationen
- **Berechtigungen**: Automatische Korrektur von Verzeichnis-Berechtigungen

## Schnellstart

```bash
# 1. Development-Umgebung einrichten
rake "scenario:prepare_development[carambus_location_5101,development]"

# 2. Production-Vorbereitung (Database + Config + Server Setup)
rake "scenario:prepare_deploy[carambus_location_5101]"

# 3. Deployment ausführen (reine Capistrano-Operation)
rake "scenario:deploy[carambus_location_5101]"
```

## Erweiterte Nutzung

### Granulare Kontrolle

```bash
# Nur Konfigurationsdateien neu generieren
rake "scenario:generate_configs[carambus_location_5101,development]"

# Nur Datenbank-Dump erstellen
rake "scenario:create_database_dump[carambus_location_5101,development]"

# Nur Datenbank-Dump wiederherstellen
rake "scenario:restore_database_dump[carambus_location_5101,development]"

# Nur Rails Root Folder erstellen
rake "scenario:create_rails_root[carambus_location_5101]"
```

### Scenario-Update

```bash
# Scenario mit Git aktualisieren (behält lokale Änderungen)
rake "scenario:update[carambus_location_5101]"
```

## Scenario-Konfiguration

Jedes Scenario wird durch eine `config.yml` Datei definiert:

```yaml
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

## Technische Details

### Asset-Pipeline (Sprockets)

Das System verwendet die Sprockets Asset-Pipeline:

```bash
# Development Asset-Compilation
yarn build          # JavaScript (esbuild)
yarn build:css      # TailwindCSS
rails assets:precompile  # Sprockets (Development)
```

### ActionCable-Konfiguration

Automatische ActionCable-Konfiguration für StimulusReflex:

```yaml
# config/cable.yml
development:
  adapter: async
production:
  adapter: async
```

### Capistrano-Integration

Automatisches Service-Management via Capistrano:

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

### Datenbank-Transformationen

#### carambus-Scenario
- **Template-Optimierung**: `createdb --template=carambus_api_development`
- **Version-Sequenz-Reset**: `setval('versions_id_seq', 1, false)`
- **Settings-Update**: 
  - `last_version_id` auf 1 setzen
  - `scenario_name` auf "carambus" setzen

#### Location-Scenarios
- **Region-Filtering**: `cleanup:remove_non_region_records` mit `ENV['REGION_SHORTNAME'] = 'NBV'`
- **Optimierte Dump-Größe**: Reduziert von ~500MB auf ~90MB
- **Temporäre DB**: Erstellt temp DB, wendet Filtering an, erstellt Dump, bereinigt

## Fehlerbehebung

### Häufige Probleme

1. **Asset-Precompilation-Fehler**
   ```bash
   # Lösung: Vollständige Asset-Pipeline ausführen
   cd carambus_location_5101
   yarn build && yarn build:css && rails assets:precompile
   ```

2. **StimulusReflex funktioniert nicht**
   ```bash
   # Lösung: ActionCable-Konfiguration prüfen
   # cable.yml muss mit async adapter erstellt werden
   ```

3. **Database Sequence Conflicts**
   ```bash
   # Lösung: Development-Datenbank neu erstellen
   rake "scenario:prepare_development[scenario_name,development]"
   ```

4. **Port-Konflikte**
   ```bash
   # Lösung: Anderen Port in config.yml verwenden
   webserver_port: 3004
   ```

## Status

✅ **Vollständig implementiert**:
- ✅ Verbesserter Deployment-Workflow mit klarer Trennung
- ✅ Automatisches Service-Management via Capistrano
- ✅ Robuste Asset-Pipeline (Sprockets + TailwindCSS)
- ✅ ActionCable-Konfiguration für StimulusReflex
- ✅ Intelligente Datenbank-Operationen
- ✅ Blank-Server-Deployment
- ✅ Template-System für alle Konfigurationsdateien
- ✅ Unix-Socket-Konfiguration (Puma ↔ Nginx)
- ✅ SSL-Zertifikat-Management (Let's Encrypt)
- ✅ Refactoriertes Task-System (2024) - Eliminierte Code-Duplikation

🔄 **In Arbeit**:
- GitHub-Zugriff für Raspberry Pi
- Production-Datenbank-Setup

📋 **Geplant**:
- Mode-Switch-System deaktivieren
- Automatisierte Tests
- Weitere Location-Scenarios

## Best Practices

### Deployment-Reihenfolge
1. **Immer zuerst**: `prepare_development` für lokale Tests
2. **Dann**: `prepare_deploy` für Production-Vorbereitung
3. **Schließlich**: `deploy` für Server-Deployment

### Asset-Entwicklung
- Verwende `prepare_development` für lokale Asset-Tests
- Teste immer in Development-Umgebung vor Production-Deployment

### Datenbank-Management
- Development-Datenbank ist die "Quelle der Wahrheit"
- Production wird immer aus Development-Dump erstellt
- Sequence-Reset erfolgt automatisch

### Service-Management
- Verwende nie manuelle `systemctl`-Befehle
- Capistrano verwaltet alle Services automatisch
- Bei Problemen: `prepare_deploy` erneut ausführen