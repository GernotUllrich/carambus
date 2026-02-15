# 🏗️ Test-Architektur für Carambus

Dieses Dokument beschreibt die Struktur und Architektur des Test-Systems.

## 🎯 Design-Prinzipien

### 1. Pragmatismus über Perfektion
- Tests für kritische Funktionalität
- Kein 100% Coverage-Zwang
- Fokus auf Wertschöpfung

### 2. Snapshot-basiert für External APIs
- VCR für HTTP Interactions
- Strukturänderungen werden automatisch erkannt
- Tests laufen offline und schnell

### 3. API-Datenbank als Basis
- Realistische Test-Daten
- Echte Beziehungen
- Authentische Edge Cases

## 📐 Architektur-Übersicht

```
┌─────────────────────────────────────────────────────────────┐
│                    Test Infrastructure                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Minitest   │  │     VCR      │  │  SimpleCov   │    │
│  │   (Rails)    │  │  (Snapshots) │  │  (Coverage)  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   WebMock    │  │ FactoryBot   │  │   Capybara   │    │
│  │ (HTTP Mock)  │  │  (Builders)  │  │   (System)   │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Test Helpers                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  test/support/                                              │
│  ├── vcr_setup.rb           # VCR Konfiguration           │
│  ├── scraping_helpers.rb    # Scraping Utilities          │
│  └── snapshot_helpers.rb    # Snapshot Vergleiche         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        Test Types                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ Unit Tests (60% der Tests)                        │    │
│  │                                                    │    │
│  │  • Concerns (LocalProtector, SourceHandler)       │    │
│  │  • Models (Business Logic)                        │    │
│  │  • Services (Complex Operations)                  │    │
│  │                                                    │    │
│  │  Fokus: Einzelne Komponenten, isoliert           │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ Snapshot Tests (25% der Tests)                    │    │
│  │                                                    │    │
│  │  • ClubCloud Scraping                             │    │
│  │  • Change Detection                               │    │
│  │  • HTML Structure Validation                      │    │
│  │                                                    │    │
│  │  Fokus: External API Integration mit VCR          │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ Integration Tests (10% der Tests)                 │    │
│  │                                                    │    │
│  │  • Scraping → Sync → Storage                      │    │
│  │  • Tournament Workflow                            │    │
│  │  • Multi-Component Interactions                   │    │
│  │                                                    │    │
│  │  Fokus: Zusammenspiel mehrerer Komponenten       │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
│  ┌───────────────────────────────────────────────────┐    │
│  │ System Tests (5% der Tests)                       │    │
│  │                                                    │    │
│  │  • Critical User Flows                            │    │
│  │  • Browser-based E2E                              │    │
│  │  • JavaScript Interactions                        │    │
│  │                                                    │    │
│  │  Fokus: End-to-End aus User-Perspektive          │    │
│  └───────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Test-Daten-Fluss

```
┌─────────────────┐
│  API Database   │ (Real Data, ID < 50M)
└────────┬────────┘
         │
         │ Inspiration für Fixtures
         ▼
┌─────────────────┐
│  Test Fixtures  │ (YAML Files)
│  ID >= 50M      │
└────────┬────────┘
         │
         ├──────────────────┐
         ▼                  ▼
┌─────────────────┐  ┌──────────────┐
│  Unit Tests     │  │ Integration  │
│  (Fast, Isolated)  │  Tests       │
└─────────────────┘  └──────────────┘
         │
         │ With Snapshots
         ▼
┌─────────────────┐
│  VCR Cassettes  │ (HTTP Recordings)
│  test/snapshots/│
│  vcr/           │
└─────────────────┘
```

## 🎭 Test-Kategorien im Detail

### 1. Concern Tests (`test/concerns/`)

**Zweck:** Teste wiederverwendbare Module

**Struktur:**
```ruby
# test/concerns/local_protector_test.rb
class LocalProtectorTest < ActiveSupport::TestCase
  test "prevents saving API records" do
    # Test isolation
  end
end
```

**Eigenschaften:**
- Schnell (< 1ms pro Test)
- Keine DB-Abhängigkeiten wo möglich
- Fokus auf Logik

### 2. Scraping Tests (`test/scraping/`)

**Zweck:** ClubCloud Integration & Change Detection

**Struktur:**
```ruby
# test/scraping/tournament_scraper_test.rb
class TournamentScraperTest < ActiveSupport::TestCase
  test "extracts tournament data" do
    VCR.use_cassette("nbv_tournament") do
      # HTTP wird recorded/replayed
    end
  end
end
```

**Eigenschaften:**
- Snapshot-basiert mit VCR
- Offline-fähig
- Change Detection

### 3. Model Tests (`test/models/`)

**Zweck:** Business Logic in Models

**Struktur:**
```ruby
# test/models/tournament_test.rb
class TournamentTest < ActiveSupport::TestCase
  test "validates required fields" do
    # Model validation logic
  end
end
```

**Eigenschaften:**
- DB-Transactions
- Fixtures verwendet
- Associations getestet

### 4. Integration Tests (`test/integration/`)

**Zweck:** Multi-Component Workflows

**Struktur:**
```ruby
# test/integration/scraping_workflow_test.rb
class ScrapingWorkflowTest < ActionDispatch::IntegrationTest
  test "complete scraping to storage workflow" do
    # Multiple components interacting
  end
end
```

**Eigenschaften:**
- Langsamer (mehrere Komponenten)
- Realistische Szenarien
- DB & HTTP Mocking

### 5. System Tests (`test/system/`)

**Zweck:** Browser-basierte E2E Tests

**Struktur:**
```ruby
# test/system/tournament_management_test.rb
class TournamentManagementTest < ApplicationSystemTestCase
  test "user creates tournament" do
    visit tournaments_path
    click_on "New Tournament"
    # Browser interactions
  end
end
```

**Eigenschaften:**
- Langsam (Browser-basiert)
- JavaScript-fähig
- Kritische User Flows nur

## 📦 Fixture-Strategie

### ID-Bereiche

```ruby
# API Server Data (readonly in production)
ID_RANGE_API = 1..49_999_999

# Local Server Data (editable)
ID_RANGE_LOCAL = 50_000_000..Float::INFINITY

# Test Fixtures (immer local range)
ID_RANGE_TEST = 50_000_000..50_099_999
```

### Fixture-Organisation

```yaml
# test/fixtures/tournaments.yml

# Basis-Fixture (minimal)
minimal:
  id: 50_000_001
  title: "Minimal Tournament"
  season: current
  organizer: nbv (Region)

# Feature-spezifische Fixture
with_scraping:
  id: 50_000_002
  title: "Scraped Tournament"
  source_url: "https://..."
  sync_date: <%= 1.day.ago %>

# Edge-Case Fixture
api_record:
  id: 1000  # Simulates API data
  title: "API Tournament"
```

## 🔌 VCR Integration

### Cassette-Struktur

```yaml
# test/snapshots/vcr/nbv_tournament_2025.yml
---
http_interactions:
- request:
    method: get
    uri: https://ndbv.de/sb_meisterschaft.php?p=...
  response:
    status:
      code: 200
    body:
      encoding: UTF-8
      string: |
        <!DOCTYPE html>
        <html>
        ...
  recorded_at: Thu, 14 Feb 2026 12:00:00 GMT
```

### Cassette-Nutzung

```ruby
# Automatisches Recording beim ersten Lauf
VCR.use_cassette("nbv_tournament") do
  # Macht echten HTTP Request
  # Speichert Response
end

# Folgende Läufe
VCR.use_cassette("nbv_tournament") do
  # Nutzt gespeicherte Response
  # Kein HTTP Request
end
```

## 🔒 Sicherheit

### Sensitive Daten filtern

```ruby
# test/support/vcr_setup.rb
VCR.configure do |config|
  config.filter_sensitive_data('<CC_USERNAME>') do |interaction|
    # Extract username from request
  end
  
  config.filter_sensitive_data('<CC_PASSWORD>') do |interaction|
    # Extract password from request
  end
end
```

### Test-Isolation

```ruby
# Jeder Test läuft in Transaction
class ActiveSupport::TestCase
  # Automatic rollback after each test
  self.use_transactional_tests = true
end
```

## 📊 Coverage-Strategie

### Ziele

```ruby
# .simplecov
SimpleCov.start do
  # Minimum overall
  minimum_coverage 60
  
  # Critical concerns should have high coverage
  add_group 'Critical Concerns' do |src_file|
    # LocalProtector, SourceHandler, etc.
    # Target: 90%+
  end
  
  # Business logic
  add_group 'Models' do |src_file|
    # Target: 70%+
  end
end
```

### Coverage ist Info, kein Ziel

- ✅ Zeigt ungetestete kritische Bereiche
- ✅ Hilft neue Entwickler
- ❌ Kein Dogma (90%+ Coverage)
- ❌ Nicht Coverage um Coverage willen

## 🚀 Performance

### Test-Geschwindigkeit

```
Unit Tests (Concerns, Models):     < 100ms gesamt
Scraping Tests (mit VCR):          < 500ms gesamt
Integration Tests:                 < 2s gesamt
System Tests:                      < 30s gesamt

Target Gesamt:                     < 2 Minuten
```

### Optimierung

1. **Parallele Ausführung**
   ```ruby
   parallelize(workers: :number_of_processors)
   ```

2. **VCR statt echte HTTP**
   - 1000x schneller
   - Offline-fähig
   - Deterministisch

3. **Fixtures statt Factory**
   - Schneller für Standard-Cases
   - Factory nur für Variationen

## 🔍 Debugging

### Test-spezifische Tools

```ruby
# Pry Breakpoint
test "complex" do
  require 'pry'; binding.pry
end

# Verbose Output
bin/rails test --verbose

# Single Test
bin/rails test test/concerns/local_protector_test.rb:23
```

### VCR Debugging

```bash
# Re-record Cassette
rm test/snapshots/vcr/problematic.yml
bin/rails test test/scraping/...

# Show Cassette
cat test/snapshots/vcr/problematic.yml
```

## 📚 Weiterführende Ressourcen

- [test/README.md](README.md) - Detaillierte Anleitung
- [TESTING.md](../TESTING.md) - Quick Start
- [docs/developers/testing-strategy.de.md](../docs/developers/testing-strategy.de.md) - Strategie

---

**Letzte Aktualisierung:** 2026-02-14
