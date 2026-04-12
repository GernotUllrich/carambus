# Architecture Research

**Domain:** UMB scraper overhaul and video cross-referencing in Rails 7.2 carom billiard tournament management app
**Researched:** 2026-04-12
**Confidence:** HIGH (all findings from direct codebase inspection)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Jobs Layer                               │
│  ScrapeUmbJob  ScrapeUmbArchiveJob  DailyInternationalScrapeJob │
│         │              │                       │                │
├─────────┴──────────────┴───────────────────────┴────────────────┤
│                      Services Layer (app/services/)             │
│                                                                 │
│  ┌───────────────────────────┐   ┌──────────────────────────┐   │
│  │  Umb:: namespace (NEW)    │   │  Video:: namespace (NEW) │   │
│  │  ├─ FutureScraper         │   │  ├─ TournamentMatcher     │   │
│  │  ├─ ArchiveScraper        │   │  └─ MetadataExtractor     │   │
│  │  ├─ DetailsScraper        │   └──────────────────────────┘   │
│  │  ├─ PdfParser             │                                   │
│  │  ├─ PlayerResolver        │   ┌──────────────────────────┐   │
│  │  └─ HttpClient            │   │  Existing (unchanged)    │   │
│  └───────────────────────────┘   │  YoutubeScraper          │   │
│                                  │  SoopliveScraper         │   │
│  ┌───────────────────────────┐   │  KozoomScraper           │   │
│  │  Facades (MODIFIED)       │   │  VideoTranslationService │   │
│  │  UmbScraper (thin wrapper)│   │  TournamentDiscovery-    │   │
│  │  UmbScraperV2 (thin wrap) │   │  Service                 │   │
│  └───────────────────────────┘   └──────────────────────────┘   │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                       Models Layer                              │
│  InternationalTournament (STI)   Video (polymorphic videoable)  │
│  Tournament  Game  Player        InternationalSource            │
├─────────────────────────────────────────────────────────────────┤
│                    PostgreSQL + Redis                           │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Classification |
|-----------|----------------|----------------|
| `Umb::FutureScraper` | Fetches `FutureTournaments.aspx`, parses HTML table, saves tournaments | ApplicationService |
| `Umb::ArchiveScraper` | Walks sequential IDs (`TournametDetails.aspx?ID=N`), builds archive | ApplicationService |
| `Umb::DetailsScraper` | Fetches and parses a single tournament details page | ApplicationService |
| `Umb::PdfParser` | Downloads and reads group results, player list, and KO bracket PDFs | ApplicationService |
| `Umb::PlayerResolver` | `find_or_create_international_player` logic, name normalization | PORO |
| `Umb::HttpClient` | `fetch_url` with redirect handling, timeout, User-Agent header | PORO |
| `Video::TournamentMatcher` | Assigns unmatched `Video` records to `InternationalTournament` | ApplicationService |
| `Video::MetadataExtractor` | Parses tournament/player/round metadata from video titles | PORO |

## Recommended Project Structure

```
app/services/
├── umb/                          # NEW — replaces logic in flat umb_scraper.rb
│   ├── future_scraper.rb         # scrape_future_tournaments
│   ├── archive_scraper.rb        # scrape_tournament_archive
│   ├── details_scraper.rb        # scrape_tournament_details, fetch_tournament_basic_data
│   ├── pdf_parser.rb             # All PDF scraping (group results, KO, player list)
│   ├── player_resolver.rb        # find_or_create_international_player
│   └── http_client.rb            # fetch_url, make_absolute_url, download_pdf
├── video/                        # NEW — video cross-referencing
│   ├── tournament_matcher.rb     # Match Video records to InternationalTournament
│   └── metadata_extractor.rb    # Extract structured data from video titles
├── umb_scraper.rb                # MODIFIED — thin facade delegating to Umb::*
├── umb_scraper_v2.rb             # MODIFIED — thin facade delegating to Umb::*
├── youtube_scraper.rb            # UNCHANGED
├── sooplive_scraper.rb           # UNCHANGED
├── kozoom_scraper.rb             # UNCHANGED
├── video_translation_service.rb  # UNCHANGED
└── tournament_discovery_service.rb # UNCHANGED

test/services/
├── umb/                          # NEW — mirrors service structure
│   ├── future_scraper_test.rb
│   ├── archive_scraper_test.rb
│   ├── details_scraper_test.rb
│   ├── pdf_parser_test.rb
│   ├── player_resolver_test.rb
│   └── http_client_test.rb
└── video/                        # NEW
    ├── tournament_matcher_test.rb
    └── metadata_extractor_test.rb
```

### Structure Rationale

- **`umb/` namespace:** Follows the established pattern from `tournament/`, `tournament_monitor/`, `league/`, `party_monitor/`, `region_cc/` (all introduced in v1.0–v4.0). Every Key Decision in PROJECT.md validates this approach.
- **`video/` namespace:** Video cross-referencing is a new capability domain, not a subset of UMB scraping. Separate namespace keeps the responsibility boundary clear and avoids inflating the `umb/` namespace with non-scraping logic.
- **Thin facade retention:** `umb_scraper.rb` and `umb_scraper_v2.rb` stay as thin delegation wrappers. `ScrapeUmbJob`, `ScrapeUmbArchiveJob`, and `Admin::IncompleteRecordsController` call `UmbScraper` by name — changing those callers is unnecessary churn and directly contradicts the "permanent API" decision from v4.0.

## Architectural Patterns

### Pattern 1: PORO for Pure Logic, ApplicationService for Side Effects

**What:** Stateless, pure-computation classes are POROs (`initialize` + methods, no `ApplicationService`). Classes that write to the database or make network calls are `ApplicationService` subclasses (`.call` class method, `new(kwargs).call` invocation pattern).

**When to use:** Every extracted class must be classified into exactly one category. Rule: does it have side effects (network, DB write)? ApplicationService. Otherwise? PORO.

**Trade-offs:** POROs are easier to unit-test without database setup. ApplicationServices are harder to isolate but the `.call` pattern keeps caller syntax uniform across the codebase.

**Applied to UMB:**
- `Umb::HttpClient` — PORO (returns body string; no DB write)
- `Umb::PlayerResolver` — PORO (lookup/build logic; the caller decides whether to persist)
- `Umb::FutureScraper`, `Umb::ArchiveScraper`, `Umb::DetailsScraper`, `Umb::PdfParser` — ApplicationService (each writes to DB)
- `Video::MetadataExtractor` — PORO (parses text; returns structured hash)
- `Video::TournamentMatcher` — ApplicationService (writes `videoable` association to DB)

**Established precedent:**
```ruby
# PORO (v1.0 pattern — TableMonitor::ScoreEngine)
class Umb::PlayerResolver
  def initialize(umb_source:)
    @umb_source = umb_source
  end

  def find_or_create(firstname:, lastname:, nationality:, region:, umb_player_id: nil)
    # pure lookup/build; caller decides to save
  end
end

# ApplicationService (v4.0 pattern — League::ClubCloudScraper)
class Umb::FutureScraper < ApplicationService
  def initialize(kwargs = {})
    @umb_source = kwargs[:umb_source]
  end

  def call
    html = Umb::HttpClient.new.fetch_url(FUTURE_TOURNAMENTS_URL)
    # ... parse and save
  end
end
```

### Pattern 2: Thin Delegation Wrapper (Permanent, Not Transitional)

**What:** The original flat class (`UmbScraper`) is reduced to a wrapper that instantiates `@umb_source` once and delegates each public method to the corresponding namespaced service. The wrapper is the permanent public API — callers are never touched.

**When to use:** Whenever the old class name is referenced from jobs, controllers, or stable external entry points. PROJECT.md Key Decisions explicitly validated this in v4.0: "Thin delegation wrappers (permanent API) — Zero caller changes, wrappers are permanent not transitional."

**Trade-offs:** One extra indirection layer per call. The alternative — updating every caller — risks missed call sites and increases diff size without behavioral benefit.

```ruby
# app/services/umb_scraper.rb — after refactoring (entire file)
class UmbScraper
  def initialize
    @umb_source = InternationalSource.find_or_create_by!(
      name: 'Union Mondiale de Billard', source_type: 'umb'
    ) { |s| s.base_url = Umb::FutureScraper::BASE_URL }
  end

  def scrape_future_tournaments
    Umb::FutureScraper.call(umb_source: @umb_source)
  end

  def scrape_tournament_archive(start_id: 1, end_id: 500, batch_size: 50)
    Umb::ArchiveScraper.call(
      start_id: start_id, end_id: end_id, batch_size: batch_size, umb_source: @umb_source
    )
  end

  def scrape_tournament_details(tournament_id_or_record, create_games: true, parse_pdfs: false)
    Umb::DetailsScraper.call(
      tournament_id_or_record: tournament_id_or_record,
      create_games: create_games, parse_pdfs: parse_pdfs, umb_source: @umb_source
    )
  end
end
```

### Pattern 3: Video Cross-Referencing via Matcher Service

**What:** `Video::TournamentMatcher` queries `Video.unassigned` (scoped: `where(videoable_id: nil)`) and scores each video against `InternationalTournament` candidates using title heuristics, date proximity, and discipline. It writes the `videoable` association only when confidence exceeds a threshold.

**When to use:** Runs in `DailyInternationalScrapeJob` Step 3, after video scraping and auto-tagging, before translation. This is tournament-led matching: given UMB-scraped tournaments, find videos that belong to them.

**Relationship to existing `TournamentDiscoveryService`:** These services move in opposite directions. `TournamentDiscoveryService` creates `InternationalTournament` records from video metadata (video-led). `Video::TournamentMatcher` assigns existing videos to UMB-scraped tournaments (tournament-led). They are complementary — run sequentially, not merged.

**Trade-offs:** Heuristic matching can produce false positives. Confidence scoring plus an optional `min_confidence` threshold prevents automatic assignment of ambiguous matches. Unmatched videos remain `videoable_id: nil` and can be manually assigned via admin.

```ruby
# app/services/video/tournament_matcher.rb
class Video::TournamentMatcher < ApplicationService
  DEFAULT_CONFIDENCE_THRESHOLD = 0.75

  def initialize(kwargs = {})
    @video = kwargs[:video]
    @confidence_threshold = kwargs.fetch(:confidence_threshold, DEFAULT_CONFIDENCE_THRESHOLD)
  end

  def call
    metadata = Video::MetadataExtractor.new(@video).extract
    candidates = candidate_tournaments(metadata)
    best = candidates.max_by { |c| c[:score] }
    return nil unless best && best[:score] >= @confidence_threshold

    @video.update!(videoable: best[:tournament])
    best[:tournament]
  end

  private

  def candidate_tournaments(metadata)
    scope = InternationalTournament.from_umb
    scope = scope.where(discipline: metadata[:discipline]) if metadata[:discipline]
    scope = scope.where("EXTRACT(year FROM date) = ?", metadata[:year]) if metadata[:year]

    scope.map { |t| { tournament: t, score: score(t, metadata) } }
  end

  def score(tournament, metadata)
    # weighted sum of: title keyword overlap, year match, discipline match, player name overlap
  end
end
```

## Data Flow

### UMB Scraping Flow (After Refactoring)

```
ScrapeUmbJob#perform
  → UmbScraper#scrape_future_tournaments           (thin wrapper — public interface unchanged)
    → Umb::FutureScraper.call(umb_source:)
      → Umb::HttpClient#fetch_url(FUTURE_TOURNAMENTS_URL)
          → HTML body (string)
      → parse_future_tournaments(Nokogiri doc)
          → array of tournament attribute hashes
      → InternationalTournament.find_or_create_by(external_id:, international_source:)
      → Umb::PlayerResolver#find_or_create(...)    (per player in tournament)
      → umb_source.mark_scraped!
```

### Video Cross-Referencing Flow

```
DailyInternationalScrapeJob#perform
  Step 1: YouTube/SoopLive/Kozoom scrapers → Video records saved (UNCHANGED)
  Step 2: Video.auto_tag! loop              (UNCHANGED)
  Step 3 (NEW/UPDATED): Video::TournamentMatcher
    → Video.unassigned.supported_platforms.find_each
        → Video::MetadataExtractor#extract(video)
            → { tournament_type:, year:, players:, round:, discipline: }
        → InternationalTournament.from_umb scoped by year + discipline
            → scored candidates
        → video.update!(videoable: tournament)  if score >= threshold
  Step 4: VideoTranslationService              (UNCHANGED)
  Step 5: InternationalSource stats update     (UNCHANGED)
```

### Key Data Relationships

```
InternationalSource (source_type: 'umb')
  └── has_many :videos       (direct UMB platform videos, if any)

InternationalTournament (STI < Tournament)
  ├── belongs_to :international_source  (always the UMB source record)
  └── has_many :videos, as: :videoable  (YouTube/Kozoom/SoopLive videos linked here)

Video
  ├── belongs_to :international_source  (YouTube / Kozoom / SoopLive — the video platform)
  └── belongs_to :videoable (polymorphic)
        → InternationalTournament  (cross-referenced by Video::TournamentMatcher)
        → Game                     (future: per-game video linking)
        → Player                   (future: player highlight videos)
```

The `videoable` polymorphic association already supports all three targets. No schema migration is required for cross-referencing — the infrastructure is in place.

## New vs Modified Components

| Component | Status | Notes |
|-----------|--------|-------|
| `app/services/umb/` (6 files) | NEW | Extracted from `UmbScraper` |
| `app/services/video/tournament_matcher.rb` | NEW | No existing equivalent |
| `app/services/video/metadata_extractor.rb` | NEW | Extends logic from `Video#detect_player_tags`, `Video#detect_discipline` |
| `app/services/umb_scraper.rb` | MODIFIED (facade) | Public interface unchanged — 3 callers unaffected |
| `app/services/umb_scraper_v2.rb` | MODIFIED (facade) | Public interface unchanged |
| `app/jobs/daily_international_scrape_job.rb` | MODIFIED (Step 3) | Calls `Video::TournamentMatcher` |
| `app/jobs/scrape_umb_job.rb` | UNCHANGED | Calls `UmbScraper` facade |
| `app/jobs/scrape_umb_archive_job.rb` | UNCHANGED | Calls `UmbScraper` facade |
| `app/controllers/admin/incomplete_records_controller.rb` | UNCHANGED | Calls `UmbScraper` facade |
| `app/models/video.rb` | UNCHANGED | `videoable` polymorphic already supports Tournament |
| `app/models/international_tournament.rb` | UNCHANGED | No structural change needed |
| `app/models/international_source.rb` | UNCHANGED | `umb` source_type already defined |

## Suggested Build Order

Build order respects three constraints: (1) dependencies — leaf services before composites, (2) test-first — characterization tests before extraction, (3) behavior preservation — each step must leave the full test suite green.

### Phase 1: Characterization Tests for UmbScraper (before any code change)

Pin current behavior with characterization tests using VCR cassettes. These become the regression harness for all subsequent extraction.

| Test file | What to pin |
|-----------|-------------|
| `test/services/umb/future_scraper_test.rb` | parse_future_tournaments output shape, save_tournaments upsert behavior |
| `test/services/umb/archive_scraper_test.rb` | sequential ID walking, 404-gap handling, batch_size behavior |
| `test/services/umb/details_scraper_test.rb` | single tournament parse, field mapping, error handling |
| `test/services/umb/pdf_parser_test.rb` | group results PDF → game records, player list PDF → seedings |
| `test/services/umb/player_resolver_test.rb` | find by umb_player_id, find by name, create new, save failure |

### Phase 2: Extract Umb:: Services (Bottom-Up)

Extract leaf services first (no internal deps), then upward toward composites.

1. **`Umb::HttpClient`** — no internal deps, pure HTTP. All other scrapers depend on it. Extract first.
2. **`Umb::PlayerResolver`** — depends only on `Player` model. Extract second.
3. **`Umb::PdfParser`** — depends on `Umb::HttpClient`. Extract third.
4. **`Umb::DetailsScraper`** — depends on `Umb::HttpClient`, `Umb::PdfParser`, `Umb::PlayerResolver`. Extract fourth.
5. **`Umb::FutureScraper`** — depends on `Umb::HttpClient`. Extract fifth.
6. **`Umb::ArchiveScraper`** — depends on `Umb::HttpClient`, `Umb::DetailsScraper`. Extract last.

After each extraction: reduce `UmbScraper` to a thin delegation call, run `bin/rails test`, commit independently. Each commit must be independently deployable.

### Phase 3: Investigate Alternative UMB Data Sources

Research before building any adapter layer. The investigation determines whether an adapter pattern is warranted at all.

Questions to answer:
- Does `files.umb-carom.org` expose a JSON/XML API alongside the ASPX pages?
- Is the ranking PDF structure consistent enough to replace HTML scraping for player world-ranking data?
- Is the `umb-carom.org/PG342L2/` archive page structured enough to replace sequential ID scanning?
- What data does the UMB website provide that the existing scraper misses?

Output: a decision memo (not a code change) that either (a) confirms the HTML-only approach is sufficient, (b) identifies a supplementary JSON feed to add alongside existing scraping, or (c) identifies a full replacement path. Only if (b) or (c) is true does a `UmbDataSource` adapter interface get built.

### Phase 4: UmbScraperV2 Refactor

`UmbScraperV2` (585 lines) operates on the same `InternationalTournament`/`Seeding`/`Game` domain but with different method decomposition. Extract using the same `Umb::` namespace.

Where logic overlaps with Phase 2 extractions (e.g., `find_player_by_name`, `parse_date_range`, `make_absolute_url`), consolidate into the existing `Umb::` services rather than creating V2-specific variants. Where logic is distinct (e.g., `Seeding`-based player linking), add to the appropriate existing service or create a focused new one.

Reduce `UmbScraperV2` to a thin facade over `Umb::*` services, matching the pattern from Phase 2.

### Phase 5: Video Cross-Referencing

Can begin in parallel with Phase 3/4 since the `videoable` polymorphic association and `InternationalTournament` model already exist. Requires Phase 1-2 to have populated UMB tournament records in the test fixtures.

1. **`Video::MetadataExtractor`** (PORO) — extend and unit-test the extraction logic from `Video#detect_player_tags` and `Video#detect_discipline`. No DB dependency; test with plain Ruby objects.
2. **`Video::TournamentMatcher`** (ApplicationService) — build on top of MetadataExtractor. Requires `InternationalTournament` fixture records. Test with confidence scoring edge cases: exact match, fuzzy match, no match, multiple candidates above threshold.
3. **Integrate into `DailyInternationalScrapeJob` Step 3** — replace/augment the existing `TournamentDiscoveryService` call with `Video::TournamentMatcher`.
4. Test job integration: assert that unassigned videos with matching tournament metadata get `videoable` set after job execution.

## Anti-Patterns

### Anti-Pattern 1: Namespace-Skipping (Flat Names)

**What people do:** Extract `UmbFutureScraper` (flat) rather than `Umb::FutureScraper` (namespaced).

**Why it's wrong:** Every prior extraction in this codebase used namespacing (`League::`, `TournamentMonitor::`, `TableMonitor::`, etc.). Flat names pollute the top-level service namespace and make it harder to discover related services as a group.

**Do this instead:** Always use the `Umb::` namespace. File goes in `app/services/umb/`, class name is `Umb::FutureScraper`.

### Anti-Pattern 2: Deleting the Facade Before Callers Are Updated

**What people do:** Delete `umb_scraper.rb` once all logic is in `Umb::*` and update the 3 callers directly.

**Why it's wrong:** PROJECT.md Key Decisions log explicitly validates the facade-as-permanent-API approach. The wrappers are "permanent not transitional" — removing them changes the public interface, risks overlooked call sites, and provides no behavioral benefit.

**Do this instead:** Keep the facade permanently. Three lines of wrapper code per method are cheaper than the audit cost of hunting every call site.

### Anti-Pattern 3: Building the Adapter Layer Speculatively

**What people do:** Build a `UmbDataSource` adapter interface before investigating whether alternative sources exist.

**Why it's wrong:** Phase 3 investigation may reveal no viable alternatives, making the adapter dead infrastructure. Or it may reveal a data shape that doesn't fit an already-built adapter. Speculative infrastructure adds complexity without return.

**Do this instead:** Complete Phase 3 investigation first. Build the adapter only if two real data sources with materially different shapes need to coexist.

### Anti-Pattern 4: Merging Video::TournamentMatcher into TournamentDiscoveryService

**What people do:** Extend `TournamentDiscoveryService` to also do reverse matching (video → existing tournament).

**Why it's wrong:** The two services have inverted data flows and different inputs. `TournamentDiscoveryService` creates tournaments from videos (video-led). `Video::TournamentMatcher` links videos to scraper-sourced tournaments (tournament-led). Merging creates a class with two distinct responsibilities — precisely what the v1.0–v4.0 refactoring effort removed from the codebase.

**Do this instead:** Run them sequentially from the job. `TournamentDiscoveryService` first (creates any missing tournament records), then `Video::TournamentMatcher` (links videos to existing tournaments including those just created).

### Anti-Pattern 5: Auto-Assigning Videos Below the Confidence Threshold

**What people do:** Set a low threshold or skip confidence scoring to maximize auto-assignment coverage.

**Why it's wrong:** A video about "World Cup 2023" could match multiple tournaments (Vigo, Antalya, Seoul). A wrongly assigned video creates confusing tournament pages that require manual correction, which is worse than leaving the video unassigned.

**Do this instead:** Default to a conservative threshold (0.75). Leave ambiguous videos as `videoable_id: nil`. Expose an admin interface for manual assignment. Log all scoring results for review.

## Integration Points

### External Service Boundaries

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| `files.umb-carom.org` | Net::HTTP, HTML scraping | Encapsulated in `Umb::HttpClient`; SSL verify mode conditional on environment |
| UMB PDF files | `Umb::HttpClient#download_pdf` + `pdf-reader` gem | PDF content extracted in `Umb::PdfParser`; binary download separate from HTML fetch |
| YouTube API | `YoutubeScraper` (UNCHANGED) | Videos land in `videos` table; `Video::TournamentMatcher` reads them afterward |
| Kozoom API | `KozoomScraper` (UNCHANGED) | Same pipeline |
| SoopLive | `SoopliveScraper` (UNCHANGED) | Same pipeline |

### Internal Module Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Umb::*` ↔ `UmbScraper` facade | Direct delegation with kwargs pass-through | Facade owns `@umb_source` instantiation; services receive it as a keyword arg |
| `Umb::PdfParser` ↔ `Umb::HttpClient` | Composition — PdfParser calls HttpClient for downloads | Prefer dependency injection over instantiating HttpClient inside PdfParser |
| `Umb::DetailsScraper` ↔ `Umb::PdfParser` | Composition — DetailsScraper calls PdfParser | DetailsScraper orchestrates; PdfParser is a focused collaborator |
| `Video::TournamentMatcher` ↔ `Video::MetadataExtractor` | Composition — Matcher instantiates Extractor | MetadataExtractor is a PORO; Matcher owns the scoring and DB write |
| `Video::TournamentMatcher` ↔ `DailyInternationalScrapeJob` | `.call(video:)` per video | Job iterates; service is single-video scoped |
| `Umb::*` ↔ `Video::*` | None (phases are sequential, not coupled) | UMB scraper populates tournaments; video matcher reads them |

## Scaling Considerations

This is a single-operator, background-job-driven scraping system. Scaling concerns are operational.

| Concern | Current State | Approach |
|---------|--------------|----------|
| UMB archive scan (500+ sequential HTTP requests) | Sync, single job, `batch_size` param | Already rate-limited by sequential HTTP; `batch_size` controls memory; no change needed |
| PDF parsing memory | Large PDFs parsed with `pdf-reader` | Extract one tournament at a time; do not buffer multiple PDFs in memory |
| Video-to-tournament matching at scale | O(V * T) naive | Scope candidates by year + discipline before scoring; realistic V and T counts are small (<5K videos, <200 tournaments) |
| Duplicate prevention | `external_id` unique index + `find_or_create_by` pattern | Already in place on `InternationalTournament`; no change needed |
| Wrong video assignment | Manual correction required | Conservative confidence threshold + admin override interface avoids bulk cleanup scenarios |

## Sources

All findings from direct codebase inspection — no external sources required for this architecture research.

- `app/services/umb_scraper.rb` (2133 lines) — method inventory, constant definitions, URL structure
- `app/services/umb_scraper_v2.rb` (585 lines) — STI-based approach, V2 method inventory
- `app/models/video.rb` — `videoable` polymorphic, `unassigned` scope, discipline/player detection
- `app/models/international_tournament.rb` — STI structure, `from_umb` scope, `json_data` accessor
- `app/models/international_source.rb` — source_type constants, `umb` type definition
- `app/services/tournament_discovery_service.rb` — video-led tournament discovery (complementary service)
- `app/jobs/daily_international_scrape_job.rb` — existing job pipeline, Step 3 integration point
- `app/jobs/scrape_umb_job.rb`, `scrape_umb_archive_job.rb` — callers of UmbScraper facade
- `app/controllers/admin/incomplete_records_controller.rb:82` — third caller of UmbScraper
- `.planning/PROJECT.md` — Key Decisions log, v1.0–v4.0 extraction patterns (namespace strategy, PORO vs ApplicationService, facade-as-permanent-API)
- Existing namespace directories confirmed: `app/services/league/`, `app/services/tournament/`, `app/services/tournament_monitor/`, `app/services/table_monitor/`, `app/services/party_monitor/`, `app/services/region_cc/`
- Existing test directory structure confirmed: `test/services/league/`, `test/services/tournament/`, etc.

---
*Architecture research for: UMB scraper overhaul and video cross-referencing (v5.0)*
*Researched: 2026-04-12*
