# Scenario Management System

Das Scenario Management System ermöglicht es, verschiedene Deployment-Umgebungen (Scenarios) für Carambus zu verwalten und automatisch zu deployen.

## Überblick

Das System unterstützt verschiedene Szenarien wie:
- **carambus**: Hauptproduktionsumgebung
- **carambus_api**: API-Server
- **carambus_location_5101**: Lokale Server-Instanz für Standort 5101
- **carambus_location_2459**: Lokale Server-Instanz für Standort 2459
- **carambus_location_2460**: Lokale Server-Instanz für Standort 2460

## Task-Matrix: Code-Sektionen vs. Rake-Tasks

| Code Section | `prepare_development` | `prepare_deploy` | `deploy` | `create_rails_root` | `generate_configs` | `create_database_dump` | `restore_database_dump` |
|--------------|----------------------|------------------|----------|-------------------|-------------------|----------------------|------------------------|
| **Load scenario config** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Create Rails root folder** | ✅* | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Generate development config files** | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Copy basic config files** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Create dev DB from template** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Apply region filtering** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Set last_version_id** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Reset version sequence (50000000+)** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Create database dump** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **Generate production config files** | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Copy production config files** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Copy credentials/master.key** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Copy deployment files** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Create production DB from dump** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Server operations** | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |

*✅* = Verwendet diese Code-Sektion  
*❌* = Verwendet diese Code-Sektion nicht  
*✅** = Verwendet diese Code-Sektion bedingt (nur wenn Rails Root nicht existiert)

## Database Flow Explanation

**Source Database**: `carambus_api_development` (mother of all API databases)

**Development Flow** (`prepare_development`):
1. **Create dev DB from template**: `carambus_scenarioname_development` ← `carambus_api_development` (using `--template`)
2. **Apply region filtering**: Remove non-region data (reduces ~500MB to ~90MB)
3. **Set last_version_id**: Update settings with current max version ID for sync tracking
4. **Reset version sequence**: Set versions_id_seq to 50,000,000+ for local server (prevents ID conflicts with API)
5. **Create database dump**: Save the processed development database

**Production Flow** (`prepare_deploy` → `deploy`):
1. **Create production DB from dump**: Create `carambus_scenarioname_production` by loading development dump
2. **Server operations**: Upload config + Capistrano deployment

**Key Insight**: The development database is the "processed" version (template + filtering + sequences), and production is created from this processed version.

## Database Flow Diagram

```
carambus_api_development (mother database)
                    ↓
    ┌─────────────────────────────────────┐
    │ prepare_development                 │
    │ 1. Create dev DB from template      │
    │ 2. Apply region filtering           │
    │ 3. Set last_version_id              │
    │ 4. Reset version sequence (50000000+)│
    │ 5. Create database dump            │
    └─────────────────────────────────────┘
                    ↓
carambus_scenarioname_development (processed)
                    ↓
    ┌─────────────────────────────────────┐
    │ prepare_deploy                     │
    │ 1. Create production DB from dump  │
    │ 2. Copy production configs         │
    └─────────────────────────────────────┘
                    ↓
carambus_scenarioname_production (on server)
                    ↓
    ┌─────────────────────────────────────┐
    │ deploy                             │
    │ 1. Upload configs to server        │
    │ 2. Capistrano deployment           │
    └─────────────────────────────────────┘
```

## Haupt-Tasks (Empfohlen für normale Nutzung)

### `scenario:prepare_development[scenario_name,environment]`
**Zweck**: Lokale Development-Umgebung einrichten

**Schritte**:
1. Generiert Konfigurationsdateien für das angegebene Environment
2. Erstellt Datenbank-Dump (frisch aus Development)
3. Stellt sicher, dass Rails Root Folder existiert (erstellt wenn nötig)
4. Kopiert grundlegende Config-Dateien (database.yml, carambus.yml)

**Perfekt für**: Lokale Entwicklung, Scenario-Testing

### `scenario:prepare_deploy[scenario_name]`
**Zweck**: Deployment-Vorbereitung (ohne Server-Operationen)

**Schritte**:
1. Generiert Production-Konfigurationsdateien
2. Stellt Datenbank-Dump wieder her (aus Development mit Region-Filtering)
3. Stellt sicher, dass Rails Root Folder existiert (erstellt wenn nötig)
4. Kopiert alle Production-Konfigurationsdateien (nginx.conf, puma.rb, puma.service)
5. Kopiert Credentials und master.key
6. Kopiert Deployment-Dateien (deploy.rb, deploy/production.rb)

**Perfekt für**: Lokale Deployment-Vorbereitung, Config-Testing

### `scenario:deploy[scenario_name]`
**Zweck**: Server-Deployment (nur Capistrano-Deployment)

**Schritte**: Nur Server-Operationen:
- Upload von shared Konfigurationsdateien auf Server
- Ausführung von Capistrano-Deployment

**Perfekt für**: Production-Deployment (nach prepare_deploy)

## Reparatur-Tasks (Für gezielte Reparaturen)

### `scenario:create_rails_root[scenario_name]`
**Zweck**: Nur Rails Root Folder erstellen

**Enthält**: Git Clone, .idea-Kopie, Verzeichnis-Setup

### `scenario:generate_configs[scenario_name,environment]`
**Zweck**: Nur Konfigurationsdateien generieren

**Enthält**: ERB-Template-Verarbeitung für alle Config-Files

### `scenario:create_database_dump[scenario_name,environment]`
**Zweck**: Nur Datenbank-Dump erstellen

**Enthält**: Region-Filtering, Template-Transformation (carambus), Optimierte DB-Erstellung

### `scenario:restore_database_dump[scenario_name,environment]`
**Zweck**: Nur Datenbank-Dump wiederherstellen

**Enthält**: DB-Drop/Create, Dump-Restore, Sequence-Reset

## Schnellstart

```bash
# Lokale Development-Umgebung einrichten
rake "scenario:prepare_development[carambus_location_2459,development]"

# Für Deployment vorbereiten (ohne Server-Operationen)
rake "scenario:prepare_deploy[carambus_location_2459]"

# Server-Deployment ausführen
rake "scenario:deploy[carambus_location_2459]"

# Scenario aktualisieren (nur Git Pull, behält lokale Änderungen)
rake "scenario:update[carambus_location_2459]"
```

## Erweiterte Nutzung

```bash
# Nur Konfigurationsdateien neu generieren
rake "scenario:generate_configs[carambus_location_2459,development]"

# Nur Datenbank-Dump erstellen (mit Region-Filtering)
rake "scenario:create_database_dump[carambus_location_2459,development]"

# Nur Datenbank-Dump wiederherstellen
rake "scenario:restore_database_dump[carambus_location_2459,development]"

# Nur Rails Root Folder erstellen
rake "scenario:create_rails_root[carambus_location_2459]"
```

## Code-Duplikation und Refactoring

Das Scenario Management System wurde 2024 umfassend refaktoriert, um Code-Duplikation zu eliminieren:

**Vorher (Problematisch):**
- `scenario:setup` und `scenario:setup_with_rails_root` waren redundant
- `scenario:deploy` erwartete existierenden Rails Root Folder
- ~150 Zeilen duplizierter Code zwischen verschiedenen Tasks
- Verwirrende Task-Namen und überlappende Funktionalitäten

**Nachher (Optimiert):**
- ✅ **Klare Task-Hierarchie**: `prepare_development` → `prepare_deploy` → `deploy`
- ✅ **Bedingte Rails Root Erstellung**: Alle Tasks erstellen Rails Root automatisch wenn nötig
- ✅ **Eliminierte Duplikation**: ~150 Zeilen weniger Code
- ✅ **Logische Trennung**: Development vs. Deploy vs. Server Tasks
- ✅ **Intuitive Nutzung**: Jeder Task hat einen klaren, nicht überlappenden Zweck
- ✅ **Unabhängige Tasks**: `prepare_deploy` wiederholt nicht `prepare_development`
- ✅ **Fokussierte Deployments**: `deploy` macht nur Server-Operationen

**Refactoring-Vorteile:**
- **Wartbarkeit**: Weniger Code, weniger Bugs
- **Verständlichkeit**: Klare Task-Zwecke ohne Verwirrung
- **Flexibilität**: Granulare Kontrolle über einzelne Schritte
- **Zuverlässigkeit**: Idempotente Operationen, keine Abhängigkeitsfehler

## Scenario-Konfiguration

Jedes Scenario wird durch eine `config.yml` Datei definiert:

```yaml
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

## Technische Details

### Datenbank-Transformationen

Das System führt automatisch verschiedene Datenbank-Transformationen durch:

#### carambus-Scenario
- **Optimierte DB-Erstellung**: Verwendet `--template=carambus_api_development` (viel schneller)
- **Version-Sequenz-Reset**: `setval('versions_id_seq', 1, false)`
- **Settings-Update**: 
  - `last_version_id` auf 1 setzen
  - `scenario_name` auf "carambus" setzen

#### Location-Scenarios (z.B. carambus_location_5101)
- **Region-Filtering**: Läuft `cleanup:remove_non_region_records` mit `ENV['REGION_SHORTNAME'] = 'NBV'`
- **Optimierte Dump-Größe**: Reduziert von ~500MB auf ~90MB
- **Temporäre DB**: Erstellt temp DB, wendet Filtering an, erstellt Dump, bereinigt

### Template-System

Alle Konfigurationsdateien werden aus ERB-Templates generiert:

- `database.yml.erb`
- `carambus.yml.erb`
- `nginx.conf.erb`
- `puma.rb.erb`
- `puma.service.erb`
- `deploy.rb.erb`

### Deployment-Automatisierung

Das System führt vollständig automatisiert aus:

1. **Konfigurationsgenerierung** (Production)
2. **Datenbank-Dump-Erstellung** (mit Transformation)
3. **Rails Root Folder** (bedingt erstellt)
4. **Konfigurationsdateien kopieren**
5. **Deployment-Dateien kopieren**
6. **Shared Konfigurationsdateien auf Server uploaden**
7. **Capistrano-Deployment ausführen**
8. **SSL-Zertifikat-Setup** (Let's Encrypt)
9. **Puma-Service-Konfiguration** (Unix-Sockets)
10. **Nginx-Konfiguration-Update** (Unix-Socket-Proxy)
11. **Version.sequence_reset** auf dem Server

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
- **Refactoriertes Task-System** (2024) - Eliminierte Code-Duplikation

🔄 **In Arbeit**:
- GitHub-Zugriff für Raspberry Pi
- Production-Datenbank-Setup

📋 **Geplant**:
- Mode-Switch-System deaktivieren
- Automatisierte Tests
- Weitere Location-Scenarios