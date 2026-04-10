# Carambus API — Model Refactoring & Test Coverage

## What This Is

A focused improvement effort on the Carambus API codebase. v1.0 broke down the two largest model classes into smaller, well-tested components. v2.0 audited and improved the entire existing test suite. v2.1 refactors Tournament (API Server) and TournamentMonitor (Local Server orchestrator) — the most critical Carambus models for live tournament management — with comprehensive test coverage across models, services, controllers, channels, and jobs.

## Core Value

A maintainable, well-tested codebase where every test is trustworthy and every model is appropriately sized.

## Requirements

### Validated

- ✓ Existing TableMonitor functionality preserved — v1.0
- ✓ Existing RegionCc functionality preserved — v1.0
- ✓ Existing test suite passes — v1.0
- ✓ Characterization tests for TableMonitor critical paths — v1.0 (58 tests)
- ✓ Characterization tests for RegionCc critical paths — v1.0 (56 tests)
- ✓ Extract service classes from TableMonitor — v1.0 (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder)
- ✓ Extract service classes from RegionCc — v1.0 (ClubCloudClient + 9 syncers)
- ✓ Tests for all extracted service classes — v1.0 (140 tests total)
- ✓ RegionCc reduced to 491 lines — v1.0
- ✓ TableMonitor reduced to 1611 lines — v1.0
- ✓ Reek quality improvement measured — v1.0 (TableMonitor 781→306, RegionCc 460→54)
- ✓ Every test file reviewed for quality issues — v2.0 (72 files audited, STANDARDS.md + AUDIT-REPORT.md)
- ✓ All skipped/pending tests resolved — v2.0 (VCR cassettes recorded, skips justified or fixed)
- ✓ Consistent patterns established — v2.0 (frozen_string_literal, fixtures-first, test naming)
- ✓ Dead/redundant tests removed — v2.0 (10 empty stubs + 1 non-test script deleted)
- ✓ All tests green after improvements — v2.0 (475 runs, 0 failures, 0 errors, 11 justified skips)

### Active

#### Current Milestone: v2.1 Tournament & TournamentMonitor Refactoring

**Goal:** Reduce Tournament (1775 lines) and TournamentMonitor (499 lines) into maintainable, well-tested components with comprehensive test coverage.

**Target features:**
- Characterization tests for Tournament and TournamentMonitor critical paths
- Extract service classes from Tournament model to reduce complexity and length
- Extract service classes from TournamentMonitor (game sequencing, player assignment, table allocation)
- Full test coverage for controllers/channels/jobs touching Tournament and TournamentMonitor
- Behavior preservation throughout — no external interface changes

### Out of Scope

- League model refactoring (2219 lines) — tackle in future milestone
- Tournament model refactoring (1775 lines) — tackle in future milestone
- New test coverage for remaining untested models, controllers, services (beyond Tournament/TournamentMonitor) — separate milestone
- Architecture or stack changes — not in scope for current project
- Scraper consolidation (UmbScraper v1/v2) — separate concern

## Context

- Brownfield Rails 7.2 app for carom billiard tournament management
- Ruby 3.2.1, PostgreSQL, Redis, ActionCable, StimulusReflex
- **v1.0 shipped 2026-04-10:** TableMonitor 3903→1611 lines (4 services), RegionCc 2728→491 lines (10 services)
- **v2.0 shipped 2026-04-10:** 72 test files audited, 475 runs green, 1121 assertions, ApiProtectorTestOverride added
- Test suite: 475 runs, 1121 assertions, 0 failures, 0 errors, 11 justified skips
- **v2.1 focus:** Tournament (1775 lines, API Server) + TournamentMonitor (499 lines, Local Server orchestrator)
- TournamentMonitor orchestrates game sequencing, player→game assignment, game→table allocation via TableMonitor
- Sync: PaperTrail + RegionTaggable filtering, local servers pull via Version.update_from_carambus_api
- ApiProtector + LocalProtector both have test overrides in test_helper.rb
- Extracted services: ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder, ClubCloudClient + 9 syncers
- Codebase map available at `.planning/codebase/`

## Constraints

- **Behavior preservation**: All existing functionality must continue to work identically
- **Incremental**: Each change must be independently deployable
- **Test-first**: Tests before any refactoring

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Start with TableMonitor and RegionCc only | Worst offenders by line count (3900 and 2700 lines) | ✓ Good — both reduced significantly |
| Write characterization tests before extracting | Ensures refactoring doesn't break existing behavior | ✓ Good — 58 char tests caught every regression |
| Extract to service classes, not concerns | Services are more testable and explicit than concerns | ✓ Good — 14 services extracted with clear boundaries |
| ScoreEngine as PORO, not ApplicationService | Stateful hash wrapper called many times per game | ✓ Good — lazy accessor pattern reused by OptionsPresenter |
| Fine-grained RegionCc syncers (9 classes) | User chose focused services over 3 large ones | ✓ Good — each syncer independently testable |
| suppress_broadcast replacing skip_update_callbacks | Explicit flag with no leaked state | ✓ Good — 79 call sites migrated cleanly |
| Fixtures primary, not FactoryBot | Already dominant, no factory definitions existed | ✓ Good — zero FactoryBot usage confirmed by audit |
| Delete empty test stubs rather than backfill | False confidence worse than no test file | ✓ Good — 10 stubs removed cleanly |
| Fix sole-assertion cases only | Precondition checks (followed by stronger assertions) are acceptable | ✓ Good — targeted fixes, no over-correction |
| ApiProtectorTestOverride in test_helper.rb | Prevents silent save rollbacks in API server context tests | ✓ Good — resolved hidden test failures |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-10 after v2.1 milestone started*
