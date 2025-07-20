# Carambus Entwicklerleitfaden

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Architektur](#architektur)
3. [Erste Schritte](#erste-schritte)
4. [Datenbankdesign](#datenbankdesign)
5. [Kern-Models](#kern-models)
6. [Hauptfunktionen](#hauptfunktionen)
7. [Entwicklungsworkflow](#entwicklungsworkflow)
8. [Deployment](#deployment)
9. [Mitwirken](#mitwirken)

## Übersicht

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
Siehe [Scoreboard Autostart Setup](scoreboard_autostart_setup.md) für detaillierte Konfiguration.

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

### Produktions-Setup
Die Anwendung ist für den Einsatz auf Raspberry Pi oder ähnlicher Hardware konzipiert:

#### Systemanforderungen
- **Hardware**: Raspberry Pi 4 (4GB RAM empfohlen)
- **OS**: Raspberry Pi OS (32-bit)
- **Datenbank**: PostgreSQL 11+
- **Web-Server**: Nginx + Puma

#### Deployment-Prozess
1. **Server-Setup**: Siehe [Runbook](doc/doc/Runbook) für detaillierte Server-Konfiguration
2. **Anwendungs-Deployment**: Capistrano-basiertes Deployment
3. **Service-Management**: Systemd-Services für Autostart
4. **Scoreboard-Setup**: Automatisierter Scoreboard-Start

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
- [Datenbankdesign](database_design.md): Detailliertes Datenbankschema
- [Scoreboard-Setup](scoreboard_autostart_setup.md): Scoreboard-Konfiguration
- [Turnierverwaltung](tournament.md): Turnier-Workflows
- [Datenverwaltung](data_management.md): Datenbehandlungsmuster

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