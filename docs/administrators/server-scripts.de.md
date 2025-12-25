# Server Management Scripts

Diese Dokumentation beschreibt alle verfügbaren Scripts für die Verwaltung von Carambus-Servern (Development, Production, API).

## Überblick

Die Server Management Scripts befinden sich in `carambus_master/bin/` und decken folgende Bereiche ab:
- **Development Server**: Lokale Entwicklungsumgebung starten/verwalten
- **Production Server**: Service-Management (Puma, Nginx)
- **Rails Console**: Datenbank-Zugriff und Debugging
- **Asset Management**: JavaScript/CSS neu bauen
- **Utilities**: Setup, Restart, Cleanup

---

## Development Server

### `start-api-server.sh`
**Zweck**: Startet den API-Server (Development-Mode)

**Verwendung**:
```bash
cd carambus_master
./bin/start-api-server.sh
```

**Was wird gemacht**:
1. ✅ Prüft, ob Port 3000 frei ist
2. ✅ Startet Puma-Server für carambus_api
3. ✅ Lädt Development-Konfiguration
4. ✅ Aktiviert Live-Reload

**Voraussetzungen**:
- `carambus_api_development` Datenbank existiert
- Dependencies installiert (`bundle install`)
- Assets kompiliert

**Zugriff**:
```
http://localhost:3000
```

---

### `start-local-server.sh`
**Zweck**: Startet einen lokalen Scenario-Server (Development-Mode)

**Verwendung**:
```bash
./bin/start-local-server.sh <scenario_name>
```

**Was wird gemacht**:
1. ✅ Wechselt in Scenario-Verzeichnis
2. ✅ Liest Port aus `config.yml`
3. ✅ Startet Puma mit Scenario-spezifischer Config
4. ✅ Aktiviert StimulusReflex/ActionCable

**Beispiele**:
```bash
# Startet carambus_location_5101 auf Port 3003
./bin/start-local-server.sh carambus_location_5101

# Startet carambus_bcw auf Port 3007  
./bin/start-local-server.sh carambus_bcw
```

**Voraussetzungen**:
- Scenario mit `prepare_development` vorbereitet
- `config.yml` existiert mit `webserver_port`

---

### `start-both-servers.sh`
**Zweck**: Startet API-Server und lokalen Server gleichzeitig

**Verwendung**:
```bash
./bin/start-both-servers.sh <scenario_name>
```

**Was wird gemacht**:
- Startet API-Server (Port 3000) im Hintergrund
- Startet Scenario-Server (Port aus config.yml)
- Beide Server laufen parallel

**Use Cases**:
- Vollständiges lokales Testing
- API-Sync-Testing
- Development mit mehreren Scenarios

**Beispiel**:
```bash
./bin/start-both-servers.sh carambus_location_5101
# API verfügbar: http://localhost:3000
# Location verfügbar: http://localhost:3003
```

**Stop**pen:
```bash
# Beide Server beenden
pkill -f puma
```

---

## Production Server Management

### `manage-puma.sh`
**Zweck**: Verwaltet Puma-Service auf Production-Server

**Verwendung**:
```bash
# Auf dem Server:
./bin/manage-puma.sh [start|stop|restart|status]

# Remote via SSH:
ssh -p 8910 www-data@192.168.178.107 'cd /var/www/carambus_location_5101/current && ./bin/manage-puma.sh restart'
```

**Aktionen**:
- `start`: Startet Puma-Service
- `stop`: Stoppt Puma-Service sauber
- `restart`: Stoppt und startet neu (verwendet von Capistrano)
- `status`: Zeigt Service-Status

**Was wird gemacht**:
1. ✅ Prüft systemd-Service-Status
2. ✅ Führt Aktion aus
3. ✅ Wartet auf Service-Start
4. ✅ Verifiziert Socket/PID

**Wichtig**: Wird automatisch von Capistrano aufgerufen, manuelle Nutzung selten nötig.

---

### `manage-puma-api.sh`
**Zweck**: Verwaltet Puma-Service für API-Server

**Verwendung**:
```bash
./bin/manage-puma-api.sh [start|stop|restart|status]
```

**Gleiche Funktionalität wie `manage-puma.sh`, speziell für API-Server**

---

### `restart-carambus.sh`
**Zweck**: Quick-Restart für Carambus-Server

**Verwendung**:
```bash
# Lokal
./bin/restart-carambus.sh

# Remote
ssh -p 8910 www-data@192.168.178.107 '/var/www/carambus_location_5101/current/bin/restart-carambus.sh'
```

**Was wird gemacht**:
1. ✅ Stoppt Puma-Service
2. ✅ Bereinigt PIDs/Sockets
3. ✅ Startet Service neu
4. ✅ Wartet auf Erfolg

**Use Cases**:
- Code-Änderungen ohne Capistrano deployen
- Nach Konfigurationsänderungen
- Schneller Restart bei Problemen

---

## Rails Console

### `console-api.sh`
**Zweck**: Öffnet Rails Console für API-Server

**Verwendung**:
```bash
./bin/console-api.sh
```

**Was wird gemacht**:
- Wechselt zu carambus_api
- Startet Rails Console (Development)
- Lädt alle Models/Helpers

**Beispiel-Session**:
```ruby
# Script starten
./bin/console-api.sh

# In der Console:
> Player.count
=> 69082

> Version.last.id
=> 12227261

> Setting.find_by(key: 'last_version_id').value
=> "12227261"
```

---

### `console-local.sh`
**Zweck**: Öffnet Rails Console für lokales Scenario

**Verwendung**:
```bash
./bin/console-local.sh <scenario_name>
```

**Beispiele**:
```bash
# Scenario-Console öffnen
./bin/console-local.sh carambus_location_5101

# Lokale Daten prüfen
> Game.where('id > 50000000').count
=> 28

> TableLocal.count
=> 10
```

---

### `console-production.sh`
**Zweck**: Öffnet Rails Console auf Production-Server

**Verwendung**:
```bash
./bin/console-production.sh <scenario_name>
```

**Was wird gemacht**:
- SSH zu Production-Server
- Wechselt in Deployment-Verzeichnis
- Startet Rails Console (Production)

**⚠️ WARNUNG**: Production-Console! Vorsicht bei Änderungen!

**Beispiel**:
```bash
# Production-Console öffnen
./bin/console-production.sh carambus_location_5101

# Vorsichtig! Production-Daten!
> Rails.env
=> "production"

> Game.count
=> 280163
```

**Best Practice**:
- Niemals destruktive Operationen ohne Backup
- Nur lesende Operationen für Debugging
- Für Änderungen: Migration erstellen

---

## Asset Management

### `rebuild_js.sh`
**Zweck**: JavaScript-Assets neu kompilieren

**Verwendung**:
```bash
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh
```

**Was wird gemacht**:
1. ✅ `yarn build` (esbuild)
2. ✅ `yarn build:css` (TailwindCSS)
3. ✅ `rails assets:precompile` (Sprockets)

**Use Cases**:
- Nach JavaScript-Änderungen
- Nach CSS-Änderungen
- Asset-Build-Fehler beheben

**Beispiel**:
```bash
# JavaScript geändert, neu bauen
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# Entwicklungsserver neustarten
./bin/start-local-server.sh carambus_location_5101
```

---

### `cleanup_rails.sh`
**Zweck**: Rails-Cache und temporäre Dateien bereinigen

**Verwendung**:
```bash
./bin/cleanup_rails.sh
```

**Was wird gemacht**:
- Löscht `tmp/cache/`
- Löscht `.sprockets-cache/`
- Löscht `log/*.log` (optional)
- Bereinigt Asset-Cache

**Use Cases**:
- Asset-Probleme beheben
- Speicherplatz freigeben
- Nach großen Code-Änderungen

---

### `cleanup_versions.sh`
**Zweck**: Bereinigt alte Version-Einträge

**Verwendung**:
```bash
./bin/cleanup_versions.sh [--dry-run]
```

**Was wird gemacht**:
- Löscht Versions-Einträge älter als X Tage
- Behält letzte N Versionen
- Optional: Nur Anzeige (--dry-run)

**⚠️ WARNUNG**: Nur auf lokalen Servern verwenden! Nicht auf API-Server!

---

## Debug & Testing

### `debug-production.sh`
**Zweck**: Debugging-Informationen von Production sammeln

**Verwendung**:
```bash
./bin/debug-production.sh <scenario_name>
```

**Was wird gesammelt**:
1. ✅ Service-Status (Puma, Nginx)
2. ✅ Log-Dateien (letzten 100 Zeilen)
3. ✅ Database-Status
4. ✅ Disk-Space
5. ✅ Memory-Usage
6. ✅ Process-Liste

**Output**:
```bash
./bin/debug-production.sh carambus_location_5101

=== Service Status ===
puma-carambus_location_5101.service: active (running)
nginx.service: active (running)

=== Logs (last 100 lines) ===
[...]

=== Database ===
Games: 280163
Players: 63972
Tournaments: 16748

=== Resources ===
Disk: 45% used
Memory: 678M / 8G
```

---

## Setup & Installation

### `carambus-install.sh`
**Zweck**: Komplette Carambus-Installation auf neuem Server

**Verwendung**:
```bash
./bin/carambus-install.sh
```

**Was wird installiert**:
1. ✅ System-Dependencies (Ruby, Node, PostgreSQL)
2. ✅ Nginx + SSL
3. ✅ Redis (für ActionCable)
4. ✅ Git + SSH-Keys
5. ✅ Deployment-User (www-data)
6. ✅ Verzeichnis-Struktur

**Voraussetzungen**:
- Frisches Ubuntu/Debian-System
- Root-Zugriff
- Internet-Verbindung

**Dauer**: ~30 Minuten

---

### `setup-local-dev.sh`
**Zweck**: Lokale Development-Umgebung einrichten

**Verwendung**:
```bash
./bin/setup-local-dev.sh
```

**Was wird gemacht**:
1. ✅ Prüft System-Dependencies
2. ✅ Installiert Ruby-Gems (`bundle install`)
3. ✅ Installiert Node-Packages (`yarn install`)
4. ✅ Erstellt lokale Datenbank
5. ✅ Lädt Seed-Daten
6. ✅ Kompiliert Assets

---

### `generate-ssl-cert.sh`
**Zweck**: SSL-Zertifikate für Development/Testing generieren

**Verwendung**:
```bash
./bin/generate-ssl-cert.sh [domain]
```

**Was wird gemacht**:
- Generiert selbst-signiertes Zertifikat
- Erstellt Private Key
- Speichert in `ssl/` Verzeichnis

**Use Cases**:
- Lokales HTTPS-Testing
- Development mit SSL-Features
- Scoreboard-Testing mit sicherer Verbindung

**Beispiel**:
```bash
# Zertifikat für localhost
./bin/generate-ssl-cert.sh localhost

# Zertifikat für Custom-Domain
./bin/generate-ssl-cert.sh carambus.local
```

---

## Legacy/Deprecated Scripts

### `deploy.sh` ⚠️
**Status**: Obsolet (durch `deploy-scenario.sh` ersetzt)  
**Grund**: Altes Deployment-System ohne Scenario-Support

### `deploy-to-raspberry-pi.sh` ⚠️
**Status**: Obsolet (durch `deploy-scenario.sh` ersetzt)  
**Grund**: Integriert in neues Scenario-System

### `puma-wrapper.sh` ⚠️
**Status**: Obsolet (durch `manage-puma.sh` ersetzt)  
**Grund**: Veraltete Service-Management-Logik

### `sync-carambus-folders.sh` ⚠️
**Status**: Obsolet  
**Grund**: Durch Git-Workflow ersetzt

---

## Workflow-Beispiele

### Lokale Development-Session starten

```bash
# 1. Development-Umgebung vorbereiten
rake "scenario:prepare_development[carambus_location_5101,development]"

# 2. Assets bauen
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# 3. Server starten
cd ../carambus_master
./bin/start-both-servers.sh carambus_location_5101

# API: http://localhost:3000
# Location: http://localhost:3003
```

### Code-Änderung deployen (vollständig)

```bash
# 1. Code committen
git add .
git commit -m "Feature: XYZ"
git push carambus master

# 2. Scenario aktualisieren
rake "scenario:update[carambus_location_5101]"

# 3. Assets neu bauen
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# 4. Deployen
cd ../carambus_master
./bin/deploy-scenario.sh carambus_location_5101

# 5. Browser auf RasPi neustarten
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'
```

### Quick-Fix ohne komplettes Deployment

```bash
# 1. Kleine Änderung committen
git commit -am "Fix: typo"
git push carambus master

# 2. Auf Production-Server pullen
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
git pull

# 3. Server neustarten
./bin/restart-carambus.sh
exit

# 4. Browser neustarten
ssh -p 8910 www-data@192.168.178.107 './bin/restart-scoreboard.sh'
```

### Debugging Production-Problem

```bash
# 1. Debug-Infos sammeln
./bin/debug-production.sh carambus_location_5101 > debug.log

# 2. Logs prüfen
less debug.log

# 3. Console öffnen (falls nötig)
./bin/console-production.sh carambus_location_5101

# 4. Quick-Fix anwenden
ssh -p 8910 www-data@192.168.178.107 'sudo systemctl restart puma-carambus_location_5101'
```

---

## Fehlerbehebung

### Puma startet nicht

```bash
# Problem: "Address already in use"
# Lösung: Alte Prozesse beenden
ssh -p 8910 www-data@192.168.178.107
pkill -9 puma
rm /var/www/carambus_location_5101/shared/pids/*.pid
rm /var/www/carambus_location_5101/shared/sockets/*.sock
./bin/manage-puma.sh start
```

### Assets fehlen nach Deployment

```bash
# Problem: "Asset not found"
# Lösung: Assets neu kompilieren
cd carambus_location_5101
../carambus_master/bin/rebuild_js.sh

# Auf Server:
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
RAILS_ENV=production bundle exec rails assets:precompile
./bin/restart-carambus.sh
```

### Datenbank-Verbindung schlägt fehl

```bash
# Problem: "could not connect to server"
# Lösung: PostgreSQL-Service prüfen
ssh -p 8910 www-data@192.168.178.107
sudo systemctl status postgresql
sudo systemctl start postgresql

# Config prüfen
cat /var/www/carambus_location_5101/shared/config/database.yml
```

### Memory-Probleme

```bash
# Problem: "Cannot allocate memory"
# Lösung: Memory-Analyse und Cleanup
./bin/debug-production.sh carambus_location_5101 | grep Memory

# Cache bereinigen
ssh -p 8910 www-data@192.168.178.107
cd /var/www/carambus_location_5101/current
./bin/cleanup_rails.sh

# Services neustarten
sudo systemctl restart puma-carambus_location_5101
```

---

## Best Practices

### Development
1. ✅ Immer beide Server starten für vollständiges Testing
2. ✅ Nach Asset-Änderungen `rebuild_js.sh` ausführen
3. ✅ Console nutzen für schnelle Datenbank-Checks
4. ✅ Regelmäßig `cleanup_rails.sh` ausführen

### Production
1. ✅ Niemals manuell Puma starten/stoppen (Capistrano nutzen)
2. ✅ Console nur für Debugging, nicht für Daten-Änderungen
3. ✅ Bei Problemen: Zuerst `debug-production.sh` ausführen
4. ✅ Logs regelmäßig prüfen

### Deployment
1. ✅ Vollständiges Deployment: `deploy-scenario.sh`
2. ✅ Quick-Fixes: Nur bei Notfällen
3. ✅ Nach Deployment: Browser auf RasPi neustarten
4. ✅ Vor Deployment: Lokales Testing durchführen

---

## Monitoring & Wartung

### Tägliche Checks

```bash
# Service-Status
ssh -p 8910 www-data@192.168.178.107 'systemctl status puma-carambus_location_5101'

# Disk-Space
ssh -p 8910 www-data@192.168.178.107 'df -h'

# Logs (Fehler)
ssh -p 8910 www-data@192.168.178.107 'tail -100 /var/www/carambus_location_5101/current/log/production.log | grep ERROR'
```

### Wöchentliche Wartung

```bash
# 1. Rails-Cache bereinigen
ssh -p 8910 www-data@192.168.178.107 'cd /var/www/carambus_location_5101/current && ./bin/cleanup_rails.sh'

# 2. Logs rotieren
ssh -p 8910 www-data@192.168.178.107 'sudo logrotate -f /etc/logrotate.d/carambus'

# 3. Disk-Space prüfen
./bin/debug-production.sh carambus_location_5101 | grep "Disk:"
```

### Monatliche Wartung

```bash
# 1. System-Updates
ssh -p 8910 www-data@192.168.178.107
sudo apt update && sudo apt upgrade -y

# 2. Ruby/Node/Gems aktualisieren
cd /var/www/carambus_location_5101/current
bundle update
yarn upgrade

# 3. Services neustarten
sudo systemctl restart puma-carambus_location_5101
sudo systemctl restart nginx
```

---

## Siehe auch

- [Deployment Workflow](../developers/deployment-workflow.de.md) - Vollständiger Deployment-Prozess
- [Scenario Management](../developers/scenario-management.de.md) - Scenario-System-Übersicht  
- [Raspberry Pi Scripts](raspberry_pi_scripts.de.md) - RasPi-Client-Management
- [Database Syncing](../developers/database-partitioning.de.md) - Datenbank-Synchronisation






