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
2. **Development-Datenbank vorbereiten**:
   - **Migrations ausführen**: Stellt sicher, dass Development-DB aktuell ist
   - **Production Dump erstellen**: Erstellt Dump aus aktueller Development-Datenbank
3. **Datenbank-Setup auf Server**:
   - **🔍 Automatische Erkennung von lokalen Daten**: Prüft auf Datensätze mit ID > 50.000.000
   - **💾 Automatisches Backup (bei lokalen Daten)**:
     - Löscht automatisch: `versions`, Spiele mit nil data, verwaiste Datensätze
     - Reduziert Backup-Größe von ~1,2 GB auf ~116 KB (99,99% Reduktion!)
   - **Upload und Load Database Dump**: Überträgt Development-Dump zum Server
   - **Database Reset**: Entfernt alte Anwendungsordner, erstellt neue Production-DB
   - **Dump Restoration**: Lädt verarbeitete Development-Datenbank in Production
   - **🔄 Automatisches Wiederherstellen (bei Backup vorhanden)**: Stellt lokale Daten nach DB-Update wieder her
   - **Verification**: Überprüft korrekte Wiederherstellung (19 Regionen)
4. **Server-Konfiguration**:
   - **File Transfers**: Upload aller Konfigurationsdateien zu `/var/www/scenario/shared/config/`
   - **Directory Setup**: Erstellt Deployment-Verzeichnisse mit korrekten Berechtigungen
   - **Service Preparation**: Bereitet systemd und Nginx vor

**Perfekt für**: Vollständige Deployment-Vorbereitung, Blank-Server-Setup, **Saisonbeginn mit vielen DB-Änderungen**

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

### Lokale Daten-Verwaltung (ID > 50.000.000)

**Neu ab 2024**: Vollständig automatisierte Verwaltung lokaler Daten während Deployments.

#### Automatischer Modus (Standard)

```bash
# Normales Deployment - lokale Daten werden automatisch gesichert/wiederhergestellt!
rake "scenario:prepare_deploy[carambus_location_5101]"

# Oder via Deployment-Script
./bin/deploy-scenario.sh carambus_location_5101
```

**Was passiert automatisch:**
1. ✅ Erkennt lokale Daten (ID > 50.000.000) in Production-DB
2. ✅ Erstellt Backup mit automatischer Bereinigung:
   - Löscht ~273.885 `versions` (nicht auf lokalen Servern benötigt)
   - Löscht ~5.019 Spiele mit `data IS NULL` (unvollständig/korrupt)
   - Löscht ~10.038 verwaiste `game_participations`
   - Löscht ~25 verwaiste `table_monitors`
   - Löscht verwaiste `seedings`
3. ✅ Aktualisiert Datenbank mit neuem Schema/Daten
4. ✅ Stellt lokale Daten wieder her
5. ✅ Fertig! (99,95% Erfolgsrate, 15.185 / 15.193 Datensätze)

**Backup-Größe**: ~116 KB statt ~1,2 GB (99,99% Reduktion!)

#### Manueller Modus (Spezialfälle)

```bash
# Manuelles Backup lokaler Daten
rake "scenario:backup_local_data[carambus_location_5101]"
# Ergebnis: scenarios/carambus_location_5101/local_data_backups/local_data_TIMESTAMP.sql

# Manuelles Wiederherstellen lokaler Daten
rake "scenario:restore_local_data[carambus_location_5101,/pfad/zum/backup.sql]"
```

**Use Cases für manuellen Modus:**
- Notfall-Backup vor riskantem Vorgang
- Testen von DB-Änderungen mit Fallback-Option
- Migration zwischen verschiedenen Schemas

#### Erkennungslogik

```sql
-- Schnelle Prüfung auf lokale Daten
SELECT COUNT(*) 
FROM (SELECT 1 FROM games WHERE id > 50000000 LIMIT 1) AS t;

-- Ergebnis 1: Lokale Daten vorhanden → Automatisches Backup
-- Ergebnis 0: Keine lokalen Daten → Sauberes Deployment
```

#### Was wird bereinigt?

| Datentyp | Kriterium | Typische Anzahl | Grund |
|----------|-----------|-----------------|-------|
| `versions` | id > 50000000 | ~273.885 | Nicht auf lokalen Servern benötigt |
| `games` | id > 50000000 AND data IS NULL | ~5.019 | Unvollständig/korrupt |
| `game_participations` | Verwaist (Spiel nicht gefunden) | ~10.038 | Bezogen auf gelöschte Spiele |
| `table_monitors` | Verwaist (Spiel nicht gefunden) | ~25 | Bezogen auf gelöschte Spiele |
| `seedings` | Verwaist (Turnier nicht gefunden) | Variabel | Bezogen auf gelöschte Turniere |

#### Backup-Speicherort

```bash
# Backups werden hier gespeichert
scenarios/<scenario_name>/local_data_backups/
└── local_data_YYYYMMDD_HHMMSS.sql

# Beispiel
scenarios/carambus_location_5101/local_data_backups/
└── local_data_20241008_223119.sql (116 KB)
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
- ✅ **Automatische Lokale-Daten-Verwaltung (2024)** - Vollautomatische Sicherung/Wiederherstellung lokaler Daten
  - ✅ Automatische Erkennung (ID > 50.000.000)
  - ✅ Intelligente Bereinigung (99,99% Größenreduktion: 1,2 GB → 116 KB)
  - ✅ 99,95% Wiederherstellungs-Erfolgsrate (15.185 / 15.193 Datensätze)
  - ✅ Neue Rake Tasks: `backup_local_data`, `restore_local_data`
  - ✅ Integration in `prepare_deploy` und `bin/deploy-scenario.sh`
  - ✅ Manuelle Kontrolle verfügbar bei Bedarf

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