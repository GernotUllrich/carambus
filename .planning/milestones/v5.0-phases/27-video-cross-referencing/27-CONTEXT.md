# Phase 27: Video Cross-Referencing - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Build `Video::TournamentMatcher` and `Video::MetadataExtractor` to automatically link unassigned videos to `InternationalTournament` records. Build `SoopliveBilliardsClient` adapter with daily sync. Wire Kozoom event cross-referencing. Provide both a backfill rake task and incremental matching in `DailyInternationalScrapeJob`.

</domain>

<decisions>
## Implementation Decisions

### Matching Confidence Model
- **D-01:** Claude's discretion on scoring model design. Available signals: date overlap (video published_at within tournament date range), player name intersection (video tags/title vs tournament participants), title similarity (Levenshtein or token overlap with tournament name). The 0.75 threshold from the roadmap is locked. Design an appropriate weighted formula or gate-based model.
- **D-02:** Auto-assign above 0.75 confidence threshold. Optionally flag videos scoring 0.5-0.75 for manual review (Claude's discretion on whether to implement the review tier).

### SoopLive Integration
- **D-03:** Build a full `SoopliveBilliardsClient` adapter covering all discovered endpoints: `/api/games` (tournament list), `/api/game/{game_no}/matches` (match data with `replay_no`), `/api/game/{game_no}/results` (final rankings).
- **D-04:** Wire `SoopliveBilliardsClient` into `DailyInternationalScrapeJob` for daily sync of SoopLive tournament and match data alongside UMB scraping.
- **D-05:** SoopLive VOD linking uses `replay_no` from match data to construct `vod.sooplive.com/player/{replay_no}` URLs for direct video-to-game linking (VIDEO-02).

### Batch vs Incremental
- **D-06:** Build BOTH: a rake task for one-time backfill of all existing unassigned videos, AND incremental matching wired into `DailyInternationalScrapeJob`.
- **D-07:** Rake task: `rake videos:match_tournaments` — runs `Video::TournamentMatcher` against `Video.unassigned` scope.
- **D-08:** Incremental: `DailyInternationalScrapeJob` Step 3 calls `Video::TournamentMatcher` for newly scraped videos after tournament data is up to date.

### MetadataExtractor Approach
- **D-09:** Regex-first, AI fallback strategy. Extract with regex patterns for known formats first:
  - Player names from `InternationalHelper::WORLD_CUP_TOP_32` and tournament participant lists
  - Round labels from `UmbScraper::GAME_TYPE_MAPPINGS` (PPPQ, PPQ, PQ, Q, R16, R32, etc.)
  - Tournament name and year from title structure
- **D-10:** Fall back to `AiSearchService` (GPT-4) for titles where regex extraction fails (non-English, unusual formats). AI extraction is optional/configurable — not called on every video.

### Claude's Discretion
- Confidence scoring model weights and formula
- Whether to implement a 0.5-0.75 review tier
- `SoopliveBilliardsClient` internal architecture (PORO vs ApplicationService)
- Error handling strategy for SoopLive API (rate limiting, retries)
- MetadataExtractor PORO design and regex pattern organization

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Video model and infrastructure
- `app/models/video.rb` — Polymorphic `videoable` association, `unassigned` scope, `detect_player_tags`, `auto_assign_discipline!`, JSONB tags
- `app/models/international_tournament.rb` — Target for video assignment; has `date`, `end_date`, `title`
- `app/models/international_game.rb` — Game records for match-level video linking

### Existing scrapers and services
- `app/services/sooplive_scraper.rb` — Current SoopLive scraper (channel VODs only); pattern for new client
- `app/services/kozoom_scraper.rb` — Uses `api.kozoom.com` JSON API; Kozoom event cross-referencing source
- `app/services/tournament_discovery_service.rb` — Fixed in Phase 25; assigns videos to tournaments (current implementation to extend)
- `app/jobs/daily_international_scrape_job.rb` — Orchestrates daily scraping; Step 3 wiring target

### Phase 24 findings (data source investigation)
- `.planning/phases/24-data-source-investigation/24-FINDINGS.md` — SoopLive API endpoints, sample responses, `replay_no` field documentation

### Phase 26 PDF parser contracts (D-08 data)
- `app/services/umb/pdf_parser/player_list_parser.rb` — Returns `[{caps_name, mixed_name, nationality, position}]`
- `app/services/umb/pdf_parser/group_result_parser.rb` — Returns `[{group, player_a, player_b, winner_name}]`

### AI infrastructure
- `app/services/ai_search_service.rb` — GPT-4 for structured extraction (D-10 fallback)
- `app/helpers/international_helper.rb` — `WORLD_CUP_TOP_32` player name list

### Existing constants
- `app/services/umb_scraper.rb` — `GAME_TYPE_MAPPINGS` for round label recognition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Video#detect_player_tags` — Existing player name detection in video titles
- `Video#auto_assign_discipline!` — Discipline assignment logic
- `Video#json_data` — JSONB column with `event_name`, `round`, `eventId` fields from scrapers
- `InternationalHelper::WORLD_CUP_TOP_32` — Known player name list for regex matching
- `UmbScraper::GAME_TYPE_MAPPINGS` — Round name patterns (PPPQ through Final)
- `text` gem — Already used in `Club#similarity_score` for Levenshtein distance
- `KozoomScraper` — Already stores `eventId` in Video json_data; Kozoom cross-ref uses this

### Established Patterns
- ApplicationService with `.call` for side-effect services
- PORO for stateless/pure-function services
- `DailyInternationalScrapeJob` orchestrates multi-source scraping in numbered steps
- Polymorphic `videoable` on Video model (type + id columns exist)

### Integration Points
- `DailyInternationalScrapeJob` — wire VideoMatcher as Step 3 after tournament data sync
- `Video.unassigned` scope — existing scope for videos without videoable assignment
- `InternationalSource` — source registry for SoopLive adapter registration
- `Kozoom` videos already have `json_data["eventId"]` — cross-ref to InternationalTournament

</code_context>

<specifics>
## Specific Ideas

- Two complementary matching paths: (1) SoopLive `replay_no` for direct high-precision VOD linking on recent events, (2) PDF-derived player/round data + title matching for broader/historic coverage
- `SoopliveBilliardsClient` is genuinely new infrastructure — a full adapter for the undocumented JSON API discovered in Phase 24
- The backfill rake task enables measuring the match rate before committing to daily automation

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-video-cross-referencing*
*Context gathered: 2026-04-12*
