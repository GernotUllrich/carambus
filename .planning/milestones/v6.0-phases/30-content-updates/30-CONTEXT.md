# Phase 30: Content Updates - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite the two most actively stale Umb developer docs to reflect the current Umb:: namespace architecture, and update the developer guide services section to list all 37 extracted services across 7 namespaces. All content changes must be bilingual (DE + EN). This is semantic content rewriting — structural link fixes were completed in Phase 29.

</domain>

<decisions>
## Implementation Decisions

### Umb Doc Rewrite Depth
- **D-01:** Structural rewrite — replace UmbScraperV2 content with current Umb:: namespace architecture. Include service list with one-liner descriptions, text-based data flow diagram, key entry points. No usage examples or deep implementation details (those can be added in future phases).
- **D-02:** Two docs to rewrite: `umb-scraping-implementation.md` (architecture overview) and `umb-scraping-methods.md` (method inventory). Both currently German-only and reference the deleted UmbScraperV2 class.

### Bilingual Creation Strategy
- **D-03:** German is the primary language — write/rewrite the German version first (consistent with project default locale `:de`), then translate to English.
- **D-04:** AI-assisted translation — use Claude to translate between DE and EN during execution. The executor agent handles both languages in one pass for consistency.
- **D-05:** The umb-scraping docs currently exist as single files (no `.de.md`/`.en.md` pairs). Phase 30 must create the bilingual pair structure: rename existing to `.de.md`, create `.en.md` translation.

### Developer Guide Services Format
- **D-06:** One table per namespace (7 tables total). Columns: Service class, file path, one-liner description. Compact and scannable.
- **D-07:** One-liner description per service — class name + file path + single sentence describing purpose. Enough to find the right service; detailed docs can link to individual service pages in future phases.

### Commit Strategy
- **D-08:** One commit per doc pair — each `.de.md` + `.en.md` pair committed together. Satisfies success criterion #4 (DE+EN in same commit). E.g., commit 1: umb-scraping-implementation DE+EN, commit 2: umb-scraping-methods DE+EN, commit 3: developer-guide DE+EN.

### Claude's Discretion
- Exact prose structure within each doc (headings, section order)
- How to describe data flow (ASCII diagram, bullet list, or narrative)
- Service one-liner wording
- Whether to include cross-references between the two umb docs

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Umb:: namespace (source of truth for service inventory)
- `app/services/umb/http_client.rb` — HTTP wrapper
- `app/services/umb/discipline_detector.rb` — Discipline detection
- `app/services/umb/date_helpers.rb` — Date parsing utilities
- `app/services/umb/player_resolver.rb` — Player matching
- `app/services/umb/future_scraper.rb` — Future tournament scraping
- `app/services/umb/archive_scraper.rb` — Historical data scraping
- `app/services/umb/details_scraper.rb` — Tournament detail scraping
- `app/services/umb/pdf_parser/` — PDF parsing (3 sub-services: group_result_parser, player_list_parser, ranking_parser)

### Other service namespaces (for developer guide)
- `app/services/table_monitor/` — 2 services
- `app/services/region_cc/` — 10 services
- `app/services/tournament/` — 3 services
- `app/services/tournament_monitor/` — 4 services
- `app/services/league/` — 4 services
- `app/services/party_monitor/` — 2 services

### Docs to rewrite
- `docs/developers/umb-scraping-implementation.md` — Currently German-only, references UmbScraperV2
- `docs/developers/umb-scraping-methods.md` — Currently German-only, method inventory for old architecture

### Developer guide
- `docs/developers/developer-guide.de.md` — German developer guide (services section needs updating)
- `docs/developers/developer-guide.en.md` — English developer guide (services section needs updating)

### Audit data
- `docs/audit.json` — Phase 30 stale_ref findings (UPDATE action items)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/developers/developer-guide.de.md` / `.en.md` — Existing bilingual pair; established pattern for how services are currently documented
- `mkdocs.yml` — Nav structure defines where docs appear; umb-scraping docs are under `developers/`
- `bin/check-docs-coderef.rb` — Verification tool to confirm no stale references remain after rewrite

### Established Patterns
- Bilingual docs use `.de.md` / `.en.md` suffix convention with `mkdocs-static-i18n` plugin
- German comments for business logic, English for technical terms (from CLAUDE.md)
- Service files follow `app/services/{namespace}/{service_name}.rb` structure

### Integration Points
- `mkdocs.yml` nav may need updating if umb-scraping doc filenames change (adding `.de.md`/`.en.md` suffixes)
- `bin/check-docs-translations.rb` can verify the new bilingual pairs are complete

</code_context>

<specifics>
## Specific Ideas

- The 10 Umb:: services are: HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, PlayerListParser (in pdf_parser/), GroupResultParser (in pdf_parser/), RankingParser (in pdf_parser/), FutureScraper, ArchiveScraper, DetailsScraper
- The success criteria specify exactly which services must be listed — the executor should read each `.rb` file to write accurate one-liners
- The "37 services" count needs verification against actual files — current count shows ~35 across 7 namespaces (may include sub-directory services)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 30-content-updates*
*Context gathered: 2026-04-13*
