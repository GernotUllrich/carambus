# 🧪 Carambus Testing-Strategie

**Pragmatischer Ansatz für kritische Funktionalität**

## 📋 Philosophie

> "Tests sind Mittel zum Zweck, kein Selbstzweck"

Wir fokussieren auf:
- ✅ **Kritische Business-Logik** (LocalProtector, Scraping)
- ✅ **Change Detection** (ClubCloud-Änderungen erkennen)
- ✅ **Regression Prevention** (Bekannte Bugs nicht wiederholen)
- ❌ **Keine Test-Maximierung** (Kein 100% Coverage-Dogma)

## 🎯 Test-Prioritäten

### 1. Höchste Priorität: ClubCloud Scraping

**Warum kritisch?**
- Externe Datenquelle ändert sich ohne Vorwarnung
- Fehler führen zu falschen Turnierdaten
- Schwer zu debuggen ohne Tests

**Test-Strategie:**
```ruby
# Snapshot-basierte Tests mit WebMock
# - HTML-Snapshots von ClubCloud speichern
# - Bei Änderungen: Test schlägt fehl → Manuell prüfen
# - Bewusste Aktualisierung statt stille Fehler
```

### 2. Kritisch: LocalProtector

**Warum kritisch?**
- Verhindert versehentliches Überschreiben von API-Daten
- Kern der Multi-Tenant-Architektur
- Fehler können Datenverlust verursachen

**Test-Strategie:**
```ruby
# Model-Tests mit API-Datenbank
# - ID < 50_000_000 → schreibgeschützt
# - ID >= 50_000_000 → beschreibbar
# - unprotected-Flag funktioniert
```

### 3. Wichtig: Change Detection

**Warum wichtig?**
- Turnierdaten müssen aktuell bleiben
- Automatische Updates ohne manuelle Prüfung
- sync_date-Tracking

**Test-Strategie:**
```ruby
# Integration Tests
# - Scraping erkennt Änderungen
# - sync_date wird korrekt gesetzt
# - Nur geänderte Felder werden überschrieben
```

## 🏗️ Test-Architektur

### Nutze API-Datenbank als Basis

```ruby
# test/test_helper.rb
# Verbindung zur API-Datenbank für realistische Tests
# - Echte Datenstrukturen
# - Reale Beziehungen
# - Authentische Edge Cases

# Für Tests: Snapshot der API-DB → Isolierte Test-DB
```

### Test-Typen & Verteilung

```
┌─────────────────────────────────────────┐
│ 1. Snapshot Tests (40%)                 │
│    - ClubCloud HTML/JSON Responses      │
│    - Change Detection                   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 2. Model Tests (30%)                    │
│    - LocalProtector                     │
│    - SourceHandler                      │
│    - RegionTaggable                     │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 3. Integration Tests (20%)              │
│    - Scraping Workflows                 │
│    - Sync-Prozesse                      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 4. Regression Tests (10%)               │
│    - Bekannte Bugs                      │
│    - Edge Cases aus Produktion          │
└─────────────────────────────────────────┘
```

## 📁 Test-Struktur

```
test/
├── snapshots/                  # NEU: HTML/JSON Snapshots
│   ├── clubcloud/
│   │   ├── tournament_list_nbv_2025.html
│   │   ├── league_details_oberliga.html
│   │   └── player_roster_bcw.json
│   └── README.md              # Snapshot-Dokumentation
│
├── concerns/                   # NEU: Concern Tests
│   ├── local_protector_test.rb
│   ├── source_handler_test.rb
│   └── region_taggable_test.rb
│
├── scraping/                   # NEU: Scraping Tests
│   ├── tournament_scraper_test.rb
│   ├── league_scraper_test.rb
│   ├── change_detection_test.rb
│   └── sync_date_test.rb
│
├── models/                     # Erweitert
│   ├── tournament_test.rb ✓
│   ├── tournament_cc_test.rb
│   ├── region_cc_test.rb
│   └── ...
│
├── integration/                # Erweitert
│   ├── clubcloud_sync_test.rb
│   └── scraping_workflow_test.rb
│
└── support/                    # NEU: Test-Helpers
    ├── scraping_helpers.rb
    ├── snapshot_helpers.rb
    └── api_database_helpers.rb
```

## 🔧 Tooling

### Minimal aber effektiv

```ruby
# Gemfile - test group
group :test do
  gem 'capybara'                    # ✓ bereits vorhanden
  gem 'factory_bot_rails'           # ✓ bereits vorhanden
  gem 'webmock'                     # ✓ bereits vorhanden
  
  # NEU - nur was wirklich hilft
  gem 'vcr'                         # HTTP Snapshot Recording
  gem 'simplecov', require: false   # Coverage (Info, kein Dogma)
end
```

### VCR für HTTP-Snapshots

```ruby
# test/support/vcr.rb
VCR.configure do |c|
  c.cassette_library_dir = 'test/snapshots/vcr'
  c.hook_into :webmock
  c.ignore_localhost = true
  
  # Sensitive Daten filtern
  c.filter_sensitive_data('<USERNAME>') { ENV['CC_USERNAME'] }
  c.filter_sensitive_data('<PASSWORD>') { ENV['CC_PASSWORD'] }
end
```

## 📝 Konkrete Test-Beispiele

### 1. Snapshot Test für ClubCloud Scraping

```ruby
# test/scraping/tournament_scraper_test.rb
require 'test_helper'

class TournamentScraperTest < ActiveSupport::TestCase
  test "scraping NBV tournament detects no changes when HTML unchanged" do
    VCR.use_cassette("nbv_tournament_2025") do
      tournament = tournaments(:nbv_example)
      
      # Erste Scraping
      tournament.scrape_single_tournament_public
      first_sync = tournament.sync_date
      
      # Zweite Scraping (gleiche HTML)
      tournament.scrape_single_tournament_public
      
      # Keine Änderung → sync_date unverändert
      assert_equal first_sync, tournament.reload.sync_date
    end
  end
  
  test "scraping detects tournament title change" do
    VCR.use_cassette("nbv_tournament_changed") do
      tournament = tournaments(:nbv_example)
      original_title = tournament.title
      
      tournament.scrape_single_tournament_public
      
      # Cassette enthält geänderten Titel
      assert_not_equal original_title, tournament.reload.title
      assert tournament.sync_date > 1.minute.ago
    end
  end
  
  test "scraping handles ClubCloud HTML structure change" do
    # Dieser Test schlägt fehl wenn CC die HTML-Struktur ändert
    VCR.use_cassette("nbv_tournament_new_structure") do
      tournament = tournaments(:nbv_example)
      
      assert_nothing_raised do
        tournament.scrape_single_tournament_public
      end
      
      # Prüfe dass alle erwarteten Felder gescraped wurden
      assert_not_nil tournament.title
      assert_not_nil tournament.date
      assert_not_nil tournament.location
    end
  end
end
```

### 2. LocalProtector Test

```ruby
# test/concerns/local_protector_test.rb
require 'test_helper'

class LocalProtectorTest < ActiveSupport::TestCase
  test "prevents modification of API records (id < 50M)" do
    tournament = Tournament.find(1000) # API record
    
    assert_raises(ActiveRecord::Rollback) do
      tournament.update!(title: "Changed")
    end
  end
  
  test "allows modification of local records (id >= 50M)" do
    tournament = Tournament.find(50_000_001) # Local record
    
    assert_nothing_raised do
      tournament.update!(title: "Changed")
    end
  end
  
  test "unprotected flag bypasses protection" do
    tournament = Tournament.find(1000) # API record
    tournament.unprotected = true
    
    assert_nothing_raised do
      tournament.update!(title: "Changed")
    end
  end
  
  test "protection is disabled in test environment" do
    # Dies ist ein Meta-Test - stellt sicher dass Tests nicht blockiert werden
    tournament = Tournament.find(1000)
    
    # In Test-Umgebung sollte auch ohne unprotected funktionieren
    assert Rails.env.test?
    assert_nothing_raised do
      tournament.update!(title: "Test Change")
    end
  end
end
```

### 3. Change Detection Test

```ruby
# test/scraping/change_detection_test.rb
require 'test_helper'

class ChangeDetectionTest < ActiveSupport::TestCase
  setup do
    @tournament = tournaments(:nbv_example)
    @initial_sync = @tournament.sync_date
  end
  
  test "sync_date updates only when content changes" do
    VCR.use_cassette("nbv_unchanged") do
      @tournament.scrape_single_tournament_public
      
      # Keine inhaltliche Änderung → sync_date bleibt
      assert_equal @initial_sync, @tournament.reload.sync_date
    end
  end
  
  test "sync_date updates when content changes" do
    VCR.use_cassette("nbv_title_changed") do
      travel_to 1.day.from_now do
        @tournament.scrape_single_tournament_public
        
        # Inhaltliche Änderung → sync_date aktualisiert
        assert @tournament.reload.sync_date > @initial_sync
      end
    end
  end
  
  test "only changed fields trigger sync_date update" do
    VCR.use_cassette("nbv_location_changed") do
      original_title = @tournament.title
      
      @tournament.scrape_single_tournament_public
      
      # Title unverändert, aber Location geändert
      assert_equal original_title, @tournament.reload.title
      assert @tournament.sync_date > @initial_sync
    end
  end
end
```

## 🚀 Umsetzungsplan

### Phase 1: Grundlagen (1-2 Tage)
- [ ] VCR konfigurieren
- [ ] Test-Helpers für Scraping erstellen
- [ ] Erste Snapshots von ClubCloud aufnehmen

### Phase 2: Kritische Tests (2-3 Tage)
- [ ] LocalProtector Tests
- [ ] Basis Scraping Tests mit Snapshots
- [ ] SourceHandler Tests

### Phase 3: Change Detection (1-2 Tage)
- [ ] sync_date Tests
- [ ] Change Detection Tests
- [ ] Regression Tests für bekannte Issues

### Phase 4: CI/CD (1 Tag)
- [ ] GitHub Actions konfigurieren
- [ ] Test-Reports generieren
- [ ] Badge im README

## 📊 Success Metrics

**Nicht Coverage-Prozent, sondern:**
- ✅ Alle kritischen Scraping-Szenarien abgedeckt
- ✅ LocalProtector-Logic vollständig getestet
- ✅ Change Detection funktioniert zuverlässig
- ✅ CI läuft grün bei jedem Push
- ✅ Tests laufen schnell (< 2 Minuten)

## 🎓 Best Practices

### 1. Snapshot-First für External APIs
```ruby
# Immer mit VCR cassette arbeiten
VCR.use_cassette("descriptive_name") do
  # ... test code
end
```

### 2. Realistische Fixtures
```ruby
# Nutze echte IDs aus API-Datenbank
fixtures :tournaments # ID 1000-2000 (API)
# Für lokale Records: ID >= 50_000_000
```

### 3. Aussagekräftige Test-Namen
```ruby
# ✅ Gut
test "scraping detects tournament date change in ClubCloud"

# ❌ Schlecht
test "test_scraping"
```

### 4. Arrange-Act-Assert Pattern
```ruby
test "descriptive name" do
  # Arrange - Setup
  tournament = tournaments(:example)
  
  # Act - Ausführung
  tournament.scrape_single_tournament_public
  
  # Assert - Prüfung
  assert_equal "Expected", tournament.title
end
```

## 📚 Weiterführende Ressourcen

- [VCR Gem Documentation](https://github.com/vcr/vcr)
- [Minitest Best Practices](https://chriskottom.com/minitest)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)

---

**Letzte Aktualisierung:** 2026-02-14
**Autor:** Generated with AI assistance
