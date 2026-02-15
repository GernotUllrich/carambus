# 🧪 Carambus Testing Guide

Pragmatische Tests für kritische Funktionalität.

## 📚 Dokumentation

| Dokument | Zweck | Zeit |
|----------|-------|------|
| **[../docs/SCRAPING_MONITORING_QUICKSTART.md](../docs/SCRAPING_MONITORING_QUICKSTART.md)** | 🔥 **NEU: Production Monitoring (EMPFOHLEN!)** | 5 Min |
| **[../docs/SCRAPING_MONITORING.md](../docs/SCRAPING_MONITORING.md)** | Vollständige Monitoring-Dokumentation | 20 Min |
| **[FIXTURES_QUICK_START.md](FIXTURES_QUICK_START.md)** | 5-Minuten Quick Start für erste Fixture | 5 Min |
| **[FIXTURES_SAMMELN.md](FIXTURES_SAMMELN.md)** | Vollständige Anleitung zum Sammeln von ClubCloud Fixtures | 15 Min |
| **[fixtures/html/README.md](fixtures/html/README.md)** | HTML Fixture-Verwaltung & Best Practices | 10 Min |
| **README.md** (dieses Dokument) | Allgemeiner Testing-Guide | 20 Min |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Test-Architektur & Design-Prinzipien | 15 Min |
| **[TEST_STRUCTURE.md](TEST_STRUCTURE.md)** | Visuelle Übersicht der Test-Struktur | 5 Min |

## 🚀 Schnellstart

### 🔥 NEU: Production Monitoring (EMPFOHLEN!)

```bash
# Scraping mit Monitoring (statt ohne!)
rake scrape:daily_update_monitored

# Web-Dashboard öffnen
open http://localhost:3000/scraping_monitor

# Statistiken ansehen
rake scrape:stats

# Health Check
rake scrape:check_health
```

**👉 Siehe: [SCRAPING_MONITORING_QUICKSTART.md](../docs/SCRAPING_MONITORING_QUICKSTART.md)**

### Tests ausführen

```bash
# Alle Tests laufen
bin/rails test

# Nur kritische Tests (Concerns + Scraping)
bin/rails test:critical

# Nur Scraping Tests
bin/rails test:scraping

# Einzelnen Test laufen lassen
bin/rails test test/concerns/local_protector_test.rb

# Mit Coverage Report
bin/rails test:coverage
```

## 🎯 Neue Scraping-Tests schreiben?

**→ Start here:** [FIXTURES_QUICK_START.md](FIXTURES_QUICK_START.md) (5 Minuten!)

Die Scraping-Tests benötigen ClubCloud HTML Fixtures. Der Quick Start zeigt wie.

## 📁 Test-Struktur

```
test/
├── concerns/              # Concern Tests (LocalProtector, SourceHandler)
├── scraping/              # Scraping & Change Detection Tests
├── models/                # Model Tests
├── controllers/           # Controller Tests
├── integration/           # Integration Tests
├── system/                # Browser-basierte End-to-End Tests
├── fixtures/              # Test-Daten (YAML)
├── snapshots/             # HTTP & Data Snapshots
│   ├── vcr/              # VCR Cassettes (HTTP Recordings)
│   └── data/             # Data Snapshots
└── support/               # Test Helpers
    ├── vcr_setup.rb
    ├── scraping_helpers.rb
    └── snapshot_helpers.rb
```

## 🎯 Test-Kategorien

### 1. Concern Tests (Höchste Priorität)

Tests für wiederverwendbare Module:

```bash
bin/rails test test/concerns/
```

**Was wird getestet:**
- ✅ LocalProtector (Datenschutz für API-Daten)
- ✅ SourceHandler (Sync-Date Tracking)
- ✅ RegionTaggable (Region-Zuordnung)

### 2. Scraping Tests (Kritisch)

Tests für ClubCloud Scraping:

```bash
bin/rails test test/scraping/
```

**Was wird getestet:**
- ✅ Tournament Scraping
- ✅ Change Detection
- ✅ HTML Structure Changes
- ✅ sync_date Updates

**Mit VCR Cassettes:**
- Echte HTTP Responses sind gespeichert
- Tests laufen schnell und offline
- Strukturänderungen werden erkannt

### 3. Model Tests

Tests für Business Logic:

```bash
bin/rails test test/models/
```

### 4. Integration Tests

End-to-End Workflows:

```bash
bin/rails test test/integration/
```

## 🔧 Test Helpers

### Scraping Helpers

```ruby
# Test mit VCR Cassette
VCR.use_cassette("nbv_tournament") do
  tournament.scrape_single_tournament_public
end

# Snapshot-Name generieren
name = snapshot_name("tournament", "nbv", "2025")
# => "tournament_nbv_2025"

# ClubCloud Response mocken
mock_clubcloud_html(url, html_content)

# Sync-Date prüfen
assert_sync_date_updated(tournament, since: 1.hour.ago)
assert_sync_date_unchanged(tournament, original_date)
```

### Snapshot Helpers

```ruby
# Data Snapshot erstellen/vergleichen
data = { title: "Test", date: Date.today }
assert_matches_snapshot("tournament_structure", data)

# Snapshot aktualisieren (bei intentionalen Änderungen)
update_snapshot("tournament_structure", new_data)

# Model Attributes für Snapshot
attrs = snapshot_attributes(tournament, :title, :date, :state)
```

## 📊 Coverage Reports

Coverage Reports zeigen, welcher Code getestet ist:

```bash
# Mit Coverage laufen lassen
COVERAGE=true bin/rails test

# Report ansehen
open coverage/index.html
```

**Wichtig:** Coverage ist Info, kein Ziel!
- 60% Gesamt-Coverage ist gut
- 90%+ für kritische Module (LocalProtector, Scraping)
- Fokus auf Qualität, nicht Quantität

## 🎨 Test-Schreiben Best Practices

### 1. Arrange-Act-Assert Pattern

```ruby
test "scraping updates sync_date when content changes" do
  # Arrange - Setup
  tournament = tournaments(:scraped)
  original_sync = tournament.sync_date
  
  # Act - Ausführung
  VCR.use_cassette("nbv_changed") do
    tournament.scrape_single_tournament_public
  end
  
  # Assert - Prüfung
  assert tournament.reload.sync_date > original_sync,
         "sync_date should update when content changes"
end
```

### 2. Aussagekräftige Test-Namen

```ruby
# ✅ Gut - beschreibt erwartetes Verhalten
test "LocalProtector prevents saving API records without unprotected flag"

# ❌ Schlecht - zu vage
test "test_local_protector"
```

### 3. Ein Konzept pro Test

```ruby
# ✅ Gut - testet eine Sache
test "sync_date updates when title changes" do
  # ...
end

test "sync_date updates when date changes" do
  # ...
end

# ❌ Schlecht - testet zu viel auf einmal
test "scraping updates everything" do
  # testet title, date, location, sync_date ...
end
```

### 4. Skip für unfertige Tests

```ruby
test "complex scraping scenario" do
  skip "Requires ClubCloud HTML fixture - TODO"
  
  # Test code here
end
```

## 🔍 VCR Cassettes

### Neue Cassette aufnehmen

1. Test schreiben mit `VCR.use_cassette`:

```ruby
test "scraping NBV tournament" do
  VCR.use_cassette("nbv_tournament_2025") do
    tournament.scrape_single_tournament_public
  end
end
```

2. Test laufen lassen - VCR nimmt HTTP auf
3. Cassette wird in `test/snapshots/vcr/` gespeichert
4. Nächster Lauf verwendet gespeicherte Response

### Cassette aktualisieren

```bash
# Cassette löschen
rm test/snapshots/vcr/nbv_tournament_2025.yml

# Test neu laufen lassen - nimmt neue Response auf
bin/rails test test/scraping/tournament_scraper_test.rb
```

### Sensitive Daten

VCR filtert automatisch:
- Usernames → `<CC_USERNAME>`
- Passwords → `<CC_PASSWORD>`

Konfiguration in `test/support/vcr_setup.rb`.

## 🐛 Debugging Tests

### Test verbose laufen lassen

```bash
bin/rails test test/concerns/local_protector_test.rb --verbose
```

### Einzelnen Test laufen

```bash
# Nach Name
bin/rails test test/concerns/local_protector_test.rb -n test_prevents_modification

# Nach Zeile
bin/rails test test/concerns/local_protector_test.rb:23
```

### Mit Pry debuggen

```ruby
test "something complex" do
  require 'pry'; binding.pry
  # Test pausiert hier
end
```

### Test Database inspizieren

```bash
# Test DB Console
rails db -e test

# Test DB zurücksetzen
bin/rails db:test:prepare
```

## 📝 Fixtures vs Factories

### Fixtures (Aktuell verwendet)

```ruby
# test/fixtures/tournaments.yml
local:
  id: 50_000_001
  title: "Local Tournament"
  # ...

# In Test
tournament = tournaments(:local)
```

**Pro:** Schnell, einfach, in YAML definiert
**Contra:** Statisch, keine Variationen

### Factories (Für komplexere Fälle)

```ruby
# test/factories/tournaments.rb (TODO)
FactoryBot.define do
  factory :tournament do
    sequence(:id) { |n| 50_000_000 + n }
    title { "Test Tournament #{id}" }
    season
    organizer { association :region }
    # ...
  end
end

# In Test
tournament = create(:tournament, title: "Custom")
```

**Pro:** Flexibel, anpassbar
**Contra:** Mehr Setup

## 🚨 Häufige Probleme

### "No fixtures found"

```bash
# Fixtures laden
bin/rails db:fixtures:load RAILS_ENV=test
```

### "VCR cassette not found"

Test einmal laufen lassen zum Aufnehmen.

### "Test database is not prepared"

```bash
bin/rails db:test:prepare
```

### "Strong Migrations Error"

```bash
# In Test-Umgebung, Migration überspringen
SAFETY_ASSURED=true bin/rails db:test:prepare
```

## 📚 Weitere Ressourcen

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Minitest Documentation](https://docs.seattlerb.org/minitest/)
- [VCR Documentation](https://github.com/vcr/vcr)
- [Testing Strategy](../docs/developers/testing-strategy.de.md)

## 🎯 Next Steps

1. ✅ Test-Infrastruktur eingerichtet
2. ✅ LocalProtector Tests vorhanden
3. ✅ SourceHandler Tests vorhanden
4. ⏳ Scraping Tests mit echten Fixtures füllen
5. ⏳ Integration Tests für Workflows
6. ⏳ CI/CD Setup (GitHub Actions)

---

**Fragen?** Siehe [Testing Strategy](../docs/developers/testing-strategy.de.md)
