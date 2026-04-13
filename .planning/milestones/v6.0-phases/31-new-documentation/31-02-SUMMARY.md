---
phase: 31-new-documentation
plan: "02"
subsystem: documentation
tags: [docs, services, league, party-monitor, umb, namespace-overview, bilingual]
dependency_graph:
  requires: []
  provides:
    - docs/developers/services/league.de.md
    - docs/developers/services/league.en.md
    - docs/developers/services/party-monitor.de.md
    - docs/developers/services/party-monitor.en.md
    - docs/developers/services/umb.de.md
    - docs/developers/services/umb.en.md
  affects:
    - DOC-01
tech_stack:
  added: []
  patterns:
    - Namespace overview page pattern (matching Plan 01 template)
    - Bilingual DE+EN pair commits
    - PORO vs ApplicationService documentation pattern
key_files:
  created:
    - docs/developers/services/league.de.md
    - docs/developers/services/league.en.md
    - docs/developers/services/party-monitor.de.md
    - docs/developers/services/party-monitor.en.md
    - docs/developers/services/umb.de.md
    - docs/developers/services/umb.en.md
  modified: []
decisions:
  - "Umb:: summary page kept at 33 lines (within 50-80 target) — brief by design per D-03"
  - "League:: StandingsCalculator documented as PORO with return hash format for all 3 methods"
  - "PartyMonitor:: TournamentMonitor.transaction scope pitfall prominently documented in both languages"
metrics:
  duration_minutes: 20
  completed_date: "2026-04-12"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 0
---

# Phase 31 Plan 02: League::, PartyMonitor::, Umb:: Namespace Overview Pages

3 namespace overview pages (League::, PartyMonitor::, Umb::) created as bilingual DE+EN pairs in `docs/developers/services/`, completing the 8 namespace overview pages required by DOC-01 (combined with Plan 01).

## What Was Built

### Task 1: League:: and PartyMonitor:: namespace pages (DE+EN)

**league.de.md / league.en.md** (~150 lines each):
- 4-service table (BbvScraper, ClubCloudScraper, GamePlanReconstructor, StandingsCalculator)
- Full public interfaces with parameter tables
- StandingsCalculator return hash format (karambol/snooker/pool all documented)
- 3 GamePlanReconstructor operation modes (:reconstruct, :reconstruct_for_season, :delete_for_season)
- Architecture decisions: ApplicationService vs PORO distinction, BBV_BASE_URL hardcoded
- Cross-reference link to developer-guide

**party-monitor.de.md / party-monitor.en.md** (~110 lines each):
- 2-service table (ResultProcessor, TablePopulator)
- Full public interfaces for all 5 ResultProcessor methods + 3 TablePopulator methods
- DB lock behavior diagram (Thread A/B race condition prevention)
- TournamentMonitor.transaction pitfall prominently documented
- Architecture decisions: PORO rationale, AASM event delegation, cattr_accessor pattern

### Task 2: Umb:: summary page (DE+EN)

**umb.de.md / umb.en.md** (33 lines each — per D-03 brief-by-design):
- 10-service table (HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, FutureScraper, ArchiveScraper, DetailsScraper, PdfParser::PlayerListParser, PdfParser::GroupResultParser, PdfParser::RankingParser)
- Cross-links to Phase 30 detailed docs (umb-scraping-implementation, umb-scraping-methods)
- GAME_TYPE_MAPPINGS cross-namespace dependency note (Umb::DetailsScraper + Video::MetadataExtractor)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1a | ff1d94de | docs(31-02): create League:: namespace overview pages (DE+EN) |
| 1b | b4b8a723 | docs(31-02): create PartyMonitor:: namespace overview pages (DE+EN) |
| 2 | 71b1e31b | docs(31-02): create Umb:: summary page (DE+EN) |

## Deviations from Plan

None — plan executed exactly as written. Three commits made (one per bilingual pair, matching D-08 directive).

## Known Stubs

None. All 6 files contain complete content per their design spec.

## Threat Flags

None. Documentation-only plan; no code changes, no new network endpoints or auth paths.

## Self-Check: PASSED

- [x] docs/developers/services/league.de.md — EXISTS, contains StandingsCalculator, BbvScraper, karambol/snooker/pool
- [x] docs/developers/services/league.en.md — EXISTS, full English translation
- [x] docs/developers/services/party-monitor.de.md — EXISTS, contains ResultProcessor, TournamentMonitor.transaction
- [x] docs/developers/services/party-monitor.en.md — EXISTS, full English translation
- [x] docs/developers/services/umb.de.md — EXISTS, 33 lines, links to umb-scraping-implementation + umb-scraping-methods, GAME_TYPE_MAPPINGS
- [x] docs/developers/services/umb.en.md — EXISTS, full English translation
- [x] ff1d94de — FOUND in git log
- [x] b4b8a723 — FOUND in git log
- [x] 71b1e31b — FOUND in git log
