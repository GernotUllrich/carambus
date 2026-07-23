---
phase: 28-audit-triage
plan: 02
subsystem: docs
tags: [audit, documentation, json, inventory, broken-links, stale-refs, coverage-gaps, bilingual-gaps]

# Dependency graph
requires:
  - bin/check-docs-translations.rb  # from 28-01
  - bin/check-docs-coderef.rb       # from 28-01
  - bin/check-docs-links.rb         # pre-existing
provides:
  - docs/audit.json: "133-finding machine-parseable inventory gating Phases 29-32"
  - docs/DOCS-AUDIT-REPORT.md: "Human-readable audit summary with all 6 required sections"
affects:
  - 29-fix-broken-links   # consumes broken_link findings (78 items)
  - 30-stale-refs         # consumes stale_ref UPDATE findings (3 items)
  - 31-coverage-gaps      # consumes coverage_gap CREATE findings (8 namespaces)
  - 32-bilingual-gaps     # consumes bilingual_gap phase 32 findings (21 items)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Audit runner pattern: run all checkers, collect findings in memory, write JSON once at end"
    - "Phase assignment rules: broken_link→29, stale DELETE→29, stale UPDATE→29 or 30 (content rewrite), coverage_gap→31, bilingual nav-linked→32, bilingual non-nav→null (TRANSLATE-01)"

key-files:
  created:
    - docs/audit.json
    - docs/DOCS-AUDIT-REPORT.md

key-decisions:
  - "Phase 29 vs 30 split for stale_refs: simple path-update references go to Phase 29, files needing full content rewrite (tournament-architecture-overview.en.md) go to Phase 30"
  - "Nav-only bilingual gap scope for Phase 32: 21 gaps confirmed via --nav-only flag, not just the single table-reservation gap from RESEARCH.md — actual nav has 10 single-language sections requiring bilingual treatment"
  - "Non-nav deferred gaps (22 items) assigned phase null with TRANSLATE-01 note — not scheduled in v6.0 milestone"

requirements-completed:
  - AUDIT-01

# Metrics
duration: 8min
completed: 2026-04-12
---

# Phase 28 Plan 02: Audit Runner Summary

**133-finding staleness inventory in docs/audit.json + docs/DOCS-AUDIT-REPORT.md: 75 broken links, 6 stale refs, 9 coverage gaps, 43 bilingual gaps — all classified and phase-assigned to gate Phases 29-32**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-12T00:00:00Z
- **Completed:** 2026-04-12T00:08:00Z
- **Tasks:** 2 (run tools + write outputs combined into single commit)
- **Files modified:** 2

## Accomplishments

- Ran `bin/check-docs-links.rb --exclude-archives` — 75 broken links found (1 administrators, 19 developers, 2 international, 2 managers, 34 players, 16 reference, 1 training_database)
- Ran `bin/check-docs-translations.rb --exclude-archives` and `--nav-only` — 43 bilingual gaps (21 nav-linked for Phase 32, 22 non-nav deferred)
- Ran `bin/check-docs-coderef.rb --exclude-archives --json` — 6 stale references in 3 files (UmbScraperV2 + TournamentMonitorSupport/tournament_monitor_support)
- Enumerated 8 coverage-gap namespaces (37 undocumented services) from FEATURES.md research
- Confirmed archive indexing exclusion (`exclude_docs: archive/**, obsolete/**` present in mkdocs.yml)
- Wrote `docs/audit.json` — 133 findings, valid JSON, all required fields present on every finding
- Wrote `docs/DOCS-AUDIT-REPORT.md` — all 6 required sections: Broken Links, Stale Code References, Coverage Gaps, Bilingual Gaps, Archive Indexing Status, Phase Workload Summary

## Task Commits

1. **Tasks 1+2: Run all audit tools and write staleness inventory** - `51f84b05` (feat)

## Files Created/Modified

- `docs/audit.json` — 133-finding inventory (generated_at, summary with by_action/by_category/by_phase, findings array)
- `docs/DOCS-AUDIT-REPORT.md` — Human-readable audit report with tables for all finding categories

## Decisions Made

- **Phase 29 vs 30 split for stale_refs:** `developers/clubcloud-upload.de.md` and `.en.md` each have a single code-comment path reference that can be fixed in place (Phase 29). `developers/tournament-architecture-overview.en.md` describes `TournamentMonitorSupport` as active architecture across multiple sections — requires a full content rewrite (Phase 30).

- **Nav-only bilingual gap scope for Phase 32:** RESEARCH.md identified only `managers/table-reservation.de.md` as confirmed nav-linked gap. Running `--nav-only` revealed 21 gaps — 10 nav entries with DE but no EN, 11 nav entries with EN but no DE (including the table-reservation one). Phase 32 scope is 21 files, not 1.

- **Non-nav deferred gaps (22 items):** 21 DE-only files + 1 EN-only file outside the nav. Assigned `phase: null` with `note: "deferred — TRANSLATE-01"` per plan instructions. These are not in the v6.0 milestone scope.

## Deviations from Plan

**1. [Rule 1 - Bug] Worktree had stale files from previous branch**
- **Found during:** Pre-execution branch verification
- **Issue:** Worktree was on an older branch; `git reset --soft` left `app/services/umb_scraper_v2.rb` and `lib/tasks/umb_v2.rake` staged. The coderef checker saw `umb_scraper_v2.rb` as a live file and did not flag `UmbScraperV2` as stale.
- **Fix:** Unstaged and deleted the two leftover files; re-ran the coderef checker which then correctly identified all 6 stale references including UmbScraperV2.
- **Files modified:** None (cleanup only)

**2. [Rule 1 - Bug] Nav-only bilingual gap count differs from RESEARCH.md**
- **Found during:** Task 1 translation checker run
- **Issue:** RESEARCH.md stated "only one confirmed gap" (`managers/table-reservation.de.md`). Actual `--nav-only` run found 21 gaps — the nav has grown since the research was written.
- **Fix:** Used actual tool output (21 gaps) for the inventory rather than the documented baseline (1 gap). This is correct behavior — the inventory must reflect current state.

## Issues Encountered

None beyond the two auto-fixed deviations above.

## Known Stubs

None — `docs/audit.json` and `docs/DOCS-AUDIT-REPORT.md` are fully populated from actual tool runs.

## Next Phase Readiness

- `docs/audit.json` is parseable by downstream phases:
  - Phase 29: `jq '.findings[] | select(.phase == 29)'` returns 78 items (FIX + DELETE + UPDATE)
  - Phase 30: `jq '.findings[] | select(.phase == 30)'` returns 3 items (UPDATE/rewrite)
  - Phase 31: `jq '.findings[] | select(.phase == 31)'` returns 8 items (CREATE/coverage)
  - Phase 32: `jq '.findings[] | select(.phase == 32)'` returns 21 items (CREATE/bilingual)
- `docs/DOCS-AUDIT-REPORT.md` provides human context for each category

---
*Phase: 28-audit-triage*
*Completed: 2026-04-12*

## Self-Check: PASSED

- docs/audit.json: FOUND
- docs/DOCS-AUDIT-REPORT.md: FOUND
- Commit 51f84b05 (Tasks 1+2): FOUND
- audit.json valid JSON: CONFIRMED (ruby -rjson parse exits 0)
- audit.json total_findings == 133: CONFIRMED
- audit.json broken_link >= 74: CONFIRMED (75)
- audit.json stale_ref >= 4: CONFIRMED (6)
- audit.json coverage_gap CREATE == 8: CONFIRMED
- audit.json bilingual_gap phase 32 >= 1: CONFIRMED (21)
- Every finding has id/category/action/severity/file/phase: CONFIRMED (0 missing)
- DOCS-AUDIT-REPORT.md contains "## Broken Links": CONFIRMED
- DOCS-AUDIT-REPORT.md contains "## Stale Code References": CONFIRMED
- DOCS-AUDIT-REPORT.md contains "## Coverage Gaps": CONFIRMED
- DOCS-AUDIT-REPORT.md contains "## Bilingual Gaps": CONFIRMED
- DOCS-AUDIT-REPORT.md contains "## Archive Indexing Status": CONFIRMED
- DOCS-AUDIT-REPORT.md contains "## Phase Workload Summary": CONFIRMED
