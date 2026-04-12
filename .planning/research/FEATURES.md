# Feature Research

**Domain:** Documentation quality audit and update for Rails app with mkdocs-material
**Researched:** 2026-04-12
**Confidence:** HIGH — full codebase + docs inventory available; domain is the existing docs themselves

---

## What This Document Maps

This is a **work-item map for milestone v6.0** on an existing Rails 7.2 carom billiards tournament management app. The codebase underwent major refactoring in v1.0–v5.0 (37 services extracted, 3 models deleted, 1 scraper replaced). Documentation was not updated alongside those code changes. The docs site uses mkdocs-material with de/en i18n (suffix strategy, German default), five audience sections (decision-makers, players, managers, administrators, developers), and a broken links report showing 74 broken links across 177 markdown files.

"Table stakes" = work items without which the milestone goal is not met (docs accurately reflect codebase).
"Differentiators" = items that significantly raise quality but are not blockers.
"Anti-features" = tempting directions to explicitly reject.

---

## Ecosystem Context

### Current State of the Docs

**What exists:**
- 177 markdown files across `docs/`, of which 89 are `.de.md` and 63 are `.en.md`
- `BROKEN_LINKS_REPORT.txt` already generated: 74 broken links in 6 directories (developers: 19, players: 34, reference: 16, administrators: 1, international: 2, managers: 2)
- `docs/obsolete/` folder exists — prior cleanup was started but not finished
- `docs/archive/` contains 2026-02 and 2026-02-pre-sti subdirectories — these are internal process notes, not user docs, but they pollute the docs corpus

**What is stale after v1.0–v5.0 refactoring:**
- `docs/developers/umb-scraping-implementation.md` and `umb-scraping-methods.md` — reference `UmbScraperV2` (deleted in v5.0) and the old monolithic `UmbScraper` (2133→175 lines). These are significantly stale.
- `docs/international/umb_scraper.md` — references old scraper architecture
- No docs exist for any of the 37 extracted service classes (ScoreEngine, Umb::*, League::*, Video::*, etc.)
- No docs cover the SoopLive JSON API integration or video cross-referencing system built in v5.0

**Multilingual sync gaps (confirmed by file count analysis):**
- 26 German docs have no English counterpart (out of `internal/`, `studies/`, `administrators/`, `developers/` subdirs)
- 3 English docs have no German counterpart (`managers/table-reservation.en.md`, `reference/mkdocs_documentation.en.md`, `developers/tournament-architecture-overview.en.md`)
- i18n plugin uses `fallback_to_default: true` — missing EN pages silently render DE content; users see correct language label but wrong language content

**Broken links breakdown (from BROKEN_LINKS_REPORT.txt):**
- `players/scoreboard-guide.de.md` and `.en.md` — 11 broken screenshot image links each (22 total)
- `developers/` — 19 broken links to files like `enhanced_mode_system.md` (in obsolete/), `scenario-system-workflow.md` (missing), `test/FIXTURES_*.md` (outside docs root), `CONTRIBUTING.md` (missing)
- `reference/` — 16 broken links including placeholder `file.md` and `assets/image.png` examples left in mkdocs_dokumentation
- `administrators/streaming-production-deployment.md` — 1 link to missing `systemd-streaming-services.md`

---

## Feature Landscape

### Table Stakes (Without These, Milestone Goal Not Met)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Fix 74 broken internal links | A docs site with 74 broken links is broken; every link checker run will surface these; developer trust erodes | LOW–MEDIUM | Breakdown: 22 missing screenshots (delete or add), 19 developer links (fix paths, consolidate, or remove), 16 reference meta-examples (clean up mkdocs_dokumentation placeholder links), 17 others. Each fix is a one-liner; volume is the complexity. |
| Update UMB scraping docs for v5.0 reality | `umb-scraping-implementation.md` and `umb-scraping-methods.md` reference `UmbScraperV2` (deleted) and old 2133-line monolith. Any developer reading these will implement against the wrong architecture. | MEDIUM | `UmbScraperV2` deleted in v5.0; `UmbScraper` reduced from 2133→175 lines; 10 `Umb::*` services extracted. Docs need full rewrite to reflect `Umb::` namespace, the 10 service classes, and SoopLive JSON API integration. Two files: `umb-scraping-implementation.md` (plan → reality), `umb-scraping-methods.md` (rake tasks still accurate, service internals not). |
| Document the 37 extracted services (developer reference) | After v1.0–v5.0, none of the extracted services appear in any doc. Zero mentions of ScoreEngine, Umb::HttpClient, Video::TournamentMatcher, League::StandingsCalculator, etc. Developers onboarding have no map. | HIGH | 37 services across 8 namespaces: `table_monitor/`, `region_cc/`, `tournament/`, `tournament_monitor/`, `league/`, `party_monitor/`, `umb/`, `video/`. A single developer reference page (or section) per namespace grouping is the right scope. Not API reference — purpose, responsibility, and public interface per class. |
| Remove or update references to deleted code | `UmbScraperV2`, old `TableMonitor` 3900-line monolith, `lib/tournament_monitor_support.rb` (deleted) — any doc citing these as the current implementation misleads developers. | LOW | Mostly in UMB scraping docs + archive. Archive files can stay as historical record but should be clearly labeled. Active nav docs must not reference deleted code. |
| Audit nav against actual file existence | `mkdocs.yml` nav references 40+ pages; some may have been created as stubs or not yet written. Any nav entry pointing to a missing file causes mkdocs build warnings (or errors with strict mode). | LOW | Verify each nav entry has a corresponding `.de.md` file. Cross-check against `docs/developers/` inventory. |

### Differentiators (Significantly Raise Quality, Not Blockers)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Synchronize missing EN counterparts for in-nav DE docs | 26 DE docs have no EN version; `fallback_to_default: true` silently serves wrong language. Any English-speaking developer hits German-only content with no indication. | MEDIUM | Priority subset: only docs that are in the mkdocs.yml nav. `internal/`, `studies/`, `archive/` are not in nav — skip. For in-nav pages, an EN stub saying "Translation pending, DE version available" beats silent fallback. |
| Add video cross-referencing system to developer docs | `Video::TournamentMatcher`, `Video::MetadataExtractor`, `SoopliveBilliardsClient` (v5.0) are entirely undocumented. The confidence scoring system (0.75 threshold), the two-path matching (regex-first + AI fallback), and the backfill rake task are non-obvious architecture decisions. | MEDIUM | This is the highest-value new feature from v5.0. One developer-section page: architecture overview, confidence scoring, operational workflow (daily job + backfill rake). |
| Stale content detection pass (beyond broken links) | Broken links are mechanical. Stale content is semantic: docs that reference correct filenames but describe wrong behavior. The UMB docs are the confirmed example. Other candidates: `developers/game-plan-reconstruction.de.md` (describes `GamePlanReconstructor` as part of `League` — check it matches v4.0 extraction), `managers/league-management` (may reference old League model size). | MEDIUM | Manual review of each developer doc against corresponding service class. Not automated — requires reading both doc and code. Scope: 10–15 most likely stale files based on what changed in v1.0–v5.0. |
| Consolidate orphaned docs outside nav | 177 files in docs but nav covers ~40 pages. ~137 files are not in nav: `internal/`, `archive/`, `studies/`, `testing/`, `features/`, `changelog/`, `international/`, etc. Some are legitimately internal; others are abandoned drafts. Labeling them clearly (or moving to a discoverable location) reduces confusion. | LOW | Not a full audit — just flag the known categories: `archive/` = historical, `internal/` = internal, `obsolete/` = delete candidates. A `docs/README.md` or `docs/internal/INDEX.md` explaining the structure is enough. |
| Verify multilingual nav translations in mkdocs.yml | The `nav_translations` section in `mkdocs.yml` covers ~60 key names for DE. If new nav entries were added for v6.0 docs, their DE translations need to be added here or EN strings appear in the DE nav. | LOW | Mechanical check: for every nav entry added in v6.0, add a corresponding `nav_translations` entry. Low effort but easy to forget. |

### Anti-Features (Tempting, Explicitly Reject)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full translation of all 26 DE-only docs into EN | Completeness appeal; "real" i18n means both languages everywhere | 26 files × average 200 lines = 5200 lines of translation. Most are internal/archive files not in nav. Translation cost far exceeds value for docs users never see. | Translate only docs that appear in mkdocs.yml nav and are user-facing. Mark internal/archive explicitly as DE-only. |
| Automated stale content detection (CI script) | Appealing as a long-term quality gate | Writing a reliable "code-to-docs sync checker" for a Rails app requires parsing Ruby AST and matching to prose. This is a multi-week project. The actual stale content in v6.0 is already known from PROJECT.md. | Do the manual audit for the known-stale files now. Consider a code comment convention (`# @docs: docs/path.md`) for future maintenance — low-tech, zero tooling. |
| Generating API reference from code (YARD/RDoc) | Automated, always-current docs from docstrings | UMB scraping docs are the only place developers need reference accuracy. The 37 services are well-named POROs with clear responsibilities. Auto-generated API docs for POROs add visual noise without navigational value. | Write one prose overview page per service namespace (8 namespaces), listing each class and its responsibility in a table. That's the right fidelity for this codebase. |
| Rewriting all docs in both languages from scratch | "Start fresh" appeal after major refactoring | Only a subset of docs are actually stale. Most audience docs (players, managers, decision-makers) describe user-facing features that haven't changed. Rewriting them risks introducing errors. | Audit-first: identify which files are stale (broken refs to deleted code = stale). Update only those. Preserve everything else. |
| Adding screenshots for all UI features | Docs without screenshots "feel incomplete" | Screenshots are maintenance debt: every UI change breaks them. Scoreboard guide already has 34 broken screenshot links — adding more screenshots without adding the actual images makes this worse. | Fix the 22 existing broken screenshot links first (either add images or remove the broken `![alt](path)` references). Do not add new screenshot placeholders that don't yet have images. |

---

## Feature Dependencies

```
Broken link audit
    └── precedes ──> any other fix (establishes clean baseline)
    └── informs ──> which nav entries need attention

UMB scraping docs rewrite
    └── requires knowing ──> actual v5.0 service structure (from codebase, already analyzed)
    └── clears stale content ──> removes UmbScraperV2 references from active docs

Document 37 extracted services
    └── depends on ──> knowing the service inventory (complete: 37 services listed in PROJECT.md)
    └── informs structure ──> one section per namespace, not one page per service

Multilingual gap fill (in-nav pages only)
    └── requires ──> knowing which pages are in nav (mkdocs.yml, already read)
    └── precedes ──> nav_translations update in mkdocs.yml

Nav_translations update
    └── required by ──> any new nav entries added in this milestone
```

### Dependency Notes

- **Link audit first.** It's mechanical, yields a clean pass/fail signal, and unblocks everything else. The BROKEN_LINKS_REPORT.txt already exists — this is executing the fixes, not finding them.
- **UMB docs rewrite is independent** of the link audit. It's semantic, not mechanical. Can run in parallel.
- **Service documentation is the largest single work item.** 37 services × average half-page each = ~20 pages of prose. Group by namespace to make it tractable (8 groups, not 37 individual pages).
- **Multilingual gaps only matter for in-nav docs.** The 26 missing EN files are mostly in `internal/`, `studies/`, `archive/` — not in nav. The actual in-nav gap is smaller. Confirm before estimating effort.

---

## MVP Definition

### Must-Do (Milestone Not Complete Without These)

1. Fix all 74 broken internal links (mechanical, high-visibility)
2. Rewrite `umb-scraping-implementation.md` and `umb-scraping-methods.md` to reflect v5.0 reality (UmbScraperV2 deleted, `Umb::` namespace, 10 services)
3. Add developer reference for all 37 extracted services (grouped by namespace, one overview section per group)
4. Verify all mkdocs.yml nav entries resolve to existing files

### Should-Do (Strong Value, Include If Feasible)

5. Add video cross-referencing system docs (Video::TournamentMatcher architecture, confidence scoring, operational workflow)
6. Fill EN stubs for in-nav pages currently DE-only (check which nav entries lack EN files)
7. Stale content pass on top-10 most likely stale developer docs (game-plan-reconstruction, league-management, clubcloud-integration)

### Defer (Not This Milestone)

8. Full translation of non-nav DE-only docs (internal, archive, studies)
9. Automated stale content detection in CI
10. New screenshots for scoreboard guide (fix broken refs first, add new ones later)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Fix 74 broken links | HIGH — docs are broken without this | LOW (mechanical, report already exists) | P1 |
| UMB scraping docs rewrite | HIGH — misleads developers with deleted code | MEDIUM (2 files, full rewrite) | P1 |
| Document 37 extracted services | HIGH — zero coverage of 5-milestone refactoring | HIGH (volume, but well-structured) | P1 |
| Verify nav file existence | MEDIUM — build warnings, missing pages | LOW (mechanical) | P1 |
| Video cross-referencing docs | HIGH — non-obvious v5.0 architecture | MEDIUM (1 new page) | P2 |
| EN stubs for in-nav DE-only pages | MEDIUM — EN users see wrong language | LOW (stubs, not full translation) | P2 |
| Stale content pass on top developer docs | MEDIUM — semantic accuracy | MEDIUM (manual review) | P2 |
| Consolidate orphaned non-nav docs | LOW — reduces confusion for maintainers | LOW | P3 |
| Nav_translations completeness check | LOW — nav label accuracy | LOW | P3 |

**Priority key:**
- P1: Required for milestone goal ("docs accurately reflect codebase")
- P2: Strong quality improvement; include if P1 work completes cleanly
- P3: Housekeeping; defer unless time permits

---

## Sources

- Direct analysis: `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/docs/BROKEN_LINKS_REPORT.txt` (74 broken links, 177 files)
- Direct analysis: `mkdocs.yml` (nav structure, i18n config, fallback_to_default: true)
- Direct analysis: `.planning/PROJECT.md` (v1.0–v5.0 change history, 37 service inventory)
- File inventory: `find docs -name "*.de.md"` (89 files) vs `*.en.md` (63 files) — 26 DE-only, 3 EN-only
- Direct analysis: `docs/developers/umb-scraping-methods.md` — confirmed stale V2 reference at line 62
- Grep analysis: zero mentions of any v1.0–v5.0 service class names across all 177 doc files
- Grep analysis: `UmbScraperV2` references in active docs (umb-scraping-implementation.md, umb-scraping-methods.md, international/umb_scraper.md) — archive refs excluded

---

*Feature research for: documentation quality audit and update (v6.0 milestone)*
*Researched: 2026-04-12*
