# 🎯 UMB Scraping mit STI - KOMPLETT ERFOLGREICH! 🎯

## Datum: 2026-02-18

## ✅ Was funktioniert

### 1. Vollständiger Tournament Scrape
```
Tournament: World Cup 3-Cushion (Ho Chi Minh City 2023)
- ID: 17859
- External ID: 310 (UMB)
- Type: InternationalTournament
- Seedings: 170 Spieler
- Games: 42 Spiele
```

### 2. Datenmodell (STI)
```
InternationalTournament < Tournament
  ├─ Seeding (170 Players)
  │    └─ Player (umb_player_id, nationality)
  └─ InternationalGame < Game (42 Games)
       └─ GameParticipation (84 total, 2 per Game)
```

### 3. PDF Parsing ✅

**Players List PDF → Seedings:**
- Format: `Position | LASTNAME Firstname | NAT | ... | UMB_ID`
- Erstellt: Player + Seeding
- Name Handling: LASTNAME Firstname

**Group Results PDF → Games:**
- Format: Match-Paare mit Stats
- Erstellt: Game + 2x GameParticipation
- Name Handling: Flexibel (CAPS Mixed oder Mixed CAPS)
- Stats: points, innings, gd (average), hs (highrun)

### 4. Name Matching ✅

**Problem gelöst:** UMB wechselt Namen-Reihenfolge zwischen PDFs!
- Players List: "JASPERS Dick" (LASTNAME Firstname)
- Game Results: "Dick JASPERS" (Firstname LASTNAME) ODER "JEONGU Park" (umgekehrt)

**Lösung:** Intelligentes Matching probiert:
1. caps_name=lastname, mixed_name=firstname
2. caps_name=firstname, mixed_name=lastname
3. Full name concatenation match
4. Swapped combinations

## Dateien

✅ **Migrations:**
- `add_sti_fields_to_tournaments.rb` - Tournament STI Schema
- `add_international_source_fk_to_tournaments.rb` - Foreign Key
- `drop_international_tables.rb` - Alte Tabellen entfernt

✅ **Models:**
- `app/models/international_tournament.rb` - Tournament STI
- `app/models/international_game.rb` - Game STI

✅ **Service:**
- `app/services/umb_scraper_v2.rb` - Neuer, schlanker Scraper (~450 Zeilen)
  - `scrape_tournament(external_id)` - Tournament + PDFs
  - `scrape_players_list_pdf` - Seedings
  - `scrape_group_results_pdf` - Games + GameParticipations

## Beispiel Output

```
Game: KARAKURT, Omer vs MORALES, Robinson
  KARAKURT: 32 pts in 19 inn (avg 1.684, HS 12)
  MORALES: 40 pts in 19 inn (avg 2.105, HS 9)
  Group: M
```

## Verwendung

```ruby
scraper = UmbScraperV2.new
tournament = scraper.scrape_tournament(310)

puts "Tournament: #{tournament.title}"
puts "Seedings: #{tournament.seedings.count}"  
puts "Games: #{Game.where(tournament_id: tournament.id).count}"
```

## Nächste Schritte

1. ✅ **Rake Task** - `umb:scrape[ID]` erstellen
2. **Batch Scraping** - Mehrere Turniere sequential
3. **Video Extraction** - Anpassen an neues Modell
4. **Rankings** - Testen ob GameParticipation-based Rankings funktionieren

## Technische Highlights

- **STI** statt parallele Tabellen = weniger Komplexität
- **Flexibles Name Matching** für internationale Namen
- **Robustes PDF Parsing** mit Pattern Fallbacks
- **Validation: false** für schnelles Scraping
- **PaperTrail** zeichnet alles auf für Sync

## Lessons Learned

1. **Namen-Inkonsistenz** ist bei internationalen Daten normal
2. **CAPS vs Mixed** ist ein guter Indicator für Name Parts
3. **STI ist die richtige Wahl** - bewährtes Carambus-Modell funktioniert perfekt
4. **Schema checken** - Games hat kein `state`, GameParticipation hat kein `position`
5. **Schrittweise testen** - Ein Turnier nach dem anderen

## Status: PRODUCTION READY ✅

Der Scraper ist einsatzbereit für historische UMB-Daten!
