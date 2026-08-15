---
phase: 06-audit-baseline-standards
plan: 01
subsystem: testing
tags: [minitest, fixtures, factorybot, vcr, webmock, shoulda-matchers, standards]

# Dependency graph
requires: []
provides:
  - STANDARDS.md — test suite conventions rubric for Phases 7-9 audit execution
  - Issue category codes (E01-E04, W01-W02, I01-I02) for AUDIT-REPORT.md
  - Helper usage analysis (4 support files documented with active vs unused methods)
affects:
  - 06-02 (AUDIT-REPORT.md uses STANDARDS.md as rubric)
  - 07-09 (file-by-file review follows these standards)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fixtures-first test data with Model.create! for complex multi-record setups"
    - "MiniTest baseline assertions; shoulda-matchers for validation/association tests"
    - "test 'description' do naming standard (not def test_)"
    - "Targeted helper inclusion (KoTournamentTestHelper) preferred over global inclusion"

key-files:
  created:
    - .planning/phases/06-audit-baseline-standards/STANDARDS.md
  modified: []

key-decisions:
  - "SnapshotHelpers is globally included but has zero callers outside its own file — all methods flagged I01"
  - "ScrapingHelpers global inclusion is a smell; most model/controller tests never call its methods — flagged I01/I02"
  - "No FactoryBot factory files exist in the codebase — prohibition is pre-existing reality, not a new constraint"
  - "Characterization tests are explicitly excluded from naming/assertion standards — they pin behavior, not test new code"

patterns-established:
  - "Issue categories E01-E04 (errors), W01-W02 (warnings), I01-I02 (info) for consistent audit tagging"
  - "Decision table for fixture vs Model.create! vs FactoryBot — codified from D-04/D-05"

requirements-completed:
  - CONS-01
  - CONS-02
  - CONS-03
  - CONS-04

# Metrics
duration: 20min
completed: 2026-04-10
---

# Phase 06 Plan 01: Audit Baseline Standards Summary

**STANDARDS.md created with 6-section conventions rubric covering fixtures-first setup, MiniTest assertion style, test naming, 4 support file analysis with usage data, file structure template, and 7 issue category codes for the Phase 7-9 audit.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-10
- **Completed:** 2026-04-10
- **Tasks:** 2 (Task 1 read-only analysis, Task 2 document creation)
- **Files modified:** 1 (STANDARDS.md created)

## Accomplishments

- Documented all 4 support files (`scraping_helpers.rb`, `snapshot_helpers.rb`, `vcr_setup.rb`, `ko_tournament_test_helper.rb`) with public method inventories and actual caller counts
- Identified `SnapshotHelpers` as entirely unused (zero calls outside its own file) and flagged all methods as I01
- Confirmed no FactoryBot factory definitions exist — the fixture-first policy is already the de facto reality
- Defined 7 issue category codes (E01-E04, W01-W02, I01-I02) that AUDIT-REPORT.md (Plan 02) will use as consistent tags

## Task Commits

Each task was committed atomically:

1. **Task 1: Review test infrastructure and support files** — read-only analysis, no commit (per plan specification)
2. **Task 2: Write STANDARDS.md** — `e029c2b0` (feat)

**Plan metadata:** see final commit below

## Files Created/Modified

- `.planning/phases/06-audit-baseline-standards/STANDARDS.md` — 429-line conventions document with 6 required sections and decision references D-04 through D-08

## Decisions Made

- `SnapshotHelpers` methods are all unused — flagged I01 in the document; resolution deferred to per-file review in Phases 7-9
- `ScrapingHelpers` is globally included but only relevant to ~3 scraping test files — flagged I01/I02; narrowing scope is an audit recommendation
- Characterization tests (from v1.0 Phase 1) are explicitly exempted from naming and assertion standards in the document

## Deviations from Plan

None — plan executed exactly as written. Task 1 was read-only analysis feeding Task 2. STANDARDS.md contains all required sections and all acceptance criteria passed on first check.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- STANDARDS.md is complete and self-contained — Phase 06 Plan 02 (AUDIT-REPORT.md) can begin immediately using STANDARDS.md as its rubric
- Issue category codes E01-E04, W01-W02, I01-I02 are defined and ready for the automated scan
- Helper analysis findings (especially `SnapshotHelpers` zero-usage) are documented for the audit to reference

---
*Phase: 06-audit-baseline-standards*
*Completed: 2026-04-10*
