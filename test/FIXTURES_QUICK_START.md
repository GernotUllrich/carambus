# 🚀 ClubCloud Fixtures - Quick Start

**5 Minuten zur ersten funktionierenden Scraping-Fixture**

## 📋 Checkliste

- [ ] **Schritt 1:** Verzeichnis erstellen (5 Sekunden)
- [ ] **Schritt 2:** URL im Browser öffnen (10 Sekunden)
- [ ] **Schritt 3:** HTML kopieren (30 Sekunden)
- [ ] **Schritt 4:** Fixture speichern (10 Sekunden)
- [ ] **Schritt 5:** Test anpassen (2 Minuten)
- [ ] **Schritt 6:** Test laufen lassen (30 Sekunden)

**Gesamtzeit:** ~5 Minuten

---

## Schritt 1: Verzeichnis erstellen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
mkdir -p test/fixtures/html
```

✅ **Fertig!**

---

## Schritt 2: URL im Browser öffnen

**URL anzeigen lassen:**

```bash
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026
```

**Output:**
```
1️⃣  Tournament Liste:
   https://ndbv.de/sb_meisterschaft.php?p=20--2025/2026--0--2-1-100000-
```

**Im Browser öffnen:**

```bash
# Kopiere die URL und öffne sie
open "https://ndbv.de/sb_meisterschaft.php?p=20--2025/2026--0--2-1-100000-"
```

✅ **Seite lädt!**

---

## Schritt 3: HTML kopieren (Browser DevTools)

**Im Browser:**

1. **DevTools öffnen:**
   - Mac: `Cmd + Option + I`
   - Windows/Linux: `F12`

2. **Network Tab:**
   - Klick auf "Network" (oben)
   - Falls Liste leer: Seite neu laden (`Cmd + R`)

3. **Response kopieren:**
   - Erste Zeile in der Liste anklicken (oft `sb_meisterschaft.php`)
   - Tab "Response" wählen (rechts)
   - Im Response-Bereich: Rechtsklick → **"Copy response"**

✅ **HTML ist im Clipboard!**

---

## Schritt 4: Fixture speichern

**Terminal:**

```bash
cd test/fixtures/html

# HTML aus Clipboard einfügen und speichern
pbpaste > tournament_list_nbv_2025_2026.html

# Verifizieren
head -5 tournament_list_nbv_2025_2026.html
```

**Expected Output:**
```html
<!DOCTYPE html>
<html lang="de">
<head>
...
```

✅ **Fixture gespeichert!**

---

## Schritt 5: Test anpassen

**Test-Datei öffnen:**

```bash
vim test/scraping/tournament_scraper_test.rb
```

**Änderung 1: Skip entfernen**

```ruby
# VORHER:
test "scraping extracts tournament details" do
  skip "Requires real ClubCloud HTML fixture"  # ← DIESE ZEILE LÖSCHEN
  # ...
end

# NACHHER:
test "scraping extracts tournament details" do
  # ...
end
```

**Änderung 2: Fixture einbinden**

```ruby
test "scraping extracts tournament details" do
  # Fixture laden
  html = File.read(Rails.root.join('test/fixtures/html/tournament_list_nbv_2025_2026.html'))
  
  # HTTP Request mocken
  stub_request(:get, %r{nbv\.clubcloud\.de/sb_meisterschaft\.php})
    .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })
  
  # Scraping durchführen
  tournament = create_scrapable_tournament(organizer: regions(:nbv))
  tournament.scrape_single_tournament_public
  
  # Assertions
  assert_tournament_scraped(tournament)
end
```

✅ **Test bereit!**

---

## Schritt 6: Test laufen lassen

```bash
# Einzelner Test
bin/rails test test/scraping/tournament_scraper_test.rb:15

# Oder alle Scraping-Tests
bin/rails test:scraping
```

**Expected Output:**

```
🕷️ Running scraping tests...

Run options: --seed 12345

# Running:

.

Finished in 0.123s, 8.13 runs/s, 12.20 assertions/s.

1 runs, 3 assertions, 0 failures, 0 errors, 0 skips
```

✅ **Test läuft! 🎉**

---

## 🎯 Nächste Schritte

### Option A: Weitere Fixtures sammeln (empfohlen)

Sammle 2 weitere Fixtures für **Change Detection**:

```bash
# 1. Tournament Details (Original)
# URL aus Browser: sb_meisterschaft.php?p=20--2025/2026-2971----1-100000-
pbpaste > test/fixtures/html/tournament_details_nbv_2971.html

# 2. Tournament Details (Modified)
cp test/fixtures/html/tournament_details_nbv_2971.html \
   test/fixtures/html/tournament_details_nbv_2971_modified.html

# 3. Manuell editieren (z.B. Titel ändern)
vim test/fixtures/html/tournament_details_nbv_2971_modified.html
```

**Dann:** Change Detection Tests aktivieren

```ruby
# test/scraping/change_detection_test.rb
# → skip entfernen
```

**Aufwand:** +10 Minuten  
**Ergebnis:** 3 weitere Tests aktiv

### Option B: Alle Scraping-Tests aktivieren

Siehe: `test/FIXTURES_SAMMELN.md`

---

## 📚 Weiterführende Dokumentation

| Dokument | Zweck | Zeit |
|----------|-------|------|
| `test/FIXTURES_QUICK_START.md` | Quick Start (dieses Dokument) | 5 Min |
| `test/FIXTURES_SAMMELN.md` | Vollständige Anleitung | 15 Min |
| `test/fixtures/html/README.md` | Fixture-Verwaltung | 10 Min |
| `test/README.md` | Test-Konzept | 20 Min |

---

## 🛠️ Rake Tasks

```bash
# URLs für Fixtures anzeigen
bin/rails test:show_fixture_urls

# Interaktiv Fixtures sammeln
bin/rails test:collect_fixtures

# Gesammelte Fixtures auflisten
bin/rails test:list_fixtures

# Fixtures validieren
bin/rails test:validate_fixtures
```

---

## 🐛 Troubleshooting

### "No such file or directory"

```bash
# Prüfen ob Fixture existiert
ls -l test/fixtures/html/tournament_list_nbv_2025_2026.html

# Falls nicht: Nochmal kopieren
pbpaste > test/fixtures/html/tournament_list_nbv_2025_2026.html
```

### "Fixture ist leer"

```bash
# Größe prüfen
ls -lh test/fixtures/html/tournament_list_nbv_2025_2026.html

# Falls 0 KB: Neu aus Browser kopieren
```

### Test schlägt weiter fehl

```bash
# Test im Detail ansehen
bin/rails test test/scraping/tournament_scraper_test.rb --verbose

# Oder mit Debug-Output
TESTOPTS="--verbose" bin/rails test:scraping
```

---

## 📞 Support

**Fragen?**

- 📖 Vollständige Anleitung: `test/FIXTURES_SAMMELN.md`
- 🐛 GitHub Issue erstellen (Label: `testing`)
- 💬 GitHub Discussions

---

**Geschafft! Sie haben Ihre erste Scraping-Fixture gesammelt! 🎉**

**Nächster Schritt:** Weitere Fixtures sammeln oder Change Detection Tests aktivieren.
