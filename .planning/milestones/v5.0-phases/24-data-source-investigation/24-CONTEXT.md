# Phase 24: Data Source Investigation - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Probe Cuesco, SoopLive, and UMB events endpoints to determine whether structured data sources exist for UMB tournament data. Document findings per source with go/no-go decisions. No code changes — investigation only.

</domain>

<decisions>
## Implementation Decisions

### Investigation Method
- **D-01:** Claude's discretion on approach per source — may use Ruby probe scripts (Net::HTTP + Nokogiri), WebFetch, or document manual browser inspection steps depending on what works for each source
- **D-02:** Focus on `umb.cuesco.net` jsRender-backed AJAX endpoints as highest-priority discovery target (research identified these as most likely structured data path)

### Findings Document Format
- **D-03:** Per-source deep dive format — one section per source (UMB events, Cuesco, SoopLive, Kozoom) with full technical details, sample responses, and verdict
- **D-04:** Document goes to `.planning/phases/24-data-source-investigation/24-FINDINGS.md`

### Go/No-Go Criteria
- **D-05:** "Structured is enough" — if a source returns structured data (JSON/XML) at all, it's worth building an adapter even if it only covers a subset of what current UMB HTML scraping provides. Fill gaps from UMB HTML as fallback.
- **D-06:** Do NOT require a source to cover >=80% of current data. Any structured subset is valuable.

### Probing Depth
- **D-07:** Existence check only — confirm whether structured endpoints exist or not per source. Do NOT characterize pagination, rate limits, auth requirements, or error handling in this phase. Leave deep analysis to Phase 25+.
- **D-08:** Get 1-2 sample responses where a structured endpoint is found (enough to confirm data format), but don't exhaustively test.

### Claude's Discretion
- Investigation method choice per source (D-01)
- Order of source investigation
- Whether to use WebFetch directly or write throwaway scripts
- How to handle sources that require authentication

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing scrapers (investigation targets)
- `app/services/umb_scraper.rb` — 2133-line scraper hitting `files.umb-carom.org`; documents current UMB data extraction patterns
- `app/services/umb_scraper_v2.rb` — 585-line scraper also hitting `files.umb-carom.org`; STI model variant
- `app/services/kozoom_scraper.rb` — Already uses `api.kozoom.com` JSON API; model for structured data integration
- `app/services/sooplive_scraper.rb` — Current SoopLive scraper (channel VODs only, not schedule/results pages)
- `app/services/youtube_scraper.rb` — YouTube data API scraper

### Research findings
- `.planning/research/STACK.md` — Zero new gems needed; UMB has no documented public API
- `.planning/research/FEATURES.md` — Cuesco is hidden structured source; SoopLive embeds VOD IDs in `data-seq`
- `.planning/research/ARCHITECTURE.md` — `Umb::` namespace strategy; adapter pattern considerations
- `.planning/research/PITFALLS.md` — Pre-existing bugs found; no characterization tests for UmbScraper

### Data models
- `app/models/international_tournament.rb` — Target model for tournament data
- `app/models/international_source.rb` — Source tracking model
- `app/models/video.rb` — Polymorphic `videoable` association for video cross-referencing

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KozoomScraper` — Already authenticates to `api.kozoom.com` REST JSON API; pattern for structured data clients
- `UmbScraper::GAME_TYPE_MAPPINGS` — Round name mappings (PPPQ, PPQ, PQ, Q, R16, etc.) useful for cross-referencing
- `InternationalSource` model — Source registry pattern already in place
- `Net::HTTP` + `Nokogiri` — HTTP/HTML stack already used by all scrapers

### Established Patterns
- All scrapers use `fetch_url` with timeout and redirect handling
- `InternationalSource.find_or_create_by!` pattern for source registration
- SSL verification inconsistency: `KozoomScraper` uses `VERIFY_NONE` unconditionally; UMB scrapers guard with `Rails.env.development?`

### Integration Points
- `DailyInternationalScrapeJob` — orchestrates daily scraping across sources
- `ScrapeUmbJob` / `ScrapeUmbArchiveJob` — entry points for UMB scraping
- `TournamentDiscoveryService` — assigns videos to tournaments (has bug: references non-existent column)

</code_context>

<specifics>
## Specific Ideas

- Cuesco (`umb.cuesco.net`) and SoopLive (`billiards.sooplive.com`) are likely the same underlying data feed — Cuesco operates both the scoring hardware and the UMB results website
- SoopLive match pages embed VOD IDs directly in `data-seq` attributes — highest-precision video cross-reference available
- `umbevents.umb-carom.org/Reports/` URL paths (ViewAllRanks, ViewTimetable, ViewPlayers) are a secondary investigation target

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-data-source-investigation*
*Context gathered: 2026-04-12*
