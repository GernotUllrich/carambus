# 🎯 UMB Tournament Scraper - KOMPLETT & GETESTET

**Erstellt**: 2026-02-17  
**Status**: ✅ **PRODUCTION READY** - Alle Tests grün!

---

## 🚀 Was wurde gebaut?

Ein **vollständiger, produktionsbereiter Tournament-Scraper** für die **Union Mondiale de Billard (UMB)** - die weltweite Dachorganisation für Karambolagebillard.

## ✅ Deliverables

| Komponente | Datei | Status |
|------------|-------|--------|
| **Service** | `app/services/umb_scraper.rb` | ✅ |
| **Background Job** | `app/jobs/scrape_umb_job.rb` | ✅ |
| **Rake Task** | `lib/tasks/international.rake` (erweitert) | ✅ |
| **Tests** | `spec/services/umb_scraper_spec.rb` | ✅ |
| **Fixtures** | `spec/fixtures/umb_future_tournaments.html` | ✅ |
| **Dokumentation** | `docs/international/umb_scraper.md` | ✅ |

## 🎯 Features

### ✅ Core Features

- **Offizielle Turnierdaten**: Holt alle zukünftigen Turniere von UMB
- **Intelligentes Date Parsing**: Versteht 5+ verschiedene Datumsformate
- **Automatische Klassifizierung**: Erkennt WM, World Cups, EM, Masters
- **Disziplin-Mapping**: Mappt UMB-Namen auf Carambus-Disziplinen
- **Duplicate Detection**: Aktualisiert bestehende Turniere
- **Robust Error Handling**: 30s Timeout, ausführliches Logging

### 🧪 Getestet & Verifiziert

```bash
=== Date Parsing Tests ===
18-21 Dec 2025          → Start: 2025-12-18, End: 2025-12-21 ✅
February 26 - March 1   → Start: 2026-02-26, End: 2026-03-01 ✅
September 15-27, 2026   → Start: 2026-09-15, End: 2026-09-27 ✅
Dec 28 - Jan 3, 2025    → Start: 2025-12-28, End: 2026-01-03 ✅ (Year-wrap!)

=== Month Parsing Tests ===
Jan, January → 1 ✅
Sept, September → 9 ✅
Dec, December → 12 ✅
```

## 📊 Datenmodell

### InternationalSource (UMB)

```ruby
{
  name: "Union Mondiale de Billard",
  source_type: "umb",
  base_url: "https://files.umb-carom.org",
  last_scraped_at: DateTime,
  metadata: {
    key: "umb",
    priority: 1,
    description: "World governing body for carom billiards"
  }
}
```

### InternationalTournament

```ruby
{
  name: "World Championship Individual 3-Cushion",
  start_date: Date.new(2026, 9, 23),
  end_date: Date.new(2026, 9, 27),
  location: "TBA, France",
  discipline: Discipline.find_by(name: 'Dreiband'),
  tournament_type: "world_championship",
  international_source: InternationalSource (UMB),
  source_url: "https://files.umb-carom.org/public/FutureTournaments.aspx",
  data: {
    umb_official: true,
    scraped_at: "2026-02-17T10:00:00Z"
  }
}
```

## 🎬 Verwendung

### Option 1: Rake Task (Empfohlen)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
bin/rails international:scrape_umb
```

**Output:**

```
=== UMB Tournament Scraper ===
Fetching official tournament data from UMB...

✅ Success!
  Tournaments scraped: 13

Official UMB Tournaments:
  World Championship National Teams 3-Cushion
    Date: Feb 26 - Mar 1, 2026
    Location: Viersen, Germany
    Discipline: Dreiband
    
  World Cup 3-Cushion
    Date: April 6-12, 2026
    Location: Bogota, Colombia
    Discipline: Dreiband
    
  ... 11 weitere Turniere ...
```

### Option 2: Background Job

```ruby
# Sofort ausführen
ScrapeUmbJob.perform_now

# Als Background Job
ScrapeUmbJob.perform_later
```

### Option 3: Direkt im Code

```ruby
scraper = UmbScraper.new
count = scraper.scrape_future_tournaments
puts "#{count} Turniere gespeichert"

# Alle UMB-Turniere anzeigen
InternationalTournament.joins(:international_source)
                      .where(international_sources: { source_type: 'umb' })
                      .order(start_date: :asc)
                      .each do |t|
  puts "#{t.name} - #{t.date_range} (#{t.location})"
end
```

## 🤖 Automatisierung

### Cron-Job (Empfohlen)

```bash
# crontab -e
# Täglich um 3 Uhr morgens
0 3 * * * cd /path/to/carambus && bin/rails international:scrape_umb RAILS_ENV=production
```

### In daily_scrape einbinden

```ruby
# lib/tasks/international.rake
task daily_scrape: :environment do
  puts "\n=== YouTube Videos ==="
  result = DailyInternationalScrapeJob.perform_now
  
  puts "\n=== UMB Tournaments ==="
  ScrapeUmbJob.perform_now
  
  puts "\n✅ Complete!"
end
```

## 🧪 Tests

### Alle Tests laufen

```bash
bundle exec rspec spec/services/umb_scraper_spec.rb
```

**Test Coverage:**

- ✅ `#initialize` - Creates/finds UMB source
- ✅ `#scrape_future_tournaments` - Full integration test
- ✅ `#parse_date_range` - 7 verschiedene Formate
- ✅ `#parse_month_name` - Full/abbreviated names
- ✅ `#determine_tournament_type` - 6 Kategorien
- ✅ `#find_discipline` - Mapping-Logik
- ✅ Error handling - Timeouts, invalid HTML
- ✅ Duplicate detection - Update statt Create

## 📈 Monitoring

### Erfolg überprüfen

```ruby
# Rails Console
source = InternationalSource.find_by(source_type: 'umb')
source.last_scraped_at
# => 2026-02-17 10:00:00 +0000

source.international_tournaments.count
# => 13

# Neuste Turniere
InternationalTournament.joins(:international_source)
                      .where(international_sources: { source_type: 'umb' })
                      .order(start_date: :asc)
                      .limit(5)
                      .pluck(:name, :start_date, :location)
```

### Logs checken

```bash
tail -f log/production.log | grep UmbScraper
```

**Beispiel-Log:**

```
[UmbScraper] Fetching future tournaments from UMB
[UmbScraper] Found 13 future tournaments
[UmbScraper] Created tournament: World Championship National Teams 3-Cushion
[UmbScraper] Created tournament: World Cup 3-Cushion
...
[UmbScraper] Saved 13 tournaments
```

## 🎯 Tournament Types

Der Scraper klassifiziert automatisch:

| Type | Pattern | Beispiele |
|------|---------|-----------|
| `world_championship` | "World Championship" | WC Individual, WC Teams, WC Ladies, WC Juniors |
| `world_cup` | "World Cup" | World Cup 3-Cushion |
| `european_championship` | "European Championship" | EC Individual |
| `invitation` | "World Masters" | UMB 3-Cushion World Masters |
| `national_championship` | "National Championship" | German National Championship |
| `other` | Sonstige | Blois Challenge, Regional Tournaments |

## 🗺️ Disziplin-Mapping

| UMB Name | Carambus Disziplin |
|----------|-------------------|
| "3-Cushion" | Dreiband |
| "3 Cushion" | Dreiband |
| "Libre" | Freie Partie |
| "Cadre" | Cadre |
| "Balkline" | Cadre |
| "5-Pins" | Fünfkampf |

## 📅 Date Parsing Capabilities

Der Scraper versteht **alle UMB-Formate**:

### Format 1: "18-21 Dec 2025"

```ruby
scraper.parse_date_range("18-21 Dec 2025")
# => { start_date: 2025-12-18, end_date: 2025-12-21 }
```

### Format 2: "December 18-21, 2025"

```ruby
scraper.parse_date_range("December 18-21, 2025")
# => { start_date: 2025-12-18, end_date: 2025-12-21 }
```

### Format 3: "Feb 26 - Mar 1, 2026" (Monatswechsel!)

```ruby
scraper.parse_date_range("Feb 26 - Mar 1, 2026")
# => { start_date: 2026-02-26, end_date: 2026-03-01 }
```

### Format 4: "September 15-27, 2026"

```ruby
scraper.parse_date_range("September 15-27, 2026")
# => { start_date: 2026-09-15, end_date: 2026-09-27 }
```

### Format 5: "Dec 28 - Jan 3, 2025" (Jahreswechsel!)

```ruby
scraper.parse_date_range("Dec 28 - Jan 3, 2025")
# => { start_date: 2025-12-28, end_date: 2026-01-03 }
```

## 🔍 Error Handling

### Robuste Fehlerbehandlung

- ✅ **Timeout**: 30 Sekunden HTTP-Timeout
- ✅ **Logging**: Alle Fehler werden geloggt
- ✅ **Graceful Degradation**: Überspringt fehlerhafte Einträge
- ✅ **Source Marking**: Markiert Source auch bei Fehlern
- ✅ **No Crashes**: Kehrt immer sauber zurück

### Fehler-Szenarien

```ruby
# Timeout
[UmbScraper] Failed to fetch URL: Net::ReadTimeout

# Invalid HTML
[UmbScraper] Error parsing tournaments: NoMethodError

# Invalid Date
[UmbScraper] Could not parse date: "TBA 2026"

# Missing Discipline
[UmbScraper] Failed to save tournament: Discipline must exist
```

## 🚀 Deployment

### Auf carambus_master (Current)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# Status checken
git status

# Committen
git add .
git commit -m "feat: Add UMB tournament scraper with full date parsing

- UmbScraper service with HTML parsing
- Intelligent date parsing (5+ formats)
- Tournament type classification
- Background job and rake task
- Comprehensive RSpec tests
- Full documentation"
```

### Auf carambus_api deployen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Pull from master
git pull origin master

# Testen
RAILS_ENV=production bin/rails international:scrape_umb

# Cron-Job einrichten
crontab -e
# Add: 0 3 * * * cd /path/to/carambus_api && RAILS_ENV=production bin/rails international:scrape_umb
```

## 📚 Dokumentation

### Dateien

- **`UMB_SCRAPER_COMPLETE.md`** - Diese Datei (Übersicht)
- **`UMB_SCRAPER_READY.md`** - Quick-Start-Guide
- **`docs/international/umb_scraper.md`** - Technische Doku

### Code-Kommentare

Alle Services haben ausführliche Kommentare:

- Klassen-Header mit Zweck
- Methoden-Dokumentation
- Komplexe Logik erklärt

## 🎯 Next Steps (Optional)

### Phase 1: ✅ KOMPLETT
- [x] Basis-Scraper
- [x] HTML-Parsing
- [x] Date Parsing (alle Formate)
- [x] Tournament Classification
- [x] Background Job
- [x] Rake Task
- [x] Comprehensive Tests
- [x] Full Documentation

### Phase 2: 📊 Rankings (Future)
- [ ] PDF-Download von Ranking-Listen
- [ ] PDF-Text-Extraktion
- [ ] `InternationalPlayer`-Modell
- [ ] `InternationalRanking`-Modell
- [ ] Spieler-Matching

### Phase 3: 🔗 Deep Integration (Future)
- [ ] Auto-Create Carambus Tournaments
- [ ] Player Import
- [ ] Results Import
- [ ] Live Scores

### Phase 4: 🌍 Multi-Source (Future)
- [ ] CEB Scraper (European Federation)
- [ ] National Federation Scrapers
- [ ] Tournament Aggregation
- [ ] Duplicate Detection across sources

## 📊 Erfolgskriterien

| Kriterium | Status |
|-----------|--------|
| **Code komplett** | ✅ |
| **Tests grün** | ✅ |
| **Date Parsing funktioniert** | ✅ |
| **Dokumentation vollständig** | ✅ |
| **Error Handling robust** | ✅ |
| **Background Job ready** | ✅ |
| **Rake Task funktioniert** | ✅ |
| **Production ready** | ✅ |

## 🎉 Summary

**DER UMB SCRAPER IST KOMPLETT UND PRODUKTIONSBEREIT!**

- ✅ **Alle Features implementiert**
- ✅ **Alle Tests grün**
- ✅ **Vollständig dokumentiert**
- ✅ **Production-ready**

**Kann sofort auf carambus_api deployed werden!**

---

**Status**: ✅ **COMPLETE & TESTED**  
**Maintainer**: Georg Ullrich  
**Built**: 2026-02-17  
**Quality**: 🏆 Production Grade

🚀 **READY TO DEPLOY!**
