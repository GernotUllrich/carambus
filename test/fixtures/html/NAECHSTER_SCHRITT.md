# 🎯 Nächster Schritt: Tournament Details Fixture sammeln

## ✅ Was bereits funktioniert

- `tournament_list_nbv_2025_2026.html` ✓ (37 KB)
- Test `tournament list HTML fixture can be loaded` ✓

## 📋 Was noch fehlt

Um die restlichen Scraping-Tests zu aktivieren, benötigen Sie **Tournament Details** Fixtures.

## 🚀 So sammeln Sie Tournament Details

### Schritt 1: cc_id aus der Tournament-Liste identifizieren

Öffnen Sie die gesammelte Liste:

```bash
open test/fixtures/html/tournament_list_nbv_2025_2026.html
```

**Oder schauen Sie direkt im Browser:**

```bash
open https://ndbv.de/sb_meisterschaft.php?p=20--2025/2026--0--2-1-100000-
```

**Suchen Sie ein Turnier** und notieren Sie die `cc_id` aus dem Link:

Beispiel-Link in der Liste:
```
sb_meisterschaft.php?p=20--2025/2026-2971----1-100000-
                                      ^^^^
                                      cc_id = 2971
```

### Schritt 2: Tournament Details URL öffnen

**WICHTIG:** Details-URL hat **4 Striche** nach der cc_id!

```bash
# ⚠️  ACHTUNG: 4 Striche (----) nach cc_id!
# Liste:   sb_meisterschaft.php?p=20--2025/2026--0--2-1-100000-     (2 Striche)
# Details: sb_meisterschaft.php?p=20--2025/2026-2971----1-100000-  (4 Striche)
#                                                   ^^^^
#                                                   Diese!

# Ersetze 2971 mit der cc_id aus Schritt 1
open https://ndbv.de/sb_meisterschaft.php?p=20--2025/2026-2971----1-100000-
```

**Verifikation:** Die Detail-Seite sollte haben:
- Titel des Turniers als Überschrift
- Tabelle mit "Kürzel", "Datum", "Location", "Meldeschluss" etc.
- Einen `<aside>` Bereich mit Details

### Schritt 3: HTML aus DevTools kopieren

1. **DevTools öffnen:** `Cmd + Option + I` (Mac) oder `F12` (Windows)
2. **Network Tab** wählen
3. **Seite neu laden:** `Cmd + R`
4. **Erste Zeile** (Document) anklicken
5. **Response Tab** → Rechtsklick → **"Copy response"**

### Schritt 4: Fixture speichern

```bash
cd test/fixtures/html

# Ersetze 2971 mit der cc_id aus Schritt 1
pbpaste > tournament_details_nbv_2971.html

# Verifizieren
ls -lh tournament_details_nbv_2971.html
head -5 tournament_details_nbv_2971.html
```

### Schritt 5: Test aktivieren

Editieren Sie `test/scraping/tournament_scraper_test.rb`:

```ruby
test "scraping extracts tournament details" do
  # skip entfernen!
  
  # Fixture laden (mit korrekter cc_id)
  html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html'))
  
  # HTTP Request mocken (WICHTIG: ndbv.de, nicht nbv.clubcloud.de!)
  stub_request(:get, %r{ndbv\.de/sb_meisterschaft\.php})
    .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })
  
  # Tournament mit tournament_cc erstellen
  tournament = create_scrapable_tournament(organizer: @region)
  tournament_cc = TournamentCc.create!(
    tournament: tournament,
    cc_id: 2971,  # WICHTIG: Gleiche cc_id wie in Fixture!
    context: @region.shortname
  )
  
  # Scraping durchführen
  tournament.scrape_single_tournament_public
  
  # Assertions
  assert_tournament_scraped(tournament)
  assert_not_nil tournament.reload.title, "Title should be scraped"
end
```

### Schritt 6: Test laufen lassen

```bash
bin/rails test test/scraping/tournament_scraper_test.rb:34
```

**Expected:** Test läuft und ist grün ✅

## 🎨 Optional: Modified Fixture für Change Detection

Erstellen Sie eine geänderte Version:

```bash
cp tournament_details_nbv_2971.html tournament_details_nbv_2971_modified.html

# Editieren Sie die Datei und ändern Sie z.B. den Titel
vim tournament_details_nbv_2971_modified.html
# Suche nach <h1> oder <title> und ändere den Text leicht
```

Dann können Sie Change Detection Tests aktivieren!

## 📊 Aktueller Status

```bash
bin/rails test:scraping
```

**Vorher:**
```
14 runs, 7 assertions, 1 failure, 0 errors, 10 skips ❌
```

**Nach Fixture-Sammlung (Ziel):**
```
14 runs, X assertions, 0 failures, 0 errors, Y skips ✅
```

## 💡 Quick Commands

```bash
# URLs anzeigen
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# Fixtures validieren
bin/rails test:validate_fixtures

# Nur Tournament Tests
bin/rails test test/scraping/tournament_scraper_test.rb

# Alle Scraping Tests
bin/rails test:scraping
```

## 🐛 Troubleshooting

### "Fixture not found"

```bash
# Prüfen ob Datei existiert
ls -l test/fixtures/html/tournament_details_nbv_2971.html

# Pfad im Test prüfen
Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html')
```

### "WebMock stub nicht getriggert"

Stelle sicher:
- Domain ist `ndbv.de` (nicht `nbv.clubcloud.de`)
- Pattern matched: `%r{ndbv\.de/sb_meisterschaft\.php}`

### "sync_date should be set"

Das Tournament braucht ein `tournament_cc` mit `cc_id`:

```ruby
tournament_cc = TournamentCc.create!(
  tournament: tournament,
  cc_id: 2971,  # aus Fixture
  context: @region.shortname
)
```

## 📚 Weiterführende Dokumentation

- **Quick Start:** `test/FIXTURES_QUICK_START.md`
- **Vollständige Anleitung:** `test/FIXTURES_SAMMELN.md`
- **Workflow:** `test/FIXTURE_WORKFLOW.md`

---

**Nächster Schritt:** Sammle `tournament_details_nbv_XXXX.html` und aktiviere weitere Tests! 🚀
