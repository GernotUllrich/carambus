# Phase 31: New Documentation - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Create 8 namespace overview pages and 1 Video:: cross-referencing page, all bilingual (DE+EN). These are new documentation files — no existing namespace docs exist. The developer guide services tables (Phase 30) provide the index; these pages go deeper with architecture, public interfaces, and data contracts.

</domain>

<decisions>
## Implementation Decisions

### Namespace Page Depth
- **D-01:** Architecture + public interface — each page covers: namespace role, service list with responsibilities, public method signatures for key entry points, data contracts (what goes in/out). No internal implementation details. Target ~200-400 lines per page.
- **D-02:** 8 namespace pages total: TableMonitor::, RegionCc::, Tournament::, TournamentMonitor::, League::, PartyMonitor::, Umb::, Video::

### Umb:: Page Strategy
- **D-03:** Summary page linking to existing Phase 30 docs — create a brief Umb:: namespace overview that links to `umb-scraping-implementation` and `umb-scraping-methods`. Avoids duplication while satisfying the "8 namespace overview pages" criterion.

### Video:: Page Scope
- **D-04:** Follow SC-2 strictly — cover exactly: TournamentMatcher confidence scoring (0.75 threshold, two-path matching), MetadataExtractor (regex-first + AI fallback), SoopliveBilliardsClient (replay_no linking), and operational workflow (backfill vs incremental matching). No broader video system context beyond SC-2.

### File Organization
- **D-05:** New `docs/developers/services/` subdirectory for all namespace pages.
- **D-06:** Namespace as kebab-case naming: `table-monitor.de.md`, `region-cc.de.md`, `tournament.de.md`, `tournament-monitor.de.md`, `league.de.md`, `party-monitor.de.md`, `umb.de.md`, `video-crossref.de.md`.

### Bilingual Strategy (carried from Phase 30)
- **D-07:** German primary, AI-assisted translation to English (consistent with D-03/D-04 from Phase 30).
- **D-08:** One commit per bilingual doc pair (consistent with D-08 from Phase 30).

### Claude's Discretion
- Internal structure of each namespace page (heading order, section grouping)
- How to present data contracts (table, code block, or narrative)
- Whether to include a services/ index page or rely on mkdocs nav
- mkdocs.yml nav updates for the new subdirectory

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Service source files (source of truth for page content)
- `app/services/table_monitor/` — 2 services (CommandHandler, TablePopulator)
- `app/services/region_cc/` — 10 services (BundScraper, LandesverbandScraper, etc.)
- `app/services/tournament/` — 3 services (StatusUpdater, Registrar, ResultProcessor)
- `app/services/tournament_monitor/` — 4 services (TablePopulator, ScoreUpdater, GameFlowController, BroadcastManager)
- `app/services/league/` — 4 services (StandingsCalculator, MatchScheduler, ResultImporter, SeasonManager)
- `app/services/party_monitor/` — 2 services (TablePopulator, ScoreUpdater)
- `app/services/umb/` — 7 services + `pdf_parser/` (3 sub-services)

### Video:: source files (models, not services)
- `app/models/video/tournament_matcher.rb` — Confidence scoring, two-path matching
- `app/models/video/metadata_extractor.rb` — Regex-first + AI fallback
- `app/services/sooplive_billiards_client.rb` — replay_no linking via SoopLive API

### Existing docs (pattern reference)
- `docs/developers/umb-scraping-implementation.de.md` / `.en.md` — Phase 30 rewrite; pattern for architecture documentation depth
- `docs/developers/umb-scraping-methods.de.md` / `.en.md` — Phase 30 rewrite; pattern for method documentation
- `docs/developers/developer-guide.de.md` / `.en.md` — Contains services tables (Phase 30); namespace pages link back here

### Audit data
- `docs/audit.json` — FIND-082 through FIND-089: 8 coverage gap findings assigned to Phase 31

### mkdocs config
- `mkdocs.yml` — Nav structure; new `developers/services/` section needs nav entries

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 30 umb-scraping docs — established pattern for bilingual architecture documentation
- Developer guide services tables — namespace → service mapping already documented; pages go deeper
- `bin/check-docs-translations.rb` — Verify bilingual pair completeness after creation

### Established Patterns
- Bilingual `.de.md` / `.en.md` suffix convention with `mkdocs-static-i18n` plugin
- German primary language with English translations
- Service files follow `app/services/{namespace}/{service_name}.rb` structure
- Video:: is in `app/models/video/`, not `app/services/video/` — exception to the namespace pattern

### Integration Points
- `mkdocs.yml` nav — new `developers/services/` section with 8+1 entries
- Developer guide services tables — namespace pages should cross-reference back
- Umb:: summary page links to existing Phase 30 docs

</code_context>

<specifics>
## Specific Ideas

- The Video:: page has the most specific requirements (SC-2) — confidence threshold, matching paths, regex+AI fallback pattern are all specified
- SoopliveBilliardsClient is a standalone service (not in `video/` namespace) but is part of the Video:: cross-referencing system
- The Umb:: page is the lightest work since Phase 30 already created the detailed docs — just a summary + links
- The 7 non-Umb, non-Video namespace pages are structurally similar — could potentially be generated with a consistent template approach

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 31-new-documentation*
*Context gathered: 2026-04-13*
