# 📸 HTML Fixtures für ClubCloud Scraping Tests

Dieses Verzeichnis enthält HTML-Snapshots von ClubCloud-Seiten für Scraping-Tests.

## 🎯 Zweck

- **Reproduzierbare Tests:** Tests verwenden gespeicherte HTML statt Live-API-Aufrufe
- **Change Detection:** Mehrere Versionen derselben Seite ermöglichen Change-Detection-Tests
- **Offline-Tests:** Tests können ohne Internetzugang laufen
- **Versionskontrolle:** HTML-Änderungen in ClubCloud werden via Git nachvollziehbar

## 📋 Fixtures sammeln

### Quick Start (5 Minuten)

```bash
# 1. URLs anzeigen
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026

# 2. Interaktiv sammeln
bin/rails test:collect_fixtures REGION=NBV SEASON=2025/2026

# 3. Validieren
bin/rails test:validate_fixtures

# 4. Auflisten
bin/rails test:list_fixtures
```

### Manuell sammeln (Browser DevTools)

**Siehe detaillierte Anleitung:** `test/FIXTURES_SAMMELN.md`

**Kurzversion:**

1. URL im Browser öffnen (z.B. ClubCloud Tournament-Liste)
2. DevTools öffnen (F12 oder Cmd+Opt+I)
3. Network Tab → Seite neu laden
4. Erste Zeile (Document) anklicken → Response Tab
5. Rechtsklick → "Copy response"
6. Terminal: `pbpaste > test/fixtures/html/tournament_list_nbv_2025.html`

## 📁 Struktur & Namenskonvention

### Empfohlene Struktur

```
test/fixtures/html/
├── tournaments/
│   ├── list_nbv_2025_2026.html                  # Tournament-Liste
│   ├── details_nbv_2971.html                    # Tournament Details (Original)
│   ├── details_nbv_2971_modified.html           # Geänderte Version (für Change Detection)
│   └── details_nbv_3142.html                    # Weiteres Tournament
│
├── leagues/
│   ├── list_nbv_2025_2026.html                  # Liga-Liste
│   └── details_oberliga_nbv.html                # Liga Details
│
├── clubs/
│   └── bcw_players_2025_2026.html               # Club mit Spielerliste
│
└── regions/
    └── nbv_home.html                            # Region Homepage
```

### Namenskonvention

**Pattern:** `{entity}_{region}_{identifier}_{variant}.html`

**Beispiele:**
- `tournament_list_nbv_2025_2026.html` - Liste aller Turniere
- `tournament_details_nbv_2971.html` - Ein spezifisches Turnier
- `tournament_details_nbv_2971_modified.html` - Geänderte Version
- `league_details_oberliga_nbv.html` - Liga-Details
- `club_bcw_players_2025_2026.html` - Club mit Spielern

## 🔒 Sicherheit & Credentials

### ⚠️ Wichtig: Keine Credentials committen!

Vor dem Commit prüfen:

```bash
# Nach sensiblen Daten suchen
grep -ri "password" test/fixtures/html/
grep -ri "session" test/fixtures/html/
grep -ri "token" test/fixtures/html/
grep -ri "cookie" test/fixtures/html/
```

### VCR Credential Filtering

VCR (für HTTP-Interaktionen) filtert automatisch:
- Usernames → `<CC_USERNAME>`
- Passwords → `<CC_PASSWORD>`
- Sessions → `<CC_SESSION>`

Siehe: `test/support/vcr_setup.rb`

### .gitignore für sensitive Fixtures

Füge zu `.gitignore` hinzu wenn nötig:

```
# .gitignore
test/fixtures/html/*_sensitive.html
test/fixtures/html/*_private.html
```

## 🧪 Fixtures in Tests verwenden

### Beispiel: Tournament Scraper Test

```ruby
# test/scraping/tournament_scraper_test.rb

test "scraping extracts tournament details" do
  # 1. Fixture laden
  html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html'))

  # 2. HTTP Request mocken
  stub_request(:get, %r{nbv\.clubcloud\.de/sb_meisterschaft\.php})
    .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

  # 3. Scraping durchführen
  tournament = create_scrapable_tournament(organizer: regions(:nbv))
  tournament.scrape_single_tournament_public

  # 4. Verifizieren
  assert_not_nil tournament.title
  assert_not_nil tournament.date
  assert_not_nil tournament.location
end
```

### Beispiel: Change Detection Test

```ruby
# test/scraping/change_detection_test.rb

test "detects changed tournament title" do
  # Original
  original_html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html'))
  
  # Geändert
  modified_html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_2971_modified.html'))

  # Erste Scraping
  stub_request(:get, tournament_url)
    .to_return(status: 200, body: original_html)
  tournament.scrape_single_tournament_public
  original_sync_date = tournament.reload.sync_date

  # Zweite Scraping (geänderte Version)
  stub_request(:get, tournament_url)
    .to_return(status: 200, body: modified_html)
  tournament.scrape_single_tournament_public

  # Sync-Date sollte sich geändert haben
  assert_not_equal original_sync_date, tournament.reload.sync_date,
                   "sync_date should update when tournament data changes"
end
```

## 🎯 Prioritäten: Welche Fixtures sammeln?

### 🔥 Kritisch (für funktionierende Tests)

**Minimum - 3 Fixtures:**

1. `tournament_list_nbv_2025_2026.html` - Tournament-Liste
2. `tournament_details_nbv_2971.html` - Ein komplettes Turnier
3. `tournament_details_nbv_2971_modified.html` - Geänderte Version

**Aufwand:** 15 Minuten  
**Ergebnis:** 7 Scraping-Tests können aktiviert werden

### 📦 Wichtig (für vollständige Abdeckung)

**Erweitert - +3 Fixtures:**

4. `league_list_nbv_2025_2026.html` - Liga-Liste
5. `league_details_oberliga_nbv.html` - Liga Details
6. `club_bcw_players_2025_2026.html` - Club mit Spielern

**Aufwand:** +30 Minuten  
**Ergebnis:** Alle Scraping-Tests voll funktional

### 🎨 Optional (für Edge Cases)

**Edge Cases - weitere Fixtures:**

- Tournament ohne Location
- Tournament mit leeren Feldern
- Leere Listen
- Error Pages

**Aufwand:** +30 Minuten  
**Ergebnis:** Robuste Tests für Sonderfälle

## 🛠️ Rake Tasks

### Fixture-Sammlung

```bash
# Interaktiv sammeln (empfohlen für erste Fixtures)
bin/rails test:collect_fixtures

# Mit Parametern
bin/rails test:collect_fixtures REGION=NBV SEASON=2025/2026

# Nur Tournaments
bin/rails test:collect_fixtures TYPE=tournaments

# URLs anzeigen (zum manuellen Sammeln)
bin/rails test:show_fixture_urls REGION=NBV SEASON=2025/2026
```

### Fixture-Management

```bash
# Alle Fixtures auflisten
bin/rails test:list_fixtures

# Fixtures validieren (prüft HTML-Struktur)
bin/rails test:validate_fixtures
```

## 📊 Fixture-Status prüfen

### Gesammelte Fixtures anzeigen

```bash
# Liste mit Details
bin/rails test:list_fixtures

# Oder direkt:
ls -lh test/fixtures/html/
```

### Fixture-Qualität prüfen

```bash
# Validierung (Nokogiri-Parsing)
bin/rails test:validate_fixtures

# Manuell prüfen
head -20 test/fixtures/html/tournament_list_nbv_2025_2026.html

# Nach spezifischem Content suchen
grep -i "Norddeutsche" test/fixtures/html/tournament_details_*.html
```

## 🔄 Fixtures aktualisieren

Wann Fixtures neu sammeln?

- **ClubCloud hat Layout geändert:** Tests schlagen fehl wegen CSS-Selektor-Änderungen
- **Neue Features testen:** Neue Felder in ClubCloud
- **Change Detection validieren:** Reale Änderungen an Turnieren dokumentieren
- **Nach Saison-Wechsel:** Neue Season-Fixtures sammeln

**Prozess:**

```bash
# 1. Alte Fixtures sichern
cp -r test/fixtures/html test/fixtures/html.backup

# 2. Neu sammeln
bin/rails test:collect_fixtures

# 3. Tests laufen lassen
bin/rails test:scraping

# 4. Falls OK: Backup löschen
rm -rf test/fixtures/html.backup
```

## 💻 Entwickler-Tipps

### Fixture schnell analysieren (Rails Console)

```ruby
# Rails Console
bin/rails console

# HTML laden
html = File.read('test/fixtures/html/tournament_list_nbv_2025_2026.html')

# Nokogiri parsen
doc = Nokogiri::HTML(html)

# CSS Selectors testen
doc.css('article table.silver tr').size
doc.css('h1').text

# Einzelne Turniere
doc.css('article table.silver tr').each do |row|
  puts row.css('td').map(&:text).join(' | ')
end
```

### Fixtures vergleichen

```bash
# Diff zwischen Original und Modified
diff test/fixtures/html/tournament_details_nbv_2971.html \
     test/fixtures/html/tournament_details_nbv_2971_modified.html

# Oder mit colored diff
git diff --no-index --word-diff \
  test/fixtures/html/tournament_details_nbv_2971.html \
  test/fixtures/html/tournament_details_nbv_2971_modified.html
```

### Fixture-Content durchsuchen

```bash
# Nach spezifischem Text suchen
grep -r "Norddeutsche Meisterschaft" test/fixtures/html/

# Mit Kontext
grep -A 3 -B 3 "Norddeutsche Meisterschaft" test/fixtures/html/*.html

# Mit Nokogiri-XPath (Rails Console)
doc.xpath('//h1[contains(text(), "Norddeutsche")]')
```

## 📚 Weiterführende Dokumentation

- **Detaillierte Anleitung:** `test/FIXTURES_SAMMELN.md`
- **Test-Konzept:** `test/README.md`
- **Scraping Helpers:** `test/support/scraping_helpers.rb`
- **VCR Setup:** `test/support/vcr_setup.rb`

## 🎓 Für Contributors

### Perfect First Issue: Fixture sammeln

**Aufgabe:** Eine neue Fixture sammeln und Test aktivieren

**Schritte:**

1. Issue wählen (Label: `good first issue`, `testing`)
2. Fixture sammeln (siehe oben)
3. Test anpassen (`test/scraping/*_test.rb`)
4. Skip entfernen
5. Test grün machen
6. Pull Request erstellen

**Aufwand:** 15-30 Minuten  
**Lerneffekt:** Rails Testing, Scraping, WebMock

### Fortgeschritten: Change Detection Fixtures

**Aufgabe:** Fixture-Paare für Change Detection

1. Original-Fixture sammeln
2. Modifizierte Version erstellen
3. Change Detection Test schreiben
4. Dokumentieren welche Felder geändert wurden

## 🐛 Troubleshooting

### Fixture wird nicht gefunden

```ruby
# Test schlägt fehl: Errno::ENOENT: No such file or directory

# Prüfen:
ls test/fixtures/html/tournament_details_nbv_2971.html

# Pfad in Test prüfen:
Rails.root.join('test/fixtures/html/tournament_details_nbv_2971.html')
```

### Parsing schlägt fehl

```ruby
# Nokogiri kann HTML nicht parsen

# Prüfen ob Datei HTML enthält:
head test/fixtures/html/tournament_details_nbv_2971.html

# Sollte mit <!DOCTYPE html> oder <html> beginnen
```

### WebMock wird nicht getriggert

```ruby
# HTTP Request wird nicht gemockt

# Prüfen ob URL exakt matched:
stub_request(:get, %r{nbv\.clubcloud\.de/sb_meisterschaft\.php})

# Oder spezifischer:
stub_request(:get, "https://nbv.clubcloud.de/sb_meisterschaft.php?p=20--2025-2971----1-100000-")
```

### Fixture enthält sensible Daten

```bash
# Credentials in Fixture gefunden

# Manuell ersetzen:
sed -i '' 's/real_password/<CC_PASSWORD>/g' test/fixtures/html/fixture.html

# Oder Fixture neu sammeln nach VCR-Setup
```

## 📞 Support

**Fragen?**

- 📖 Dokumentation: `test/FIXTURES_SAMMELN.md`
- 🐛 Issue erstellen: GitHub Issues (Label: `testing`)
- 💬 Diskussion: GitHub Discussions

---

**Letztes Update:** 2026-02-14  
**Maintained by:** Carambus Contributors
