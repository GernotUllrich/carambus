# ✅ UMB Tournament Scraper - Production Ready

**Erstellt**: 2026-02-17  
**Status**: ✅ **PRODUKTIONSBEREIT**

## Was wurde gebaut?

Ein **vollständiger Tournament-Scraper** für die **Union Mondiale de Billard (UMB)** - die weltweite Dachorganisation für Karambolagebillard.

## Features

✅ **Offizielle Turnierdaten**: Holt alle zukünftigen Turniere von UMB  
✅ **Intelligentes Date Parsing**: Versteht verschiedene Datumsformate  
✅ **Automatische Klassifizierung**: Erkennt WM, World Cups, EM, etc.  
✅ **Background Job**: Kann als Cron-Job laufen  
✅ **Rake Task**: `bin/rails international:scrape_umb`  
✅ **Vollständig getestet**: RSpec-Tests mit Fixtures  
✅ **Dokumentiert**: Ausführliche Doku in `docs/international/umb_scraper.md`

## Schnellstart

### 1. Manuell ausführen

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
bin/rails international:scrape_umb
```

### 2. Im Code verwenden

```ruby
scraper = UmbScraper.new
count = scraper.scrape_future_tournaments
puts "Gespeicherte Turniere: #{count}"
```

### 3. Als Background Job

```ruby
ScrapeUmbJob.perform_later
```

## Beispiel-Output

```
=== UMB Tournament Scraper ===
Fetching official tournament data from UMB...

✅ Success!
  Tournaments scraped: 13

Official UMB Tournaments:
  Blois 3-Cushion Challenge
    Date: Dec 18-21, 2025
    Location: Blois, France
    Discipline: Dreiband

  World Championship National Teams 3-Cushion
    Date: Feb 26 - Mar 1, 2026
    Location: Viersen, Germany
    Discipline: Dreiband

  UMB 3-Cushion World Masters
    Date: March 31 - April 4, 2026
    Location: Bogota, Colombia
    Discipline: Dreiband
    
  World Cup 3-Cushion
    Date: April 6-12, 2026
    Location: Bogota, Colombia
    Discipline: Dreiband
    
  ... 9 weitere Turniere ...
```

## Datei-Struktur

```
app/
  services/
    umb_scraper.rb                    # ✅ Haupt-Service
  jobs/
    scrape_umb_job.rb                 # ✅ Background Job

lib/
  tasks/
    international.rake                # ✅ Erweitert mit :scrape_umb

spec/
  services/
    umb_scraper_spec.rb               # ✅ Vollständige Tests
  fixtures/
    umb_future_tournaments.html       # ✅ Test-Daten

docs/
  international/
    umb_scraper.md                    # ✅ Ausführliche Doku
```

## Date Parsing

Der Scraper versteht **alle UMB-Datumsformate**:

| Format | Beispiel | Funktioniert? |
|--------|----------|---------------|
| Tag-Range mit Monat | "18-21 Dec 2025" | ✅ |
| Monat ausgeschrieben | "December 18-21, 2025" | ✅ |
| Monat-zu-Monat | "Feb 26 - Mar 1, 2026" | ✅ |
| Langer Monat | "September 15-27, 2026" | ✅ |
| Year-Wrap | "Dec 28 - Jan 3, 2025" | ✅ |

## Tests ausführen

```bash
bundle exec rspec spec/services/umb_scraper_spec.rb
```

**Alle Tests grün** ✅

## Integration mit Carambus

### InternationalSource

Erstellt automatisch:

```ruby
InternationalSource.find_by(source_type: 'umb')
# => {
#   name: "Union Mondiale de Billard",
#   source_type: "umb",
#   base_url: "https://files.umb-carom.org",
#   priority: 1
# }
```

### InternationalTournament

Jedes gescrapte Turnier wird als `InternationalTournament` gespeichert mit:

- ✅ `name` - Turnierbezeichnung
- ✅ `start_date` / `end_date` - Korrekt geparsed
- ✅ `location` - Stadt, Land
- ✅ `discipline` - Gemappt auf Carambus-Disziplinen
- ✅ `tournament_type` - Automatisch klassifiziert
- ✅ `international_source` - Verknüpft mit UMB-Source
- ✅ `source_url` - Original-URL
- ✅ `data` - JSON mit `umb_official: true`

## Automatisierung

### Empfohlen: Täglicher Cron-Job

```bash
# crontab -e
0 3 * * * cd /path/to/carambus && bin/rails international:scrape_umb RAILS_ENV=production
```

### Oder: In daily_scrape einbinden

```ruby
# lib/tasks/international.rake
task daily_scrape: :environment do
  # ... YouTube scraping ...
  
  # UMB scraping
  puts "\n=== UMB Tournament Data ==="
  ScrapeUmbJob.perform_now
end
```

## Nächste Schritte (Optional)

### Phase 1: ✅ DONE
- [x] Basis-Scraper
- [x] Date Parsing
- [x] Background Job
- [x] Tests
- [x] Dokumentation

### Phase 2: 📊 Rankings (Optional)
- [ ] PDF-Download von Ranking-Listen
- [ ] PDF-Text-Extraktion
- [ ] `InternationalPlayer`-Modell
- [ ] `InternationalRanking`-Modell

### Phase 3: 🔗 Deep Integration (Optional)
- [ ] Automatisches Anlegen von Carambus-Turnieren
- [ ] Spieler-Import
- [ ] Ergebnis-Import
- [ ] Live-Score-Integration

## Bekannte Limitierungen

⚠️ **Aktuell**:

1. **HTML-Struktur-Abhängigkeit**: Parser ist heuristisch
2. **Keine Ranking-Daten**: Nur Future Tournaments
3. **TBA-Locations**: Einige Turniere haben noch keine Location

✅ **Aber**: Alle Core-Features funktionieren!

## Deployment

### Auf carambus_master (CURRENT)

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
git add .
git commit -m "feat: Add UMB tournament scraper with date parsing"
```

### Auf carambus_api deployen

```bash
cd /Users/gullrich/DEV/carambus/carambus_api
git pull origin master
bin/rails international:scrape_umb RAILS_ENV=production
```

## Monitoring

**Logs checken**:

```bash
tail -f log/production.log | grep UmbScraper
```

**Erfolgsmessung**:

```ruby
# Rails Console
InternationalSource.find_by(source_type: 'umb').last_scraped_at
# => kürzlicher Timestamp

InternationalTournament.joins(:international_source)
                      .where(international_sources: { source_type: 'umb' })
                      .count
# => Anzahl UMB-Turniere
```

## Support

- **Dokumentation**: `docs/international/umb_scraper.md`
- **Tests**: `spec/services/umb_scraper_spec.rb`
- **Logs**: Rails.logger mit `[UmbScraper]` prefix

---

**Status**: ✅ **READY FOR PRODUCTION**  
**Maintainer**: Georg Ullrich  
**Tested**: ✅ RSpec Tests grün  
**Documented**: ✅ Vollständig  

🚀 **GO LIVE!**
