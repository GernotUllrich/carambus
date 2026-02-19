# UMB PDF Parsing - Game Participations

## Overview

The UMB scraper now supports parsing PDF files from tournament detail pages to extract game results and create `GameParticipation` records.

## Features

### 1. Tournament Details Scraping

- Fetches tournament details from `https://files.umb-carom.org/public/TournametDetails.aspx?ID=XXX`
- Extracts all PDF links (players list, groups, timetables, results, rankings)
- Identifies distinct game types from GroupResults and MTResults PDFs
- Stores metadata in `InternationalTournament.data` (JSONB field)

### 2. Game Creation

Creates **two types** of `Game` records:

**A) Phase Marker Games** (8 per tournament):
These serve as containers and store PDF metadata:

- PPPQ: Pre-Pre-Pre-Qualification
- PPQ: Pre-Pre-Qualification
- PQ: Pre-Qualification
- Q: Qualification
- R16: Round of 16
- Rank_8: Match for 8th Place
- Quarter_Final: Quarter Final
- Semi_Final-Final: Semi Final & Final

Phase game metadata stored in `game.data`:
```json
{
  "umb_game_type": "Q",
  "umb_category": "group",
  "umb_pdf_url": "https://...",
  "umb_pdf_filename": "J. GroupResults_Q.pdf",
  "umb_scraped_at": "2026-02-18T22:33:04+01:00"
}
```

**B) Individual Match Games** (many per phase):
Each represents a single match between 2 players:

- Game name: "Qualification - Group A - Match 5"
- `group_no`: Group letter (A, B, C, ...)
- Exactly 2 `GameParticipation` records per game

Match game metadata stored in `game.data`:
```json
{
  "phase": "Qualification",
  "phase_game_id": 854353,
  "umb_match_number": 5,
  "umb_scraped_from": "group_results_pdf"
}
```

### 3. PDF Parsing for Game Participations

Parses GroupResults PDFs to extract match data:

**Extracted Data:**
- Player name
- Group (A, B, C, ...)
- Result (Caroms/Points scored)
- Innings played
- Average
- Match Points (2 for win, 0 for loss)
- High Runs (1st and 2nd best)

**GameParticipation Fields:**
- `player_id`: Link to Player record (created if not exists)
- `result`: Total caroms/points
- `innings`: Total innings played
- `gd`: Average (General Durchschnitt)
- `hs`: High Series (best high run)
- `points`: Match points earned
- `data`: Additional info (group, high_runs array, source)

## Usage

### Test Single Tournament

```bash
# Without PDF parsing (just creates Games)
bundle exec rake "umb:test_scrape[310]"

# With PDF parsing (creates Games + GameParticipations)
bundle exec rake "umb:test_scrape[310,true]"
```

### Scrape Range of Tournaments

```bash
# Scrape tournaments 300-350 with full PDF parsing
bundle exec rake "umb:scrape_details[300,350]"
```

### Manual Scraping in Rails Console

```ruby
scraper = UmbScraper.new

# Find tournament
tournament = InternationalTournament.find_by(external_id: '310')

# Scrape without PDF parsing
scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: false)

# Scrape with full PDF parsing
scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: true)
```

## Data Model

### Polymorphic Associations

Games use polymorphic associations to support both Tournaments and Parties:

```ruby
class Game < ApplicationRecord
  belongs_to :tournament, polymorphic: true
  has_many :game_participations
end

class InternationalTournament < Tournament
  has_many :games, as: :tournament
end
```

The `tournament_type` column stores the class name ("Tournament", not the game category).

### Player Management

Players are automatically created from parsed data:

```ruby
# Player fields
firstname: "Christian"
lastname: "LATORRE"
fl_name: "LATORRE Christian"  # Auto-generated
nationality: nil  # Not available in GroupResults PDFs
region_id: 24    # UMB region
international_player: true
```

## PDF Structure

### GroupResults PDFs

Format:
```
Group               Match Players               T-Car    T-Inn    Avg      MP      1st HR  2nd HR

                     OH Sung Kyu                 40       31     1.290      1        5        4
                   KARAKURT Omer                 40       31     1.290      1        6        5

                    LEGAZPI Ruben                40       39     1.025      2       10        5
 A                   OH Sung Kyu                 37       39     0.948      0        4        4
```

Parser recognizes:
- Group indicators (single letter, optionally inline with match data)
- Player names (can contain spaces)
- Match statistics (Points, Innings, Average, Match Points, High Runs)

### MTResults PDFs

Main tournament (knockout) phase PDFs are now supported. The parser handles:

Format:
```
Quarter Final

                    JASPERS Dick                 40       20     2.000      2       10        8
                    CAUDRON Frederic             35       20     1.750      0        9        7

Semi Final

                    ZANETTI Marco                40       25     1.600      2        8        6
                    MERCKX Eddy                  38       25     1.520      0        7        5
```

Parser recognizes:
- Round/section headers (Quarter Final, Semi Final, Final, Round of 16, etc.)
- Player pairs (consecutive players form a match)
- Match statistics (Points, Innings, Average, Match Points, High Runs)
- Creates individual Game records for each knockout match
- Game names include round: "Quarter Final - Match 1"

## Statistics

Example results from tournament #317:

```
Total Games: 228
  - 8 phase marker games (metadata containers)
  - 220 individual match games (each with 2 players)

Total Participations: 440 (220 matches × 2 players)

Sample match:
  Round of 16 - Group F - Match 34
    - DAO Van Ly: 40 pts in 22 inn (MP: 2) ← Winner
    - LONG Nguyen Chi: 36 pts in 22 inn (MP: 0)

Matches per phase:
  - Pre-Pre-Pre-Qualification: 24 matches
  - Pre-Pre-Qualification: 24 matches
  - Pre-Qualification: 24 matches
  - Qualification: 18 matches
  - Round of 16: 16 matches
  - Main Tournament: 0 matches (different PDF format)
```

## Implementation Details

### SSL Certificate Handling

Development environment disables SSL verification for `umb-carom.org`:

```ruby
if Rails.env.development? && uri.host.include?('umb-carom.org')
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
end
```

### PDF Reader Gem

Requires: `pdf-reader` gem

```bash
bundle add pdf-reader
```

### Validation Bypassing

International tournaments may not satisfy all local validations:

```ruby
tournament.save(validate: false)
game.save(validate: false)
participation.save(validate: false)
```

### JSONB Data Storage

Both `tournaments.data` and `games.data` are JSONB columns that store hashes directly:

```ruby
# Correct (Rails handles serialization)
game.data = { umb_game_type: "Q", umb_category: "group" }

# Incorrect (manual JSON string)
game.data = { umb_game_type: "Q" }.to_json  # ERROR!
```

## Recent Enhancements

### ✅ Discipline Detection Improvements

The discipline detection has been significantly improved:

- **Cadre variants**: Now correctly identifies Cadre 47/2, 57/2, 71/2, 52/2, 35/2
- **3-Cushion**: Improved pattern matching for "3 cushion", "3-cushion", "three cushion"
- **Case insensitive**: All pattern matching is now case-insensitive
- **Priority order**: Cadre patterns are checked first (more specific), then 3-Cushion

Example: "World Championship 3 Cushion" → Correctly detected as Dreiband halb (not Cadre 57/2)

### ✅ Knockout Round Parsing

MTResults PDFs (Quarter Final, Semi Final, Final, etc.) are now fully parsed:

- Recognizes round headers (Quarter Final, Semi Final, Final, Round of 16, etc.)
- Pairs consecutive players into knockout matches
- Creates individual Game records for each match
- Game names include round: "Quarter Final - Match 1"
- Stores round name in game.data and game_participation.data

### ✅ Game Names in Result Lists

Game names now clearly show the context:

**Group Phase:**
- Format: "Qualification - Group A - Match 5"
- Stored in: `game.gname`
- Group letter: `game.group_no`

**Knockout Phase:**
- Format: "Quarter Final - Match 1"
- Stored in: `game.gname`
- Round name: `game.data['round_name']`

**GameParticipation Data:**
- `game_participation.data['group']`: Group letter (if applicable)
- `game_participation.data['round_name']`: Round name (if knockout)
- `game_participation.data['umb_scraped_from']`: Source PDF type

## Future Enhancements

### Player Nationality

GroupResults PDFs don't include nationality. This information is available in the Players List PDF (A. Players List.pdf) but requires separate parsing.

### InternationalParticipation vs GameParticipation

Currently using `GameParticipation` for direct game-level results. The `InternationalParticipation` model could be used for tournament-level participation tracking (separate from individual game results).

## Troubleshooting

### No Participations Created

Check:
1. `parse_pdfs: true` parameter is set
2. PDF URL is valid and accessible
3. PDF format matches expected structure
4. Check logs for parsing errors

### Player Not Found/Created

Players are created with minimal data. The `find_or_create_international_player` method needs:
- firstname, lastname (from name parsing)
- region (UMB)
- Optionally: umb_player_id, nationality

### Data Not Persisting

Ensure JSONB fields receive hashes, not JSON strings:

```ruby
# Correct
game.data = { key: "value" }
game.save

# Wrong
game.data = { key: "value" }.to_json  # TypeError!
```
