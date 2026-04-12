# Phase 26: UmbScraper Service Extraction + V2 Absorption - Research

**Researched:** 2026-04-12
**Domain:** Rails service extraction, Ruby PORO/ApplicationService patterns, PDF parsing
**Confidence:** HIGH (full source read, no external lookups required — this is pure refactoring)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-02:** Planned services: PlayerResolver, PdfParser (or split), DetailsScraper, FutureScraper, ArchiveScraper. `Umb::HttpClient` already exists from Phase 25.
- **D-03:** PORO for stateless/pure-algorithm services, ApplicationService for side-effect-heavy services.
- **D-04:** Delete `umb_scraper_v2.rb` entirely after absorbing its PDF parsing. Also delete its characterization test. Clean break — V2 has zero production callers.
- **D-05:** Write new tests for the extracted `Umb::` services that cover the same behavior V2's char tests pinned.
- **D-06:** Absorb ALL three PDF types: player lists (working in V2), group results (working in V2), AND final rankings (stub in V2 — implement fully).
- **D-07:** RANK-01 (ranking PDF extraction) pulled into Phase 26 scope. UMB ranking PDFs from `files.umb-carom.org/Public/Ranking/` are in scope.
- **D-08:** PDF parsing must produce structured data (player names, rounds, scores) consumable by Phase 27's `Video::TournamentMatcher`.

### Claude's Discretion

- **D-01:** Single `Umb::PdfParser` vs split by PDF type (`Umb::PlayerListParser`, `Umb::GroupResultParser`, `Umb::RankingParser`)
- **D-09:** Optimal extraction order based on dependency analysis

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCRP-06 | Extract UmbScraper into `Umb::` namespaced services (HttpClient, PlayerResolver, PdfParser, DetailsScraper, FutureScraper, ArchiveScraper) | Full method inventory below maps each method to its target service |
| SCRP-07 | Merge UmbScraperV2 overlapping logic into unified `Umb::` services, reduce V2 to thin facade or deprecate | V2 method inventory below; all unique logic maps to `Umb::PdfParser` and `Umb::PlayerResolver` |
</phase_requirements>

---

## Summary

`UmbScraper` (2133 lines, `app/services/umb_scraper.rb`) is a single-class monolith with six distinct responsibility clusters: HTTP transport, future-tournament HTML scraping, archive/detail scraping, player resolution, PDF parsing, and game record creation. `UmbScraperV2` (585 lines) duplicates the HTTP layer but contributes the only working PDF parsing pipeline in the codebase. `Umb::HttpClient` already exists from Phase 25 and handles HTTP transport.

The extraction is straightforward bottom-up: each private method cluster maps cleanly to one target service with minimal cross-cluster dependencies. The most complex decision is game creation: both scrapers create `Game` + `GameParticipation` records inside their PDF parsers, and this side-effectful logic belongs in `Umb::PdfParser` (or a dedicated `Umb::GameCreator` helper).

The `scrape_rankings` public method in `UmbScraper` is a documented stub (returns 0, logs "not yet implemented"). Implementing ranking PDF parsing is genuinely new work for Phase 26 — the UMB ranking URL pattern is known (`files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf`) but the PDF format must be inferred from structure.

**Primary recommendation:** Extract bottom-up in five waves: PlayerResolver → PdfParser (with split by type: PlayerListParser, GroupResultParser, RankingParser) → DetailsScraper → FutureScraper → ArchiveScraper. Reduce `UmbScraper` to thin delegation wrapper at the end. Delete V2 and its test after PdfParser is verified.

---

## Standard Stack

### Core (already in project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `pdf-reader` | In Gemfile | PDF text extraction | Already used by V2; `PDF::Reader.new(StringIO.new(pdf_data))` pattern established |
| `nokogiri` | In Gemfile | HTML parsing | Used in both scrapers for `doc.css(...)` selectors |
| `Umb::HttpClient` | Phase 25 | HTTP transport with SSL | Already extracted; `fetch_url` with redirect handling and User-Agent |

### No new gems required

This phase is pure refactoring + new PDF parsing. All dependencies exist.

---

## Architecture Patterns

### Recommended Project Structure (after Phase 26)

```
app/services/umb/
├── http_client.rb           # EXISTING (Phase 25) — HTTP transport PORO
├── player_resolver.rb       # NEW — find_or_create player by name/umb_player_id
├── pdf_parser/
│   ├── player_list_parser.rb  # NEW — players list PDF → Seeding records
│   ├── group_result_parser.rb # NEW — group results PDF → Game + GameParticipation records
│   └── ranking_parser.rb      # NEW — final ranking PDF + weekly ranking PDFs
├── details_scraper.rb       # NEW — scrape_tournament_details logic
├── future_scraper.rb        # NEW — scrape_future_tournaments logic
└── archive_scraper.rb       # NEW — scrape_tournament_archive logic

app/services/
├── umb_scraper.rb           # REDUCED — thin delegation wrapper only (public API unchanged)
└── umb_scraper_v2.rb        # DELETED — after PdfParser verified

test/services/umb/
├── http_client_test.rb      # EXISTING
├── player_resolver_test.rb  # NEW
├── pdf_parser/
│   ├── player_list_parser_test.rb
│   ├── group_result_parser_test.rb
│   └── ranking_parser_test.rb
├── details_scraper_test.rb  # NEW (WebMock/fixture-backed)
├── future_scraper_test.rb   # NEW (WebMock/VCR)
└── archive_scraper_test.rb  # NEW (WebMock)
```

### Pattern 1: PORO extraction (pure logic, no side effects)

Use for: `Umb::PlayerListParser`, `Umb::GroupResultParser`, `Umb::RankingParser` (PDF text → structured data only)

```ruby
# Source: [VERIFIED: app/services/league/standings_calculator.rb]
# Source: [VERIFIED: app/services/tournament/ranking_calculator.rb]
class Umb::GroupResultParser
  # frozen_string_literal: true

  # Parst Group Results PDF Text → strukturierte Match-Daten.
  # Kein ORM-Coupling: gibt Hashes zurück, keine DB-Aufrufe.

  def initialize(pdf_text)
    @pdf_text = pdf_text
  end

  # Returns Array of { group:, player_a:, player_b: } match hashes
  def parse
    # ... extracted from scrape_group_results_pdf / V2's scrape_group_results_pdf
  end
end
```

### Pattern 2: ApplicationService for side-effect services

Use for: `Umb::DetailsScraper`, `Umb::FutureScraper`, `Umb::ArchiveScraper`, `Umb::PlayerResolver`

```ruby
# Source: [VERIFIED: app/services/application_service.rb pattern in project]
class Umb::FutureScraper
  # frozen_string_literal: true

  def initialize
    @http = Umb::HttpClient.new
    @umb_source = InternationalSource.find_or_create_by!(...)
  end

  def call
    # scrape_future_tournaments logic
  end
end
```

### Pattern 3: Thin delegation wrapper (permanent API)

```ruby
# Source: [VERIFIED: v4.0 Key Decision — thin facades are permanent API, not transitional shims]
class UmbScraper
  def scrape_future_tournaments
    Umb::FutureScraper.new.call
  end

  def scrape_tournament_archive(start_id: 1, end_id: 500, batch_size: 50)
    Umb::ArchiveScraper.new.call(start_id: start_id, end_id: end_id, batch_size: batch_size)
  end

  def scrape_tournament_details(tournament_id_or_record, create_games: true, parse_pdfs: false)
    Umb::DetailsScraper.new.call(tournament_id_or_record, create_games: create_games, parse_pdfs: parse_pdfs)
  end

  def detect_discipline_from_name(tournament_name)
    Umb::DisciplineDetector.detect(tournament_name)
    # OR inline the pure logic here — it's used by admin controller via .send(:find_discipline_from_name)
  end
end
```

### Anti-Patterns to Avoid

- **Extracting to ApplicationService when PORO suffices:** PDF text parsing has no DB side effects. Use PORO. Game/Seeding creation is separate concern.
- **Duplicating `fetch_url`:** Both scrapers have private `fetch_url`. Both must delegate to `Umb::HttpClient.new.fetch_url` — do not copy the method into the new services.
- **Leaving `download_pdf` duplicated:** Both scrapers have a `download_pdf` that calls `fetch_url` then `PDF::Reader.new(StringIO.new(...))`. This belongs in `Umb::HttpClient` or a shared `pdf_text_from_url` helper on the client.

---

## Complete Method Inventory

### UmbScraper Public Methods (all must have delegation wrappers)

| Method | Line | Target Service | Notes |
|--------|------|----------------|-------|
| `initialize` | 36 | `UmbScraper` (keep) | Wrapper init; delegates umb_source creation |
| `detect_discipline_from_name` | 51 | `Umb::DisciplineDetector` (PORO, or inline) | Called by `Admin::IncompleteRecordsController` via `.send` — must remain accessible |
| `scrape_future_tournaments` | 111 | `Umb::FutureScraper#call` | Returns Integer count |
| `scrape_rankings` | 137 | `Umb::RankingParser` (NEW implementation) | Currently stub returning 0; RANK-01 makes this real |
| `scrape_tournament_archive` | 151 | `Umb::ArchiveScraper#call` | Keyword args: `start_id:`, `end_id:`, `batch_size:` |
| `fetch_tournament_basic_data` | 204 | `Umb::DetailsScraper` | Called by rake tasks and characterization tests |
| `save_tournament_from_details` | 239 | `Umb::DetailsScraper` | Used internally by archive path |
| `scrape_tournament_details` | 297 | `Umb::DetailsScraper#call` | Main detail-page entry; keyword args: `create_games:`, `parse_pdfs:` |

### UmbScraper Private Methods (extract or inline by target)

| Method | Line | Target Service | PORO or AS? |
|--------|------|----------------|-------------|
| `fetch_url` | 481 | DELETE — delegate to `Umb::HttpClient` | — |
| `parse_future_tournaments` | 529 | `Umb::FutureScraper` | internal |
| `extract_tournament_from_row` | 617 | `Umb::FutureScraper` | internal |
| `extract_location` | 732 | `Umb::FutureScraper` / shared | pure |
| `parse_location_components` | 758 | `Umb::DetailsScraper` / shared | pure |
| `country_name_to_code` | 791 | shared helper | pure |
| `find_or_create_location_from_text` | 819 | `Umb::DetailsScraper` | side-effect |
| `find_or_create_season_from_date` | 846 | `Umb::DetailsScraper` / shared | side-effect |
| `find_or_create_umb_organizer` | 870 | `Umb::DetailsScraper` / shared | side-effect |
| `enhance_date_with_context` | 898 | `Umb::FutureScraper` | pure |
| `save_tournaments` | 935 | `Umb::FutureScraper` | side-effect |
| `parse_date_range` | 1064 | shared date helper | pure |
| `parse_single_date` | 1094 | shared | pure |
| `parse_day_range_with_month` | 1106 | shared | pure |
| `parse_month_day_range` | 1153 | shared | pure |
| `parse_full_month_range` | 1183 | shared (stub) | pure |
| `parse_month_name` | 1189 | shared | pure |
| `find_discipline_from_name` | 1211 | `Umb::DisciplineDetector` | pure |
| `determine_tournament_type` | 1286 | shared | pure |
| `parse_tournament_detail_for_archive` | 1316 | `Umb::ArchiveScraper` | internal |
| `save_archived_tournament` | 1374 | `Umb::ArchiveScraper` | side-effect |
| `parse_date` | 1438 | shared | pure |
| `determine_discipline_from_name` | 1468 | `Umb::DisciplineDetector` (NOTE: duplicate of `find_discipline_from_name` with different logic!) | pure |
| `save_archived_tournaments` | 1479 | DEAD CODE — never called by active path | delete |
| `parse_location_country` | 1536 | shared | pure |
| `make_absolute_url` | 1549 | `Umb::HttpClient` or shared | pure |
| `download_pdf` | 1560 | DELETE — move to `Umb::HttpClient#fetch_pdf` | — |
| `scrape_players_from_pdf` | 1588 | `Umb::PlayerListParser` | side-effect |
| `scrape_results_from_pdf` | 1637 | `Umb::RankingParser` | side-effect |
| `save_participations` | 1680 | `Umb::PlayerListParser` (or separate) | side-effect |
| `save_results` | 1724 | `Umb::RankingParser` (or separate) | side-effect (uses legacy `InternationalResult`) |
| `find_or_create_international_player` | 1772 | `Umb::PlayerResolver` | side-effect |
| `create_games_for_tournament` | 1820 | `Umb::DetailsScraper` | side-effect |
| `parse_group_results_pdf` | 1879 | `Umb::GroupResultParser` | mixed |
| `create_games_from_matches` | 1960 | `Umb::GroupResultParser` (or `Umb::GameCreator`) | side-effect |
| `parse_knockout_results_pdf` | 2047 | `Umb::GroupResultParser` | mixed |

### UmbScraperV2 Method Inventory (absorb unique logic, delete rest)

| Method | Line | Action | Target |
|--------|------|--------|--------|
| `initialize` | 17 | DELETE (same logic as UmbScraper) | — |
| `scrape_tournament` | 31 | DELETE (only caller: `umb_v2.rake`) | — |
| `fetch_url` | 57 | DELETE — use `Umb::HttpClient` | — |
| `parse_tournament_details` | 94 | DELETE — superseded by `Umb::DetailsScraper` | — |
| `save_tournament` | 174 | DELETE — superseded | — |
| `scrape_pdfs_for_tournament` | 220 | ABSORB → `Umb::PdfParser#call` entry | `Umb::PdfParser` |
| `scrape_players_list_pdf` | 236 | ABSORB → `Umb::PlayerListParser` | Better regex/pattern than V1 |
| `scrape_group_results_pdf` | 290 | ABSORB → `Umb::GroupResultParser` | V2 pair-accumulator pattern is different from V1 |
| `scrape_final_ranking_pdf` | 362 | IMPLEMENT → `Umb::RankingParser` | Currently stub; new work |
| `create_game_from_match` | 369 | ABSORB → `Umb::GroupResultParser` | Game creation from PDF pairs |
| `create_game_participation` | 412 | ABSORB → `Umb::GroupResultParser` | GameParticipation creation |
| `find_player_by_caps_and_mixed` | 431 | ABSORB → `Umb::PlayerResolver` | Caps+mixed name resolution strategy |
| `find_player_by_name` | 447 | ABSORB → `Umb::PlayerResolver` | Name swap handling |
| `find_or_create_player` | 459 | ABSORB → `Umb::PlayerResolver` | Similar to V1 `find_or_create_international_player` but cleaner |
| `download_pdf` | 495 | DELETE — use `Umb::HttpClient#fetch_pdf` | — |
| `make_absolute_url` | 510 | DELETE — duplicate of UmbScraper version | — |
| `parse_single_date` | 519 | DELETE — duplicate | — |
| `parse_date_range` | 543 | DELETE — duplicate | — |
| `determine_discipline_from_name` | 570 | DELETE — duplicate | — |
| `determine_tournament_type` | 578 | DELETE — duplicate | — |

---

## Critical Differences Between V1 and V2 PDF Parsers

This section is essential for deciding what to keep.

### PlayerList PDF: V1 vs V2

Both scrapers implement `scrape_players_from_pdf` / `scrape_players_list_pdf`. They use similar regex but differ in:
- **V2** creates `Seeding` records (correct current data model)
- **V1** calls `save_participations` → creates `Seeding` records but also has a dead `save_results` path that references `InternationalResult` (old model, may no longer exist)

**Decision:** Use V2's implementation as the base for `Umb::PlayerListParser`.

### GroupResults PDF: V1 vs V2

Two different parsing strategies exist:

**V1 approach** (`parse_group_results_pdf`, line 1879):
- Creates "phase game" records (`tournament.games.find_or_initialize_by(gname: ...)`) then creates individual match games inside those
- Two-level hierarchy: phase game → match games
- Groups consecutive player lines into pairs via `each_slice(2)`
- Creates `Game` records with `type: nil` (not `InternationalGame`)

**V2 approach** (`scrape_group_results_pdf`, line 290):
- Stateful line-by-line accumulator: stores `pending_player`, creates game when pair found
- More robust: handles group header detection, skips malformed lines
- Creates `Game` with `type: 'InternationalGame'` explicitly
- Simpler game hierarchy (flat, not two-level)

**Decision:** V2's pair-accumulator approach is cleaner. Use V2 as the base. But extract the text-parsing (pure function) from the side-effectful game creation. The `Umb::GroupResultParser` PORO returns match data; a separate `Umb::GameCreator` (or the parser itself) handles DB writes.

### Ranking PDF: New Work

V2's `scrape_final_ranking_pdf` is a stub:
```ruby
def scrape_final_ranking_pdf(tournament, pdf_url)
  Rails.logger.info "[UmbScraperV2] Final Ranking PDF parsing not yet implemented"
  0
end
```

V1's `scrape_results_from_pdf` (line 1637) has a partial implementation using a loose regex pattern. This implementation:
- Uses a complex multiline `scan` with optional capture groups for Points/Average
- Creates `InternationalResult` records — but `InternationalResult` is an old model; check if it still exists
- The regex pattern may not match real UMB ranking PDFs

**For `Umb::RankingParser`, the planner must include:**
1. A Wave 0 fixture task: download a real UMB ranking PDF and add it as a test fixture
2. Implementation based on actual PDF structure (see URL pattern: `files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf`)
3. Output: structured data (position, player name, nationality, points, average) that `Video::TournamentMatcher` can consume per D-08

---

## Dependency Graph

The dependency graph determines the safest extraction order:

```
Umb::HttpClient (Phase 25, DONE)
    └── depended on by: ALL other services

Umb::PlayerResolver
    └── depends on: HttpClient (none direct), Player model
    └── depended on by: PlayerListParser, GroupResultParser

Umb::PlayerListParser (PORO: text → data)
    └── depends on: PlayerResolver (for Seeding creation), pdf-reader
    └── depended on by: DetailsScraper (via parse_pdfs:), PdfParser entry

Umb::GroupResultParser (PORO: text → data + Game creation)
    └── depends on: PlayerResolver (player lookup), Game/GameParticipation models
    └── depended on by: DetailsScraper (via parse_pdfs:)

Umb::RankingParser (PORO: text → data + optional Seeding update)
    └── depends on: PlayerResolver
    └── depended on by: FutureScraper (ranking PDFs), DetailsScraper

Umb::DetailsScraper
    └── depends on: HttpClient, PlayerResolver, PlayerListParser, GroupResultParser
    └── depended on by: UmbScraper#scrape_tournament_details wrapper

Umb::FutureScraper
    └── depends on: HttpClient, date helpers
    └── depended on by: UmbScraper#scrape_future_tournaments wrapper

Umb::ArchiveScraper
    └── depends on: HttpClient, date helpers, discipline helpers
    └── depended on by: UmbScraper#scrape_tournament_archive wrapper
```

**Recommended extraction order (bottom-up, D-09):**

1. `Umb::PlayerResolver` — no upstream dependencies beyond models; independently testable
2. `Umb::PlayerListParser` (PORO, text-only) + side-effect companion — absorbs V2's players list logic
3. `Umb::GroupResultParser` (PORO, text-only) + `Umb::GameCreator` — absorbs V2's group results + V1's create_games_from_matches
4. `Umb::RankingParser` — new implementation; needs real PDF fixture first (Wave 0 task)
5. `Umb::DetailsScraper` — wires parsers together; large but mostly mechanical delegation
6. `Umb::FutureScraper` — self-contained HTML scraper for future tournaments page
7. `Umb::ArchiveScraper` — sequential ID scanner; thin wrapper around detail page logic
8. Reduce `UmbScraper` to delegation wrappers
9. Delete V2 + its char test

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PDF text extraction | Custom binary parser | `PDF::Reader.new(StringIO.new(data))` | Already in Gemfile, tested by V2 |
| HTTP with redirects | Custom loop | `Umb::HttpClient#fetch_url` | Already extracted in Phase 25 |
| SSL mode selection | Hardcoded VERIFY_NONE | `Umb::HttpClient.ssl_verify_mode` | Already handles env-based selection |
| Player deduplication | New fuzzy match | Extend `Umb::PlayerResolver` with caps+mixed strategy from V2 | V2 already handles the Asian name ordering problem |

---

## Common Pitfalls

### Pitfall 1: `find_discipline_from_name` vs `determine_discipline_from_name` — Two methods with the same job

**What goes wrong:** UmbScraper has TWO different private methods with similar names and different logic:
- `find_discipline_from_name` (line 1211) — comprehensive DB lookup with ILIKE queries, returns Discipline object
- `determine_discipline_from_name` (line 1468) — simple string → string mapping, returns name string

These serve different call sites. The archive scraper uses `determine_discipline_from_name` to get a name, then calls `Discipline.find_by(name: ...)`. The main detail scraper uses `find_discipline_from_name` to get a Discipline object.

**How to avoid:** During extraction, identify which call sites need which version. Consolidate to one canonical `Umb::DisciplineDetector.detect(name) → Discipline` that returns a Discipline record (not a name string). The `detect_discipline_from_name` public method (used by admin controller) should stay on `UmbScraper` as a thin wrapper that delegates.

### Pitfall 2: The admin controller uses `.send(:find_discipline_from_name, ...)`

**What goes wrong:** `Admin::IncompleteRecordsController` calls `scraper.send(:find_discipline_from_name, tournament.title)` (line 88). This uses Ruby's `send` to call a private method. If `find_discipline_from_name` is removed from `UmbScraper` during extraction, this call will silently break.

**How to avoid:** Either (a) keep `find_discipline_from_name` as a public delegation method on `UmbScraper`, or (b) refactor the controller call to use `Umb::DisciplineDetector.detect(...)` directly. Option (b) is cleaner but touches a caller. Prefer (a) as a thin public wrapper.

### Pitfall 3: V1 and V2 PDF parsers use different game models

**What goes wrong:**
- V1's `create_games_from_matches` creates `Game` records with `type: nil` (line 1987: `tournament.games.find_or_initialize_by(gname: ...)`)
- V2's `create_game_from_match` creates `Game` records with `type: 'InternationalGame'` explicitly (line 388)

Mixing these in tests will produce inconsistent behavior. `InternationalGame` is the STI subclass; `type: nil` creates a base `Game` record for a tournament that IS an `InternationalTournament`.

**How to avoid:** `Umb::GroupResultParser` should always create `type: 'InternationalGame'` records (V2 approach). Verify `InternationalGame` model exists and has the expected `game_participations` association.

### Pitfall 4: `save_results` references `InternationalResult` — possibly a deleted model

**What goes wrong:** `UmbScraper#save_results` (line 1743) creates `InternationalResult` records. This model is not present in the models directory based on research (the STI hierarchy uses `Game`/`GameParticipation` for results). This method may be dead code or reference a model that no longer exists.

**How to avoid:** Before absorbing `scrape_results_from_pdf` into `Umb::RankingParser`, verify whether `InternationalResult` still exists. If not, the ranking parser should create `Seeding` records with position data instead (matching the V2 pattern for players list).

### Pitfall 5: V2's `scrape_pdfs_for_tournament` treats groups and final_ranking as mutually exclusive

**What goes wrong:** V2's `scrape_pdfs_for_tournament` (line 220-233) only parses `groups` OR `final_ranking` (elif logic). UMB tournaments have group stage PDFs AND a separate final ranking PDF. A tournament can have both.

**How to avoid:** `Umb::PdfParser#call` should parse all available PDF types independently, not short-circuit on the first one found.

### Pitfall 6: `umb_v2.rake` is a V2 caller that also needs deletion

**What goes wrong:** The CONTEXT.md says "V2 has zero production callers." But `lib/tasks/umb_v2.rake` calls `UmbScraperV2.new` for the `umb_v2:scrape` and `umb_v2:scrape_range` rake tasks. These are development/admin tasks, not production paths, but deleting V2 without deleting the rake file will cause `NameError: uninitialized constant UmbScraperV2` when the rake task is invoked.

**How to avoid:** Delete `lib/tasks/umb_v2.rake` alongside `umb_scraper_v2.rb`. The equivalent functionality will be accessible via `umb:scrape_tournament_details[ID]` in `umb.rake`.

---

## Data Output Contract for Phase 27

Per D-08, `Umb::PdfParser` services must produce structured data consumable by `Video::TournamentMatcher`. The minimum required output from each parser:

### PlayerListParser output (per Seeding)
```ruby
{
  tournament_id: Integer,
  player_id: Integer,
  player_name: "Firstname Lastname",
  nationality: "NL",
  position: 1,          # seeding position
  umb_player_id: 106    # for future cross-reference
}
```

### GroupResultParser output (per Match)
```ruby
{
  tournament_id: Integer,
  group: "A",
  player_a: { name:, nationality:, points:, innings:, average:, hs:, match_points: },
  player_b: { name:, nationality:, points:, innings:, average:, hs:, match_points: },
  winner_name: "Firstname Lastname"   # for video title matching
}
```

### RankingParser output (per tournament result + weekly ranking)
```ruby
# Tournament final ranking
{
  tournament_id: Integer,
  position: 1,
  player_name: "Firstname Lastname",
  nationality: "NL",
  points: 150,
  average: 2.5
}

# Weekly UMB ranking (new work — RANK-01)
{
  discipline: "3-Cushion",
  week: 30,
  year: 2025,
  entries: [
    { rank: 1, player_name: "Firstname Lastname", nationality: "NL", points: 1200 }
  ]
}
```

---

## Code Examples

### Verified Pattern: PDF text extraction

```ruby
# Source: [VERIFIED: app/services/umb_scraper_v2.rb lines 495-506]
def download_pdf(url)
  pdf_data = fetch_url(url)
  return nil if pdf_data.blank?

  reader = PDF::Reader.new(StringIO.new(pdf_data))
  text = reader.pages.map(&:text).join("\n")
  text
rescue StandardError => e
  Rails.logger.error "[UmbScraperV2] PDF parsing error: #{e.message}"
  nil
end
```

Migrate to `Umb::HttpClient`:
```ruby
# Target pattern for Phase 26
def fetch_pdf_text(url)
  raw = fetch_url(url)
  return nil if raw.blank?
  PDF::Reader.new(StringIO.new(raw)).pages.map(&:text).join("\n")
rescue StandardError => e
  Rails.logger.error "[Umb::HttpClient] PDF error #{url}: #{e.message}"
  nil
end
```

### Verified Pattern: V2's pair-accumulator group results parser

```ruby
# Source: [VERIFIED: app/services/umb_scraper_v2.rb lines 290-358]
def scrape_group_results_pdf(tournament, pdf_url)
  pdf_content = download_pdf(pdf_url)
  return 0 unless pdf_content

  games_created = 0
  current_group = nil
  pending_player = nil  # Store first player of a match pair

  pdf_content.each_line do |line|
    if line =~ /^Group\s+([A-Z])/i
      current_group = $1
      pending_player = nil
      next
    end

    next if line =~ /^\s*(Players|Nat|Group)/i

    match = line.match(/^\s*([A-Z][A-Z\s]+?)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)/)
    next unless match

    # ... build player_data hash

    if pending_player
      game = create_game_from_match(tournament, current_group, pending_player, player_data)
      games_created += 1 if game
      pending_player = nil
    else
      pending_player = player_data
    end
  end
  games_created
end
```

### Verified Pattern: Player name resolution (caps+mixed strategy)

```ruby
# Source: [VERIFIED: app/services/umb_scraper_v2.rb lines 431-456]
def find_player_by_caps_and_mixed(caps_name, mixed_name)
  # Try 1: caps=lastname, mixed=firstname (Western names)
  player = find_player_by_name(mixed_name, caps_name)
  return player if player

  # Try 2: caps=firstname, mixed=lastname (Asian names)
  player = find_player_by_name(caps_name, mixed_name)
  return player if player

  # Try 3: full name match either order
  full_name = "#{caps_name} #{mixed_name}"
  Player.where('LOWER(firstname || \' \' || lastname) = ? OR LOWER(lastname || \' \' || firstname) = ?',
               full_name.downcase, full_name.downcase).first
end
```

### Verified Pattern: UMB ranking PDF URL structure

```ruby
# Source: [VERIFIED: app/services/umb_scraper.rb line 141-142 — scrape_rankings method comment]
# UMB ranking PDFs at: files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf
# Example: https://files.umb-carom.org/Public/Ranking/1_WP_Ranking/2025/W30_2025.pdf
RANKING_BASE_URL = "#{BASE_URL}/Public/Ranking"
RANKING_PATH_MAP = {
  '3-Cushion'   => '1_WP_Ranking',
  '1-Cushion'   => '2_WP_Ranking',   # [ASSUMED] — confirm from actual directory listing
  'Cadre 47/2'  => '3_WP_Ranking',   # [ASSUMED]
}.freeze
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UmbScraper monolith | `Umb::` namespaced services | Phase 26 | Testability, single responsibility |
| V2 parallel scraper | Absorbed into `Umb::PdfParser` services | Phase 26 | Single source of truth for PDF parsing |
| `scrape_rankings` stub | `Umb::RankingParser` with real implementation | Phase 26 | RANK-01 fulfilled |
| Two `determine_discipline_from_name` methods | One `Umb::DisciplineDetector.detect` | Phase 26 | Eliminates inconsistency |

**Dead code identified:**
- `save_archived_tournaments` (line 1479) — method exists but is never called; all archive paths use `save_archived_tournament` (singular). Delete during extraction.
- `parse_full_month_range` (line 1183) — stub that always returns nil; delegated to `parse_day_range_with_month`. Keep or delete.
- `InternationalResult` references in `save_results` (line 1724) — likely references a deleted model. Verify before absorbing.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `InternationalResult` model no longer exists (replaced by `Game`/`GameParticipation` STI) | Don't Hand-Roll, Pitfall 4 | `save_results` would fail silently; `Umb::RankingParser` needs different output target |
| A2 | UMB ranking PDF URL subdirectory numbers (`1_WP_Ranking`, `2_WP_Ranking`, etc.) follow the `1_=3C, 2_=1C` pattern | Code Examples (ranking URL) | Ranking PDF fetching would fail if path is wrong |
| A3 | `umb_v2.rake` has zero production use and can be safely deleted alongside V2 | Pitfall 6 | If any CI/CD or scheduled task invokes `umb_v2:scrape`, it will break |
| A4 | `Umb::HttpClient#fetch_url` can be extended with a `fetch_pdf_text` method without breaking Phase 25 tests | Don't Hand-Roll | New method would need its own test; existing tests unaffected |

---

## Open Questions

1. **[RESOLVED] Does `InternationalResult` model still exist?**
   - What we know: `UmbScraper#save_results` references it; it is not in the STI hierarchy described in CONTEXT.md
   - What's unclear: Whether it was deleted in a prior phase or just unused
   - Recommendation: `grep -r "InternationalResult" app/models/` before writing `Umb::RankingParser`. If absent, ranking output target is `Seeding` with position data.
   - Resolution: Verified in Plan 02 execution — `InternationalResult` does not exist; `Umb::RankingParser` uses `Seeding` with position data as output target.

2. **[RESOLVED] What does a real UMB final ranking PDF look like?**
   - What we know: URL pattern is `files.umb-carom.org/public/TournametDetails.aspx?ID=N` → links to FinalRanking PDFs
   - What's unclear: Exact text layout (columns, player name format, whether it matches the V1 regex)
   - Recommendation: Wave 0 task — download one real ranking PDF as test fixture before writing `Umb::RankingParser`. Use VCR cassette or store binary in `test/fixtures/pdf/`.
   - Resolution: Wave 0 fixture task in Plan 02 downloads a real ranking PDF and stores it in `test/fixtures/pdf/umb_ranking_sample.pdf`; PDF text layout confirmed and parser implemented against actual structure.

3. **[RESOLVED] Does `Umb::PdfParser` entry point belong on `UmbScraper` or `Umb::DetailsScraper`?**
   - What we know: V2's `scrape_pdfs_for_tournament` is called from `scrape_tournament`; UmbScraper calls PDF parsing from inside `create_games_for_tournament` (via `parse_pdfs: true`)
   - What's unclear: Whether the Phase 27 VideoMatcher calls PDFs independently or always via tournament details
   - Recommendation: Keep PDF parsing invoked from `Umb::DetailsScraper`. `Umb::PdfParser` is a coordinator that `DetailsScraper` calls; it is not a public entry point on `UmbScraper`.
   - Resolution: PDF parsing entry point lives in `Umb::DetailsScraper` (Plan 03). `Umb::PdfParser::*` parsers are invoked from DetailsScraper when `parse_pdfs: true`; they are not exposed on `UmbScraper` directly.

---

## Environment Availability

Step 2.6: SKIPPED (no new external dependencies — all tools already in project: `pdf-reader` gem, `Umb::HttpClient`, PostgreSQL/Rails stack)

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest (Rails default) |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/services/umb/` |
| Full suite command | `bin/rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCRP-06 | `Umb::PlayerResolver` finds/creates players by name and umb_player_id | unit | `bin/rails test test/services/umb/player_resolver_test.rb` | ❌ Wave 0 |
| SCRP-06 | `Umb::PlayerListParser` extracts seedings from PDF text | unit | `bin/rails test test/services/umb/pdf_parser/player_list_parser_test.rb` | ❌ Wave 0 |
| SCRP-06 | `Umb::GroupResultParser` extracts match pairs and creates Game records | unit | `bin/rails test test/services/umb/pdf_parser/group_result_parser_test.rb` | ❌ Wave 0 |
| SCRP-06 | `Umb::RankingParser` extracts final ranking positions | unit | `bin/rails test test/services/umb/pdf_parser/ranking_parser_test.rb` | ❌ Wave 0 |
| SCRP-06 | `Umb::DetailsScraper` processes tournament detail page HTML | unit | `bin/rails test test/services/umb/details_scraper_test.rb` | ❌ Wave 0 |
| SCRP-06 | `Umb::FutureScraper` returns integer count and saves tournaments | unit | `bin/rails test test/services/umb/future_scraper_test.rb` | ❌ Wave 0 |
| SCRP-06 | `Umb::ArchiveScraper` scans ID range and returns count | unit | `bin/rails test test/services/umb/archive_scraper_test.rb` | ❌ Wave 0 |
| SCRP-06 | `UmbScraper` thin wrappers preserve original public interface | regression | `bin/rails test test/characterization/umb_scraper_char_test.rb` | ✅ existing |
| SCRP-07 | V2's PDF parsing behavior is preserved in `Umb::` services | unit | Covered by SCRP-06 tests above | ❌ Wave 0 |
| SCRP-07 | `umb_scraper_v2.rb` does not exist after phase | smoke | `bin/rails test test/characterization/umb_scraper_v2_char_test.rb` | ✅ DELETE this file |

### Sampling Rate

- **Per task commit:** `bin/rails test test/services/umb/` (new service tests only — fast)
- **Per wave merge:** `bin/rails test test/characterization/umb_scraper_char_test.rb test/services/umb/`
- **Phase gate:** `bin/rails test` full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/services/umb/player_resolver_test.rb` — covers SCRP-06 PlayerResolver
- [ ] `test/services/umb/pdf_parser/player_list_parser_test.rb` — covers SCRP-06/07 V2 absorption
- [ ] `test/services/umb/pdf_parser/group_result_parser_test.rb` — covers SCRP-06/07 V2 absorption
- [ ] `test/services/umb/pdf_parser/ranking_parser_test.rb` — covers SCRP-06 new implementation
- [ ] `test/services/umb/details_scraper_test.rb` — covers SCRP-06
- [ ] `test/services/umb/future_scraper_test.rb` — covers SCRP-06
- [ ] `test/services/umb/archive_scraper_test.rb` — covers SCRP-06
- [ ] `test/fixtures/pdf/umb_ranking_sample.pdf` (or text fixture) — needed by ranking_parser_test.rb (real PDF or text dump)
- [ ] `lib/tasks/umb_v2.rake` DELETE — Wave 0 deletion task alongside V2 removal

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | PDF text parsed with regex; malformed PDFs should be caught by rescue blocks |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed PDF causes exception | DoS | Existing `rescue StandardError => e` in all PDF methods |
| SSRF via user-supplied PDF URL | Tampering | PDF URLs come from UMB HTML pages, not user input — acceptable risk |
| SSL downgrade in production | Information Disclosure | `Umb::HttpClient.ssl_verify_mode` already handles this (Phase 25) |

---

## Sources

### Primary (HIGH confidence)

- [VERIFIED: app/services/umb_scraper.rb] — Full read, 2133 lines, all methods inventoried
- [VERIFIED: app/services/umb_scraper_v2.rb] — Full read, 585 lines, all methods inventoried
- [VERIFIED: app/services/umb/http_client.rb] — Phase 25 extraction; current interface documented
- [VERIFIED: test/characterization/umb_scraper_char_test.rb] — Existing tests that must pass
- [VERIFIED: test/characterization/umb_scraper_v2_char_test.rb] — Tests to delete with V2
- [VERIFIED: app/models/international_tournament.rb] — STI model, `pdf_links` accessor confirmed
- [VERIFIED: app/models/international_game.rb] — STI subclass of Game
- [VERIFIED: app/jobs/scrape_umb_job.rb, scrape_umb_archive_job.rb] — Caller interfaces confirmed
- [VERIFIED: app/controllers/admin/incomplete_records_controller.rb:82] — `.send` caller confirmed
- [VERIFIED: lib/tasks/umb_v2.rake] — V2 rake file confirmed; must be deleted
- [VERIFIED: app/services/league/standings_calculator.rb] — PORO pattern reference
- [VERIFIED: app/services/tournament/ranking_calculator.rb] — PORO pattern reference

### Secondary (MEDIUM confidence)

None required — this is a codebase-internal refactoring with no external library dependencies.

---

## Metadata

**Confidence breakdown:**
- Method inventory: HIGH — full source read
- Extraction order: HIGH — dependency graph built from actual code
- PDF parser distinction: HIGH — V1/V2 differences directly verified
- Ranking PDF format: LOW — stub in V2, comment in V1, URL pattern known but format unverified
- `InternationalResult` existence: LOW — assumed deleted, not verified

**Research date:** 2026-04-12
**Valid until:** Indefinite (codebase state is deterministic — no external versioning)
