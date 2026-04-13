# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Milestones

- ✅ **v1.0 Model Refactoring** - Phases 1-5 (shipped 2026-04-10)
- ✅ **v2.0 Test Suite Audit** - Phases 6-10 (shipped 2026-04-10)
- ✅ **v2.1 Tournament Refactoring** - Phases 11-16 (shipped 2026-04-11)
- ✅ **v3.0 Broadcast Isolation Testing** - Phases 17-19 (shipped 2026-04-11)
- ✅ **v4.0 League & PartyMonitor Refactoring** - Phases 20-23 (shipped 2026-04-12)
- ✅ **v5.0 UMB Scraper Überarbeitung** - Phases 24-27 (shipped 2026-04-12)
- 🚧 **v6.0 Documentation Quality** - Phases 28-32 (in progress)

## Phases

<details>
<summary>✅ v1.0 Model Refactoring (Phases 1-5) - SHIPPED 2026-04-10</summary>

Phases 1-5 delivered: TableMonitor 3903→1611 lines (4 services), RegionCc 2728→491 lines (10 services), 140 passing tests for all extracted service classes, Reek warnings reduced from 781→306 (TableMonitor) and 460→54 (RegionCc).

</details>

<details>
<summary>✅ v2.0 Test Suite Audit (Phases 6-10) - SHIPPED 2026-04-10</summary>

Phases 6-10 delivered: 72 test files audited, STANDARDS.md + AUDIT-REPORT.md, 10 empty stubs deleted, all VCR cassettes recorded, 475 runs green (0 failures, 0 errors, 11 justified skips), ApiProtectorTestOverride added.

</details>

<details>
<summary>✅ v2.1 Tournament Refactoring (Phases 11-16) - SHIPPED 2026-04-11</summary>

Phases 11-16 delivered: Tournament 1775→575 lines (3 services), TournamentMonitor 499→181 lines (4 services), lib/tournament_monitor_support.rb deleted, 751 runs green.

</details>

<details>
<summary>✅ v3.0 Broadcast Isolation Testing (Phases 17-19) - SHIPPED 2026-04-11</summary>

Phases 17-19 delivered: Capybara/Selenium system test infrastructure, 5 broadcast isolation tests (morph, score:update, table_scores, rapid-fire, 3-session), BROADCAST-GAP-REPORT.md. FIX-01/FIX-02 deferred.

</details>

<details>
<summary>✅ v4.0 League & PartyMonitor Refactoring (Phases 20-23) - SHIPPED 2026-04-12</summary>

Phases 20-23 delivered: League 2221→663 lines (4 services: StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper), PartyMonitor 605→217 lines (2 services: TablePopulator, ResultProcessor), 30 controller + 10 reflex tests, 901 runs green.

</details>

<details>
<summary>✅ v5.0 UMB Scraper Überarbeitung (Phases 24-27) - SHIPPED 2026-04-12</summary>

Phases 24-27 delivered: SoopLive JSON API discovered and integrated, UmbScraper 2133→175 lines (10 Umb:: services), UmbScraperV2 deleted (585 lines absorbed into Umb::PdfParser::*), 3 pre-existing bugs fixed, RANK-01 implemented, Video::TournamentMatcher + Video::MetadataExtractor + SoopliveBilliardsClient built, DailyInternationalScrapeJob Steps 3a/3b/3c wired.

</details>

### v6.0 Documentation Quality (In Progress)

**Milestone Goal:** Ensure mkdocs-based documentation accurately reflects the post-refactoring codebase — every implemented feature documented, no references to unimplemented or deleted features, documentation quality on par with code quality.

- [x] **Phase 28: Audit & Triage** - Build complete staleness inventory and two new audit scripts before any content editing (completed 2026-04-12)
- [x] **Phase 29: Break-Fix** - Fix all 74 broken links and remove stale deleted-code references (completed 2026-04-12)
- [x] **Phase 30: Content Updates** - Rewrite UMB scraping docs and update developer guide services sections to reflect post-v5.0 reality (completed 2026-04-12)
- [x] **Phase 31: New Documentation** - Create namespace overview pages for all 37 extracted services and the video cross-referencing system (completed 2026-04-12)
- [ ] **Phase 32: Nav, i18n & Verification** - Add new docs to mkdocs.yml nav, resolve bilingual gaps, and verify clean build

## Phase Details

### Phase 28: Audit & Triage
**Goal**: A complete, classified inventory of every documentation problem exists — broken links by category, stale code identifiers with file/line citations, coverage gaps per namespace, and bilingual pair gaps for nav-linked files — so that all subsequent editing is scoped and verifiable
**Depends on**: Phase 27
**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03
**Success Criteria** (what must be TRUE):
  1. A staleness inventory document exists that classifies every finding as DELETE, UPDATE, or CREATE, covering all 74 known broken links, all stale class identifier references (UmbScraperV2, tournament_monitor_support, pre-refactoring god-object descriptions), all 37 undocumented service namespaces, and all in-nav bilingual gaps
  2. `bin/check-docs-translations.rb` exists as a runnable stdlib-Ruby script that reports which `.de.md` files lack `.en.md` counterparts and vice versa, producing actionable output with file paths
  3. `bin/check-docs-coderef.rb` exists as a runnable stdlib-Ruby script that extracts CamelCase class names from docs and verifies each exists in `app/` — confirming or denying the presence of stale deleted-class references
  4. `lib/tasks/mkdocs.rake` contains a `mkdocs:check` task that wraps `mkdocs build --strict`, exits non-zero on any warning, and is documented as CI-ready
  5. Archive directory indexing status is confirmed (mkdocs.yml `exclude_docs` or `not_in_nav` coverage checked) and any gap is recorded in the inventory
**Plans:** 2/2 plans complete
Plans:
- [x] 28-01-PLAN.md — Create audit tooling (translation checker, code reference checker, mkdocs:check task, archive exclusion)
- [x] 28-02-PLAN.md — Run audit tools and produce staleness inventory (audit.json + DOCS-AUDIT-REPORT.md)

### Phase 29: Break-Fix
**Goal**: The active docs site has zero broken internal links and zero references to deleted code — a clean structural baseline before any semantic content is rewritten
**Depends on**: Phase 28
**Requirements**: FIX-01, FIX-02
**Success Criteria** (what must be TRUE):
  1. `bin/check-docs-links.rb` reports zero broken links in all active (non-archive, non-obsolete) nav-linked documentation
  2. No active doc references `UmbScraperV2`, `tournament_monitor_support`, or pre-refactoring god-object class descriptions — confirmed by `bin/check-docs-coderef.rb` output
  3. Every file deletion was preceded by an inbound-link grep confirming no other active doc links to the deleted file
  4. `mkdocs build --strict` completes with zero missing-file warnings for all nav entries
**Plans:** 2/2 plans complete
Plans:
- [x] 29-01-PLAN.md — Run automated fixer and resolve 44 pattern-based broken links (screenshots + template examples)
- [x] 29-02-PLAN.md — Fix 31 remaining broken links manually and update 3 stale code references

### Phase 30: Content Updates
**Goal**: The two most actively stale developer docs accurately describe the current Umb:: architecture and the developer guide services section reflects all 37 extracted services across 7 namespaces — both in German and English
**Depends on**: Phase 29
**Requirements**: UPDATE-01, UPDATE-02
**Success Criteria** (what must be TRUE):
  1. `developers/umb-scraping-implementation.md` (both `.de.md` and `.en.md`) describes the Umb:: namespace with 10 services — HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, PlayerListParser, GroupResultParser, RankingParser, FutureScraper, ArchiveScraper, DetailsScraper — and contains no reference to UmbScraperV2
  2. `developers/umb-scraping-methods.md` (both `.de.md` and `.en.md`) method inventory matches the Umb::* namespace; UmbScraperV2 section is removed or replaced with Umb::PdfParser breakdown
  3. The developer guide services section (both `.de.md` and `.en.md`) lists all 37 extracted services organized by namespace (TableMonitor::, RegionCc::, Tournament::, TournamentMonitor::, League::, PartyMonitor::, Umb::)
  4. Every content change updates both the `.de.md` and `.en.md` files in the same commit — confirmed by diff before marking done
**Plans:** 2/2 plans complete
Plans:
- [x] 30-01-PLAN.md — Rewrite umb-scraping-implementation and umb-scraping-methods as bilingual pairs (UPDATE-01)
- [x] 30-02-PLAN.md — Add extracted services section to developer guide DE+EN (UPDATE-02)

### Phase 31: New Documentation
**Goal**: Developers can find accurate architecture-level documentation for all 37 extracted services across 8 namespaces and for the video cross-referencing system — with both German and English coverage
**Depends on**: Phase 30
**Requirements**: DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. 8 namespace overview pages exist covering all 37 extracted services (TableMonitor::, RegionCc::, Tournament::, TournamentMonitor::, League::, PartyMonitor::, Umb::, Video::) — each page describes namespace role, public interface, and data contract; no private method documentation
  2. A `Video::` cross-referencing page (both `.de.md` and `.en.md`) documents Video::TournamentMatcher confidence scoring (0.75 threshold, two-path matching), Video::MetadataExtractor (regex-first + AI fallback), SoopliveBilliardsClient (replay_no linking), and the operational workflow for backfill vs incremental matching
  3. All new pages are written in both `.de.md` and `.en.md` — the EN version is not a stub; it has the same architecture coverage as DE
**Plans:** 3/3 plans complete
Plans:
- [x] 31-01-PLAN.md — Create TableMonitor::, RegionCc::, Tournament::, TournamentMonitor:: namespace pages (DE+EN)
- [x] 31-02-PLAN.md — Create League::, PartyMonitor::, Umb:: namespace pages (DE+EN)
- [x] 31-03-PLAN.md — Create Video:: cross-referencing page (DE+EN)

### Phase 32: Nav, i18n & Verification
**Goal**: All new Phase 31 documentation is reachable from the mkdocs.yml nav in both languages, in-nav bilingual gaps are resolved, and `mkdocs build --strict` passes with zero warnings
**Depends on**: Phase 31
**Requirements**: DOC-03
**Success Criteria** (what must be TRUE):
  1. All Phase 31 namespace overview pages and the Video:: cross-referencing page appear in `mkdocs.yml` nav with correct DE nav_translations entries
  2. Every in-nav page identified in the Phase 28 bilingual audit has a corresponding `.en.md` file — no in-nav page is silently falling back to DE for English users
  3. `mkdocs build --strict` completes with zero warnings — no missing files, no broken nav references, no unresolved i18n fallbacks for nav-linked pages
  4. `bin/check-docs-links.rb` final run shows zero broken links — broken link count is at or below the Phase 29 baseline
**Plans:** 3 plans
Plans:
- [ ] 32-01-PLAN.md — Update mkdocs.yml (exclude_docs, Services nav block, nav_translations) and fix 7 broken links
- [ ] 32-02-PLAN.md — Rename and translate first 5 bilingual pairs (deployment-checklist, frontend-sti-migration, pool-scoreboard-changelog, rubymine-setup, scenario-workflow)
- [ ] 32-03-PLAN.md — Complete remaining 4 bilingual pairs (umb-deployment-checklist, fixture-collection-guide, testing-quickstart, table-reservation) and run final verification sweep

## Progress

**Execution Order:**
Phases execute in numeric order: 28 → 29 → 30 → 31 → 32

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5. Model Refactoring | v1.0 | 18/18 | Complete | 2026-04-10 |
| 6-10. Test Suite Audit | v2.0 | 11/11 | Complete | 2026-04-10 |
| 11-16. Tournament Refactoring | v2.1 | 15/15 | Complete | 2026-04-11 |
| 17-19. Broadcast Isolation | v3.0 | 6/6 | Complete | 2026-04-11 |
| 20-23. League & PartyMonitor | v4.0 | 9/9 | Complete | 2026-04-12 |
| 24-27. UMB Scraper | v5.0 | 12/12 | Complete | 2026-04-12 |
| 28. Audit & Triage | v6.0 | 2/2 | Complete    | 2026-04-12 |
| 29. Break-Fix | v6.0 | 2/2 | Complete    | 2026-04-12 |
| 30. Content Updates | v6.0 | 2/2 | Complete    | 2026-04-12 |
| 31. New Documentation | v6.0 | 3/3 | Complete    | 2026-04-12 |
| 32. Nav, i18n & Verification | v6.0 | 0/3 | Not started | - |
