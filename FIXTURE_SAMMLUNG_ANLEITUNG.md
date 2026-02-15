# 📸 ClubCloud Fixtures sammeln - Zusammenfassung

**Erstellt am:** 2026-02-14  
**Status:** ✅ Dokumentation komplett, bereit zum Sammeln

---

## 🎯 Was wurde erstellt?

Ich habe ein **vollständiges System zum Sammeln und Verwenden von ClubCloud HTML Fixtures** erstellt:

### 📚 Dokumentation (4 neue Dokumente)

1. **[test/FIXTURES_QUICK_START.md](test/FIXTURES_QUICK_START.md)**
   - 5-Minuten Schnellstart
   - Schritt-für-Schritt mit Checkboxen
   - Perfekt für den ersten Fixture-Sammlung

2. **[test/FIXTURES_SAMMELN.md](test/FIXTURES_SAMMELN.md)**
   - Vollständige Anleitung (60 Seiten)
   - Alle Scraping-Entitäten (Tournaments, Leagues, Clubs, Players)
   - Browser DevTools Methode
   - Edge Cases & Troubleshooting

3. **[test/fixtures/html/README.md](test/fixtures/html/README.md)**
   - Fixture-Verwaltung
   - Namenskonventionen
   - Verwendung in Tests
   - Security Best Practices

4. **[test/FIXTURE_WORKFLOW.md](test/FIXTURE_WORKFLOW.md)**
   - Visueller ASCII-Art Workflow
   - Diagramme für alle Prozesse
   - Learning Path für Contributors
   - Quick Commands Reference

### ⚙️ Rake Tasks (4 neue Tasks)

```bash
# URLs für Fixtures anzeigen
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# Interaktiv Fixtures sammeln (mit Prompts)
bin/rails test:collect_fixtures

# Gesammelte Fixtures auflisten
bin/rails test:list_fixtures

# Fixtures validieren (HTML-Struktur prüfen)
bin/rails test:validate_fixtures
```

**Datei:** `lib/tasks/test_fixtures.rake`

### 📁 Verzeichnisstruktur

```
test/fixtures/html/
├── .gitkeep               # Git-Verzeichnis-Placeholder
└── README.md              # Fixture-Dokumentation
```

Bereit für Fixtures:
```
test/fixtures/html/
├── tournaments/
│   ├── list_nbv_2025_2026.html
│   ├── details_nbv_2971.html
│   └── details_nbv_2971_modified.html
├── leagues/
├── clubs/
└── regions/
```

---

## 🚀 Nächste Schritte für Sie

### Schritt 1: Quick Start lesen (5 Min)

```bash
cat test/FIXTURES_QUICK_START.md
```

Oder im Editor:
```bash
vim test/FIXTURES_QUICK_START.md
```

### Schritt 2: Erste Fixture sammeln (15 Min)

```bash
# 1. URLs anzeigen
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# 2. Browser öffnen mit der URL
# 3. DevTools → Network → Response kopieren
# 4. Speichern:
mkdir -p test/fixtures/html
cd test/fixtures/html
pbpaste > tournament_list_nbv_2025_2026.html

# 5. Verifizieren
head -10 tournament_list_nbv_2025_2026.html
```

### Schritt 3: Test aktivieren (5 Min)

```ruby
# test/scraping/tournament_scraper_test.rb
# → skip Zeilen entfernen
# → Fixture einbinden (siehe Quick Start)
```

### Schritt 4: Tests laufen lassen

```bash
bin/rails test:scraping
```

**Expected:** Tests laufen (einige noch `skip`)

---

## 📋 Empfohlene Reihenfolge

### Phase 1: Minimum (heute, 15 Min)

**3 Fixtures sammeln:**

1. `tournament_list_nbv_2025_2026.html`
2. `tournament_details_nbv_2971.html`
3. `tournament_details_nbv_2971_modified.html`

**Ergebnis:**
- 7 Tournament Scraper Tests können aktiviert werden
- Change Detection Tests funktionieren

### Phase 2: Erweitert (später, +30 Min)

**+3 Fixtures sammeln:**

4. `league_list_nbv_2025_2026.html`
5. `league_details_oberliga_nbv.html`
6. `club_bcw_players_2025_2026.html`

**Ergebnis:**
- Alle 14 Scraping-Tests voll funktional
- Vollständige Abdeckung

### Phase 3: Optional (bei Bedarf)

- Edge Cases (leere Listen, Fehlerseiten)
- Weitere Regions (BBV, WBV, etc.)
- Historische Fixtures (Season 2024/2025)

---

## 🎯 Welche Fixtures für welche Tests?

### Concern Tests (✅ bereits fertig)

```bash
bin/rails test:critical
```

**Status:** Alle 14 Tests laufen ✅

- `test/concerns/local_protector_test.rb` (8 Tests)
- `test/concerns/source_handler_test.rb` (6 Tests)

**Keine Fixtures benötigt!**

### Scraping Tests (⏸️ warten auf Fixtures)

```bash
bin/rails test:scraping
```

**Status:** 14 Tests, alle mit `skip` markiert

#### Tournament Scraper (7 Tests)

**Benötigt:**
- `tournament_list_nbv_2025_2026.html`
- `tournament_details_nbv_2971.html`

**Tests:**
```ruby
test/scraping/tournament_scraper_test.rb
├─▶ test_scraping_extracts_tournament_details
├─▶ test_scraping_creates_tournament_cc_record
├─▶ test_scraping_handles_missing_fields_gracefully
├─▶ test_scraping_updates_existing_tournament
├─▶ test_scraping_multiple_tournaments
├─▶ test_scraping_respects_abandoned_tournaments
└─▶ test_scraping_with_vcr
```

#### Change Detection (7 Tests)

**Benötigt:**
- `tournament_details_nbv_2971.html` (Original)
- `tournament_details_nbv_2971_modified.html` (Geändert)

**Tests:**
```ruby
test/scraping/change_detection_test.rb
├─▶ test_detects_changed_tournament_title
├─▶ test_detects_changed_location
├─▶ test_detects_new_seedings
├─▶ test_sync_date_updates_on_changes
├─▶ test_sync_date_unchanged_when_no_changes
├─▶ test_tracks_changes_across_multiple_scrapes
└─▶ test_change_detection_with_vcr
```

---

## 💡 Tipps für effizientes Sammeln

### 1. Batch-Sammlung (mehrere Tabs öffnen)

```bash
# URLs anzeigen lassen
bin/rails test:show_fixture_urls

# Im Browser:
# - Tab 1: Tournament Liste
# - Tab 2: Tournament Details (id=2971)
# - Tab 3: Tournament Details (id=3142)

# DevTools in allen Tabs öffnen
# Alle auf einmal kopieren und speichern
```

### 2. URL-Pattern verstehen

**Tournament Liste:**
```
https://ndbv.de/sb_meisterschaft.php?
  p=20--2025/2026--0--2-1-100000-
    ^^  ^^^^^^^^
    |   |
    |   └─ Season
    └─ region_cc_id
```

**Tournament Details:**
```
https://ndbv.de/sb_meisterschaft.php?
  p=20--2025/2026-2971----1-100000-
    ^^  ^^^^^^^^  ^^^^
    |   |         |
    |   |         └─ Tournament cc_id
    |   └─ Season
    └─ region_cc_id
```

### 3. Modified Fixture erstellen

```bash
# Option A: Kopieren und manuell editieren
cp tournament_details_nbv_2971.html \
   tournament_details_nbv_2971_modified.html

vim tournament_details_nbv_2971_modified.html
# Titel ändern: "Norddeutsche" → "Norddeutsche 2025"

# Option B: Mit sed
cp tournament_details_nbv_2971.html \
   tournament_details_nbv_2971_modified.html

sed -i '' 's/Norddeutsche Meisterschaft/Norddeutsche Meisterschaft 2025/g' \
  tournament_details_nbv_2971_modified.html
```

---

## 📊 Aktueller Test-Status

### ✅ Funktionierende Tests (ohne Fixtures)

```bash
bin/rails test:critical

# Output:
🔥 Running critical tests...
🔧 Running concern tests...
14 runs, 31 assertions, 0 failures, 0 errors, 0 skips ✅

🕷️ Running scraping tests...
14 runs, 0 assertions, 0 failures, 0 errors, 14 skips ⏸️
```

**Concern Tests:** 14 Tests ✅ (100% pass)  
**Scraping Tests:** 14 Tests ⏸️ (100% skip, warten auf Fixtures)

### 🎯 Nach Fixture-Sammlung (Ziel)

```bash
bin/rails test:critical

# Expected Output:
🔥 Running critical tests...
🔧 Running concern tests...
14 runs, 31 assertions, 0 failures, 0 errors, 0 skips ✅

🕷️ Running scraping tests...
14 runs, 42 assertions, 0 failures, 0 errors, 0 skips ✅
```

**Alle Tests:** 28 Tests ✅ (100% pass)

---

## 🔍 So identifizieren Sie die richtigen Fixtures

### Methode 1: Aus daily_update Task ableiten

```ruby
# lib/tasks/scrape.rake - daily_update zeigt alle Scraping-Operationen:

1. Region.scrape_regions
   └─▶ Fixture: region_nbv_home.html

2. Location.scrape_locations
   └─▶ Fixture: location_list_nbv.html

3. Club.scrape_clubs (inkl. Players)
   └─▶ Fixture: club_bcw_players_2025_2026.html

4. Tournament.scrape_single_tournaments_public_cc
   └─▶ Fixtures:
       - tournament_list_nbv_2025_2026.html
       - tournament_details_nbv_2971.html

5. League.scrape_leagues_from_cc
   └─▶ Fixtures:
       - league_list_nbv_2025_2026.html
       - league_details_oberliga_nbv.html
```

### Methode 2: Aus Test-Code ableiten

```ruby
# test/scraping/tournament_scraper_test.rb

test "scraping extracts tournament details" do
  # Diese Fixture wird benötigt:
  html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html'))
  #                                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #                                                    Diese Datei sammeln!
end
```

### Methode 3: Live-System beobachten

```bash
# Rails Console
bin/rails console

# Scraping durchführen und URLs loggen:
season = Season.find_by_name("2025/2026")
region = Region.find_by_shortname("NBV")

# URLs die gescraped werden:
tournament = season.tournaments.first
puts tournament.tournament_cc_url
# → Diese URL im Browser öffnen und HTML sammeln
```

---

## 🎓 Für Contributors / Open Source

### Good First Issue: Fixture sammeln

**Perfekter Einstieg in das Projekt!**

**Aufgabe:**
1. `test/FIXTURES_QUICK_START.md` lesen (5 Min)
2. 1 Fixture sammeln (15 Min)
3. Test aktivieren (Skip entfernen)
4. Pull Request erstellen

**Labels:**
- `good first issue`
- `testing`
- `scraping`
- `documentation`

**Lerneffekt:**
- Rails Testing Framework (Minitest)
- WebMock & HTTP Stubbing
- Nokogiri HTML Parsing
- ClubCloud API-Struktur

### Issue Template

```markdown
## 📸 Fixture sammeln: [Entity-Name]

**Beschreibung:**
Sammle ClubCloud HTML Fixture für [Tournament Liste / Details / etc.]

**Fixture:**
- [ ] Datei: `test/fixtures/html/tournament_list_nbv_2025_2026.html`
- [ ] URL: (siehe `bin/rails test:show_fixture_urls`)

**Test aktivieren:**
- [ ] Skip entfernen in `test/scraping/tournament_scraper_test.rb`
- [ ] Fixture einbinden (siehe Quick Start)

**Dokumentation:**
- [FIXTURES_QUICK_START.md](test/FIXTURES_QUICK_START.md)

**Aufwand:** 15-30 Minuten  
**Labels:** `good first issue`, `testing`, `scraping`
```

---

## 🔒 Security Checklist

**Vor jedem Commit:**

```bash
# 1. Nach sensiblen Daten suchen
grep -ri "password" test/fixtures/html/
grep -ri "session" test/fixtures/html/
grep -ri "token" test/fixtures/html/
grep -ri "cookie" test/fixtures/html/

# 2. Falls gefunden: Manuell ersetzen
vim test/fixtures/html/problematic_fixture.html
# password="real123" → password="<CC_PASSWORD>"

# 3. Git-Status prüfen
git diff test/fixtures/html/

# 4. Commit nur wenn clean
git add test/fixtures/html/
git commit -m "Add: ClubCloud fixtures for tournament scraping"
```

---

## 📚 Alle Dokumentations-Dateien

| Datei | Beschreibung | Größe |
|-------|-------------|-------|
| `test/FIXTURES_QUICK_START.md` | 5-Min Quick Start | ~3 KB |
| `test/FIXTURES_SAMMELN.md` | Vollständige Anleitung | ~25 KB |
| `test/fixtures/html/README.md` | Fixture-Verwaltung | ~12 KB |
| `test/FIXTURE_WORKFLOW.md` | ASCII-Art Workflow | ~8 KB |
| `test/README.md` | Test-Guide (aktualisiert) | ~15 KB |
| `lib/tasks/test_fixtures.rake` | Rake Tasks | ~8 KB |
| **GESAMT** | | **~71 KB** |

---

## 🎯 Zusammenfassung

### ✅ Was ist fertig?

- [x] Vollständige Dokumentation (4 Guides)
- [x] 4 Rake Tasks für Fixture-Management
- [x] Verzeichnisstruktur vorbereitet
- [x] Test-Framework bereit
- [x] 14 Concern Tests laufen ✅
- [x] 14 Scraping Tests vorbereitet (mit `skip`)

### ⏸️ Was fehlt noch?

- [ ] ClubCloud HTML Fixtures sammeln (15-30 Min)
- [ ] Scraping Tests aktivieren (`skip` entfernen)
- [ ] Tests laufen lassen und validieren

### 🚀 Empfohlener nächster Schritt

```bash
# 1. Quick Start lesen (5 Min)
cat test/FIXTURES_QUICK_START.md

# 2. URLs anzeigen
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# 3. Im Browser öffnen, HTML kopieren, speichern
mkdir -p test/fixtures/html
# ... DevTools → Copy Response
pbpaste > test/fixtures/html/tournament_list_nbv_2025_2026.html

# 4. Verifizieren
bin/rails test:validate_fixtures

# 5. Test aktivieren
vim test/scraping/tournament_scraper_test.rb
# → skip entfernen

# 6. Testen
bin/rails test:scraping
```

---

## 💬 Fragen?

**Dokumentation konsultieren:**
- Quick Start: `test/FIXTURES_QUICK_START.md`
- Vollständig: `test/FIXTURES_SAMMELN.md`
- Workflow: `test/FIXTURE_WORKFLOW.md`

**GitHub:**
- Issues (Label: `testing`)
- Discussions

---

**Status:** ✅ Bereit zum Sammeln!  
**Nächster Schritt:** [FIXTURES_QUICK_START.md](test/FIXTURES_QUICK_START.md)

🎉 **Viel Erfolg beim Fixture-Sammeln!**
