# 🧪 Testing Carambus - Quick Start

Dieses Dokument zeigt, wie man die Tests für Carambus nutzt und erweitert.

## 🚀 Sofort loslegen

```bash
# 1. Dependencies installieren
bundle install

# 2. Test-Setup validieren
bin/rails test:validate

# 3. Tests laufen lassen
bin/rails test

# 4. Nur kritische Tests (schnell)
bin/rails test:critical
```

## 📊 Was wird getestet?

### ✅ Bereits implementiert

1. **LocalProtector** - Datenschutz für API-Daten
   - Verhindert versehentliches Überschreiben von API-Server-Daten
   - Kritisch für Multi-Tenant-Architektur

2. **SourceHandler** - Sync-Date Tracking
   - Verfolgt wann Daten zuletzt von ClubCloud geholt wurden
   - Basis für Change Detection

3. **Change Detection** - Framework vorhanden
   - Tests bereit für ClubCloud HTML Fixtures
   - VCR für HTTP Recording konfiguriert

### ⏳ Nächste Schritte

1. **ClubCloud HTML Fixtures sammeln**
   ```bash
   # Browser DevTools nutzen oder:
   curl "https://nbv.clubcloud.de/..." > test/fixtures/html/nbv_tournament.html
   ```

2. **Scraping Tests mit Fixtures füllen**
   - Tests sind vorbereitet (mit `skip`)
   - HTML Fixtures hinzufügen
   - `skip` entfernen und Tests grün machen

3. **Integration Tests**
   - Komplette Workflows testen
   - Tournament-Erstellung bis Ergebnis-Upload

## 🎯 Test-Arten

### Model Tests (Unit Tests)

Testen einzelne Models und Concerns:

```bash
# Alle Model Tests
bin/rails test:models

# Nur Concerns
bin/rails test:concerns
```

**Beispiel:**
```ruby
test "LocalProtector prevents saving API records" do
  tournament = Tournament.new(id: 1000) # API record
  
  # Should not save in production (allowed in test env)
  assert_equal true, tournament.disallow_saving_global_records
end
```

### Scraping Tests

Testen ClubCloud Scraping mit VCR:

```bash
bin/rails test:scraping
```

**Beispiel:**
```ruby
test "scraping extracts tournament details" do
  VCR.use_cassette("nbv_tournament") do
    tournament.scrape_single_tournament_public
    
    assert_not_nil tournament.title
    assert_not_nil tournament.date
  end
end
```

### Integration Tests

Testen komplette Workflows:

```bash
bin/rails test test/integration/
```

## 🛠️ Nützliche Commands

```bash
# Mit Coverage
COVERAGE=true bin/rails test
open coverage/index.html

# Nur kritische Tests (schnell)
bin/rails test:critical

# Test-Statistiken
bin/rails test:stats

# Einzelnen Test
bin/rails test test/concerns/local_protector_test.rb

# Test nach Name
bin/rails test test/concerns/local_protector_test.rb -n test_prevents_modification

# Verbose
bin/rails test --verbose

# VCR Cassettes neu aufnehmen
bin/rails test:rerecord_vcr
```

## 📝 Neuen Test schreiben

### 1. Test-Datei erstellen

```bash
# Model Test
touch test/models/my_model_test.rb

# Scraping Test
touch test/scraping/my_scraper_test.rb
```

### 2. Test-Template

```ruby
# frozen_string_literal: true

require "test_helper"

class MyModelTest < ActiveSupport::TestCase
  setup do
    @model = my_models(:fixture_name)
  end
  
  test "descriptive name of what is tested" do
    # Arrange - Setup
    expected_value = "something"
    
    # Act - Execute
    result = @model.some_method
    
    # Assert - Verify
    assert_equal expected_value, result,
                 "Helpful message if assertion fails"
  end
end
```

### 3. Fixtures erstellen (falls nötig)

```yaml
# test/fixtures/my_models.yml
fixture_name:
  id: 50_000_001  # Local ID (>= 50M)
  name: "Test Name"
  created_at: <%= 1.day.ago %>
```

### 4. Test laufen lassen

```bash
bin/rails test test/models/my_model_test.rb
```

## 🕷️ VCR für Scraping Tests

VCR nimmt HTTP Requests auf und spielt sie ab:

### Cassette erstellen

```ruby
test "scraping works" do
  VCR.use_cassette("descriptive_name") do
    # Erster Lauf: Echte HTTP Request, wird aufgenommen
    # Folgende Läufe: Gespeicherte Response wird verwendet
    result = some_http_request
    
    assert_something(result)
  end
end
```

### Cassette aktualisieren

```bash
# Cassette löschen
rm test/snapshots/vcr/descriptive_name.yml

# Test neu laufen - nimmt neue Response auf
bin/rails test test/scraping/...
```

### Sensitive Daten

VCR filtert automatisch:
- Usernames → `<CC_USERNAME>`
- Passwords → `<CC_PASSWORD>`

Konfiguration in `test/support/vcr_setup.rb`.

## 📊 Coverage Reports

```bash
# Tests mit Coverage
COVERAGE=true bin/rails test

# Report öffnen
open coverage/index.html
```

**Coverage-Ziele:**
- ✅ 60%+ Gesamt-Coverage (realistisches Ziel)
- ✅ 90%+ für kritische Concerns (LocalProtector, SourceHandler)
- ✅ 70%+ für Scraping-Code
- ⚠️ Coverage ist Info, kein Dogma!

## 🐛 Debugging

### Pry verwenden

```ruby
test "complex scenario" do
  require 'pry'; binding.pry
  # Test pausiert hier, interaktive Shell
end
```

### Logger aktivieren

```ruby
test "with logging" do
  Rails.logger.level = :debug
  # ... test code
end
```

### Test DB inspizieren

```bash
# Test DB Console
rails db -e test

# Schema ansehen
bin/rails db:schema:dump RAILS_ENV=test
```

## 🔄 CI/CD

Tests laufen automatisch auf GitHub:

- **Push zu main/develop** → Alle Tests
- **Pull Request** → Alle Tests
- **Lint Check** → Standard & Brakeman

Badge im README:
```markdown
![Tests](https://github.com/USER/REPO/actions/workflows/tests.yml/badge.svg)
```

## 📚 Weitere Dokumentation

- **[Test README](test/README.md)** - Detaillierte Anleitung
- **[Testing Strategy](docs/developers/testing-strategy.de.md)** - Konzept & Philosophie
- **[Snapshots README](test/snapshots/README.md)** - VCR & Snapshots

## ❓ FAQ

### Q: Warum schlagen Tests wegen Migrationen fehl?

```bash
# Test DB vorbereiten
bin/rails db:test:prepare

# Oder mit StrongMigrations
SAFETY_ASSURED=true bin/rails db:test:prepare
```

### Q: Wie teste ich mit echter API-Datenbank?

Die Test-Strategie nutzt die API-Datenbank als Inspiration für Fixtures.
Für Tests verwenden wir isolierte Test-Daten (ID >= 50M).

### Q: Warum sind viele Scraping-Tests mit `skip` markiert?

Die Tests sind vorbereitet, aber wir brauchen noch:
1. Echte ClubCloud HTML Fixtures
2. VCR Cassettes von echten Requests

**Du kannst helfen:**
1. ClubCloud HTML speichern
2. In `test/fixtures/html/` ablegen
3. `skip` entfernen
4. Test grün machen

### Q: Muss ich Tests für jede kleine Änderung schreiben?

**Nein!** Pragmatischer Ansatz:
- ✅ Tests für neue kritische Features
- ✅ Tests wenn Bug gefunden (Regression Prevention)
- ✅ Tests für Scraping (externe Abhängigkeiten)
- ⚠️ Nicht für jeden Getter/Setter

### Q: Wie aktualisiere ich Tests wenn ClubCloud sich ändert?

1. Tests schlagen fehl (gut!)
2. VCR Cassettes löschen: `bin/rails test:rerecord_vcr`
3. Tests neu laufen lassen
4. Scraping-Code anpassen falls nötig
5. Commit mit Beschreibung der ClubCloud-Änderung

## 🎓 Best Practices

1. **Ein Test, ein Konzept**
   - Teste eine Sache pro Test
   - Aussagekräftige Namen

2. **Arrange-Act-Assert**
   - Setup → Ausführung → Prüfung
   - Klar getrennte Phasen

3. **Realistische Fixtures**
   - IDs >= 50M für lokale Daten
   - Valide Beziehungen

4. **Snapshots für External APIs**
   - VCR für HTTP Requests
   - Tests laufen offline & schnell

5. **Skip statt Löschen**
   - Unfertige Tests mit `skip` markieren
   - Nicht einfach löschen

## 🚀 Nächste Schritte

1. ✅ Setup validieren: `bin/rails test:validate`
2. ✅ Vorhandene Tests laufen lassen: `bin/rails test`
3. ⏳ ClubCloud HTML Fixtures sammeln
4. ⏳ Scraping Tests komplettieren
5. ⏳ Integration Tests schreiben

---

**Fragen?** Siehe [test/README.md](test/README.md) oder [Testing Strategy](docs/developers/testing-strategy.de.md)

**Beitragen?** Pull Requests für Tests sind sehr willkommen! 🎉
