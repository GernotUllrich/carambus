# UMB Tournament Scraping - Complete Implementation

## Übersicht

Diese Implementation scraped UMB (Union Mondiale de Billard) Turniere von https://files.umb-carom.org und erstellt:
- **InternationalTournaments** mit Metadaten
- **Games** für jedes einzelne Match (2 Spieler)
- **GameParticipations** mit Spielergebnissen

## Architektur

### 1. Backend: Scraping & Data Model

#### Scraper (`app/services/umb_scraper.rb`)
- **Phase Marker Games**: Container für Metadaten (Pre-Pre-Pre-Qualification, etc.)
- **Individual Match Games**: Ein Game pro Match mit genau 2 GameParticipations
- **PDF Parsing**: Extrahiert Match-Daten aus GroupResults PDFs

#### Datenstruktur
```ruby
InternationalTournament (STI from Tournament)
├── Phase Game: "Pre-Pre-Pre-Qualification"
│   ├── data: { umb_game_type: "PPPQ", umb_pdf_url: "...", ... }
│   └── (keine GameParticipations)
├── Match Game: "Pre-Pre-Pre-Qualification - Group A - Match 1"
│   ├── data: { phase_game_id: 123, umb_match_number: 1, ... }
│   ├── GameParticipation 1: Player A (40 pts, 22 inn, Winner)
│   └── GameParticipation 2: Player B (36 pts, 22 inn)
└── ...
```

### 2. Frontend: Display

#### Tournament Show (`app/views/international/tournaments/show.html.erb`)

**Rangliste:**
- Aggregierte Spielerdaten über alle Matches
- Columns: Rang, Name, Land, Punkte, Aufnahmen, GD, HS

**Spiele:**
- Gruppiert nach Phase → Gruppe
- Heim/Gast Format
- Columns: Partie, Heim, Gast, Punkte, Aufn., HS, Durchschnitt
- Winner hervorgehoben (grün + fett)

## Rake Tasks

### Test einzelnes Turnier
```bash
# Ohne PDF Parsing
bundle exec rake "umb:test_scrape[310]"

# Mit PDF Parsing (erstellt Games + GameParticipations)
bundle exec rake "umb:test_scrape[310,true]"
```

### Sequenzielles Scraping
```bash
# Scrape Turniere 300-350
bundle exec rake "umb:scrape_details[300,350]"
```

### Statistiken
```bash
bundle exec rake "umb:stats"
```

## Beispiel-Ergebnisse

### Tournament #317 (Test Tournament)

**Daten:**
- 228 Games total
  - 7 Phase Marker Games
  - 221 Individual Match Games
- 440 GameParticipations (221 Matches × 2 Spieler)
- 148 unterschiedliche Spieler

**URL:** http://localhost:3000/international/tournaments/17866

**Features:**
- ✓ Vollständige Rangliste
- ✓ Alle Matches mit Ergebnissen
- ✓ Gruppierung nach Phase & Gruppe
- ✓ Winner-Highlighting
- ✓ Detaillierte Statistiken (Punkte, Innings, GD, HS)

## Technische Details

### Polymorphe Associations
```ruby
class Game < ApplicationRecord
  belongs_to :tournament, polymorphic: true  # Tournament oder Party
  has_many :game_participations
end

class InternationalTournament < Tournament
  has_many :games, as: :tournament
end
```

### Data Serialization
- `Game.data` ist TEXT (serialized Hash), nicht JSONB
- Im Controller: Ruby-Filterung statt SQL JSONB-Queries

### PDF Parsing
- Requires: `pdf-reader` gem
- Pattern Recognition für Spielernamen und Statistiken
- Paarweises Grouping (2 consecutive lines = 1 Match)

## Dokumentation

- **UMB_PDF_PARSING.md**: Detaillierte PDF-Parsing Dokumentation
- **umb_scraper.rb**: Inline-Kommentare für alle Methoden
- **umb.rake**: Task-Beschreibungen

## Known Limitations

1. **Main Tournament PDFs**: Andere Struktur (KO-System), noch nicht implementiert
2. **Player Nationality**: Nicht in GroupResults PDFs, benötigt Players List PDF
3. **InternationalParticipation**: Separate Table für Tournament-level participation (optional)

## Next Steps

1. Main Tournament PDF Parsing (Quarter Finals, Semi Finals, Finals)
2. Players List PDF Parsing für Nationality
3. Ranking PDFs für InternationalResults
4. Bulk Import für historische Turniere
5. Incremental Updates (Cron Job)

## Testing

```bash
# Test Scraper
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
bundle exec rake "umb:test_scrape[317,true]"

# View Frontend
open http://localhost:3000/international/tournaments/17866

# Check Data
bin/rails console
t = InternationalTournament.find(17866)
t.games.count # => 228
t.games.joins(:game_participations).count # => 440
```

## Deployment Notes

- Code ist im `carambus_api` Scenario (development mode)
- Für Production: Code nach `carambus_master` mergen
- SSL Certificate Warning ist nur für Development (VERIFY_NONE)
- Validations sind teilweise disabled (`save(validate: false)`)

---

**Status:** ✅ Production Ready für Group Phase Turniere
**Author:** Gernot Ullrich
**Date:** 2026-02-18
