# UMB Scraping — Architecture

The `Umb::` namespace handles scraping of tournament data from the Union Mondiale de Billard (UMB) official website [files.umb-carom.org](https://files.umb-carom.org). It consists of **10 services** across two sub-namespaces: `Umb::` (7 classes + 1 module) and `Umb::PdfParser::` (3 classes).

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `Umb::HttpClient` | `app/services/umb/http_client.rb` | Stateless HTTP transport — fetches HTML and PDF content from UMB URLs, handles SSL, redirects, and timeouts |
| `Umb::DisciplineDetector` | `app/services/umb/discipline_detector.rb` | Stateless PORO — maps tournament names to `Discipline` DB records via regex + DB-ILIKE fallback |
| `Umb::DateHelpers` | `app/services/umb/date_helpers.rb` | Module with `module_function` — parses UMB date range strings into `{start_date:, end_date:}` hashes |
| `Umb::PlayerResolver` | `app/services/umb/player_resolver.rb` | Finds or creates `Player` records from UMB caps/mixed-case name pairs, enriches umb_player_id and nationality |
| `Umb::FutureScraper` | `app/services/umb/future_scraper.rb` | Scrapes `FutureTournaments.aspx`, parses HTML table including cross-month events, creates/updates `InternationalTournament` records |
| `Umb::ArchiveScraper` | `app/services/umb/archive_scraper.rb` | Sequential ID scan of `TournametDetails.aspx?ID=N`, discovers and saves historical tournament records |
| `Umb::DetailsScraper` | `app/services/umb/details_scraper.rb` | Scrapes a tournament detail page, extracts PDF links, creates `InternationalGame` records, and orchestrates the PDF pipeline |

**Umb::PdfParser:: sub-namespace:**

| Class | File | Description |
|-------|------|-------------|
| `Umb::PdfParser::PlayerListParser` | `app/services/umb/pdf_parser/player_list_parser.rb` | Pure PORO — parses player seeding list PDF text into `{caps_name:, mixed_name:, nationality:, position:}` hashes |
| `Umb::PdfParser::GroupResultParser` | `app/services/umb/pdf_parser/group_result_parser.rb` | Pure PORO — parses group result PDF text into match pairs using a pair-accumulator pattern |
| `Umb::PdfParser::RankingParser` | `app/services/umb/pdf_parser/ranking_parser.rb` | Pure PORO — parses final or weekly ranking PDF text; supports `:final` and `:weekly` type modes |

## Architecture Decisions

### a. PORO vs. ApplicationService

Services are divided based on side effects:

- **POROs** (no DB access): `Umb::DisciplineDetector`, `Umb::DateHelpers`, `Umb::PdfParser::PlayerListParser`, `Umb::PdfParser::GroupResultParser`, `Umb::PdfParser::RankingParser`
- **ApplicationService** (DB side effects): `Umb::FutureScraper`, `Umb::ArchiveScraper`, `Umb::DetailsScraper`, `Umb::PlayerResolver`

### b. Module vs. Class

`Umb::DateHelpers` is a `module` with `module_function` and is called statically:

```ruby
Umb::DateHelpers.parse_date_range("18-21 Dec 2025")
```

All other nine services are classes.

### c. Delegation Pattern

The three scraper classes (`FutureScraper`, `ArchiveScraper`, `DetailsScraper`) delegate:
- HTTP requests to `Umb::HttpClient`
- Date parsing to `Umb::DateHelpers`
- Discipline detection to `Umb::DisciplineDetector`

They do not perform their own HTTP logic or date parsing.

### d. Optional PDF Pipeline

`DetailsScraper#call` defaults to `parse_pdfs: false`. When enabled, all three PdfParser services are run **independently** — no short-circuit on individual failures:

1. `Umb::PdfParser::PlayerListParser` → Seeding records
2. `Umb::PdfParser::GroupResultParser` → `InternationalGame` + `GameParticipation`
3. `Umb::PdfParser::RankingParser` → Seedings with final position

### e. InternationalGame STI

`DetailsScraper` creates game records with `type: 'InternationalGame'` (STI). Omitting this causes incorrect ActiveRecord behavior, since `Game` is the base class.

## Data Flow

```
UMB Website
  ├── FutureTournaments.aspx ──→ Umb::FutureScraper
  │                                    ├── Umb::HttpClient (fetch HTML)
  │                                    ├── Umb::DateHelpers (parse dates)
  │                                    └── Umb::DisciplineDetector (match discipline)
  │                                         → InternationalTournament (upsert)
  │
  ├── TournametDetails.aspx?ID=N ──→ Umb::ArchiveScraper
  │                                        ├── Umb::HttpClient (fetch HTML)
  │                                        ├── Umb::DateHelpers (parse dates)
  │                                        └── Umb::DisciplineDetector (match discipline)
  │                                             → InternationalTournament (create)
  │
  └── TournametDetails.aspx?ID=N ──→ Umb::DetailsScraper
           ├── Umb::HttpClient (fetch HTML + PDFs)
           ├── Umb::PlayerResolver (find/create Player)
           ├── PDF pipeline (optional, parse_pdfs: true):
           │     ├── PdfParser::PlayerListParser → Seeding records
           │     ├── PdfParser::GroupResultParser → InternationalGame + GameParticipation
           │     └── PdfParser::RankingParser → Seedings with final position
           └── InternationalGame records (HTML-based, create_games: true)
```

## Entry Points

The three primary entry points for operation:

- `Umb::FutureScraper.new.call` — scrapes upcoming tournaments from the UMB site, no parameters
- `Umb::ArchiveScraper.new.call(start_id:, end_id:)` — scans historical tournament IDs within a range
- `Umb::DetailsScraper.new.call(tournament_id_or_record)` — enriches one tournament with games and PDF data

For a complete method reference with signatures, return values, and parameters, see the [Method Reference](umb-scraping-methods.md).
