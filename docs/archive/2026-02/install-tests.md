# 🚀 Test-Setup Installation

**Schnellanleitung zur Installation des Test-Systems**

## ✅ Voraussetzungen

- Ruby 3.2+
- Rails 7.2+
- PostgreSQL 15+
- Carambus bereits lauffähig

## 📦 Installation (5 Minuten)

### Schritt 1: Gems installieren

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# Neue Gems installieren (vcr, simplecov, shoulda-matchers)
bundle install
```

### Schritt 2: Test-Datenbank vorbereiten

```bash
# Test-Datenbank mit StrongMigrations vorbereiten
SAFETY_ASSURED=true bin/rails db:test:prepare
```

**Hinweis:** `SAFETY_ASSURED=true` ist notwendig wegen der StrongMigrations-Warnung im Schema. Dies ist für die Test-Umgebung sicher.

### Schritt 3: Test-Setup validieren

```bash
# Prüft ob alles korrekt eingerichtet ist
bin/rails test:validate
```

Erwartete Ausgabe:
```
🔍 Validating test setup...

✅ Test database connection OK
✅ Fixtures directory exists
✅ Test support directory exists
  ✅ vcr_setup.rb
  ✅ scraping_helpers.rb
  ✅ snapshot_helpers.rb
✅ VCR directory exists
✅ VCR gem loaded
✅ WebMock gem loaded

✅ All checks passed! Test setup is ready.
```

### Schritt 4: Tests laufen lassen

```bash
# Kritische Tests (schnell, ca. 1 Sekunde)
bin/rails test:critical

# Alle Tests
bin/rails test

# Mit Coverage Report
COVERAGE=true bin/rails test
open coverage/index.html
```

## 🐛 Troubleshooting

### Problem: "Migrations are pending" oder "StrongMigrations::UnsafeMigration"

```bash
# Lösung: Test-DB mit SAFETY_ASSURED vorbereiten
SAFETY_ASSURED=true bin/rails db:test:prepare
```

**Warum SAFETY_ASSURED?**
- StrongMigrations warnt vor `force: true` im Schema
- Für Test-Datenbank ist dies sicher (wird bei jedem Test neu erstellt)
- Production-Datenbank ist nicht betroffen

### Problem: "Gem not found"

```bash
# Lösung: Bundle installieren
bundle install
```

### Problem: "Test database connection failed"

```bash
# Test-DB erstellen
bin/rails db:create RAILS_ENV=test

# Dann Schema laden
SAFETY_ASSURED=true bin/rails db:test:prepare
```

### Problem: "VCR cassette not found"

Das ist normal für Tests mit `skip`. Cassettes werden erstellt wenn Tests aktiviert werden.

### Problem: Coverage-Report fehlt

```bash
# Muss mit ENV Variable laufen
COVERAGE=true bin/rails test

# Dann öffnen
open coverage/index.html
```

## 🎯 Was wurde installiert?

### Neue Gems

| Gem | Zweck | Verwendung |
|-----|-------|------------|
| `vcr` | HTTP Recording | Scraping-Tests offline |
| `simplecov` | Coverage Reports | Code-Coverage messen |
| `shoulda-matchers` | Bessere Assertions | Klarere Test-Syntax |

### Neue Dateien

```
test/
├── concerns/                    # ✅ NEU
│   ├── local_protector_test.rb
│   └── source_handler_test.rb
├── scraping/                    # ✅ NEU
│   ├── tournament_scraper_test.rb
│   └── change_detection_test.rb
├── support/                     # ✅ NEU
│   ├── vcr_setup.rb
│   ├── scraping_helpers.rb
│   └── snapshot_helpers.rb
└── snapshots/                   # ✅ NEU
    ├── vcr/
    └── data/

lib/tasks/
└── test.rake                    # ✅ NEU - Nützliche Rake Tasks

Dokumentation:
├── TESTING.md                   # ✅ NEU - Quick Start
├── INSTALL_TESTS.md             # ✅ NEU - Diese Datei
├── TEST_SETUP_SUMMARY.md        # ✅ NEU - Zusammenfassung
├── test/README.md               # ✅ NEU - Detailliert
├── test/ARCHITECTURE.md         # ✅ NEU - Architektur
├── test/TEST_STRUCTURE.md       # ✅ NEU - Struktur
└── docs/developers/
    └── testing-strategy.de.md  # ✅ NEU - Strategie
```

## 🧪 Erste Tests

### Test laufen lassen

```bash
# LocalProtector Tests (sollten grün sein)
bin/rails test test/concerns/local_protector_test.rb

# SourceHandler Tests (sollten grün sein)
bin/rails test test/concerns/source_handler_test.rb

# Scraping Tests (sind mit skip markiert)
bin/rails test test/scraping/
```

### Erwartetes Ergebnis

```
Running 12 tests in a single process...
........SSSS

Finished in 0.234s, 51.28 runs/s, 34.19 assertions/s.

12 tests, 8 assertions, 0 failures, 0 errors, 4 skips
```

- ✅ 8 Tests laufen (LocalProtector, SourceHandler)
- ⏭️ 4 Tests übersprungen (Scraping - benötigen Fixtures)

## 📊 Coverage Report

```bash
# Tests mit Coverage
COVERAGE=true bin/rails test

# Report im Browser öffnen
open coverage/index.html
```

Der Report zeigt:
- Welcher Code getestet ist (grün)
- Welcher Code nicht getestet ist (rot)
- Coverage-Prozente pro Datei

**Ziel:** 60%+ Gesamt-Coverage, 90%+ für kritische Concerns

## 🔍 Nützliche Commands

```bash
# Test-Statistiken anzeigen
bin/rails test:stats

# Alle Test-Dateien auflisten
bin/rails test:list

# Nur kritische Tests (schnell)
bin/rails test:critical

# Einzelnen Test laufen
bin/rails test test/concerns/local_protector_test.rb

# Test mit Name
bin/rails test test/concerns/local_protector_test.rb -n test_prevents_modification

# Verbose Output
bin/rails test --verbose
```

## ⏭️ Nächste Schritte

### 1. Tests vervollständigen

Einige Tests sind mit `skip` markiert und benötigen:

```ruby
test "scraping extracts tournament details" do
  skip "Requires real ClubCloud HTML fixture"
  # ... test code
end
```

**Zum Vervollständigen:**

1. ClubCloud HTML Fixtures sammeln
2. VCR Cassettes aufnehmen
3. `skip` entfernen
4. Tests grün machen

### 2. CI/CD einrichten (Optional)

GitHub Actions Workflow ist vorbereitet in `.github/workflows/tests.yml`.

Badge ins README:
```markdown
![Tests](https://github.com/USER/REPO/actions/workflows/tests.yml/badge.svg)
```

## ✨ Test-Philosophie

### Was getestet wird ✅

- LocalProtector (Datenschutz)
- SourceHandler (Sync Tracking)
- ClubCloud Scraping
- Change Detection
- Business Logic

### Was nicht getestet wird ❌

- Getter/Setter ohne Logik
- Rails Standard-Features
- Third-Party Gems

### Motto

> "Tests sind Mittel zum Zweck, kein Selbstzweck"

- Pragmatisch, nicht dogmatisch
- 60% Coverage ist gut
- Fokus auf kritische Funktionalität

## 📚 Weitere Dokumentation

| Dokument | Inhalt | Für wen? |
|----------|--------|----------|
| [TESTING.md](TESTING.md) | Quick Start | Alle |
| [test/README.md](test/README.md) | Detaillierte Anleitung | Entwickler |
| [test/ARCHITECTURE.md](test/ARCHITECTURE.md) | Architektur | Fortgeschrittene |
| [docs/developers/testing-strategy.de.md](docs/developers/testing-strategy.de.md) | Strategie & Konzept | Interessierte |

## 🎓 Beispiel-Test

Ein einfacher Test zum Verstehen:

```ruby
# test/models/tournament_test.rb
require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  test "tournament requires title" do
    # Arrange - Setup
    tournament = Tournament.new(season: seasons(:current))
    
    # Act - Ausführung
    valid = tournament.valid?
    
    # Assert - Prüfung
    assert_not valid, "Tournament should be invalid without title"
    assert_includes tournament.errors[:title], "can't be blank"
  end
end
```

## 🤝 Beitragen

Tests sind perfekt für Einsteiger:

1. Test mit `skip` finden
2. Fixtures hinzufügen
3. `skip` entfernen
4. Test grün machen
5. Pull Request erstellen

## ✅ Checkliste

Nach Installation sollte alles ✅ sein:

- [ ] `bundle install` erfolgreich
- [ ] `SAFETY_ASSURED=true bin/rails db:test:prepare` erfolgreich
- [ ] `bin/rails test:validate` zeigt alle ✅
- [ ] `bin/rails test:critical` läuft durch
- [ ] `bin/rails test` zeigt Ergebnisse
- [ ] `COVERAGE=true bin/rails test` erzeugt Report
- [ ] Coverage Report öffnet im Browser

## 🎉 Geschafft!

Das Test-System ist installiert und einsatzbereit.

**Nächste Schritte:**
1. ✅ Tests laufen lassen: `bin/rails test`
2. 📖 [TESTING.md](TESTING.md) lesen
3. 🧪 Ersten eigenen Test schreiben

**Bei Fragen:**
- Siehe [test/README.md](test/README.md)
- Siehe [TESTING.md](TESTING.md)
- GitHub Issues erstellen

---

**Installation erfolgreich! Happy Testing! 🚀**
