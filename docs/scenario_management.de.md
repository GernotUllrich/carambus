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

## Migration von Carambus2

**Neu ab Oktober 2025**: Automatische Schema-Migration für Server mit der alten Carambus2-Version.

### Überblick

Das System erkennt automatisch alte Carambus2-Datenbanken und migriert sie zum aktuellen Schema. Die Migration erfolgt **transparent während `prepare_development`** - keine manuellen Schritte erforderlich!

### Was wird migriert?

| Schema-Änderung | Aktion | Wert |
|----------------|--------|------|
| `region_id` Spalte fehlt | Spalte hinzufügen + Wert setzen | `1` (für lokale Daten) |
| `global_context` Spalte fehlt | Spalte hinzufügen + Wert setzen | `false` (für lokale Daten) |
| `users.role` ist TEXT | Konvertierung zu INTEGER | `0` (player) |

**Betroffene Tabellen:**
- `clubs`, `locations`, `players`, `tournaments`, `tournament_locals`
- `users`, `tables`, `table_locals`, `settings`
- `games`, `game_participations`, `seedings`, `versions`

### Automatischer Workflow

```
prepare_development[scenario_name,development]
        ↓
  Step 6.5: Schema-Migration
    ├─ Download old production DB
    ├─ Create temp local database
    ├─ Detect schema mismatches
    ├─ Add missing columns
    ├─ Update local records (id > 50M)
    └─ Extract migrated data
        ↓
  Step 8: Restore to Development
    ├─ Load migrated data
    └─ Ready for testing!
        ↓
  Development DB enthält jetzt:
    ✅ Official data (id < 50M)
    ✅ Migrated local data (id > 50M)
```

### Praktisches Beispiel

```bash
# Einmalige Migration von Carambus2 → Current
rake "scenario:prepare_development[carambus_bcw,development]"

# Was passiert automatisch:
# 1. Download old production database
# 2. Detect old schema (missing region_id, global_context columns)
# 3. Add missing columns to temp database
# 4. Update local records: region_id=1, global_context=false
# 5. Extract local data with NEW schema
# 6. Load into development database
# 7. Backup stored: local_data_20251021_204254.sql

# Ergebnis prüfen:
psql carambus_bcw_development -c "
  SELECT COUNT(*) FROM players WHERE id > 50000000 AND region_id = 1;
  -- Sollte alle migrierten Spieler zeigen
"
```

### Migration-Backup

Das migrierte Backup wird gespeichert und in `config.yml` referenziert:

```yaml
last_local_backup: "/path/to/scenarios/scenario_name/local_data_backups/local_data_TIMESTAMP.sql"
```

Dieses Backup ist **schema-kompatibel** und kann jederzeit wiederverwendet werden!

### Troubleshooting

**Problem**: Migration erkennt kein altes Schema
```bash
# Lösung: Manuell prüfen
psql old_database -c "
  SELECT column_name 
  FROM information_schema.columns 
  WHERE table_name='players' AND column_name='region_id';
"
# Leer = altes Schema → Migration wird durchgeführt
```

**Problem**: Migration schlägt fehl
```bash
# Lösung: Backup existiert bereits
ls scenarios/scenario_name/local_data_backups/
# Nutze existierendes Backup für Restore
```

### Wichtige Hinweise

⚠️ **Einmalige Migration**: Diese Feature ist für die **erste Migration** von Carambus2 → Current gedacht.  
✅ **Backward Compatible**: Funktioniert auch mit bereits migrierten Datenbanken.  
✅ **Non-Destructive**: Erstellt temporäre Datenbank, berührt Production nicht.  
✅ **Automatic Detection**: Erkennt automatisch ob Migration nötig ist.

## Raspberry Pi Table Clients (Multi-WLAN Setup)

**Neu ab Oktober 2025**: Vereinfachtes Multi-WLAN Setup für Tisch-Raspberry Pis mit automatischer Konfiguration.

### Überblick

Tisch-Raspberry Pis müssen in **zwei verschiedenen WLANs** funktionieren:
- **Büro/Development WLAN** (192.168.178.x) - Vorbereitung und Testing mit DHCP
- **Club/Production WLAN** (192.168.2.x) - Produktiveinsatz mit statischer IP

Das neue Setup-Script `bin/setup-table-raspi.sh` konfiguriert automatisch beide Netzwerke!

### Konfigurationsquellen

Das Script liest Konfiguration aus **drei Quellen**:

#### 1. Club-WLAN (config.yml)

```yaml
production:
  network:
    club_wlan:
      ssid: "WLAN-BCW-CLUB"
      password: "club_passwort"
      priority: 20
      gateway: "192.168.2.1"
      subnet: "192.168.2.0/24"
```

#### 2. Dev-WLAN (~/.carambus_config)

```bash
# Development/Office WLAN Configuration (nicht committed!)
CARAMBUS_DEV_WLAN_SSID="DEIN_BÜRO_WLAN"
CARAMBUS_DEV_WLAN_PASSWORD="büro_passwort"
CARAMBUS_DEV_WLAN_PRIORITY=10
```

#### 3. Statische IP (Datenbank)

```sql
-- IP-Adresse wird aus table_locals geholt
SELECT ip_address FROM table_locals 
WHERE table_id = (SELECT id FROM tables WHERE name = 'Tisch 2');
-- Ergebnis: 192.168.2.212
```

### Vereinfachte Verwendung

```bash
# Nur 3 Parameter benötigt!
./bin/setup-table-raspi.sh carambus_bcw 192.168.178.81 "Tisch 2"

# Das Script holt automatisch:
# ✅ Club-WLAN aus config.yml
# ✅ Dev-WLAN aus ~/.carambus_config
# ✅ Statische IP (192.168.2.212) aus Datenbank
# ✅ Server-URL aus config.yml
# ✅ Location MD5 aus Datenbank
```

### Was wird konfiguriert?

**Multi-WLAN (wpa_supplicant.conf)**:
```
network={
    ssid="BÜRO_WLAN"
    psk="***"
    priority=10      # Niedrigere Priorität
}

network={
    ssid="CLUB_WLAN"
    psk="***"
    priority=20      # Höhere Priorität (bevorzugt!)
}
```

**Netzwerk-Konfiguration**:
- **Dev-WLAN**: DHCP (flexible IP, wechselt bei jedem Neustart)
- **Club-WLAN**: Statische IP aus Datenbank (192.168.2.212)

**Scoreboard-Client**:
- Chromium Kiosk-Modus (ohne Sandbox-Warnung!)
- Automatischer Start via systemd
- Schneller Start (~18 Sekunden)
- Sidebar automatisch geschlossen

### Automatisches WLAN-Switching

Der Raspberry Pi wählt automatisch das verfügbare WLAN:

```
┌─ Im Büro ─────────────────┐     ┌─ Im Club ─────────────────┐
│ BÜRO_WLAN verfügbar       │     │ CLUB_WLAN verfügbar       │
│ ├─ Verbindet zu Priorität │     │ ├─ Verbindet zu Priorität │
│ │  10 (niedrig)           │     │ │  20 (hoch)              │
│ ├─ Verwendet DHCP         │     │ ├─ Verwendet Static IP    │
│ └─ IP: 192.168.178.81     │     │ └─ IP: 192.168.2.212      │
│ Server: 192.168.178.107   │     │ Server: 192.168.178.107   │
└───────────────────────────┘     └───────────────────────────┘
```

### Workflow: Tisch-Raspi vorbereiten

```bash
# 1. Konfiguration vorbereiten
#    a) ~/.carambus_config: DEV_WLAN Settings
#    b) config.yml: Club WLAN + Passwort
#    c) Datenbank: table_local.ip_address für den Tisch

# 2. Raspberry Pi im Büro-WLAN identifizieren
./bin/find-raspberry-pi.sh
# Ergebnis z.B.: 192.168.178.81

# 3. Multi-WLAN Setup ausführen
./bin/setup-table-raspi.sh carambus_bcw 192.168.178.81 "Tisch 2"

# 4. Testen im Büro
ssh pi@192.168.178.81 'sudo systemctl status scoreboard-kiosk'
# Scoreboard sollte im Browser laufen

# 5. Raspberry Pi in den Club bringen und einschalten
#    → Verbindet automatisch zu Club-WLAN
#    → Nutzt statische IP: 192.168.2.212
#    → Scoreboard startet automatisch

# 6. Verifizieren im Club
ping 192.168.2.212
ssh pi@192.168.2.212 'sudo systemctl status scoreboard-kiosk'
```

### Unterstützte Netzwerk-Manager

**NetworkManager** (bevorzugt auf Debian Trixie):
- Verwendet `nmcli` für Konfiguration
- Separate Connection-Profile pro WLAN
- Sauberes Switching zwischen Netzwerken

**dhcpcd** (ältere Raspberry Pi OS):
- Verwendet dhcpcd.conf + hooks
- SSID-spezifische IP-Konfiguration
- Automatische Anwendung beim Verbinden

### Voraussetzungen

**Datenbank**:
```sql
-- Table muss existieren mit table_local
SELECT t.name, tl.ip_address 
FROM tables t
JOIN table_locals tl ON t.id = tl.table_id
WHERE t.location_id = 1;

-- Beispiel:
-- Tisch 2 | 192.168.2.212
```

**WLAN-Credentials**:
- Club-WLAN Passwort in `config.yml` setzen
- Dev-WLAN in `~/.carambus_config` konfigurieren (optional)

**SSH-Zugriff**:
- Raspberry Pi muss über aktuelle IP erreichbar sein
- Standard: `pi@192.168.178.81` Port 22

### Troubleshooting

**WLAN verbindet nicht**:
```bash
# Auf dem Raspberry Pi prüfen
ssh pi@<current_ip> 'sudo wpa_cli status'
ssh pi@<current_ip> 'sudo wpa_cli list_networks'

# WLAN neu scannen
ssh pi@<current_ip> 'sudo wpa_cli scan && sudo wpa_cli scan_results'
```

**Falsche IP nach Reboot**:
```bash
# NetworkManager: Connection prüfen
ssh pi@<current_ip> 'nmcli connection show'

# dhcpcd: Hook prüfen
ssh pi@<current_ip> 'cat /etc/dhcpcd.exit-hook'
```

**Scoreboard startet nicht**:
```bash
# Service-Status prüfen
ssh pi@<ip> 'sudo systemctl status scoreboard-kiosk'

# Logs ansehen
ssh pi@<ip> 'sudo journalctl -u scoreboard-kiosk -n 50'

# Browser-Log prüfen
ssh pi@<ip> 'tail -50 /tmp/chromium-kiosk.log'
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
- ✅ **Carambus2 Migration (Oktober 2025)** - Automatische Schema-Migration
  - ✅ Automatische Erkennung alter Carambus2-Schemas
  - ✅ Transparente Migration während `prepare_development`
  - ✅ Fügt fehlende Spalten hinzu (region_id, global_context)
  - ✅ Konvertiert users.role von TEXT zu INTEGER
  - ✅ Nicht-destruktiv (verwendet temporäre Datenbank)
  - ✅ Schema-kompatibles Backup für Wiederverwendung
- ✅ **Multi-WLAN Table Client Setup (Oktober 2025)** - Vereinfachtes Raspberry Pi Setup
  - ✅ Automatisches Multi-WLAN mit Prioritäts-basiertem Failover
  - ✅ Dev-WLAN mit DHCP (Büro-Testing)
  - ✅ Club-WLAN mit statischer IP aus Datenbank
  - ✅ Vereinfachter Aufruf (nur Scenario, IP, Tischname)
  - ✅ WLAN-Credentials aus config.yml und ~/.carambus_config
  - ✅ NetworkManager + dhcpcd Support
  - ✅ Schneller Startup (~18s statt ~45s)
  - ✅ Optimierte Chromium-Flags (keine Sandbox-Warnung)
  - ✅ Sidebar automatisch geschlossen bei Scoreboard-URLs

🔄 **In Arbeit**:
- Weitere Location-Scenarios

📋 **Geplant**:
- Automatisierte Tests
- Performance-Monitoring

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