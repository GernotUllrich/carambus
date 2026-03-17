# ⚡ Tests Schnellstart

**Die Tests sind bereit - führen Sie diese 3 Befehle aus:**

## 🚀 In 3 Schritten zu laufenden Tests

```bash
# 1. Gems installieren (falls noch nicht geschehen)
bundle install

# 2. Test-Datenbank vorbereiten
SAFETY_ASSURED=true bin/rails db:test:prepare

# 3. Tests laufen lassen!
bin/rails test:critical
```

## ✅ Erwartetes Ergebnis

Nach `bin/rails test:critical` sollten Sie sehen:

```
🔥 Running critical tests...
🔧 Running concern tests...
Running 12 tests in a single process...
........SSSS

Finished in 0.234s
12 tests, 8 assertions, 0 failures, 0 errors, 4 skips

🕷️ Running scraping tests...
Running 8 tests in a single process...
SSSSSSSS

Finished in 0.123s
8 tests, 0 assertions, 0 failures, 0 errors, 8 skips
```

**Bedeutung:**
- ✅ **8 Tests erfolgreich** (LocalProtector, SourceHandler)
- ⏭️ **12 Tests übersprungen** (benötigen ClubCloud HTML Fixtures)
- 🎯 **0 Fehler** - Setup funktioniert!

## 📊 Weitere nützliche Commands

```bash
# Alle Tests (inkl. existierende Model/Controller Tests)
bin/rails test

# Mit Coverage Report
COVERAGE=true bin/rails test
open coverage/index.html

# Test-Statistiken
bin/rails test:stats

# Setup validieren
bin/rails test:validate
```

## 🐛 Falls Probleme auftreten

### "Migrations are pending"

```bash
SAFETY_ASSURED=true bin/rails db:test:prepare
```

### "Gem not found"

```bash
bundle install
```

### "Database does not exist"

```bash
bin/rails db:create RAILS_ENV=test
SAFETY_ASSURED=true bin/rails db:test:prepare
```

## 📚 Mehr erfahren

- **Detaillierte Installation:** [INSTALL_TESTS.md](INSTALL_TESTS.md)
- **Test schreiben:** [TESTING.md](../developers/testing/testing-quickstart.md)
- **Vollständige Anleitung:** [test/README.md](../developers/testing/testing-quickstart.md)

---

**Das war's! Tests laufen. 🎉**
