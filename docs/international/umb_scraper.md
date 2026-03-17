# UMB Tournament Scraper

**Union Mondiale de Billard (UMB)** ist die weltweite Dachorganisation für Karambolagebillard.

## Übersicht

Der `UmbScraper` holt **offizielle Turnierdaten** von der UMB-Website und speichert sie als `InternationalTournament`-Einträge.

## Features

✅ **Offizielle Turniere**: WM, World Cups, EM
✅ **Automatische Klassifizierung**: Erkennt Turniertypen automatisch
✅ **Quelle markiert**: Alle Daten haben `international_source` = UMB
✅ **Background Job**: Kann als Cron-Job laufen

## Verwendung

### Manuell scrapen

```bash
bin/rails international:scrape_umb
```

### Background Job

```ruby
ScrapeUmbJob.perform_later
```

### Im Code verwenden

```ruby
scraper = UmbScraper.new
count = scraper.scrape_future_tournaments

puts "Gespeicherte Turniere: #{count}"
```

## Datenstruktur

### InternationalSource

```ruby
{
  name: "Union Mondiale de Billard",
  source_type: "umb",
  base_url: "https://files.umb-carom.org",
  metadata: {
    key: "umb",
    priority: 1,
    description: "World governing body for carom billiards"
  }
}
```

### InternationalTournament

Jedes gescrapte Turnier wird gespeichert mit:

```ruby
{
  name: "World Championship National Teams 3-Cushion",
  start_date: Date,
  end_date: Date,
  location: "Viersen, Germany",
  discipline: Discipline,
  tournament_type: "world_championship",
  international_source: InternationalSource (UMB),
  source_url: "https://files.umb-carom.org/public/FutureTournaments.aspx",
  data: {
    umb_official: true,
    scraped_at: "2025-02-17T12:00:00Z"
  }
}
```

## Turniertypen

Der Scraper erkennt automatisch:

| Turniertyp | Name-Pattern | Beispiel |
|------------|--------------|----------|
| `world_championship` | "World Championship" | WC Individual 3-Cushion |
| `world_cup` | "World Cup" | World Cup 3-Cushion |
| `european_championship` | "European Championship" | EC Individual 3-Cushion |
| `invitation` | "World Masters" | UMB 3-Cushion World Masters |
| `national_championship` | "National Championship" | German National Championship |
| `other` | Sonstige | Blois Challenge |

## Disziplin-Mapping

UMB-Namen werden auf unsere Disziplinen gemappt:

| UMB-Name | Carambus-Disziplin |
|----------|-------------------|
| "3-Cushion" / "3 Cushion" | Dreiband |
| "Libre" | Freie Partie |
| "Cadre" | Cadre |
| "5-Pins" | Fünfkampf |
| "Balkline" | Cadre |

## UMB-Datenquellen

### Future Tournaments
- URL: `https://files.umb-carom.org/public/FutureTournaments.aspx`
- Format: HTML-Tabelle
- Inhalt: Alle offiziell geplanten Turniere

### Rankings (geplant)
- URL: `https://files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf`
- Format: PDF
- Inhalt: Offizielle Weltranglisten

## Automatisierung

### Cron-Job (empfohlen)

```bash
# Täglich um 3 Uhr morgens
0 3 * * * cd /path/to/carambus && bin/rails international:scrape_umb RAILS_ENV=production
```

### Oder: In `daily_scrape` einbinden

```ruby
# lib/tasks/international.rake
task daily_scrape: :environment do
  # ... existing scraping ...
  
  # UMB scraping
  ScrapeUmbJob.perform_now
end
```

## Fehlerbehandlung

Der Scraper ist **robust**:

- ✅ Timeout nach 30 Sekunden
- ✅ Loggt alle Fehler ausführlich
- ✅ Speichert nur valide Daten
- ✅ Überspringt unvollständige Einträge
- ✅ Markiert Source auch bei Fehlern

## Beispiel-Output

```
=== UMB Tournament Scraper ===
Fetching official tournament data from UMB...

✅ Success!
  Tournaments scraped: 12

Official UMB Tournaments:
  World Championship National Teams 3-Cushion
    Date: Feb 26 - Mar 1, 2026
    Location: Viersen, Germany
    Discipline: Dreiband

  World Cup 3-Cushion
    Date: April 6-12, 2026
    Location: Bogota, Colombia
    Discipline: Dreiband

  UMB 3-Cushion World Masters
    Date: June 30 - July 4, 2026
    Location: Bordeaux, France
    Discipline: Dreiband
    
  ...
```

## Tests

```bash
bundle exec rspec spec/services/umb_scraper_spec.rb
```

## Limitierungen

⚠️ **Aktuell noch nicht implementiert**:

1. **Date Parsing**: Datumsformate von UMB sind variabel
   - "18-21 Dec 2025"
   - "Feb 26 - Mar 1, 2026"
   - "September 15-27, 2026"
   
2. **Ranking Import**: PDF-Parsing für Rankings

## Roadmap

### Phase 1: ✅ Basis-Scraper (DONE)
- [x] InternationalSource für UMB
- [x] HTML-Parser für Future Tournaments
- [x] Background Job
- [x] Rake Task
- [x] Tests

### Phase 2: 🔄 Date Parsing (TODO)
- [ ] Robustes Parsing von verschiedenen Datumsformaten
- [ ] Multi-Month Events (z.B. "Sept 15 - Oct 2")
- [ ] Zeitzonen-Handling

### Phase 3: 📊 Rankings (TODO)
- [ ] PDF-Download von Ranking-Listen
- [ ] PDF-Text-Extraktion
- [ ] `InternationalPlayer`-Modell
- [ ] `InternationalRanking`-Modell
- [ ] Spieler-Matching zu Carambus-Usern

### Phase 4: 🔗 Deep Integration (TODO)
- [ ] Automatisches Anlegen von Turnieren
- [ ] Spieler-Import
- [ ] Ergebnis-Import von fertigen Turnieren
- [ ] Live-Score-Integration (falls verfügbar)

## Architektur

```
UmbScraper
  ├── fetch_url()           # HTTP-Request mit Timeout
  ├── parse_future_tournaments()  # HTML → Turnier-Array
  ├── save_tournaments()    # Speichern in DB
  ├── parse_date_range()    # String → {start_date, end_date}
  ├── find_discipline()     # Name → Discipline
  └── determine_tournament_type()  # Name → tournament_type

ScrapeUmbJob
  └── perform()             # Background execution

Rake Task: international:scrape_umb
  └── CLI-Output + Aufruf
```

## Verwandte Dokumentation

- [International Videos System](./international_videos.md)
- [YouTube Scraper](./youtube_scraper.md)
- [Tournament Management](../managers/table_reservation_heating_control.md)

---

**Status**: ✅ Produktionsbereit (außer Date Parsing)
**Maintainer**: Georg Ullrich
**Last Updated**: 2026-02-17
