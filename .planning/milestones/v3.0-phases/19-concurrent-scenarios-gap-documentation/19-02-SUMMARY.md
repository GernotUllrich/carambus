---
phase: 19-concurrent-scenarios-gap-documentation
plan: "02"
subsystem: documentation
tags: [gap-report, broadcast-isolation, architecture, documentation, FIX-01, FIX-02]
dependency_graph:
  requires:
    - 19-01-SUMMARY.md  # CONC-01 + CONC-02 test results referenced in report
    - 18-01-SUMMARY.md  # ISOL-01 + ISOL-04 results and Phase 18 findings
    - 18-02-SUMMARY.md  # ISOL-02 + ISOL-03 results, 4 auto-fixed bugs documented
    - 17-01-SUMMARY.md  # INFRA-01..INFRA-03 results
    - 17-02-SUMMARY.md  # INFRA-04 result and smoke test details
  provides:
    - DOC-01 gap report covering all 11 v1 requirements from Phases 17-19
    - FIX-01 and FIX-02 deferred fix references for future v2 milestone planning
    - Architectural risk statement for global table-monitor-stream + client-side filtering
  affects:
    - .planning/BROADCAST-GAP-REPORT.md
tech_stack:
  added: []
  patterns: []
key_files:
  created:
    - .planning/BROADCAST-GAP-REPORT.md
  modified: []
decisions:
  - Included architectural risk section even on full clean pass — the structural gap (global stream + client-side filter) is the most important finding regardless of test outcomes
  - Documented score:update dispatch event behavior (Finding 2) as a separate risk from the morph path — different isolation mechanism with weaker guarantees
  - Retained all 4 Phase 18 auto-fixed bugs as gap findings — they reveal non-obvious architectural nuances useful for future maintainers
metrics:
  duration: ~10min
  completed: "2026-04-11T18:30:00Z"
  tasks_completed: 1
  files_changed: 1
---

# Phase 19 Plan 02: Broadcast Isolation Gap Report Summary

**Comprehensive gap report documenting all 11 v1 broadcast isolation requirements as PASS, architectural risk of global stream with client-side filtering, 4 Phase 18 development findings, and FIX-01/FIX-02 deferred v2 fix references.**

## What Was Built

### Task 1 — BROADCAST-GAP-REPORT.md (commit bb007ab6)

Created `.planning/BROADCAST-GAP-REPORT.md` (215 lines) covering:

**Section 1 — Executive Summary:** All 11 requirements passed. Structural architectural risk clearly stated: server broadcasts to global `table-monitor-stream`; isolation enforced entirely client-side in `shouldAcceptOperation` and `score:update` listener. Fix deferred to v2.

**Section 2 — Scope:** All 11 v1 requirements listed with their phase assignment (INFRA-01..INFRA-04 in Phase 17; ISOL-01..ISOL-04 in Phase 18; CONC-01, CONC-02, DOC-01 in Phase 19).

**Section 3 — Test Results Table:** Per-requirement PASS/FAIL with test method name, commit, and specific assertion details. All 11 entries PASS. Final suite: 6 runs, 49 assertions, 0 failures.

**Section 4 — Known Architectural Gap:** Documents the global `table-monitor-stream`, where filtering happens (`shouldAcceptOperation` lines 107-196 and `score:update` listener lines 10-40), and specific failure modes including the `unknown` page context fallback and the risk from new operation types.

**Section 5 — Known Limitations of Testing Approach:** Documents 4 limitations: synchronous `perform_now` cannot simulate true parallel race conditions; `sleep 2` is a timing assumption; single-threaded Puma serializes concurrent HTTP requests; maximum 3 browser sessions tested.

**Section 6 — Phase 18 Development Findings:** 4 findings documented:
1. `update_columns` with serialized JSON column still invokes Rails serializer (raw SQL workaround required)
2. `score:update` DOM event dispatched to ALL sessions before channel listener can filter it
3. `User.scoreboard` (scoreboard@carambus.de) does not exist in the fixture database (causes 500 on `table_scores` page)
4. `refute_selector` does not accept a failure message string as the second argument (Capybara API difference)

**Section 7 — Deferred Fixes:** FIX-01 (server-side targeted broadcasts per-table) and FIX-02 (per-table stream names) verbatim from REQUIREMENTS.md v2 Requirements section.

**Section 8 — Recommendation:** FIX-01 + FIX-02 should be implemented together; client-side filter retained as defense-in-depth; load testing with real Puma threads recommended after server-side fix; `score:update` dispatch event architecture flagged for longer-term consideration.

## Commits

| Task | Description | Hash | Files |
|------|-------------|------|-------|
| 1 | Create BROADCAST-GAP-REPORT.md with all Phase 17-19 results | bb007ab6 | .planning/BROADCAST-GAP-REPORT.md |

## Deviations from Plan

None — plan executed exactly as written. All 8 required sections present, all acceptance criteria met.

## Known Stubs

None. The gap report is a complete documentation artifact. All test results are drawn from verified SUMMARY.md files. No future plan is required to complete any section of this report.

## Threat Flags

None. Documentation-only plan — no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check

### Files

- [x] `.planning/BROADCAST-GAP-REPORT.md` — FOUND (215 lines)
- [x] `grep -c "FIX-01"` — returns 10 (>= 2 required) ✓
- [x] `grep -c "FIX-02"` — returns 10 (>= 2 required) ✓
- [x] `grep -c "table-monitor-stream"` — returns 5 (>= 1 required) ✓
- [x] `grep -c "shouldAcceptOperation"` — returns 6 (>= 1 required) ✓
- [x] All 11 requirement IDs (INFRA-01..DOC-01) present ✓

### Commits

- [x] `bb007ab6` — verified via git log ✓

## Self-Check: PASSED

---
*Phase: 19-concurrent-scenarios-gap-documentation*
*Completed: 2026-04-11*
