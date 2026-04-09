# Carambus API — Model Refactoring & Test Coverage

## What This Is

A focused improvement effort on the Carambus API codebase to break down the two largest model classes (TableMonitor at 3900 lines and RegionCc at 2700 lines) into smaller, well-tested components. This is a refactoring initiative — no new features, no architecture changes.

## Core Value

Reduce the two worst god-object models into maintainable, testable units without changing external behavior.

## Requirements

### Validated

- ✓ Existing TableMonitor functionality (AASM state machine, reflex interactions, CableReady broadcasts) — existing
- ✓ Existing RegionCc functionality (ClubCloud sync, league/team/player data transformation) — existing
- ✓ Existing test suite passes — existing

### Active

- [ ] Backfill tests for TableMonitor critical paths before refactoring
- [ ] Backfill tests for RegionCc critical paths before refactoring
- [ ] Extract service classes from TableMonitor (state management, broadcasting, callback logic)
- [ ] Extract service classes from RegionCc (ClubCloud sync, data transformation, HTTP handling)
- [ ] Tests for all extracted service classes
- [ ] Both models reduced to under ~500 lines of direct model code

### Out of Scope

- League model refactoring (2219 lines) — tackle after TableMonitor and RegionCc
- Tournament model refactoring (1775 lines) — tackle after TableMonitor and RegionCc
- Architecture or stack changes — explicitly excluded per project goals
- New features — this is purely refactoring and test coverage
- Scraper consolidation (UmbScraper v1/v2) — separate concern

## Context

- Brownfield Rails 7.2 app for carom billiard tournament management
- Ruby 3.2.1, PostgreSQL, Redis, ActionCable, StimulusReflex
- TableMonitor has 96 methods, AASM state machine, complex callbacks, and reflex interactions
- RegionCc has deeply nested ClubCloud sync logic with manual HTTP and raw response parsing
- Existing test framework: Minitest with fixtures, FactoryBot, WebMock, VCR cassettes
- `LocalProtector` concern prevents modification of global records (id < 50_000_000) — disabled in tests
- Codebase map available at `.planning/codebase/`

## Constraints

- **Behavior preservation**: All existing functionality must continue to work identically
- **Incremental**: Each extraction must be independently deployable
- **Test-first**: Characterization tests before any refactoring

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Start with TableMonitor and RegionCc only | Worst offenders by line count (3900 and 2700 lines) | — Pending |
| Write characterization tests before extracting | Ensures refactoring doesn't break existing behavior | — Pending |
| Extract to service classes, not concerns | Services are more testable and explicit than concerns | — Pending |

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
*Last updated: 2026-04-09 after initialization*
