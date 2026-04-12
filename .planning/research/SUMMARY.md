# Project Research Summary

**Project:** UMB Scraper Overhaul & Video Cross-Referencing (v5.0)
**Domain:** Web scraping refactoring + video cross-referencing in Rails 7.2
**Researched:** 2026-04-12
**Confidence:** HIGH (primary source: direct codebase inspection throughout)

## Executive Summary

This milestone has three parallel work streams inside an existing Rails 7.2 carom billiards tournament management app: (1) investigate whether better-structured data sources exist for UMB tournament data, (2) refactor the 2718-line UMB scraper monolith into namespaced service classes following the established project pattern, and (3) build a `Video::TournamentMatcher` service that assigns unlinked video records to `InternationalTournament` records. Zero new gems are required — every tool needed is already in the Gemfile. The codebase already has the polymorphic `videoable` association, the `Text::Levenshtein` gem, `pdf-reader`, and a well-established `Umb::` namespace convention from four prior refactoring milestones.

The recommended approach is investigation-first, refactor-second, cross-reference-third. The investigation phase gates the refactoring strategy: if `umbevents.umb-carom.org/Reports/` endpoints return JSON under `Accept: application/json`, the HTML parsing layer becomes a fallback rather than the primary path and the refactoring plan changes. If no JSON API exists, the extraction proceeds as a pure code reorganization. Either way, characterization tests using VCR cassettes must be written before a single line of `UmbScraper` is changed — this is the non-negotiable project convention validated across v1.0–v4.0.

The key risks are three pre-existing bugs that will silently corrupt results if not fixed before new code is written: `TournamentDiscoveryService` references a non-existent `international_tournament_id` column (the correct polymorphic API is `video.update(videoable: tournament)`), `ScrapeUmbArchiveJob` passes keyword arguments that `UmbScraper#scrape_tournament_archive` silently ignores, and `KozoomScraper` sets `VERIFY_NONE` unconditionally in all environments. These must be corrected as the first act of the scraper refactoring phase, not deferred.

## Key Findings

### Recommended Stack

No new dependencies are needed. All tooling is already installed and actively used. The stack decision is clear: `net/http` for HTTP, `nokogiri` for HTML parsing, `pdf-reader 2.15.x` for PDF extraction, `Text::Levenshtein` for fuzzy name matching, and the established ApplicationService/PORO pattern for service class design. The only open question is whether `umbevents.umb-carom.org/Reports/` responds to JSON requests — that investigation should run before committing to the refactoring plan.

**Core technologies:**
- `net/http` (stdlib): HTTP requests to UMB and all scrapers — no HTTP client gem swap needed or warranted
- `nokogiri >= 1.12.5`: HTML parsing of UMB ASP.NET pages — already used in both UmbScraper and UmbScraperV2
- `pdf-reader ~> 2.12` (current 2.15.x): PDF extraction for UMB result and ranking PDFs — already used in UmbScraperV2
- `text` gem: `Text::Levenshtein.distance` for video-to-tournament name similarity — already used in `Club#similarity_score`
- ApplicationService/PORO split: established project pattern across 27 prior extractions — pure logic as PORO, I/O side effects as ApplicationService
- VCR cassettes: record/replay HTTP for deterministic scraper tests — infrastructure already in `test/snapshots/vcr/`

### Expected Features

**Must have (table stakes):**
- Cuesco/SoopLive data source investigation — gates the entire refactoring strategy; skip this and the architecture decision is blind
- UmbScraper split into `Umb::` namespaced service classes — 2133-line file is unmaintainable and the project convention demands this structure
- UmbScraperV2 merge or deprecation decision — two overlapping scrapers create duplicated bugs; must be resolved
- `Video::TournamentMatcher` service — core deliverable of the video track; assigns unlinked `Video` records to `InternationalTournament` by date + player name intersection
- SoopLive schedule/results scraping for platform-native VOD linking — highest-precision cross-reference path (VOD IDs embedded directly in match pages)

**Should have (competitive):**
- Cuesco JSON API integration if the `umbevents.umb-carom.org/Reports/` endpoint returns structured data — replaces brittle HTML parsing for recent events
- Video-to-game (individual match) assignment — more precise than tournament-level; achievable via SoopLive `data-seq` VOD attributes once schedule scraping is in place
- AI-assisted title parsing for non-English video titles — fills matching gaps for Korean/Vietnamese/Spanish content; uses existing `AiSearchService` infrastructure

**Defer (v2+):**
- Ranking PDF integration — `scrape_rankings` stub exists, high effort, low immediate display value
- UMB archive backfill — already implemented operationally; treat as a run-task, not a phase deliverable
- Bulk video translation — OpenAI cost risk at scale; `Video#translated_title` already exists for on-demand use

### Architecture Approach

The architecture follows the identical pattern used in v1.0–v4.0: extract logic from the monolith into `Umb::` namespaced services, reduce `umb_scraper.rb` to a thin delegation wrapper (permanent, not transitional), and add a parallel `Video::` namespace for the cross-referencing domain. The original `UmbScraper` public interface is never changed — the three callers (`ScrapeUmbJob`, `ScrapeUmbArchiveJob`, `Admin::IncompleteRecordsController`) and the `umb:update` rake task are untouched. Video cross-referencing integrates as Step 3 of `DailyInternationalScrapeJob`, sitting between video scraping/auto-tagging and translation.

**Major components:**
1. `Umb::HttpClient` (PORO) — shared HTTP fetcher with environment-guarded SSL; replaces per-scraper `fetch_url` duplication
2. `Umb::PlayerResolver` (PORO) — `find_or_create_international_player` lookup logic, no DB write; caller decides persistence
3. `Umb::PdfParser` (ApplicationService) — downloads and reads group results, KO bracket, and player list PDFs
4. `Umb::DetailsScraper`, `Umb::FutureScraper`, `Umb::ArchiveScraper` (ApplicationService) — one HTTP+parse+persist service per scraping concern
5. `Video::MetadataExtractor` (PORO) — extracts tournament type, year, players, round, discipline from video title; extends existing `Video#detect_player_tags`
6. `Video::TournamentMatcher` (ApplicationService) — scores unassigned videos against `InternationalTournament` candidates; writes `videoable` association above confidence threshold (default 0.75)
7. `UmbScraper`, `UmbScraperV2` (thin facades, permanent) — unchanged public interface; delegate to `Umb::*` services

### Critical Pitfalls

1. **`TournamentDiscoveryService` references non-existent column** — fix `video.update(videoable: tournament)` before writing any cross-referencing logic; this bug silently aborts `DailyInternationalScrapeJob` Steps 4-5 today
2. **No characterization tests before extraction** — VCR cassettes for every public `UmbScraper` method are mandatory before any code change; skipping this breaks the 901-test regression harness silently
3. **`ScrapeUmbArchiveJob` argument mismatch** — `discipline:`, `year:`, `event_type:` kwargs are silently ignored by `UmbScraper#scrape_tournament_archive`; fix the interface alignment before extraction propagates the wrong signature
4. **PaperTrail version bloat during bulk scrape** — wrap bulk save loops in `PaperTrail.request(enabled: false)` for first-time imports; daily re-scrapes create 200+ version rows per run, degrading local server sync
5. **`KozoomScraper` unconditional `VERIFY_NONE`** — fix during extraction of shared `Umb::HttpClient`; do not copy the unguarded pattern into new services; run `brakeman` after each extraction step
6. **Video-to-tournament name matching brittleness** — "World Cup Antalya 2025" vs "3C World Cup Antalya 2025" breaks fuzzy match; normalize both sides before comparing and instrument `Video.unassigned.count` after every run

## Implications for Roadmap

Based on research, the investigation result is a hard gate on everything else. The phase structure must treat that decision point as a real checkpoint, not a formality.

### Phase 1: Data Source Investigation
**Rationale:** The Cuesco/SoopLive investigation gates the refactoring strategy. If `umbevents.umb-carom.org/Reports/` returns JSON, the HTML parser is demoted to a fallback and the service class design changes materially. Building before investigating wastes effort. This is also the phase to audit rate-limiting behavior and design the archive scan strategy.
**Delivers:** A written decision memo — either (a) HTML-only confirmed, proceed with pure code reorganization, or (b) JSON API found, describe data shape and integration plan. Also: 429-handling strategy for archive scans.
**Addresses:** Cuesco/SoopLive investigation (P1 table stake), sequential ID scan rate-limiting (Pitfall 8)
**Avoids:** Speculative adapter layer (Architecture Anti-Pattern 3), misdesigned archive scan (Pitfall 8)

### Phase 2: UmbScraper Characterization Tests
**Rationale:** Project convention is test-first before any extraction. The 901-test suite has no coverage for `UmbScraper` public methods today. Writing characterization tests first creates the regression harness that makes all subsequent extraction safe. This phase also fixes the two pre-existing bugs (job argument mismatch, `TournamentDiscoveryService` column error) because both surface during test writing.
**Delivers:** VCR cassettes for all `UmbScraper` public methods; smoke tests for `ScrapeUmbJob` and `ScrapeUmbArchiveJob`; pre-existing bug fixes for job argument mismatch and `VERIFY_NONE` inconsistency
**Addresses:** All table-stake characterization work from FEATURES.md
**Avoids:** Silent regression during extraction (Pitfall 3), argument mismatch propagation (Pitfall 2)

### Phase 3: UmbScraper Service Extraction
**Rationale:** With characterization tests in place, extract bottom-up: `Umb::HttpClient` first (all others depend on it), then `Umb::PlayerResolver`, `Umb::PdfParser`, `Umb::DetailsScraper`, `Umb::FutureScraper`, `Umb::ArchiveScraper`. Each extraction commits independently and leaves `bin/rails test` green. Reduce `umb_scraper.rb` to a thin delegation wrapper at each step.
**Delivers:** `app/services/umb/` with 6 focused service classes; `UmbScraper` and `UmbScraperV2` as thin facades; PaperTrail versioning suppression on bulk import paths; Brakeman-clean SSL handling
**Uses:** ApplicationService/PORO pattern, `net/http`, `nokogiri`, `pdf-reader`, VCR cassettes
**Implements:** `Umb::*` component layer from Architecture diagram
**Avoids:** PaperTrail bloat (Pitfall 5), SSL `VERIFY_NONE` propagation (Pitfall 7), facade deletion before callers update (Anti-Pattern 2)

### Phase 4: UmbScraperV2 Resolution
**Rationale:** After Phase 3, `UmbScraper` and `UmbScraperV2` share much overlapping logic now extracted into `Umb::*`. The V2 merge-or-deprecate decision becomes straightforward: merge overlapping V2 logic into the Phase 3 services, point `UmbScraperV2` at the same `Umb::*` services. This phase is short but must follow Phase 3 (dependencies on extracted services).
**Delivers:** `UmbScraperV2` reduced to a thin facade; duplicate `find_player_by_name` / `make_absolute_url` / `parse_date_range` logic consolidated; no dead code
**Addresses:** UmbScraperV2 merge/deprecate decision (P1 table stake from FEATURES.md)

### Phase 5: Video Cross-Referencing
**Rationale:** `Video::TournamentMatcher` depends on `InternationalTournament` fixture records being populated (from Phase 3 work) but is otherwise independent of the scraper structure. The pre-existing `TournamentDiscoveryService` bug must be fixed first (done in Phase 2). Build `Video::MetadataExtractor` (PORO) first, then `Video::TournamentMatcher` (ApplicationService), then integrate into `DailyInternationalScrapeJob` Step 3. SoopLive schedule scraping for platform-native match linking can be added in the same phase if time permits.
**Delivers:** `app/services/video/tournament_matcher.rb` and `metadata_extractor.rb`; `DailyInternationalScrapeJob` Step 3 wired; `Video.unassigned.count` measurably decreasing after each daily job run; `TournamentDiscoveryService` column bug fixed
**Addresses:** VideoMatcher service (P1), SoopLive schedule scraping (P2), video-to-game assignment foundation (P2)
**Avoids:** Non-existent column bug (Pitfall 1), name matching brittleness (Pitfall 6), auto-assignment below confidence threshold (Anti-Pattern 5), merging with `TournamentDiscoveryService` (Anti-Pattern 4)

### Phase Ordering Rationale

- Investigation must precede extraction because the refactoring design depends on whether a JSON API is available. Building HTML-only services and then discovering a JSON API means structural rework.
- Characterization tests must precede code changes — project convention established across v1.0–v4.0; `UmbScraper` is the only major scraper with zero characterization test coverage.
- Bottom-up extraction (leaf services before composites) prevents a partially extracted service from being called by another service that also still has the original logic inline.
- Video cross-referencing last because it reads from `InternationalTournament` records that the refactored scrapers populate; starting earlier risks testing against an incomplete fixture set.
- Each phase is independently deployable — the facade pattern guarantees this; callers never change.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Investigation):** Cuesco/SoopLive AJAX endpoint behavior is unknown — requires live network inspection, cannot be determined from static analysis. Confidence is LOW on JSON API availability.
- **Phase 5 (Video Cross-Referencing):** SoopLive match page scraping requires probing the schedule/results URL structure in detail; existing `SoopliveScraper` does not cover these pages.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Characterization Tests):** VCR cassette pattern is established; smoke test pattern is in `test/scraping/scraping_smoke_test.rb`. No new patterns needed.
- **Phase 3 (Extraction):** Identical to v1.0–v4.0 extractions. 27 prior service class extractions in this codebase; pattern fully established.
- **Phase 4 (V2 Resolution):** Simple facade reduction following the Phase 3 pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All tooling read directly from Gemfile.lock and active usage confirmed in source files |
| Features | MEDIUM | Codebase analysis HIGH; Cuesco/SoopLive API availability LOW — that gap is the milestone's primary risk |
| Architecture | HIGH | All findings from direct codebase inspection; patterns confirmed across 27 prior extractions |
| Pitfalls | HIGH | Bugs (column mismatch, argument mismatch, VERIFY_NONE) confirmed by reading actual source and schema files |

**Overall confidence:** HIGH for the refactoring work stream; MEDIUM for the video cross-referencing work stream (gated on investigation outcome)

### Gaps to Address

- **Cuesco/SoopLive JSON API availability:** Cannot be resolved without live HTTP inspection. Phase 1 must answer this before any architecture commitment on the data source layer. If JSON is available, add a `Umb::CuescoClient` ApplicationService and demote HTML parsing to fallback.
- **`umbevents.umb-carom.org` rate-limiting behavior:** Unknown. Phase 1 investigation should probe request frequency tolerance and determine whether exponential backoff is necessary for archive scans.
- **UMB archive maximum ID:** `InternationalTournament.maximum(:external_id)` determines the correct `start_id` for archive scans. Confirm current value before writing the extracted `Umb::ArchiveScraper` to avoid re-scanning known IDs on every run.
- **SoopLive VOD retention window:** Historical cross-referencing for past tournaments depends on whether SoopLive archives VODs beyond the current season. Needs confirmation before designing the backfill strategy.

## Sources

### Primary (HIGH confidence)
- `app/services/umb_scraper.rb` (2133 lines) — URL patterns, method signatures, SSL handling, duplicate detection logic
- `app/services/umb_scraper_v2.rb` (585 lines) — V2 implementation, PDF::Reader usage, STI-based approach
- `app/services/tournament_discovery_service.rb` — `international_tournament_id` column bug confirmed against schema
- `app/models/video.rb` — polymorphic `videoable`, `unassigned` scope, player/discipline detection methods
- `db/schema.rb` — `videos` table confirms no `international_tournament_id` column
- `app/jobs/scrape_umb_archive_job.rb` — argument mismatch with `UmbScraper#scrape_tournament_archive` confirmed
- `app/jobs/daily_international_scrape_job.rb` — Step 3 integration point, no rescue on discovery service call
- `.planning/PROJECT.md` — Key Decisions log, v1.0–v4.0 namespace/facade/PORO patterns
- Confirmed namespace directories: `app/services/league/`, `tournament/`, `tournament_monitor/`, `table_monitor/`, `party_monitor/`, `region_cc/`

### Secondary (MEDIUM confidence)
- Direct HTTP probe of `files.umb-carom.org/public/FutureTournaments.aspx` — confirmed static HTML, no JSON API
- Direct HTTP probe of `umbevents.umb-carom.org/` — HTML + jQuery confirmed; `/Reports/` URLs discovered but JSON response not tested
- `billiards.sooplive.com/schedule/129?sub1=result` — JS-template rendering with `data-seq` VOD ID attributes confirmed
- `https://github.com/yob/pdf-reader` — version 2.15.x actively maintained (Jan 2025)
- `https://github.com/threedaymonk/text` — `Text::Levenshtein` version 1.2.3 confirmed available

### Tertiary (LOW confidence)
- `umbevents.umb-carom.org/Reports/` JSON API availability — URL patterns found but response format under `Accept: application/json` not confirmed; needs live probe in Phase 1
- `cuesco.eu/about-us` — no public API documented; AJAX endpoint behavior unknown without network inspection

---
*Research completed: 2026-04-12*
*Ready for roadmap: yes*
