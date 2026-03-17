# Carambus Entwicklerleitfaden

## Inhaltsverzeichnis

1. [Übersicht](#uebersicht)
2. [Architektur](#architektur)
3. [Erste Schritte](#erste-schritte)
4. [Datenbank-Setup](#datenbank-setup)
5. [Datenbankdesign](#datenbankdesign)
6. [Kern-Models](#kern-models)
7. [Hauptfunktionen](#hauptfunktionen)
8. [Entwicklungsworkflow](#entwicklungsworkflow)
9. [Deployment](#deployment)
10. [Mitwirken](#mitwirken)

## Übersicht {#uebersicht}

Carambus ist ein umfassendes Billard-Turnierverwaltungssystem, das mit Ruby on Rails entwickelt wurde. Es bietet eine vollständige Automatisierung der Billard-Betriebsabläufe von der Turnierplanung bis zur Datenerfassung und Ergebnisübertragung.

### Hauptfunktionen
- **Turnierverwaltung**: Vollständige Turnierlebenszyklus-Verwaltung
- **Echtzeit-Scoreboards**: Live-Scoreboard-Anzeigen mit WebSocket-Unterstützung
- **Ligaverwaltung**: Team-basierte Ligaorganisation
- **Datensynchronisation**: Integration mit externen Billard-Datenbanken (BA/CC)
- **Mehrsprachige Unterstützung**: Deutsche und englische Benutzeroberflächen
- **Responsive Design**: Funktioniert auf Desktop- und Mobilgeräten

### Technologie-Stack
- **Backend**: Ruby on Rails 7.2
- **Datenbank**: PostgreSQL
- **Frontend**: Hotwire (Turbo + Stimulus) + Stimulus Reflex
- **Echtzeit**: Action Cable mit Redis
- **Authentifizierung**: Devise
- **Autorisierung**: Pundit + CanCanCan
- **Admin-Interface**: Administrate
- **Deployment**: Capistrano + Puma

## Architektur

### Rails-Struktur
Carambus folgt den Standard-Rails-Konventionen mit einigen Anpassungen:

```
app/
├── controllers/          # RESTful Controller
├── models/              # ActiveRecord Models mit Concerns
├── views/               # ERB Templates
├── javascript/          # Stimulus Controller und Utilities
├── channels/            # Action Cable Channels
├── jobs/                # Hintergrund-Jobs
├── services/            # Geschäftslogik-Services
└── helpers/             # View Helper
```

### Wichtige Architekturmuster

#### Concerns
Die Anwendung verwendet Rails Concerns, um Funktionalität zu teilen:

- `LocalProtector`: Schützt lokale Daten vor externen Änderungen
- `SourceHandler`: Verwaltet externe Datensynchronisation
- `RegionTaggable`: Behandelt regionsbasierte Datenorganisation

#### Echtzeit-Funktionen
- **Action Cable**: WebSocket-Verbindungen für Live-Updates
- **Stimulus Reflex**: Server-seitige Reflexe für reaktive UI
- **Cable Ready**: Client-seitige DOM-Manipulation

## Erste Schritte

### Voraussetzungen
- Ruby 3.2+ (siehe `.ruby-version`)
- PostgreSQL 11+
- Redis 5+
- Node.js 14+ (für Asset-Kompilierung)

### Installation

1. **Repository klonen**
   ```bash
   git clone <repository-url>
   cd carambus
   ```

2. **Abhängigkeiten installieren**
   ```bash
   bundle install
   yarn install
   ```

3. **Datenbank einrichten**
   ```bash
   cp config/database.yml.example config/database.yml
   # database.yml mit Ihren PostgreSQL-Zugangsdaten bearbeiten
   
   # Option 1: Bestehenden Datenbank-Dump importieren (empfohlen)
   # Stellen Sie sicher, dass Sie eine Datenbank-Dump-Datei haben (z.B., carambus_api_development_YYYYMMDD_HHMMSS.sql)
   # Datenbank erstellen und Dump importieren:
   createdb carambus_development
   psql -d carambus_development -f /pfad/zu/ihrem/dump.sql
   
   # Option 2: Neue Datenbank erstellen (falls kein Dump verfügbar)
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Umgebungskonfiguration**
   ```bash
   cp config/application.yml.example config/application.yml
   # application.yml mit Ihrer Konfiguration bearbeiten
   ```

5. **Anwendung starten**
   ```bash
   rails server
   ```

### Entwicklungstools

#### Code-Qualität
- **RuboCop**: Code-Stil-Erzwingung
- **Standard**: Ruby-Code-Formatierung
- **Brakeman**: Sicherheitslücken-Scanning
- **Overcommit**: Git-Hooks für Code-Qualität

#### Testing
- **RSpec**: Unit- und Integrationstests
- **Capybara**: Systemtests
- **Factory Bot**: Test-Daten-Factories

## Datenbank-Setup {#datenbank-setup}

Für die Einrichtung einer neuen Entwicklungsdatenbank wird empfohlen, einen bestehenden Datenbank-Dump zu importieren. Detaillierte Anweisungen finden Sie in der separaten Dokumentation:

**[🗄️ Datenbank-Setup Anleitung](../administrators/database-setup.md)**

### Schnellstart
```bash
# Datenbank erstellen
createdb carambus_development

# Dump importieren
psql -d carambus_development -f /pfad/zu/ihrem/dump.sql
```

### Erwartete Fehler
Beim Import können folgende Fehler auftreten, die ignoriert werden können:
- `relation "table_name" already exists` - Tabelle existiert bereits
- `multiple primary keys for table "table_name" are not allowed` - Primärschlüssel bereits definiert
- `relation "index_name" already exists` - Index existiert bereits
- `constraint "constraint_name" for relation "table_name" already exists` - Constraint bereits definiert

Diese Fehler sind normal, wenn die Datenbank bereits teilweise initialisiert wurde.

## Datenbankdesign

### Kern-Models

#### Seeding Model (Doppelzweck)
Das `Seeding` Model dient zwei verschiedenen Zwecken:

1. **Team-Kader-Verwaltung**
   - Verbunden mit `LeagueTeam` über `league_team_id`
   - Verwaltet den vollständigen Spielerkader für ein Ligateam
   - Wird während der initialen Liga/Team-Einrichtung erstellt

2. **Spiel-Teilnahme-Verfolgung**
   - Verbunden mit `Party` über polymorphic `tournament_id`
   - Verfolgt, welche Spieler an bestimmten Spielen teilnehmen
   - Wird beim Einrichten einzelner Spiele erstellt

```ruby
class Seeding < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :league_team, optional: true
  include LocalProtector
  include SourceHandler
  include RegionTaggable
end
```

#### Party und LeagueTeam Beziehung
```ruby
class Party < ApplicationRecord
  belongs_to :league_team_a, class_name: "LeagueTeam"
  belongs_to :league_team_b, class_name: "LeagueTeam"
  belongs_to :host_league_team, class_name: "LeagueTeam"
  has_many :seedings, as: :tournament
  include LocalProtector
  include SourceHandler
end
```

### Datenspeicherungsmuster

#### Flexible Datenspeicherung
Mehrere Models verwenden serialisierte Spalten für flexible Datenspeicherung:

```ruby
# JSON Serialisierung
serialize :data, coder: JSON, type: Hash
# Verwendet in: Party, Seeding, LeagueTeam

# YAML Serialisierung  
serialize :remarks, coder: YAML, type: Hash
# Verwendet in: Party
```

#### Regions-Tagging-System
Das `RegionTaggable` Concern bietet intelligente Regions-Behandlung:

```ruby
# Automatisches Regions-Tagging basierend auf Kontext
when Seeding
  if tournament_id.present?
    # Turnier-basiertes Regions-Tagging
    tournament ? [
      tournament.region_id,
      (tournament.organizer_type == "Region" ? tournament.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  elsif league_team_id.present?
    # Liga-Team-basiertes Regions-Tagging
    league_team&.league ? [
      (league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  end
```

## Kern-Models

### Turnierverwaltung
- **Tournament**: Haupt-Turnier-Entität
- **Discipline**: Spieltypen (z.B. 3-Banden, 1-Bande)
- **Player**: Einzelne Spieler
- **Seeding**: Turnier-Teilnahme und Ranglisten

### Ligaverwaltung
- **League**: Liga-Organisation
- **LeagueTeam**: Teams innerhalb von Ligen
- **Party**: Einzelne Spiele zwischen Teams
- **Season**: Liga-Saisons

### Standortverwaltung
- **Location**: Billard-Clubs/Standorte
- **Table**: Einzelne Billard-Tische
- **TableMonitor**: Echtzeit-Tischüberwachung
- **TableLocal**: Lokale Tisch-Konfigurationen

### Benutzerverwaltung
- **User**: Systembenutzer mit Devise-Authentifizierung
- **Role**: Benutzerrollen und Berechtigungen
- **Admin**: Administratives Interface über Administrate

## Hauptfunktionen

### Echtzeit-Scoreboards
Das Scoreboard-System bietet Live-Updates für Turnier-Anzeigen:

#### Komponenten
- **Tisch-Monitor**: Echtzeit-Spielverfolgung
- **Scoreboard-Anzeige**: Öffentliche Scoreboard-Ansichten
- **WebSocket-Integration**: Live-Updates über Action Cable

#### Einrichtung
Siehe [Scoreboard-Setup](../administrators/scoreboard-autostart.md) für detaillierte Konfiguration.

### Datensynchronisation
Integration mit externen Billard-Datenbanken:

#### Externe Quellen
- **BA (Billard-Verband)**: Offizielle Spieler- und Turnierdaten
- **CC (Competition Center)**: Wettkampf-Management-System

#### Synchronisationsprozess
1. Externe Daten werden über API abgerufen
2. Lokale Daten sind vor externen Änderungen geschützt
3. Regions-Tagging wird automatisch angewendet
4. Konflikte werden basierend auf Quellen-Priorität gelöst

### Turnier-Workflows

#### Turnier-Erstellung
1. Turnier mit Disziplin und Einstellungen erstellen
2. Teilnehmer definieren (Spieler/Teams)
3. Spielpläne generieren
4. Turnier mit Echtzeit-Überwachung starten

#### Spiel-Management
1. Spiele planen (Parties)
2. Live-Spielfortschritt verfolgen
3. Ergebnisse und Ranglisten aufzeichnen
4. Berichte und Statistiken generieren

## Entwicklungsworkflow

### Code-Stil
Das Projekt verwendet Standard Ruby für Code-Formatierung:

```bash
# Code formatieren
bundle exec standardrb --fix

# Auf Probleme prüfen
bundle exec standardrb
```

### Git-Workflow
1. Feature-Branch von main erstellen
2. Änderungen mit Tests vornehmen
3. Code-Qualitätsprüfungen ausführen
4. Pull Request einreichen

### Testing
```bash
# Alle Tests ausführen
rails test

# Bestimmte Test-Datei ausführen
rails test test/models/tournament_test.rb

# Systemtests ausführen
rails test:system
```

### Datenbank-Migrationen
```bash
# Migration generieren
rails generate migration AddFieldToModel

# Migrationen ausführen
rails db:migrate

# Zurückrollen
rails db:rollback
```

## Deployment

### Scenario Management System
Carambus verwendet ein **Scenario Management System** für die Verwaltung verschiedener Deployment-Umgebungen und Konfigurationen:

#### Hauptfunktionen
- ✅ **Scenario-basierte Konfiguration** mit YAML-basierten Konfigurationsdateien
- ✅ **Automatische Konfigurationsgenerierung** aus ERB-Templates
- ✅ **Intelligente Update-Mechanismen** (Development vs. Deploy vs. Update)
- ✅ **Konflikt-Analyse** und interaktive Auflösung bei Deployment-Konflikten
- ✅ **Parallele Deployments** mehrerer Scenarios auf demselben Server
- ✅ **Idempotente Operationen** für wiederholbare Deployments
- ✅ **RubyMine-Integration** mit .idea-Konfiguration
- ✅ **Region-Filtering** für optimierte Datenbank-Dumps
- ✅ **Template-basierte Datenbank-Transformation** für carambus-Scenario

#### Task-Matrix: Code-Sektionen vs. Rake-Tasks

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

*✅* = Uses this code section  
*❌* = Doesn't use this code section  
*✅** = Uses this code section conditionally (only if Rails root doesn't exist)

#### Database Flow Explanation

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

#### Database Flow Diagram

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
    │ 3. Upload configs to server        │
    │ 4. Create systemd service          │
    │ 5. Create Nginx config             │
    └─────────────────────────────────────┘
                    ↓
carambus_scenarioname_production (on server)
                    ↓
    ┌─────────────────────────────────────┐
    │ deploy                             │
    │ 1. Transfer & load database dump   │
    │ 2. Standard Capistrano deployment  │
    │ 3. Start Puma service              │
    └─────────────────────────────────────┘
```

#### Task-Übersicht

##### Haupt-Tasks (Empfohlen für normale Nutzung)

**`scenario:prepare_development[scenario_name,environment]`**
- **Zweck**: Lokale Development-Umgebung einrichten
- **Schritte**: Config-Generierung → DB-Dump-Erstellung → Rails Root → Basic Config Files
- **Perfekt für**: Lokale Entwicklung, Scenario-Testing

**`scenario:prepare_deploy[scenario_name]`**
- **Zweck**: Vollständige Deployment-Vorbereitung (inklusive Server-Setup)
- **Schritte**: Production Config → DB-Restore → Rails Root → All Config Files → Credentials → Deploy Files → Server-Setup → systemd-Service → Nginx-Config
- **Perfekt für**: Vollständige Deployment-Vorbereitung, Blank-Server-Setup

**`scenario:deploy[scenario_name]`**
- **Zweck**: Standard Capistrano-Deployment (nach Server-Setup)
- **Schritte**: Database Transfer → Standard Capistrano Deploy → Start Services
- **Perfekt für**: Production-Deployment (nach prepare_deploy), Standard-Deployment

##### Reparatur-Tasks (Für gezielte Reparaturen)

**`scenario:create_rails_root[scenario_name]`**
- **Zweck**: Nur Rails Root Folder erstellen
- **Enthält**: Git Clone, .idea-Kopie, Verzeichnis-Setup

**`scenario:generate_configs[scenario_name,environment]`**
- **Zweck**: Nur Konfigurationsdateien generieren
- **Enthält**: ERB-Template-Verarbeitung für alle Config-Files

**`scenario:create_database_dump[scenario_name,environment]`**
- **Zweck**: Nur Datenbank-Dump erstellen
- **Enthält**: Region-Filtering, Template-Transformation (carambus), Optimierte DB-Erstellung

**`scenario:restore_database_dump[scenario_name,environment]`**
- **Zweck**: Nur Datenbank-Dump wiederherstellen
- **Enthält**: DB-Drop/Create, Dump-Restore, Sequence-Reset

#### Verfügbare Scenarios
- **carambus**: Hauptproduktionsumgebung (carambus.de)
- **carambus_api**: API-Server (api.carambus.de)
- **carambus_location_2459**: PHAT Consulting Location
- **carambus_location_2460**: Test-Location
- **carambus_location_5101**: Weitere Test-Location

#### Schnellstart
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

#### Erweiterte Nutzung
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

#### Code-Duplikation und Refactoring

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
- ✅ **Logische Trennung**: Development vs. Deploy vs. Repair Tasks
- ✅ **Intuitive Nutzung**: Jeder Task hat einen klaren, nicht überlappenden Zweck

**Refactoring-Vorteile:**
- **Wartbarkeit**: Weniger Code, weniger Bugs
- **Verständlichkeit**: Klare Task-Zwecke ohne Verwirrung
- **Flexibilität**: Granulare Kontrolle über einzelne Schritte
- **Zuverlässigkeit**: Idempotente Operationen, keine Abhängigkeitsfehler

**[🚀 Vollständige Scenario Management Dokumentation](scenario-management.md)**

### Produktions-Setup
Die Anwendung ist für den Einsatz auf Raspberry Pi oder ähnlicher Hardware konzipiert:

#### Systemanforderungen
- **Hardware**: Raspberry Pi 4 (4GB RAM empfohlen)
- **OS**: Raspberry Pi OS (32-bit)
- **Datenbank**: PostgreSQL 11+
- **Web-Server**: Nginx + Puma

#### Deployment-Prozess
1. **Server-Setup**: Siehe [Runbook](../developers/developer-guide.de.md#operations) für detaillierte Server-Konfiguration
2. **Scenario Management**: Verwenden Sie das Scenario Management System für Deployment-Konfiguration
3. **Anwendungs-Deployment**: Capistrano-basiertes Deployment
4. **Service-Management**: Systemd-Services für Autostart
5. **Scoreboard-Setup**: Automatisierter Scoreboard-Start

### Konfigurationsdateien

#### Datenbank-Konfiguration
```yaml
# config/database.yml
production:
  adapter: postgresql
  database: carambus_production
  host: localhost
  username: www_data
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

#### Anwendungs-Konfiguration
```yaml
# config/application.yml
defaults: &defaults
  database_url: postgresql://www_data:password@localhost/carambus_production
  redis_url: redis://localhost:6379/0
  secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
```

### Service-Management
```bash
# Anwendung starten
sudo systemctl start carambus

# Autostart aktivieren
sudo systemctl enable carambus

# Status prüfen
sudo systemctl status carambus
```

## Mitwirken

### Entwicklungsumgebung
1. Folgen Sie dem [Erste Schritte](#erste-schritte) Leitfaden
2. Pre-commit-Hooks einrichten: `bundle exec overcommit --install`
3. Machen Sie sich mit dem [Datenbankdesign](#datenbankdesign) vertraut

### Code-Beiträge
1. **Repository forken**
2. **Feature-Branch erstellen**
3. **Änderungen vornehmen**
4. **Tests für neue Funktionalität hinzufügen**
5. **Sicherstellen, dass alle Tests bestehen**
6. **Pull Request einreichen**

### Dokumentation
- Relevante Dokumentation bei Hinzufügen von Features aktualisieren
- Code-Beispiele für neue APIs einschließen
- Konfigurationsänderungen dokumentieren

### Test-Richtlinien
- Tests für alle neue Funktionalität schreiben
- Test-Abdeckung über 80% halten
- Integrationstests für komplexe Workflows einschließen
- Sowohl deutsche als auch englische Locales testen

### Code-Review-Prozess
1. Alle Änderungen erfordern Code-Review
2. Automatisierte Prüfungen müssen bestehen
3. Manuelles Testing auf Staging-Umgebung
4. Dokumentations-Updates nach Bedarf

## Zusätzliche Ressourcen

### Dokumentation
- [Datenbankdesign](database-design.md): Detailliertes Datenbankschema
- [Scoreboard-Setup](../administrators/scoreboard-autostart.md): Scoreboard-Konfiguration
- [Turnierverwaltung](../managers/tournament-management.md): Turnier-Workflows
- [Installationsübersicht](../administrators/installation-overview.md): Installationsübersicht
- [Scenario Management](scenario-management.md): Deployment-Konfiguration und Multi-Environment-Support

### Externe Links
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Dokumentation](https://hotwired.dev/)
- [Stimulus Reflex](https://docs.stimulusreflex.com/)
- [Action Cable](https://guides.rubyonrails.org/action_cable_overview.html)

### Support
- **Issues**: Verwenden Sie GitHub Issues für Bug-Reports und Feature-Requests
- **Diskussionen**: GitHub Discussions für Fragen und Ideen
- **Dokumentation**: Dokumentation mit Änderungen aktuell halten

---

*Diese Dokumentation wird vom Carambus-Entwicklungsteam gepflegt. Für Fragen oder Beiträge siehe den [Mitwirken](#mitwirken) Abschnitt.* 