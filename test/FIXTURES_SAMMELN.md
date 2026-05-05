# 📸 ClubCloud Fixtures systematisch sammeln

**Anleitung zum Sammeln von HTML/JSON Fixtures für Scraping-Tests**

## 🎯 Übersicht

Die `scrape:daily_update` Task zeigt alle Scraping-Operationen:

```ruby
# lib/tasks/scrape.rake - daily_update
1. Season.update_seasons
2. Region.scrape_regions
3. Location.scrape_locations  
4. Club.scrape_clubs (inkl. Players)
5. Tournament.scrape_single_tournaments_public_cc
6. League.scrape_leagues_from_cc
```

## 📋 Scraping-Hierarchie

```
ClubCloud
│
├── 1️⃣ Regions (Bundesverbände)
│   ├── NBV (Niedersachsen)
│   ├── BBV (Bayern)
│   └── ...
│
├── 2️⃣ Seasons (Spielzeiten)
│   ├── 2024/2025
│   ├── 2025/2026
│   └── ...
│
├── 3️⃣ Locations (Spielorte)
│   ├── BC Wedel
│   ├── BC Hamburg
│   └── ...
│
├── 4️⃣ Clubs (Vereine)
│   ├── BC Wedel 61 e.V.
│   ├── Players (Spieler)
│   │   ├── Name, DBU-Nr
│   │   └── SeasonParticipation
│   └── ...
│
├── 5️⃣ Tournaments (Turniere)
│   ├── Tournament Details
│   ├── Seedings (Meldungen)
│   └── Games (Spiele & Ergebnisse)
│
└── 6️⃣ Leagues (Ligen)
    ├── League Details
    ├── LeagueTeams (Mannschaften)
    ├── Parties (Spieltage)
    └── PartyGames (Einzelspiele)
```

## 🛠️ Methode 1: Browser DevTools (Empfohlen)

### Vorbereitung

1. Browser öffnen (Chrome/Firefox)
2. DevTools öffnen (F12)
3. Network Tab öffnen
4. "Preserve Log" aktivieren

### Fixtures sammeln

#### 1. Region-Liste

**URL:** `https://ndbv.de/` (oder andere Region)

**Schritte:**
```bash
# 1. In Browser öffnen
open https://ndbv.de/

# 2. DevTools → Network → Reload-Seite
# 3. Response der Haupt-HTML kopieren
# 4. Speichern als:
test/fixtures/html/region_nbv_home.html
```

**Was wird getestet:**
- Region-Name, Shortname
- Region-URL
- Verfügbare Sparten (Branches)

#### 2. Tournament-Liste

**URL:** `https://ndbv.de/sb_meisterschaft.php?p=20--2025--0--2-1-100000-`

**Schritte:**
```bash
# 1. URL in Browser öffnen
# 2. DevTools → Network → Response kopieren
# 3. Speichern als:
test/fixtures/html/tournament_list_nbv_2025.html
```

**Was wird getestet:**
- Liste aller Turniere einer Region/Season
- Tournament-IDs (cc_id)
- Tournament-Namen

#### 3. Tournament Details

**URL:** `https://ndbv.de/sb_meisterschaft.php?p=20--2025-123----1-100000-`

**Schritte:**
```bash
# 1. Konkretes Turnier öffnen (cc_id bekannt)
# 2. DevTools → Network → Response kopieren
# 3. Speichern als:
test/fixtures/html/tournament_details_nbv_123.html
```

**Was wird getestet:**
- Tournament Details (Datum, Ort, Meldeschluss)
- Seedings (Teilnehmer)
- Games (Spiele & Ergebnisse)
- Groups (Gruppen)

#### 4. League-Liste

**URL:** Via Region-Homepage → Ligen-Bereich

**Schritte:**
```bash
# 1. Liga-Übersicht öffnen
# 2. DevTools → Network → Response kopieren
# 3. Speichern als:
test/fixtures/html/league_list_nbv_2025.html
```

#### 5. League Details

**URL:** Konkrete Liga-Seite

**Schritte:**
```bash
# 1. Einzelne Liga öffnen (z.B. Oberliga)
# 2. DevTools → Network → Response kopieren
# 3. Speichern als:
test/fixtures/html/league_details_oberliga_2025.html
```

**Was wird getestet:**
- League Teams (Mannschaften)
- Parties (Spieltage)
- Party Games (Einzelspiele)
- Standings (Tabelle)

#### 6. Club & Player Details

**URL:** Club-Seite in ClubCloud

**Schritte:**
```bash
# 1. Club-Seite öffnen (z.B. BC Wedel)
# 2. DevTools → Network → Response kopieren
# 3. Speichern als:
test/fixtures/html/club_bcw_players_2025.html
```

**Was wird getestet:**
- Player-Liste
- SeasonParticipation (Aktiv/Passiv)
- Player Details (Name, DBU-Nr, etc.)

#### 7. Location-Liste

**URL:** Locations-Übersicht

**Schritte:**
```bash
# 1. Locations öffnen
# 2. DevTools → Network → Response kopieren
# 3. Speichern als:
test/fixtures/html/location_list_nbv.html
```

## 🛠️ Methode 2: cURL mit Recording (Automatisiert)

### VCR Recording Script

Erstellen Sie `test/scripts/record_fixtures.rb`:

```ruby
# test/scripts/record_fixtures.rb
require 'vcr'
require 'webmock'

# VCR muss konfiguriert sein
require_relative '../support/vcr_setup'

# Fixtures aufnehmen
fixtures = {
  'region_nbv_home' => 'https://ndbv.de/',
  'tournament_list_nbv_2025' => 'https://ndbv.de/sb_meisterschaft.php?p=20--2025--0--2-1-100000-',
  # ... weitere URLs
}

fixtures.each do |name, url|
  VCR.use_cassette(name, record: :new_episodes) do
    puts "Recording: #{name}"
    response = Net::HTTP.get(URI(url))
    File.write("test/fixtures/html/#{name}.html", response)
    puts "  ✅ Saved to test/fixtures/html/#{name}.html"
  end
end
```

**Ausführen:**
```bash
cd test/scripts
ruby record_fixtures.rb
```

## 🛠️ Methode 3: Rake Task zum Sammeln (Empfohlen!)

Ich erstelle Ihnen einen Rake Task der die wichtigsten Fixtures automatisch sammelt:

```bash
# lib/tasks/test_fixtures.rake
namespace :test do
  desc "Collect ClubCloud HTML fixtures for testing"
  task collect_fixtures: :environment do
    require 'fileutils'
    
    html_dir = Rails.root.join('test', 'fixtures', 'html')
    FileUtils.mkdir_p(html_dir)
    
    season = Season.find_by_name("2025/2026")
    region = Region.find_by_shortname("NBV")
    
    puts "📸 Collecting ClubCloud Fixtures..."
    puts
    
    # 1. Region Home
    puts "1️⃣  Region Home..."
    # ... Code zum Speichern
    
    # 2. Tournament List
    puts "2️⃣  Tournament List..."
    # ... Code zum Speichern
    
    puts
    puts "✅ Fixtures collected!"
    puts "📁 Location: #{html_dir}"
  end
end
```

## 📝 Empfohlene Fixture-Sammlung

### Minimum für Tests (Phase 1)

```
test/fixtures/html/
├── region_nbv_home.html                 # Region-Übersicht
├── tournament_list_nbv_2025.html        # Tournament-Liste
├── tournament_details_nbv_123.html      # Ein komplettes Turnier
└── tournament_details_nbv_456.html      # Ein Turnier mit Änderungen
```

**Aufwand:** ~15 Minuten

### Erweitert für vollständige Tests (Phase 2)

```
test/fixtures/html/
├── Regions
│   ├── region_nbv_home.html
│   ├── region_bbv_home.html
│   └── region_list.html
│
├── Tournaments
│   ├── tournament_list_nbv_2025.html
│   ├── tournament_details_nbv_123.html
│   ├── tournament_details_nbv_123_updated.html  # Gleiche, aber geändert
│   ├── tournament_with_results.html
│   └── tournament_without_location.html
│
├── Leagues
│   ├── league_list_nbv_2025.html
│   ├── league_details_oberliga.html
│   └── league_standings.html
│
├── Clubs
│   ├── club_list_nbv.html
│   ├── club_bcw_details.html
│   └── club_bcw_players.html
│
└── Locations
    └── location_list_nbv.html
```

**Aufwand:** ~1 Stunde

## 🎯 Praktische Anleitung - Schritt für Schritt

### Schritt 1: Fixture-Verzeichnis erstellen

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
mkdir -p test/fixtures/html
cd test/fixtures/html
```

### Schritt 2: Browser vorbereiten

```bash
# In Browser öffnen:
open https://ndbv.de/
```

1. DevTools öffnen (F12 oder Cmd+Opt+I)
2. Network Tab wählen
3. "Preserve Log" aktivieren
4. "Disable Cache" aktivieren

### Schritt 3: Erste Fixture sammeln

**Tournament-Liste (wichtigste Fixture):**

1. URL öffnen: `https://ndbv.de/sb_meisterschaft.php?p=20--2025--0--2-1-100000-`
2. Warten bis Seite geladen
3. DevTools → Network → Erste Zeile (Document) anklicken
4. Response Tab → Rechtsklick → "Copy response"
5. Terminal:

```bash
pbpaste > tournament_list_nbv_2025.html
```

6. Verifizieren:

```bash
head -20 tournament_list_nbv_2025.html
# Sollte HTML zeigen
```

### Schritt 4: Tournament Details sammeln

1. Aus der Liste ein Turnier anklicken
2. URL notieren (enthält cc_id): `...p=20--2025-123----1-100000-`
3. DevTools → Network → Response kopieren
4. Terminal:

```bash
pbpaste > tournament_details_nbv_123.html
```

### Schritt 5: Fixture mit Änderungen

**Wichtig für Change Detection Tests!**

**Option A: Warten auf echte Änderung**
- Turnier in 1 Woche nochmal scrapen
- Vergleichen

**Option B: Manuell modifizieren**
```bash
# Kopie erstellen
cp tournament_details_nbv_123.html tournament_details_nbv_123_modified.html

# Mit Editor öffnen
vim tournament_details_nbv_123_modified.html

# Titel ändern:
# <h1>Norddeutsche Meisterschaft</h1>
# →
# <h1>Norddeutsche Meisterschaft 2025</h1>
```

### Schritt 6: In Tests verwenden

```ruby
# test/scraping/tournament_scraper_test.rb
test "scraping extracts tournament details" do
  # skip "Requires real ClubCloud HTML fixture"  # ← ENTFERNEN
  
  html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_123.html'))
  
  # Mock the HTTP request
  stub_request(:get, /nbv\.clubcloud\.de.*sb_meisterschaft/)
    .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })
  
  tournament = create_scrapable_tournament(organizer: regions(:nbv))
  tournament.scrape_single_tournament_public
  
  assert_tournament_scraped(tournament)
end
```

## 🤖 Automatisierte Fixture-Sammlung (Advanced)

Ich erstelle einen Rake Task der Fixtures automatisch sammelt:

```bash
# Fixtures sammeln
bin/rails test:collect_fixtures

# Mit spezifischer Region
bin/rails test:collect_fixtures REGION=NBV SEASON=2025/2026

# Nur Tournaments
bin/rails test:collect_fixtures TYPE=tournaments
```

### Task-Code

Siehe `lib/tasks/test_fixtures.rake` (wird gleich erstellt)

## 📊 Prioritäten

### 🔥 Kritisch (für erste funktionierende Tests)

1. **Tournament List** - 1 Fixture
   - `tournament_list_nbv_2025.html`
   - Testet: Liste parsen, cc_ids extrahieren

2. **Tournament Details** - 2 Fixtures
   - `tournament_details_nbv_123.html` (Original)
   - `tournament_details_nbv_123_modified.html` (Geändert)
   - Testet: Details parsen, Change Detection

**Aufwand:** 15 Minuten  
**Ergebnis:** 7 Skip-Tests können aktiviert werden

### 📦 Wichtig (für vollständige Abdeckung)

3. **League Details** - 1 Fixture
   - `league_details_oberliga.html`
   - Testet: Liga-Scraping

4. **Club & Players** - 1 Fixture
   - `club_bcw_players.html`
   - Testet: Spieler-Scraping

**Aufwand:** +30 Minuten  
**Ergebnis:** Alle Scraping-Tests aktiv

### 🎨 Optional (für Edge Cases)

5. **Edge Cases**
   - Tournament ohne Location
   - Tournament mit geänderten Feldern
   - Leere Listen

**Aufwand:** +30 Minuten  
**Ergebnis:** Robuste Tests

## 🗂️ Fixture-Organisation

### Namenskonvention

```
{entity}_{region}_{identifier}_{variant}.html

Beispiele:
tournament_list_nbv_2025.html           # Liste
tournament_details_nbv_123.html         # Details, original
tournament_details_nbv_123_modified.html # Details, geändert
league_details_oberliga_nbv.html        # Liga
club_bcw_players_2025.html              # Club mit Spielern
```

### Verzeichnis-Struktur

```
test/fixtures/html/
├── README.md                    # Diese Anleitung
├── tournaments/
│   ├── list_nbv_2025.html
│   ├── details_123.html
│   ├── details_123_modified.html
│   └── details_456.html
├── leagues/
│   ├── list_nbv_2025.html
│   └── details_oberliga.html
├── clubs/
│   └── bcw_players_2025.html
└── regions/
    └── nbv_home.html
```

## 💻 Praktisches Beispiel

### Beispiel: Tournament Details Fixture

**1. URL identifizieren:**

Aus `app/models/tournament.rb`:
```ruby
tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}-#{tournament_cc_id}----1-100000-"
```

Beispiel: `https://ndbv.de/sb_meisterschaft.php?p=20--2025-2971----1-100000-`

**2. Im Browser öffnen:**
```bash
open "https://ndbv.de/sb_meisterschaft.php?p=20--2025-2971----1-100000-"
```

**3. HTML speichern:**

DevTools → Network → Response → Copy → Terminal:
```bash
cd test/fixtures/html
pbpaste > tournament_details_nbv_2971.html
```

**4. In Test verwenden:**

```ruby
test "scraping extracts tournament details from NBV" do
  html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html'))
  
  stub_request(:get, %r{nbv\.clubcloud\.de/sb_meisterschaft\.php})
    .to_return(status: 200, body: html)
  
  tournament = Tournament.create!(
    id: 50_000_100,
    title: "Test Tournament",
    season: seasons(:current),
    organizer: regions(:nbv),
    organizer_type: "Region"
  )
  
  tournament.scrape_single_tournament_public
  
  assert_not_nil tournament.title
  assert_not_nil tournament.date
  assert_not_nil tournament.location
end
```

## 🔒 Wichtig: Credentials filtern!

### Automatische Filterung durch VCR

VCR ist bereits konfiguriert um zu filtern:
- Usernames → `<CC_USERNAME>`
- Passwords → `<CC_PASSWORD>`
- Session IDs → `<CC_SESSION>`

### Manuelle Prüfung

Vor dem Commit prüfen:

```bash
# In Fixture-Datei suchen
grep -i "password" test/fixtures/html/*.html
grep -i "session" test/fixtures/html/*.html
grep -i "token" test/fixtures/html/*.html

# Falls gefunden: Manuell ersetzen
```

### .gitignore für sensitive Fixtures

```bash
# .gitignore
# Ignore fixtures with real credentials
test/fixtures/html/*_sensitive.html
test/snapshots/vcr/*_auth*.yml
```

## 📋 Checkliste: Fixture-Sammlung

### Minimum für funktionierende Tests

- [ ] `tournament_list_nbv_2025.html`
- [ ] `tournament_details_nbv_123.html`
- [ ] `tournament_details_nbv_123_modified.html`

**Dann:**
- [ ] Skip aus `tournament_scraper_test.rb` entfernen
- [ ] Skip aus `change_detection_test.rb` entfernen
- [ ] Tests laufen lassen: `bin/rails test:scraping`

### Erweitert

- [ ] `league_list_nbv_2025.html`
- [ ] `league_details_oberliga.html`
- [ ] `club_bcw_players.html`
- [ ] `location_list_nbv.html`

## 🚀 Quick Start: Erste Fixture in 5 Minuten

```bash
# 1. Verzeichnis erstellen
mkdir -p test/fixtures/html

# 2. Browser öffnen
open "https://ndbv.de/sb_meisterschaft.php?p=20--2025--0--2-1-100000-"

# 3. DevTools → Network → Response kopieren (Cmd+C)

# 4. Im Terminal:
cd test/fixtures/html
pbpaste > tournament_list_nbv_2025.html

# 5. Verifizieren
head -10 tournament_list_nbv_2025.html

# 6. Test anpassen
# Siehe test/scraping/tournament_scraper_test.rb
# → skip entfernen
# → Fixture verwenden

# 7. Test laufen lassen
bin/rails test test/scraping/tournament_scraper_test.rb
```

## 🎯 Nächste Schritte

### Phase 1: Sammeln (heute, 15 Min)

```bash
# 1. HTML Verzeichnis erstellen
mkdir -p test/fixtures/html

# 2. Browser DevTools nutzen
# 3. 3 wichtigste Fixtures sammeln:
#    - tournament_list_nbv_2025.html
#    - tournament_details_nbv_123.html
#    - tournament_details_nbv_123_modified.html
```

### Phase 2: Tests aktivieren (heute, 30 Min)

```ruby
# In test/scraping/tournament_scraper_test.rb:
# - skip Zeilen entfernen
# - Fixtures einbinden
# - Tests laufen lassen
```

### Phase 3: Verifikation (heute, 5 Min)

```bash
# Tests sollten grün sein
bin/rails test:scraping

# Erwartetes Ergebnis:
# 14 runs, 14 assertions, 0 failures, 0 errors, 0 skips
```

## 💡 Tipps & Tricks

### Fixture schnell testen

```bash
# Nokogiri Console
bin/rails console

# HTML laden und parsen
html = File.read('test/fixtures/html/tournament_list_nbv_2025.html')
doc = Nokogiri::HTML(html)

# CSS Selectors testen
doc.css('article table.silver tr')
```

### Fixture vergleichen

```bash
# Diff zwischen Original und Modified
diff test/fixtures/html/tournament_details_nbv_123.html \
     test/fixtures/html/tournament_details_nbv_123_modified.html
```

### Fixtures aktualisieren

```bash
# Alte Fixtures löschen
rm test/fixtures/html/tournament_*.html

# Neu sammeln
# (Browser DevTools oder Rake Task)
```

## 📚 Ressourcen

- **daily_update Task:** `lib/tasks/scrape.rake`
- **Scraping Code:** `app/models/tournament.rb#scrape_single_tournament_public`
- **Test Helpers:** `test/support/scraping_helpers.rb`
- **Dokumentation:** `test/README.md`

## 🎓 Für Contributors

**Perfekte Einstiegs-Aufgabe:**

1. Fixture sammeln (15 Min)
2. Test aktivieren (Skip entfernen)
3. Test grün machen
4. Pull Request → Beitrag! 🎉

**Labels für GitHub:**
- `good first issue` - Fixture sammeln
- `testing` - Test-bezogene Issues
- `scraping` - ClubCloud Integration

---

**Nächster Schritt:** Ich erstelle Ihnen jetzt einen automatisierten Rake Task zum Sammeln! 🚀
