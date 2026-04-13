# UMB Scraping — Method Reference

This page documents the public entry points and key methods of the `Umb::` namespace services. For an overview of the architecture and design decisions, see the [Architecture Documentation](umb-scraping-implementation.md).

## Scraper Entry Points

### `Umb::FutureScraper`

**File:** `app/services/umb/future_scraper.rb`

```ruby
Umb::FutureScraper.new.call
```

**Parameters:** none

**Description:** Scrapes `FutureTournaments.aspx` on the UMB website. Parses the HTML table including cross-month events and applies duplicate detection (title + location + date ±30 days).

**DB effects:**
- Creates or updates `InternationalTournament` records
- Creates `Location`, `Season`, and `Region` (UMB organizer) records as needed

**Return value:** `Integer` — number of tournaments saved/updated

---

### `Umb::ArchiveScraper`

**File:** `app/services/umb/archive_scraper.rb`

```ruby
Umb::ArchiveScraper.new.call(start_id: 1, end_id: 500)
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start_id:` | Integer | `1` | First tournament ID to check |
| `end_id:` | Integer | `500` | Last tournament ID to check (inclusive) |
| `batch_size:` | Integer | `50` | Rate limiting: sleep after every this many IDs |

**Description:** Scans `TournametDetails.aspx?ID=N` sequentially for each ID in the given range. Stops early after 50 consecutive IDs not found. Skips already-known tournaments (by `external_id`).

**DB effects:**
- Creates new `InternationalTournament` records for discovered tournaments
- Creates `Location`, `Season`, and `Region` records as needed

**Return value:** `Integer` — number of tournaments saved

---

### `Umb::DetailsScraper`

**File:** `app/services/umb/details_scraper.rb`

```ruby
Umb::DetailsScraper.new.call(tournament_id_or_record, create_games: true, parse_pdfs: false)
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tournament_id_or_record` | Integer / InternationalTournament | — | DB id or existing record |
| `create_games:` | Boolean | `true` | Whether to create `InternationalGame` records from the HTML table |
| `parse_pdfs:` | Boolean | `false` | Whether to run the PDF pipeline (PlayerList, GroupResults, Ranking) |

**Description:** Scrapes a tournament detail page from `TournametDetails.aspx?ID=N`. Extracts and categorises PDF links, updates tournament fields (location, season, organiser). When `create_games: true`, creates `InternationalGame` records with `type: 'InternationalGame'` (STI). When `parse_pdfs: true`, runs all three PdfParser services independently.

**DB effects:**
- Updates the existing `InternationalTournament` record
- Creates `InternationalGame` records (when `create_games: true`)
- Creates `Seeding` and `GameParticipation` records (when `parse_pdfs: true`)

**Return value:** `InternationalTournament` record on success, `false` on error

---

## PDF Parsers

### `Umb::PdfParser::PlayerListParser`

**File:** `app/services/umb/pdf_parser/player_list_parser.rb`

```ruby
Umb::PdfParser::PlayerListParser.new(pdf_text).parse
```

**Input:** Extracted PDF text (String) of a UMB player seeding list

**Output:** Array of hashes with these keys:

```ruby
[
  { position: 1, caps_name: "JASPERS", mixed_name: "Dick", nationality: "NL" },
  { position: 2, caps_name: "CAUDRON", mixed_name: "Frederic", nationality: "FR" },
  # ...
]
```

**Notes:**
- Pure PORO — no DB access
- Returns `[]` for nil/empty input or when no player lines are found
- `caps_name` is the surname in uppercase (UMB PDF convention)
- `mixed_name` is the given name in mixed case

---

### `Umb::PdfParser::GroupResultParser`

**File:** `app/services/umb/pdf_parser/group_result_parser.rb`

```ruby
Umb::PdfParser::GroupResultParser.new(pdf_text).parse
```

**Input:** Extracted PDF text (String) of a UMB group result

**Output:** Array of match hashes:

```ruby
[
  {
    group: "A",
    player_a: { name: "JASPERS Dick", nationality: nil, points: 30, innings: 14, average: 2.142, match_points: 2, hs: 9 },
    player_b: { name: "CAUDRON Frederic", nationality: nil, points: 25, innings: 14, average: 1.785, match_points: 0, hs: 5 },
    winner_name: "JASPERS Dick"
  },
  # ...
]
```

**Notes:**
- Pure PORO — no DB access
- Uses a pair-accumulator pattern: first player line is held, second completes the match
- Returns `[]` for nil/empty input
- `nationality` is not present in group result PDFs (always `nil`)

---

### `Umb::PdfParser::RankingParser`

**File:** `app/services/umb/pdf_parser/ranking_parser.rb`

```ruby
Umb::PdfParser::RankingParser.new(pdf_text, type: :final).parse
Umb::PdfParser::RankingParser.new(pdf_text, type: :weekly).parse
```

**Input:**
- `pdf_text` — Extracted PDF text (String) of a UMB ranking
- `type:` — `:final` (tournament final ranking) or `:weekly` (weekly UMB world ranking)

**Output for `type: :final`:**

```ruby
[
  { position: 1, player_name: "JASPERS Dick", nationality: "NL", points: 150, average: 2.500 },
  # ...
]
```

**Output for `type: :weekly`:**

```ruby
[
  { rank: 1, player_name: "JASPERS Dick", nationality: "NL", points: 1200 },
  # ...
]
```

**Notes:**
- Pure PORO — no DB access
- Returns `[]` for nil/empty input or unknown type
- Weekly rankings are available at `files.umb-carom.org/Public/Ranking/`

---

## Supporting Services

The following services are used internally by the scrapers and have no direct public entry points for operation:

| Service | Called by |
|---------|-----------|
| `Umb::HttpClient` | FutureScraper, ArchiveScraper, DetailsScraper |
| `Umb::DisciplineDetector` | FutureScraper, ArchiveScraper, DetailsScraper |
| `Umb::DateHelpers` | FutureScraper, ArchiveScraper, DetailsScraper |
| `Umb::PlayerResolver` | DetailsScraper |

For full descriptions of these services, see the [Architecture Documentation](umb-scraping-implementation.md).
