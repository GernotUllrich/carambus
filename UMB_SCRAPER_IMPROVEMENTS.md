# UMB Scraper Verbesserungen

## Übersicht

Dieser Commit behebt drei kritische Probleme mit dem UMB Scraping:

1. ✅ **Disziplin-Erkennung funktioniert nicht korrekt**
2. ✅ **KO-Runden (Knockout) Parsing fehlt**
3. ✅ **Spielname wird nicht in Ergebnislisten angezeigt**

## Problem 1: Disziplin-Erkennung

### Vorher
- Alles wurde als "Cadre 57/2" erkannt, auch wenn im Titel "3 cushion" stand
- Keine Unterscheidung zwischen verschiedenen Cadre-Varianten
- Case-sensitive Pattern Matching

### Nachher
- **Cadre-Varianten werden korrekt erkannt**: 47/2, 57/2, 71/2, 52/2, 35/2
- **3-Cushion Pattern verbessert**: "3 cushion", "3-cushion", "three cushion", "dreiband"
- **Priorität**: Cadre-Patterns werden zuerst geprüft (spezifischer)
- **Case-insensitive**: Alle Pattern sind nun case-insensitive

### Beispiele

```ruby
"World Championship 3 Cushion"        → Dreiband halb ✓
"European Championship Cadre 47/2"    → Cadre 47/2 ✓
"World Cup Cadre 57/2"                → Cadre 57/2 ✓
"World Cup Cadre 71/2"                → Cadre 71/2 ✓
"National Championship 3-Cushion"     → Dreiband halb ✓
"International Tournament Three Cushion" → Dreiband halb ✓
"World Cup 5-Pins"                    → 5-Pin Billards ✓
```

### Code-Änderungen

**Datei**: `app/services/umb_scraper.rb`  
**Methode**: `find_discipline_from_name`

- Cadre-Pattern-Matching mit Regex: `/47[\s\/\-]*2/`
- Verbesserte 3-Cushion Patterns: `/3[\s\-]*cushion|three[\s\-]*cushion|dreiband/`
- Reihenfolge: Cadre → 3-Cushion → 5-Pin → 1-Cushion → Artistique → Libre

## Problem 2: KO-Runden Parsing

### Vorher
- Nur `GroupResults_*.pdf` Dateien wurden geparst
- `MTResults_*.pdf` (Main Tournament = KO-Phase) wurden erkannt aber nicht verarbeitet
- Keine Matches für Quarter Final, Semi Final, Final erstellt

### Nachher
- **Neue Methode**: `parse_knockout_results_pdf` für MTResults PDFs
- **Runden-Erkennung**: Quarter Final, Semi Final, Final, Round of 16, etc.
- **Match-Erstellung**: Paare von aufeinanderfolgenden Spielern werden als Matches erkannt
- **Spielname**: Enthält Runde: "Quarter Final - Match 1"

### PDF Format (MTResults)

```
Quarter Final

                    JASPERS Dick                 40       20     2.000      2       10        8
                    CAUDRON Frederic             35       20     1.750      0        9        7

Semi Final

                    ZANETTI Marco                40       25     1.600      2        8        6
                    MERCKX Eddy                  38       25     1.520      0        7        5
```

### Code-Änderungen

**Datei**: `app/services/umb_scraper.rb`

**Neue Methode**: `parse_knockout_results_pdf(phase_game, pdf_url)`
- Parst MTResults PDFs
- Erkennt Runden-Header (Quarter Final, Semi Final, etc.)
- Paart aufeinanderfolgende Spieler zu Matches
- Erstellt Game-Records mit korrektem Rundennamen

**Erweiterte Methode**: `create_games_from_tournament`
- Ruft nun auch `parse_knockout_results_pdf` auf wenn MTResults PDF vorhanden

## Problem 3: Spielname in Ergebnislisten

### Vorher
- Game-Namen enthielten keine Kontext-Information
- Kein Unterschied zwischen Gruppen- und KO-Phase sichtbar
- Rundennamen fehlten

### Nachher

#### Gruppenphasen-Spiele
```
Format: "Qualification - Group A - Match 5"
Gespeichert in:
  - game.gname: "Qualification - Group A - Match 5"
  - game.group_no: "A"
  - game.data['phase']: "Qualification"
  - game_participation.data['group']: "A"
```

#### KO-Phasen-Spiele
```
Format: "Quarter Final - Match 1"
Gespeichert in:
  - game.gname: "Quarter Final - Match 1"
  - game.group_no: nil
  - game.data['round_name']: "Quarter Final"
  - game_participation.data['round_name']: "Quarter Final"
```

### Code-Änderungen

**Datei**: `app/services/umb_scraper.rb`

**Erweiterte Methode**: `create_games_from_matches`
- Neuer Parameter: `round_name` für KO-Runden
- Dynamische Spielnamen basierend auf Kontext:
  - Gruppen: "Phase - Group X - Match Y"
  - KO: "Phase - Round - Match Y"
- Speichert `round_name` in `game.data` und `game_participation.data`

## Neue Rake Tasks

### Disziplin-Fix für bestehende Turniere
```bash
# Zeigt Statistiken über Disziplinen
rake umb:discipline_stats

# Analysiert und behebt falsche Disziplin-Zuordnungen
rake umb:fix_disciplines
```

### Verwendung

```bash
# Zeige aktuelle Verteilung
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
rake umb:discipline_stats

# Prüfe und korrigiere Disziplinen
rake umb:fix_disciplines
```

## Testing

### Test-Script
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
ruby test_umb_improvements.rb
```

### Erwartete Ausgabe
```
✓ World Championship 3 Cushion → Dreiband halb
✓ European Championship Cadre 47/2 → Cadre 47/2
✓ World Cup Cadre 57/2 → Cadre 57/2
✓ Method parse_knockout_results_pdf exists
✓ Method create_games_from_matches exists
```

## Migration bestehender Daten

### Schritt 1: Analyse
```bash
rake umb:discipline_stats
```

### Schritt 2: Vorschau
```bash
rake umb:fix_disciplines
# Zeigt alle vorgeschlagenen Änderungen
# Fragt vor dem Anwenden um Bestätigung
```

### Schritt 3: Anwendung
```
Apply changes? (y/n)
y
```

### Schritt 4: Verifikation
```bash
rake umb:discipline_stats
```

## Betroffene Dateien

```
Modified:
  app/services/umb_scraper.rb
  docs/UMB_PDF_PARSING.md

Added:
  lib/tasks/umb_fix_disciplines.rake
  test_umb_improvements.rb
  UMB_SCRAPER_IMPROVEMENTS.md (dieses Dokument)
```

## API-Änderungen

### Neue Methoden
- `UmbScraper#parse_knockout_results_pdf(phase_game, pdf_url)`
- Keine Breaking Changes

### Erweiterte Methoden
- `UmbScraper#find_discipline_from_name(name)` - Verbesserte Logik
- `UmbScraper#create_games_from_matches(tournament, phase_game, matches, round_name: nil)` - Neuer Parameter

### Datenstruktur-Änderungen

#### Game.data
```json
{
  "phase": "Quarter Final",
  "phase_game_id": 12345,
  "round_name": "Quarter Final",
  "umb_match_number": 1,
  "umb_scraped_from": "knockout_results_pdf"
}
```

#### GameParticipation.data
```json
{
  "group": "A",
  "round_name": "Quarter Final",
  "high_runs": [10, 8],
  "umb_scraped_from": "knockout_results_pdf"
}
```

## Nächste Schritte

### Sofort
1. ✅ Code-Review
2. ✅ Test mit bestehenden Turnieren
3. ⏳ Migration bestehender Daten mit `rake umb:fix_disciplines`

### Optional
1. Scrape neue Turniere mit verbesserter Logik
2. Re-scrape aller MTResults PDFs für bestehende Turniere
3. UI-Anpassungen für Anzeige von Rundennamen

## Bekannte Einschränkungen

1. **PDF-Reader Gem erforderlich**: `bundle add pdf-reader` falls nicht installiert
2. **Historische Daten**: Bestehende Game-Records werden nicht automatisch aktualisiert
3. **MTResults Format**: Verschiedene Turniere können leicht unterschiedliche Formate haben

## Troubleshooting

### Disziplin wird nicht erkannt
```ruby
# In Rails Console:
scraper = UmbScraper.new
tournament_name = "Your Tournament Name"
detected = scraper.send(:find_discipline_from_name, tournament_name)
puts detected&.name
```

### KO-Matches werden nicht erstellt
- Prüfe ob `parse_pdfs: true` gesetzt ist
- Prüfe PDF-Format in Browser
- Prüfe Logs: `tail -f log/development.log | grep UmbScraper`

### Game-Namen fehlen
- Prüfe `game.gname` und `game.data['round_name']`
- Prüfe `game_participation.data['round_name']`
- Re-scrape mit aktuellem Code

## Support

Bei Problemen siehe:
- Logs: `log/development.log`
- Docs: `docs/UMB_PDF_PARSING.md`
- Tests: `test_umb_improvements.rb`
