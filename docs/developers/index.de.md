# Entwickler-Dokumentation

Willkommen zur Carambus-Entwickler-Dokumentation! Hier finden Sie alle technischen Informationen für die Entwicklung, Erweiterung und den Beitrag zum Projekt.

## 🎯 Für Entwickler

Als Entwickler finden Sie hier:
- 🚀 **Getting Started**: Entwicklungsumgebung aufsetzen
- 🏗️ **Architektur**: System-Design und Komponenten
- 💾 **Datenbank**: Schema, Modelle, Optimierungen
- 🔌 **API**: REST-API und WebSocket-Integration
- 🧪 **Testing**: Test-Framework und Best Practices
- 📦 **Deployment**: Deployment-Workflows und Automatisierung
- 🤝 **Contribution**: Wie Sie zum Projekt beitragen können

## 🚀 Schnellstart für neue Entwickler

### 1. Entwicklungsumgebung einrichten (15-30 Minuten)

**Voraussetzungen**:
- Ruby 3.2+
- Rails 7.2+
- PostgreSQL 14+
- Node.js 18+ & Yarn
- Git

**Setup-Schritte**:
```bash
# Repository klonen
git clone https://github.com/GernotUllrich/carambus.git
cd carambus

# Dependencies installieren
bundle install
yarn install

# Datenbank einrichten
rails db:create
rails db:migrate
rails db:seed  # Testdaten

# Assets kompilieren
yarn build
yarn build:css

# Server starten
rails server
```

➡️ **[Detaillierte Getting-Started-Anleitung](getting-started.md)**

### 2. Erste Schritte (30 Minuten)

1. **Code-Struktur erkunden**: `app/`, `config/`, `db/`
2. **Entwicklerhandbuch lesen**: Conventions und Patterns
3. **Tests ausführen**: `rails test` oder `rspec`
4. **Erste Änderung**: Kleine Verbesserung implementieren
5. **Pull Request**: Contribution einreichen

➡️ **[Developer Guide](developer-guide.md)**

## 📚 Hauptthemen

### 1. Getting Started

**Entwicklungsumgebung**:
- Ruby, Rails, PostgreSQL installieren
- Repository setup
- Credentials konfigurieren
- Erste Schritte

➡️ **[Getting Started für Entwickler](getting-started.md)**

### 2. Architektur & Design

**System-Übersicht**:
- MVC-Architektur (Rails)
- Hotwire/Turbo für SPA-ähnliches UX
- Stimulus für JavaScript-Sprinkles
- Action Cable für WebSockets
- Background Jobs mit Sidekiq/Solid Queue

**Design Patterns**:
- Service Objects
- Form Objects
- Presenters/Decorators
- Repository Pattern (teilweise)

➡️ **[Developer Guide - Architektur](developer-guide.de.md#architektur)**

### 3. Datenbank

**Schema & Modelle**:
- ER-Diagramm
- Kern-Modelle (Tournament, Game, Player, etc.)
- Associations
- Validations
- Scopes

**Optimierungen**:
- Indizes
- Query-Optimierung
- N+1-Problem vermeiden
- Caching-Strategien

➡️ **[Datenbankdesign](database-design.md)**  
➡️ **[ER-Diagramm](er-diagram.md)**

### 4. API & Integration

**REST API**:
- Endpoints
- Authentifizierung (Token-based)
- Versionierung
- Rate Limiting

**WebSocket (Action Cable)**:
- Channels
- Broadcasting
- Client-Integration
- Troubleshooting

➡️ **[API-Referenz](../reference/API.md)**

### 5. Frontend-Entwicklung

**Technologie-Stack**:
- **Hotwire**: Turbo Drive, Turbo Frames, Turbo Streams
- **Stimulus**: JavaScript-Controller
- **Tailwind CSS**: Utility-First CSS
- **ViewComponent**: Komponenten-basiertes UI

**Asset Pipeline**:
- esbuild für JavaScript
- Tailwind für CSS
- Build-Prozess

➡️ **[Developer Guide - Frontend](developer-guide.de.md#frontend)**

### 6. Setup & Konfiguration

**Entwicklungsumgebung**:
- Development-Logging konfigurieren
- Email/SMTP-Setup (Gmail)
- AI-Suche einrichten
- Credentials verwalten

➡️ **[AI-Suche Setup](setup/ai-search-setup.md)**  
➡️ **[Development Logging](setup/development-logging.md)**  
➡️ **[Email-Konfiguration](setup/email-configuration.md)**

### 7. Debugging & Troubleshooting

**Debugging-Tools**:
- WebSocket-Logging aktivieren
- Puma-Socket-Probleme beheben
- Log-Analyse
- Performance-Profiling

➡️ **[WebSocket Logging](debugging/websocket-logging.md)**  
➡️ **[Puma Socket Troubleshooting](debugging/puma-socket-troubleshooting.md)**

### 8. Testing

**Test-Framework**:
- Minitest (Standard) oder RSpec
- System Tests (Capybara)
- Integration Tests
- Unit Tests

**Test-Pläne**:
- Feature-Test-Pläne
- Integrationstests
- Manuelle Test-Checklisten

➡️ **[AI-Suche Test-Plan](testing/ai-search-test-plan.md)**  
➡️ **[Admin Settings Test-Plan](testing/admin-settings-test-plan.md)**

**Coverage**:
- SimpleCov für Code-Coverage
- Ziel: > 80% Coverage

### 9. Operations & Security

**Produktionsbetrieb**:
- Scraper-Schutz konfigurieren
- Turnier-/Spiel-Schutz
- IP-Whitelisting/-Blacklisting
- Sicherheitsfeatures

➡️ **[Scraper-Protection](operations/scraper-protection.md)**  
➡️ **[Scraper-Protection Advanced](operations/scraper-protection-advanced.md)**  
➡️ **[Tournament Game Protection](operations/tournament-game-protection.md)**

**Best Practices**:
- TDD/BDD
- Fixtures vs. Factories
- Mocking & Stubbing

➡️ **[Testing & Debugging](rake-tasks-debugging.md)**

### 7. Deployment & DevOps

**Deployment-Strategien**:
- Capistrano (klassisch)
- Docker (containerized)
- Kamal (Rails 7.2+)

**CI/CD**:
- GitHub Actions
- Automatische Tests
- Deployment-Pipeline

**Scenario Management**:
- Multi-Environment Setup
- Deployment-Scripts

➡️ **[Deployment Workflow](deployment-workflow.md)**  
➡️ **[Scenario Management](scenario-management.md)**

### 8. Performance & Optimierung

**Monitoring**:
- Performance-Metriken
- N+1-Query-Detection
- Memory Profiling
- WebSocket-Health

**Optimierungen**:
- Database-Optimierung
- Caching (Fragment, Action, Russian Doll)
- Asset-Optimierung
- Background Jobs

➡️ **[Paper Trail Optimization](paper-trail-optimization.md)**

### 9. Datenverwaltung

**Migrations**:
- Schema-Änderungen
- Data Migrations
- Rollback-Strategien

**Seeding**:
- Test-Daten
- Production-Seeds

**Partitionierung**:
- Database-Partitioning
- Sharding-Strategien

➡️ **[Datenverwaltung](data-management.md)**  
➡️ **[Datenbank-Partitionierung](database-partitioning.md)**

## 🏗️ Projekt-Struktur

```
carambus/
├── app/
│   ├── channels/          # Action Cable Channels
│   ├── controllers/       # MVC Controllers
│   ├── helpers/           # View Helpers
│   ├── javascript/        # Stimulus Controllers
│   ├── jobs/              # Background Jobs
│   ├── mailers/           # Email Mailer
│   ├── models/            # ActiveRecord Models
│   ├── policies/          # Pundit Authorization
│   ├── services/          # Service Objects
│   └── views/             # ERB Templates
├── config/
│   ├── credentials/       # Encrypted Credentials
│   ├── deploy/            # Capistrano Config
│   ├── environments/      # Environment Configs
│   ├── initializers/      # Rails Initializers
│   ├── locales/           # I18n Translations
│   ├── database.yml       # DB Config
│   ├── routes.rb          # URL Routing
│   └── tailwind.config.js # Tailwind Config
├── db/
│   ├── migrate/           # Database Migrations
│   ├── seeds/             # Seed Data
│   └── schema.rb          # Current Schema
├── lib/
│   ├── assets/            # Non-standard Assets
│   ├── tasks/             # Rake Tasks
│   └── capistrano/        # Capistrano Extensions
├── public/                # Static Assets
├── test/ (oder spec/)     # Tests
├── docs/                  # Documentation (mkdocs)
└── bin/                   # Executables & Scripts
```

## 🔧 Wichtige Rake-Tasks

```bash
# Datenbank
rails db:create              # DB anlegen
rails db:migrate             # Migrationen ausführen
rails db:seed                # Test-Daten laden
rails db:reset               # DB neu aufsetzen

# Assets
yarn build                   # JavaScript kompilieren
yarn build:css               # CSS kompilieren
rails assets:precompile      # Assets für Production

# Tests
rails test                   # Alle Tests
rails test:system            # System Tests
rails test TEST=test/models/tournament_test.rb  # Einzelner Test

# Scenarios (Multi-Environment)
rake scenario:list           # Verfügbare Scenarios
rake scenario:prepare[bcw]   # Scenario vorbereiten
rake scenario:deploy[bcw]    # Scenario deployen

# Maintenance
rails log:clear              # Logs löschen
rails tmp:clear              # Tmp-Dateien löschen
rails restart                # Server neu starten (Touch tmp/restart.txt)

# Custom Tasks
rails clubcloud:sync         # ClubCloud-Daten synchronisieren
rails tournament:reconstruct # Spielplan rekonstruieren
```

➡️ **[Rake Tasks & Debugging](rake-tasks-debugging.md)**

## 💻 Entwickler-Workflows

### Feature-Entwicklung

1. **Branch erstellen**:
   ```bash
   git checkout -b feature/mein-feature
   ```

2. **Entwickeln**:
   - Code schreiben
   - Tests schreiben
   - Lokal testen

3. **Commit**:
   ```bash
   git add .
   git commit -m "feat: Beschreibung des Features"
   ```

4. **Push & PR**:
   ```bash
   git push origin feature/mein-feature
   # GitHub: Pull Request erstellen
   ```

5. **Review & Merge**:
   - Code Review abwarten
   - Feedback einarbeiten
   - Nach Approval: Merge

### Bug-Fix

1. **Issue erstellen** (falls nicht vorhanden)
2. **Branch**: `bugfix/issue-123-beschreibung`
3. **Fix implementieren & testen**
4. **Commit**: `fix: #123 - Beschreibung`
5. **PR mit Link zu Issue**

### Testing-Workflow

```bash
# Während Entwicklung
rails test                    # Alle Tests
rails test:watch              # Tests bei Änderung (Guard)

# Vor Commit
rails test                    # Sicherstellen: Alles grün
rubocop                       # Linter
brakeman                      # Security-Audit

# CI/CD prüft automatisch
```

## 🎨 Code-Style & Conventions

### Ruby Style Guide

Wir folgen der [Ruby Style Guide](https://rubystyle.guide/):
- 2 Spaces Indentation
- Snake_case für Methoden und Variablen
- CamelCase für Klassen und Module
- SCREAMING_SNAKE_CASE für Konstanten

**Linter**: RuboCop
```bash
rubocop                      # Alle Files prüfen
rubocop --auto-correct       # Auto-Fix
```

### JavaScript/Stimulus

- **Stimulus-Controller**: `data-controller="tournament"`
- **Actions**: `data-action="click->tournament#start"`
- **Targets**: `data-tournament-target="score"`

### CSS/Tailwind

- Utility-First: Tailwind-Klassen bevorzugen
- Komponenten nur bei Wiederverwendung
- Responsive: Mobile-First

### Naming Conventions

**Modelle**: Singular, z.B. `Tournament`, `Game`, `Player`  
**Controller**: Plural, z.B. `TournamentsController`  
**Views**: Plural-Ordner, z.B. `app/views/tournaments/`  
**Partials**: Unterstrich-Präfix, z.B. `_game_card.html.erb`

## 🧪 Testing Best Practices

### Unit Tests (Modelle)

```ruby
# test/models/tournament_test.rb
class TournamentTest < ActiveSupport::TestCase
  test "should not save tournament without name" do
    tournament = Tournament.new
    assert_not tournament.save
  end
  
  test "should calculate correct standings" do
    tournament = tournaments(:one)
    standings = tournament.standings
    assert_equal 5, standings.first.points
  end
end
```

### Integration Tests (Controller)

```ruby
# test/controllers/tournaments_controller_test.rb
class TournamentsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tournaments_url
    assert_response :success
  end
  
  test "should create tournament" do
    assert_difference('Tournament.count') do
      post tournaments_url, params: { tournament: { name: "Test" } }
    end
    assert_redirected_to tournament_url(Tournament.last)
  end
end
```

### System Tests (E2E)

```ruby
# test/system/tournaments_test.rb
class TournamentsTest < ApplicationSystemTestCase
  test "creating a tournament" do
    visit tournaments_url
    click_on "New tournament"
    
    fill_in "Name", with: "Test Tournament"
    click_on "Create Tournament"
    
    assert_text "Tournament was successfully created"
  end
end
```

## 🤝 Contribution Guidelines

### Wie kann ich beitragen?

1. **Issues**: Bugs melden, Features vorschlagen
2. **Discussions**: Fragen stellen, Ideen diskutieren
3. **Pull Requests**: Code-Beiträge
4. **Dokumentation**: Docs verbessern
5. **Testing**: Edge-Cases testen

### Pull Request Prozess

1. **Fork** das Repository
2. **Branch** erstellen: `feature/beschreibung`
3. **Entwickeln** mit Tests
4. **Commit** mit aussagekräftigen Messages
5. **Push** zu deinem Fork
6. **PR erstellen** mit Beschreibung
7. **Review** abwarten und Feedback einarbeiten

### Commit Messages

Wir nutzen [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: Add snooker scoreboard
fix: #123 - Correct calculation of GD
docs: Update installation guide
refactor: Extract service object for game creation
test: Add integration tests for tournament creation
chore: Update dependencies
```

**Typen**:
- `feat`: Neues Feature
- `fix`: Bug-Fix
- `docs`: Dokumentation
- `style`: Code-Formatierung
- `refactor`: Code-Refactoring
- `test`: Tests
- `chore`: Maintenance

## 📚 Wichtige Ressourcen

### Interne Dokumentation

- **[Getting Started](getting-started.md)**: Entwicklungsumgebung
- **[Developer Guide](developer-guide.md)**: Umfassendes Entwicklerhandbuch
- **[Database Design](database-design.md)**: Datenbank-Schema
- **[ER-Diagramm](er-diagram.md)**: Visuelle Datenbankübersicht
- **[API Reference](../reference/API.md)**: API-Dokumentation
- **[Deployment Workflow](deployment-workflow.md)**: Deployment-Prozesse
- **[Scenario Management](scenario-management.md)**: Multi-Environment
- **[Testing & Debugging](rake-tasks-debugging.md)**: Test-Strategien

### Externe Ressourcen

**Rails**:
- [Rails Guides](https://guides.rubyonrails.org/)
- [Rails API Docs](https://api.rubyonrails.org/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)

**Hotwire**:
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)

**Testing**:
- [Minitest Docs](https://github.com/minitest/minitest)
- [Capybara](https://github.com/teamcapybara/capybara)

**PostgreSQL**:
- [PostgreSQL Docs](https://www.postgresql.org/docs/)

## 🔗 Alle Entwickler-Dokumente

1. **[Getting Started](getting-started.md)** - Entwicklungsumgebung einrichten
2. **[Developer Guide](developer-guide.md)** - Umfassendes Entwicklerhandbuch
3. **[Database Design](database-design.md)** - Datenbank-Schema und Modelle
4. **[ER-Diagramm](er-diagram.md)** - Visuelle Datenbankübersicht
5. **[API Reference](../reference/API.md)** - REST-API Dokumentation
6. **[Scenario Management](scenario-management.md)** - Multi-Environment Setup
7. **[Testing & Debugging](rake-tasks-debugging.md)** - Test-Strategien
8. **[Deployment Workflow](deployment-workflow.md)** - Deployment-Prozesse
9. **[Server Management Scripts](../administrators/server-scripts.md)** - Automatisierungs-Scripts
10. **[Raspberry Pi Scripts](../administrators/raspberry_pi_scripts.md)** - RasPi-spezifische Tools
11. **[Data Management](data-management.md)** - Datenverwaltung
12. **[Database Partitioning](database-partitioning.md)** - Partitionierungs-Strategien
13. **[Paper Trail Optimization](paper-trail-optimization.md)** - Audit-Log-Performance
14. **[Game Plan Reconstruction](game-plan-reconstruction.md)** - Spielplan-Algorithmen
15. **[Tournament Duplicates](tournament-duplicate-handling.md)** - Duplikat-Handling
16. **[Region Tagging](region-tagging-cleanup-summary.md)** - Geografische Zuordnung
17. **[ClubCloud Upload System](clubcloud-upload.md)** - Automatischer Upload & CSV-Export
18. **[YouTube Streaming Architecture](streaming-architecture.md)** - Live-Streaming System (Architektur, FFmpeg, Hardware)
19. **[YouTube Streaming Development Setup](streaming-dev-setup.md)** - Entwicklungsumgebung für Streaming (SSH-Keys, Custom Port)

---

**Happy Coding! 💻**

*Wir freuen uns auf Ihre Beiträge! Bei Fragen: gernot.ullrich@gmx.de oder GitHub Discussions.*




