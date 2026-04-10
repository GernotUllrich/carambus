# Carambus API — Test Suite Audit & Improvement

## What This Is

A systematic audit and improvement of the existing 72 test files (538 methods, 8770 lines) in the Carambus API codebase. Reviewing every test for quality, consistency, and correctness — fixing brittle tests, resolving skipped/pending tests, removing dead code, and establishing consistent patterns. Follows the v1.0 model refactoring milestone.

## Core Value

Every existing test file is reviewed, consistent, and trustworthy — no dead tests, no skipped tests without justification, no brittle patterns.

## Current Milestone: v2.0 Test Suite Audit & Improvement

**Goal:** Review and improve all 72 existing test files for quality, consistency, and correctness.

**Target features:**
- Audit every existing test file for quality issues (brittle tests, weak assertions, dead code)
- Fix or remove all skipped/pending tests (8 files identified)
- Establish consistent patterns (fixtures vs factories, setup conventions, assertion style)
- Remove dead/redundant tests
- All tests green after improvements

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
- ✓ TableMonitor reduced to 1611 lines — v1.0 (target was 800, accepted at 1611)
- ✓ Reek quality improvement measured — v1.0 (TableMonitor 781→306, RegionCc 460→54)

### Active

- [ ] Every test file reviewed for quality issues
- [ ] All skipped/pending tests resolved (fixed or removed with justification)
- [ ] Consistent patterns established across test suite
- [ ] Dead/redundant tests removed
- [ ] All tests green after improvements

### Out of Scope

- League model refactoring (2219 lines) — tackle after TableMonitor and RegionCc
- Tournament model refactoring (1775 lines) — tackle after TableMonitor and RegionCc
- Architecture or stack changes — explicitly excluded per project goals
- New features — this is purely test improvement
- Scraper consolidation (UmbScraper v1/v2) — separate concern
- New test coverage for untested models/controllers/services — future milestone
- Writing tests for code that has none — this milestone improves existing tests only

## Context

- Brownfield Rails 7.2 app for carom billiard tournament management
- Ruby 3.2.1, PostgreSQL, Redis, ActionCable, StimulusReflex
- **v1.0 shipped 2026-04-10:** TableMonitor 3903→1611 lines (4 services), RegionCc 2728→491 lines (10 services)
- 140 service unit tests + 58 characterization tests = 198 total extraction tests
- Reek: TableMonitor 781→306 warnings (61%), RegionCc 460→54 warnings (88%)
- Extracted services: ScoreEngine (PORO), GameSetup (ApplicationService), OptionsPresenter (PORO), ResultRecorder (ApplicationService), ClubCloudClient + 9 syncers
- **v2.0 test audit scope:** 72 existing test files, 538 methods, 8770 lines; 8 files with skipped/pending tests
- `LocalProtector` concern prevents modification of global records (id < 50_000_000) — disabled in tests
- Codebase map available at `.planning/codebase/`

## Constraints

- **Behavior preservation**: All existing functionality must continue to work identically
- **Incremental**: Each extraction must be independently deployable
- **Test-first**: Characterization tests before any refactoring

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Start with TableMonitor and RegionCc only | Worst offenders by line count (3900 and 2700 lines) | ✓ Good — both reduced significantly |
| Write characterization tests before extracting | Ensures refactoring doesn't break existing behavior | ✓ Good — 58 char tests caught every regression |
| Extract to service classes, not concerns | Services are more testable and explicit than concerns | ✓ Good — 14 services extracted with clear boundaries |
| ScoreEngine as PORO, not ApplicationService | Stateful hash wrapper called many times per game | ✓ Good — lazy accessor pattern reused by OptionsPresenter |
| GameSetup/ResultRecorder as ApplicationService | One-shot operations with AR writes | ✓ Good — consistent .call(kwargs) pattern |
| Fine-grained RegionCc syncers (9 classes) | User chose focused services over 3 large ones | ✓ Good — each syncer independently testable |
| suppress_broadcast replacing skip_update_callbacks | Explicit flag with no leaked state | ✓ Good — 79 call sites migrated cleanly |

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
*Last updated: 2026-04-10 after v2.0 milestone start*
