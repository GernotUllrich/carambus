# Feature Research

**Domain:** UMB scraper overhaul and video cross-referencing (v5.0 milestone)
**Researched:** 2026-04-12
**Confidence:** MEDIUM — codebase analysis HIGH, external API availability LOW (no public UMB/Cuesco API documented)

---

## What This Document Maps

This is a **work-item map for a subsequent milestone** on an existing Rails 7.2 carom billiards tournament management app. "Table stakes" means work items without which the milestone goal is not met. "Differentiators" means items that significantly increase the value of the milestone but are not blockers. "Anti-features" means tempting directions to explicitly reject.

The milestone has two parallel tracks:
1. **Data source track** — Find better-structured alternatives to the current UMB HTML scraper, integrate what is found, and refactor the 2718-line scraper into service classes
2. **Video track** — Cross-reference scraped videos (YouTube, Kozoom, SoopLive) to specific UMB tournaments and games

Both tracks feed the same domain model: `Video` (polymorphic `videoable` → `Tournament`, `Game`, `Player`), `InternationalTournament`, `InternationalSource`.

---

## Ecosystem Context

### What Exists for UMB Data

**files.umb-carom.org** (current scrape target):
- HTML pages: `FutureTournaments.aspx`, `TournametDetails.aspx?ID=N` (sequential IDs), ranking archives at `nrankarchive.aspx`
- PDFs: player lists, group results, knockout brackets, final rankings — hosted at `files.umb-carom.org/Public/...`
- No public API documented anywhere. HTML is ASP.NET WebForms (span IDs, aspx pages, postback forms). HIGH complexity to scrape correctly.
- Rankings are PDF-only (weekly editions, 200+ editions from 2013). No machine-readable format confirmed.

**umb.cuesco.net** (Five&Six platform):
- Cuesco manages live scoring for nearly every UMB event. Real-time match data (match number, time, status, players, scores, round, group, table) is rendered via JavaScript templating against a backend API (jsRender-style `{{:match_no}}` template variables seen in DOM). The underlying API endpoint is not publicly documented.
- The `billiards.sooplive.com/schedule/N?sub1=result` pages expose match data in the same template-bound pattern — data attributes like `data-seq`, `data-no`, click handlers with numeric IDs reference VOD endpoints at `vod.sooplive.com/player/[ID]`.
- **Key insight**: `umb.cuesco.net` and `billiards.sooplive.com` are the same data feed — Cuesco operates both the scoring hardware and the UMB results website. If an undocumented JSON API exists behind the template variables, it would be the best structured UMB data source available.

**Kozoom API** (already partially integrated via `KozoomScraper`):
- `api.kozoom.com` — authenticated REST API already used by the codebase. Events endpoint: `/events/days?startDate=...&endDate=...&sportId=1`. Kozoom covers major UMB events. Data is structured JSON with event metadata. Does not provide individual game results — event-level only.
- Kozoom VOD URLs: `tv.kozoom.com/en/event/[eventId]`. Already stored in `Video#json_data["eventId"]`.

**SoopLive** (already partially integrated via `SoopliveScraper`):
- `billiards.sooplive.com/schedule/[N]` — tournament schedule and results pages. Data available: contest title, dates, location, match list, player names (English), scores, round, group, table, match VOD IDs. Structure is browser-rendered JS templates; likely requires either a browser scraper or reverse-engineering the AJAX endpoint.
- Existing `SoopliveScraper` covers channel VODs but does not touch the schedule/results pages.
- SOOP has a public Open API at `openapi.sooplive.co.kr/apidoc` for VOD embed access (JSON responses confirmed), but it covers VOD metadata, not match results.

**No sports data aggregator provides carom billiards data** — no SportsRadar, Sportradar, or similar commercial API was found covering UMB events. The ecosystem is entirely platform-specific.

### What Exists for Video Cross-Referencing

**Current state in codebase**:
- `Video` model has a polymorphic `videoable` association to `Tournament`, `Game`, and `Player`. The association is optional (`videoable_id` nullable).
- Scrapers (`YoutubeScraper`, `SoopliveScraper`, `KozoomScraper`) save videos without tournament/game assignment. Videos sit as `unassigned` records.
- `Video` has `detect_player_tags`, `detect_content_type_tags`, player name detection via `InternationalHelper::WORLD_CUP_TOP_32`, event name extraction via `json_data["event_name"]`, and round extraction via `json_data["round"]`.
- `Video#title` contains structured information: player names, tournament name, round, year — but in non-uniform formats across sources (Korean, Vietnamese, Spanish, French titles from different channels).

**Cross-referencing approaches in practice** (observed from community sources):
1. **Date + player name intersection**: A video published during a tournament's date window, mentioning known players who participated, is likely from that tournament.
2. **Platform-native linking**: `umb.cuesco.net` links livestream URLs to each match. SoopLive match pages embed VOD IDs directly (`data-seq` attributes). This is the highest-confidence linking — platform handles it.
3. **Title parsing**: Tournament name and round in video title matched against `InternationalTournament#title` and known round labels (PPPQ, PPQ, PQ, Q, R32, R16, Quarter Final, Semi Final, Final). Known patterns from `UmbScraper::GAME_TYPE_MAPPINGS` already in codebase.
4. **AI-assisted extraction**: GPT-4 or similar used to extract player names, tournament name, round from non-English titles — already in codebase as `AiSearchService` and `AiTranslationService`.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features without which the milestone goal is not achieved.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Investigation of Cuesco/SoopLive structured data | Core milestone goal is to find better sources before refactoring; if Cuesco has a JSON API it changes the refactoring strategy entirely | MEDIUM | Requires: network inspection of `umb.cuesco.net` and `billiards.sooplive.com` AJAX calls to find hidden API endpoints; if found, evaluate data completeness vs current UMB HTML scraping |
| UMB scraper split into focused service classes | 2133-line `umb_scraper.rb` is unmaintainable. Minimum split: HTTP fetching, HTML parsing, PDF parsing, entity persistence — following the pattern already used for League, TournamentMonitor, TableMonitor | HIGH | Established pattern: characterization tests first, then extract. At least 4 service classes expected: `Umb::TournamentFetcher`, `Umb::HtmlParser`, `Umb::PdfParser`, `Umb::EntityPersister` |
| UmbScraperV2 absorbs or supersedes UmbScraper | Two scrapers doing overlapping work (both scrape `TournametDetails.aspx`, both parse PDFs) creates confusion and duplicated bugs | MEDIUM | Decision required: merge into one namespace under `Umb::` or deprecate the 585-line V2 in favor of a refactored V1. Depends on discovery from Cuesco investigation. |
| Video-to-tournament assignment via date+player matching | Current state: all scraped videos are unassigned (`videoable_id = nil`). Assigning them to tournaments is the defined milestone deliverable | HIGH | Core algorithm: `published_at` within tournament date range AND player name intersection. `Video` model already has `detect_player_tags`, `InternationalTournament` has `date`/`end_date`. Service class: `VideoMatcher` |
| Platform-native video linking for SoopLive matches | SoopLive match pages embed VOD IDs directly in `data-seq` attributes. This is the highest-precision cross-reference available — direct match-to-video links | MEDIUM | Requires extending `SoopliveScraper` to scrape schedule/results pages in addition to channel VODs. Dependency: needs `InternationalTournament` records with SoopLive tournament IDs in `data` JSON |

### Differentiators (Competitive Advantage)

Features that make the result significantly better but are not blockers.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Cuesco JSON API integration (if endpoint found) | Replaces brittle HTML parsing with structured match data — player names, scores, round, status in JSON; would eliminate PDF parsing entirely for recent events | HIGH | Confidence: LOW that a public or semi-public endpoint exists. Investigation phase determines whether this is buildable. If found, becomes highest-priority item. |
| Video-to-game (individual match) assignment | Currently target is tournament-level assignment. Game-level is more precise — "this video is Caudron vs Merckx QF, World Cup Bogota 2026" | HIGH | Requires: game records with player_a/player_b + round, video with extracted player pair and round. Platform-native linking from SoopLive match data makes this achievable for recent tournaments. |
| AI-assisted title parsing for non-English videos | Korean, Vietnamese, Spanish video titles contain player names and tournament references in non-standard formats. GPT-4 extraction already works in `AiTranslationService` | MEDIUM | Use existing `AiSearchService` infrastructure. Apply to `Video.unassigned` records. Cost consideration: OpenAI API calls per video. Should be optional/configurable, not run on every scrape. |
| Ranking data integration (PDF extraction) | UMB world rankings are published weekly as PDFs at `files.umb-carom.org/Public/Ranking/`. Parsing them would provide player ranking history. `scrape_rankings` method exists but is a stub. | HIGH | `pdf-reader` gem already in Gemfile. PDF format is tabular. Could extract: player name, country, points, rank. Deferred in `UmbScraper#scrape_rankings` ("not yet implemented"). |
| UMB archive backfill via sequential ID scan | `UmbScraper#scrape_tournament_archive` already implements ID scanning (1..500). Running it comprehensively would fill historical gaps. Not new code — it's an operational task. | LOW | Already implemented. Needs VCR cassettes for testing. Main value: complete historical tournament coverage. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full replacement of HTML scraping with browser automation (Selenium/Puppeteer) | Some UMB/Cuesco pages are JS-rendered, seemingly requiring a real browser | Adds Selenium dependency to background jobs; non-deterministic, slow, hard to test with VCR. Current pages parse with Nokogiri successfully for HTML content. | Investigate AJAX endpoints first (network tab inspection). If JSON API exists, use it. If not, Nokogiri scraping of server-rendered HTML is sufficient for current data. |
| Real-time video matching (match videos as they are scraped) | Appealing to have instant video-tournament links | Video scraping and tournament scraping run on different schedules. Tight coupling creates fragile dependencies. A video may arrive before the tournament is fully loaded. | Run video matching as a separate background job after both tournament and video records exist. Decouple matching from scraping. |
| Replacing UmbScraper with third-party sports data API | A commercial sports data API might seem like a clean solution | No commercial API covers UMB carom billiards. Kozoom covers events but not results. Cuesco is the best candidate but has no public API. | Investigate Cuesco AJAX endpoints; integrate if found. Otherwise refactor existing scrapers into maintainable service classes. |
| Automatic video hiding/moderation | Admin task: hide irrelevant videos | Not in scope; behavioral change, not data quality improvement. Existing `Video#hide!` method already exists for manual use. | Keep admin-manual. Auto-hiding based on confidence thresholds is a separate feature. |
| Multi-language title generation for all videos | Translate all non-English titles | OpenAI API cost and quota risk at scale (thousands of videos). Translation value is high for display but not needed for cross-referencing. | Translate on-demand (already exists as `Video#translated_title`). Do not bulk-translate during scrape. |

---

## Feature Dependencies

```
Cuesco/SoopLive investigation
    └── gates ──> Cuesco JSON API integration (if endpoint found)
    └── informs ──> UmbScraper refactoring strategy (replace vs refactor)

UmbScraper characterization tests
    └── required before ──> UmbScraper service extraction
    └── required before ──> UmbScraperV2 merge decision

UmbScraper service extraction
    └── enables ──> replacing PDF parsing with structured data (if Cuesco found)
    └── enables ──> ranking data integration (UmbScraper::RankingFetcher)

InternationalTournament records with correct date ranges
    └── required for ──> Video-to-tournament date+player matching
    └── required for ──> Platform-native SoopLive match linking

SoopLive schedule/results scraping
    └── required for ──> Platform-native video-to-game linking
    └── enhances ──> Video-to-game assignment (higher precision than title parsing)

VideoMatcher service (date+player)
    └── required for ──> bulk assignment of existing unassigned videos
    └── enhanced by ──> AI-assisted title parsing (fills gaps where player names not in known list)

Video-to-tournament assignment
    └── precedes ──> Video-to-game assignment (coarser first, then refine)
```

### Dependency Notes

- **Investigation gates everything.** If Cuesco has a JSON API, the refactoring strategy changes — the HTML parser becomes less important than the API client. Run investigation before committing to a refactoring plan.
- **Characterization tests before any refactoring.** The established project pattern (see all v1.0–v4.0 decisions). `UmbScraper` has VCR cassettes in `test/snapshots/vcr/` for scraping tests. Extend before extracting services.
- **Video matching is independent of scraper refactoring.** The `VideoMatcher` service works on existing `Video` and `InternationalTournament` records. It can be built while scraper refactoring proceeds in parallel.
- **SoopLive match-level linking is higher precision but higher effort.** Build tournament-level date+player matching first. Add match-level SoopLive linking only after tournament matching is validated.

---

## MVP Definition

### Phase 1: Investigation (blocks strategy decisions)

- [ ] Inspect network traffic from `umb.cuesco.net` and `billiards.sooplive.com` to find AJAX/JSON endpoints — determines whether a structured Cuesco API exists
- [ ] Document what data is available from each source: Kozoom API (event-level, structured), SoopLive schedule pages (match-level, JS-rendered), UMB files (tournament+PDF, HTML), Cuesco (match-level, unknown structure)
- [ ] Make go/no-go decision on Cuesco API integration vs. HTML scraping continuation

### Phase 2: UMB Scraper Refactoring (core structural work)

- [ ] Characterization tests for `UmbScraper` critical paths (future tournaments, archive scan, detail page, PDF parsing)
- [ ] Extract service classes: `Umb::TournamentFetcher` (HTTP), `Umb::HtmlParser`, `Umb::PdfParser`, `Umb::EntityPersister`
- [ ] Decide fate of `UmbScraperV2` (merge or deprecate), execute decision
- [ ] If Cuesco JSON API found: add `Umb::CuescoClient` as primary data path, demote HTML parsing to fallback

### Phase 3: Video Cross-Referencing

- [ ] `VideoMatcher` service: assign unassigned `Video` records to `InternationalTournament` by date range intersection + player name match
- [ ] If SoopLive match data accessible: extend `SoopliveScraper` to scrape schedule pages, link VOD IDs directly to game records

### Future Consideration

- [ ] Ranking data integration (PDF extraction from `files.umb-carom.org/Public/Ranking/`) — stub already exists, high effort for marginal display value
- [ ] AI-assisted title parsing for unmatched non-English videos — adds cost, best deferred until match rate of rule-based matching is measured

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Cuesco/SoopLive investigation | HIGH — gates strategy | LOW (investigation only) | P1 |
| UmbScraper characterization tests | HIGH — gates refactoring | MEDIUM | P1 |
| UmbScraper service extraction | HIGH — maintainability | HIGH | P1 |
| UmbScraperV2 merge/deprecate decision | MEDIUM — removes confusion | LOW after extraction | P1 |
| VideoMatcher (date+player) | HIGH — fills unassigned backlog | MEDIUM | P1 |
| SoopLive schedule/results scraping | HIGH — precise match linking | MEDIUM | P2 |
| Cuesco JSON API integration (if found) | HIGH — replaces brittle HTML | HIGH | P2 (conditional) |
| Video-to-game assignment | MEDIUM — display quality | HIGH | P2 |
| AI-assisted title parsing | MEDIUM — fills gaps | MEDIUM | P3 |
| Ranking PDF integration | LOW — historical curiosity | HIGH | P3 |
| UMB archive backfill | LOW — operational task | LOW | P3 |

**Priority key:**
- P1: Required for milestone completion
- P2: Strong value add; include if Phase 1+2 complete cleanly
- P3: Defer unless time permits or strong user demand

---

## Competitor Feature Analysis

| Feature | Cuesco/SoopLive | Kozoom | 3cushionbilliards.com | Our Approach |
|---------|-----------------|--------|----------------------|--------------|
| Tournament results | Live + historical, match-level | Event-level, no results | Links only | Scrape + persist in DB |
| Video per match | SoopLive VOD ID embedded per match | VOD per event on tv.kozoom.com | External links | Polymorphic videoable on Game |
| Player rankings | Via UMB PDF links | No structured rankings | Links to UMB PDFs | PDF extraction (deferred) |
| Structured API | Unknown (AJAX suspected) | Yes (api.kozoom.com, auth required) | None | Use Kozoom; investigate Cuesco |
| Historic archive | 2009+ World Cup seasons on SoopLive schedule pages | Partial | Wikipedia + community | UMB sequential ID archive scan |

---

## Sources

- Direct analysis: `app/services/umb_scraper.rb` (2133 lines), `app/services/umb_scraper_v2.rb` (585 lines)
- Direct analysis: `app/models/video.rb`, `app/models/international_source.rb` (known channel lists, source types)
- Direct analysis: `app/services/kozoom_scraper.rb`, `app/services/sooplive_scraper.rb`, `app/services/youtube_scraper.rb`
- Direct analysis: `.planning/PROJECT.md` (milestone requirements), memory notes (UmbScraper milestone direction)
- WebFetch: `files.umb-carom.org/Public/nrankarchive.aspx` — confirmed PDF-only rankings structure
- WebFetch: `billiards.sooplive.com/schedule/129?sub1=result` — confirmed JS-template rendering with `data-seq` VOD ID attributes
- WebFetch: `cuesco.eu/about-us` — confirmed no public API documented; hardware/service marketing only
- WebFetch: `samvanetten.nl/2025/world-cup-driebanden-info-2/` — confirmed community cross-referencing workflow: umb.cuesco.net → SoopLive match pages → VOD
- WebSearch: UMB data source alternatives, Kozoom API, SoopLive structured data, sports video cross-referencing patterns

---

*Feature research for: UMB scraper overhaul and video cross-referencing (v5.0 milestone)*
*Researched: 2026-04-12*
