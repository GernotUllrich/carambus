# Stack Research: UMB Scraper Overhaul & Video Cross-Referencing (v5.0)

**Domain:** Web scraping, PDF extraction, multi-platform video cross-referencing in a Rails 7.2 app
**Researched:** 2026-04-12
**Confidence:** HIGH (codebase read directly; UMB site probed; key libraries verified)

---

## Decision Summary

The v5.0 milestone has three distinct work streams, each with different stack implications:

1. **Investigate alternative UMB data sources** — UMB runs two sites (`files.umb-carom.org` and `umbevents.umb-carom.org`). Both are server-rendered HTML with no public JSON API. No REST/GraphQL endpoints were found. Data is embedded in HTML tables or loaded from PDF files. The only structured data path is PDF downloads for results/rankings and sequential HTML scraping for tournament lists. No new HTTP library is needed — `net/http` (already used) is sufficient.

2. **Refactor the 2718-line UMB scraper** — Pure service-class extraction following the established project pattern (ApplicationService for side effects, POROs for pure logic). No new libraries. The key tool is the `reek` quality measurement already in the workflow.

3. **Video cross-referencing** — The `Video` model (polymorphic `videoable`) and `InternationalTournament` model are already in place. Cross-referencing is a matching problem: given a video title/description + date, find the best-matching `InternationalTournament`. The `text` gem (already installed, `Text::Levenshtein`) covers the similarity algorithm. No new gem is needed.

**Net result: Zero new gems required for this milestone.**

---

## Recommended Stack

### Core Technologies (all already installed)

| Technology | Version in Gemfile | Purpose | Why Sufficient |
|------------|--------------------|---------|----------------|
| `net/http` | Ruby stdlib | HTTP requests to UMB, Kozoom, SoopLive | Already used in all 5 scrapers. No additional gem gives meaningful benefit for this use case. |
| `nokogiri` | >= 1.12.5 | HTML parsing of UMB tournament pages | Already used in UmbScraper and UmbScraperV2. CSS selectors handle the table-based UMB markup. |
| `pdf-reader` | ~> 2.12 | Parse UMB result/ranking PDFs | Already in Gemfile. UmbScraperV2 already uses `PDF::Reader.new(StringIO.new(pdf_data))` for group results and player lists. Current upstream is 2.15.x (Aug 2025) — gem is actively maintained. |
| `text` gem | present in Gemfile | Levenshtein string similarity for name matching | Already used in `Club#similarity_score`. `Text::Levenshtein.distance` is the right tool for fuzzy player/tournament name matching during cross-referencing. |
| `google-apis-youtube_v3` | ~> 0.40.0 | YouTube video metadata | Already used in `YoutubeScraper`. Cross-referencing uses the video records already fetched; no new YouTube calls needed. |
| ApplicationService PORO pattern | project convention | Extracted scraper service classes | Established pattern in 27 prior extractions. Use ApplicationService for I/O-heavy operations, PORO for pure matching logic. |

### Supporting Patterns (no new code required)

| Pattern | Purpose | Integration Point |
|---------|---------|-------------------|
| `VCR` cassettes | Record/replay HTTP for scraper tests | `test/snapshots/vcr/` — already used for ClubCloud and CEB scraper tests. New UMB service classes get their own cassettes. |
| `WebMock` | Block real HTTP in test suite | Already active via `test_helper.rb`. All new scraper tests automatically covered. |
| `InternationalSource` model | Registry for all external data sources | UMB is already seeded (`source_type: 'umb'`). New source types (if any found) follow the same `find_or_create_by!` pattern. |
| `Video#videoable` polymorphic | Attach video to tournament | Assign `videoable_type: 'Tournament'`, `videoable_id: tournament.id` when a cross-reference match is found. Field already exists in schema. |
| `Text::Levenshtein.distance` | Fuzzy name matching | `require 'text'` inline (as done in `Club`). Build a similarity score: `1.0 - distance / max_length`. Threshold ~0.8 for confident match. |

---

## UMB Data Source Investigation Findings

This section documents what was verified through direct site inspection — critical input for the investigation work stream.

### files.umb-carom.org (current scraping target)

- **Format:** Server-rendered HTML, minimal JavaScript, no XHR or JSON
- **Technology:** Static or simple server-rendered pages (no ASP.NET WebForms `__VIEWSTATE`, no React/Vue)
- **Known URL patterns scraped today:**
  - `/public/FutureTournaments.aspx` — upcoming tournaments as HTML table
  - `/public/TournametDetails.aspx?ID={n}` — per-tournament detail page (sequential integer IDs)
  - `/Public/Ranking/1_WP_Ranking/{year}/W{week}_{year}.pdf` — weekly ranking PDFs
  - Result PDFs linked from tournament detail pages
- **Assessment:** No undiscovered API layer. The sequential ID scan (`start_id..end_id`) in `UmbScraper#scrape_tournament_archive` is the correct discovery mechanism. IDs up to ~500 appear to be the full archive.

### umbevents.umb-carom.org (secondary site, requires investigation)

- **Format:** HTML pages with jQuery-based filtering UI
- **Known URL patterns (discovered via site inspection):**
  - `/Reports/EntryFormViewOnly` — entry/registration forms
  - `/Reports/ViewPlayers` — player lists
  - `/Reports/ViewPlayersData` — player statistics
  - `/Reports/ViewTimetable` — match timetables
  - `/Reports/ViewAllRanks` — rankings
  - `/Reports/ViewFinalRanking` — final standings
  - `/Login/Login` — authentication
- **Assessment:** These `/Reports/` paths may return structured data (HTML tables or potentially JSON) depending on their Accept headers or parameters. This is the primary investigation target: check whether these endpoints respond to `Accept: application/json` or have query parameters that return structured data. This needs live investigation — cannot determine from static inspection.
- **Confidence:** LOW for API availability. Requires manual HTTP probing in Phase 1 of v5.0.

### Kozoom API (already partially integrated)

- The existing `KozoomScraper` authenticates to `api.kozoom.com` and calls `/events/days`. This is a real JSON API.
- **Cross-referencing use:** Kozoom event IDs in `Video#data["eventId"]` can be matched to `InternationalTournament` records by date range + discipline. This is a reliable path — no additional investigation needed.

### SoopLive / Five&Six (already integrated)

- `SoopliveScraper` calls the public SoopLive API. Videos are saved with `videoable_id: nil`.
- **Cross-referencing use:** Title parsing + date window is the matching strategy. Same approach as YouTube.

---

## Scraper Refactoring: Decomposition Strategy

The 2718 lines across two files should extract to the same pattern used for League (4 services) and TournamentMonitor (4 services).

### Recommended service boundaries for UmbScraper (2133 lines)

| Service Class | Responsibility | Type |
|--------------|---------------|------|
| `Umb::TournamentListScraper` | Fetches and parses future/archive tournament HTML pages | ApplicationService |
| `Umb::TournamentDetailParser` | Parses a single tournament detail HTML doc → structured hash | PORO |
| `Umb::PdfResultParser` | Reads result PDFs, extracts player/game data | PORO |
| `Umb::DisciplineDetector` | Maps tournament name → discipline ID via regex patterns | PORO |
| `Umb::TournamentPersister` | Saves tournament + seedings + games to DB | ApplicationService |

### Recommended service boundaries for UmbScraperV2 (585 lines)

| Service Class | Responsibility | Type |
|--------------|---------------|------|
| `Umb::V2::TournamentScraper` | Orchestrates fetch → parse → persist for a single tournament | ApplicationService |
| `Umb::V2::PdfListParser` | Parses players-list PDFs (already in `scrape_players_list_pdf`) | PORO |

PORO rule: pure parsing/calculation, no DB or HTTP calls. ApplicationService rule: has side effects (DB writes or HTTP requests).

---

## Video Cross-Referencing: Matching Strategy

No new infrastructure needed. The algorithm is:

1. **Candidate selection:** For each unassigned video (`videoable_id: nil`), find `InternationalTournament` records within ±14 days of `video.published_at`.
2. **Name similarity:** Use `Text::Levenshtein` to compare normalized video title tokens against tournament title. Threshold: similarity >= 0.75.
3. **Player overlap:** Extract player names from video title using `Video#detect_player_tags` (already implemented). If 1+ players match a tournament seeding, boost confidence.
4. **Assignment:** Set `video.videoable_type = 'Tournament'` and `video.videoable_id = tournament.id`. Call `video.auto_assign_discipline!` (already implemented).
5. **Fallback:** Videos with confidence < threshold remain unassigned for manual review.

This logic belongs in a new `Umb::VideoMatcher` PORO — pure input/output, no DB writes. A separate `Umb::VideoMatcherJob` or ApplicationService handles the batch persistence.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `faraday` or `httparty` | Both scrapers use `net/http` directly with custom redirect handling. Replacing HTTP client mid-refactor introduces risk for zero benefit. | `net/http` (already used in all 5 scrapers) |
| `mechanize` | Designed for browser-simulation scraping. UMB HTML is static server-rendered — no form submission or JS rendering needed. Adds a heavyweight dependency. | `net/http` + `nokogiri` |
| `ferrum` or `watir` (headless browser) | UMB pages are plain HTML. No JavaScript rendering is required to access the data. The existing Chrome/Selenium setup is for system tests only. | `nokogiri` HTML parsing |
| `fuzzy_match` gem | Heavyweight library combining multiple algorithms. `Text::Levenshtein` (already installed) is sufficient for the matching precision needed. | `text` gem (already in Gemfile) |
| `iguvium` (PDF table extraction) | For structured PDF tables. UMB PDFs are text-based and already parsed character-by-character by `pdf-reader`. The existing custom row-parsing logic in `UmbScraperV2` works. | `pdf-reader` (already used) |
| FactoryBot factories for new services | Zero factories exist in this project. All tests use fixtures. | Add fixture rows to existing YAML files |

---

## Testing Strategy for New Services

Pattern established in v1.0–v4.0 extractions:

1. **Characterization tests first** — before extracting any service, write tests against the current `UmbScraper`/`UmbScraperV2` that pin existing behavior. Use VCR cassettes.
2. **VCR cassettes for HTTP** — record real responses from `files.umb-carom.org` during cassette recording session. Store in `test/snapshots/vcr/umb/`.
3. **Fixture PDFs for PDF parsing** — save representative PDF bytes in `test/fixtures/files/umb/` for deterministic `PDF::Reader` tests.
4. **Unit test extracted POROs** — no HTTP, no DB. Input: raw HTML doc or PDF bytes. Output: structured hash. Fast.
5. **Integration test ApplicationServices** — VCR cassette + fixtures DB. Verify `InternationalTournament.count` delta.

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| No public UMB JSON API exists | HIGH | Direct HTTP inspection of both UMB domains. HTML-only responses, no XHR patterns, no API docs found. |
| `umbevents.umb-carom.org/Reports/` endpoints | LOW | URL patterns discovered but response format under `Accept: application/json` not tested. Needs live probe. |
| `text` gem sufficient for matching | HIGH | `Text::Levenshtein` already used in `Club#similarity_score`. Same pattern, same gem. |
| `pdf-reader` sufficient for UMB PDFs | HIGH | Already used in `UmbScraperV2` for result and player list PDFs. Version 2.15.x actively maintained as of Aug 2025. |
| `Video#videoable` polymorphic ready | HIGH | Schema confirmed: `videoable_type`, `videoable_id` columns exist, scopes exist, no migration needed. |
| Kozoom API as reliable cross-ref path | HIGH | `KozoomScraper` already authenticates to `api.kozoom.com`. Event IDs in `Video#data["eventId"]` are a direct match key. |
| Refactoring pattern (PORO/ApplicationService split) | HIGH | Identical to 27 prior extractions. Pattern is well-established in this codebase. |

---

## Open Questions for Phase 1 Investigation

1. **`umbevents.umb-carom.org` response format** — Do the `/Reports/` endpoints accept query parameters or `Accept: application/json`? Probe with `curl -H "Accept: application/json" https://umbevents.umb-carom.org/Reports/ViewAllRanks`. If JSON is returned, a lightweight structured data path becomes available without scraping HTML.
2. **UMB event IDs vs. Kozoom event IDs** — Is there a stable mapping between UMB tournament IDs (e.g., `TournametDetails.aspx?ID=123`) and Kozoom event IDs in `api.kozoom.com/events`? If yes, video-to-UMB-tournament linking via Kozoom becomes trivial.
3. **UMB ranking PDF schedule** — The pattern `Public/Ranking/1_WP_Ranking/{year}/W{week}_{year}.pdf` is known. Are all weeks populated? Are discipline-specific sub-paths available (e.g., for 1-cushion, 5-pin)?
4. **SoopLive VOD availability** — SoopLive archives VODs after live events end. What is the retention window? This affects whether historic cross-referencing for past events is feasible.

---

## Sources

- `app/services/umb_scraper.rb` (2133 lines) — current implementation, URL patterns, PDF path patterns
- `app/services/umb_scraper_v2.rb` (585 lines) — current V2 implementation, PDF::Reader usage
- `app/services/kozoom_scraper.rb` — Kozoom JSON API authentication pattern
- `app/services/youtube_scraper.rb` — existing YouTube integration
- `app/services/sooplive_scraper.rb` — SoopLive integration
- `app/models/video.rb` — polymorphic videoable, existing keyword/tag/similarity logic
- `app/models/international_source.rb` — source registry, known channels
- `app/models/international_tournament.rb` — STI subclass of Tournament
- `app/models/club.rb:743` — `Text::Levenshtein.distance` usage (confirmed pattern)
- Direct HTTP probe of `https://files.umb-carom.org/public/FutureTournaments.aspx` — confirmed static HTML, no JSON API
- Direct HTTP probe of `https://umbevents.umb-carom.org/` — confirmed HTML + jQuery, `/Reports/` URL patterns discovered
- https://github.com/yob/pdf-reader — version 2.15.x, actively maintained (latest commit Jan 2025)
- https://github.com/threedaymonk/text — `Text::Levenshtein` confirmed available (1.2.3)

---

*Stack research for: UMB Scraper Overhaul & Video Cross-Referencing (v5.0)*
*Researched: 2026-04-12*
