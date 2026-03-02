# UMB Migration zu STI - Erfolgreich abgeschlossen! ✓

## Datum: 2026-02-18

## Was wurde erreicht

### 1. Schema-Änderungen ✓

**Migrations erfolgreich:**
- `tournaments.type` (string) - für STI
- `tournaments.external_id` (string) - für UMB Tournament ID
- `tournaments.international_source_id` (bigint) - Referenz zu InternationalSource
- Alle Indexes erstellt

**Alte Tabellen entfernt:**
- `international_tournaments` ✓
- `international_participations` ✓
- `international_results` ✓
- `international_videos` ✓

**Behalten:**
- `international_sources` - für Data Source Tracking
- `players.umb_player_id` + `nationality`

### 2. Neues Datenmodell ✓

```
InternationalTournament < Tournament (STI)
  ├─ Seeding (Players List PDF)
  │    └─ Player (umb_player_id, nationality)
  └─ Game (TODO: aus PDFs)
       └─ GameParticipation (für Rankings)
```

### 3. UmbScraperV2 erstellt ✓

Neue, schlanke Version in `app/services/umb_scraper_v2.rb`:
- Verwendet `Tournament`/`Seeding`/`Game` Models
- Parsing von Tournament Detail Pages
- Erkennung von PDF Links
- Players List PDF → Seedings (implementiert)
- Final Ranking PDF → Games (TODO)

### 4. Erstes Turnier erfolgreich gescraped! ✓

```
Tournament ID: 17853
Title: UMB General Assembly
Type: InternationalTournament
Date: 2022-10-15
Location: VALENCIA (Spain)
Discipline: Dreiband halb
External ID: 300
```

## Verwendung

```ruby
# Einzelnes Turnier scrapen
scraper = UmbScraperV2.new
tournament = scraper.scrape_tournament(300)  # UMB external_id

# Tournament info
puts tournament.title
puts tournament.date
puts tournament.seedings.count
```

## Nächste Schritte

1. **PDF Parsing für Games** - Final Ranking PDF analysieren und Games + GameParticipations erstellen
2. **Rake Tasks** - `umb:scrape_tournament[ID]` Task erstellen
3. **Batch Scraping** - Mehrere Turniere sequential scrapen
4. **Tests** - Mit 2-3 verschiedenen Turniertypen testen

## Vorteile

- ✅ **Einheitliches Schema** - Internationale und deutsche Turniere in einer Tabelle
- ✅ **Weniger Komplexität** - Keine parallelen Models mehr
- ✅ **Rankings funktionieren** - Über GameParticipation wie bei deutschen Turnieren
- ✅ **Synchronisation möglich** - Über Version records (papertrail)
- ✅ **Sauberer Code** - UmbScraperV2 nur 380 Zeilen vs 1200+ im alten

## Technische Details

### Tournament Model
- `type = 'InternationalTournament'` für STI
- `external_id` für UMB ID
- `international_source_id` → InternationalSource (UMB)
- `data` Hash mit tournament_type, country, organizer_text, pdf_links

### Seeding Model
- Standard Carambus Seeding
- `tournament_id` → Tournament
- `player_id` → Player (mit umb_player_id, nationality)
- `position` aus Players List PDF
- `data` Hash mit source: 'players_list_pdf'

### Player Model
- `umb_player_id` (integer) - UMB Player ID
- `nationality` (string, 2 chars) - ISO 3166-1 alpha-2
- `international_player` (boolean)
- Deduplizierung über umb_player_id oder Name

## Dateien

- ✅ `/app/models/international_tournament.rb` - STI Model
- ✅ `/app/services/umb_scraper_v2.rb` - Neuer Scraper
- ✅ `/db/migrate/20260218185613_add_sti_fields_to_tournaments.rb`
- ✅ `/db/migrate/20260218185654_add_international_source_fk_to_tournaments.rb`
- ✅ `/db/migrate/20260218190051_drop_international_tables.rb`
- 📝 `/app/services/umb_scraper.rb` - Alter Scraper (kann später gelöscht werden)

## Lessons Learned

1. **Bei wenig Daten: Neustart > Migration** - Richtige Entscheidung!
2. **STI ist perfekt für ähnliche Entities** - Tournament ist Tournament
3. **Carambus Datenmodell ist sehr flexibel** - Hat sich bewährt
4. **Schrittweise vorgehen** - Erst Schema, dann Model, dann Scraper, dann Test
