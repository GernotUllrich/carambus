---
phase: 35-printable-quick-reference-card
plan: 01
subsystem: docs
tags: [mkdocs, mkdocs-material, print-css, css, media-print, a4]

# Dependency graph
requires:
  - phase: 34-task-first-doc-rewrite
    provides: Post-rebase mkdocs strict baseline (191 WARNING log lines) and bilingual skeleton gate pattern
provides:
  - Shared print-only stylesheet at docs/stylesheets/print.css
  - mkdocs.yml extra_css wiring for print.css (sibling of extra.css)
  - Phase 35 D-09 baseline file recording pre-edit and post-edit mkdocs strict counts
affects:
  - 35-02-PLAN.md (skeleton + nav entry — will inherit print.css automatically)
  - 35-03-PLAN.md (prose content — prints correctly via print.css)
  - 35-04-PLAN.md (scoreboard shortcut cheat sheet — prints correctly via print.css)
  - 35-05-PLAN.md (final verification — uses 35-01-BASELINE.txt as D-09 reference)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared @media print CSS file registered in mkdocs.yml extra_css (no plugins per D-02c)"
    - "BASELINE.txt file tracking pre-edit and post-edit mkdocs strict warning counts for phase-wide D-09 gate"

key-files:
  created:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/stylesheets/print.css
    - .planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml

key-decisions:
  - "print.css is @media-print-only: no on-screen rules, so visual regression risk on the live site is zero"
  - "Font typography set to 11pt base / 16-14-13pt headings / 10pt monospace per D-02b"
  - "A4 @page margins 15mm top/bottom, 12mm left/right (D-02a)"
  - "Ten chrome-hiding selectors from D-02 all present: .md-header, .md-header__button, .md-tabs, .md-search, .md-sidebar, .md-sidebar--primary, .md-sidebar--secondary, .md-nav, .md-footer, .md-top"
  - "Links forced to color: inherit + text-decoration: none in print per D-05 (printed card reads as plain text)"
  - "Admonitions kept bordered but black-on-white so !!! warning callouts from D-06 print legibly"

patterns-established:
  - "Cross-repo split commits: carambus_master receives the mkdocs/docs artifact commit, carambus_api receives the matching .planning BASELINE commit — edits happen via absolute paths per feedback_scenario_edits_in_current_dir.md"
  - "Pre-edit mkdocs baseline capture: record warning_log_lines BEFORE any docs edits, verify post-edit delta == 0 before marking plan done"

requirements-completed:
  - QREF-02

# Metrics
duration: ~5min
completed: 2026-04-13
---

# Phase 35 Plan 01: Print CSS Infrastructure Summary

**Shared @media print stylesheet stripping mkdocs-material chrome (10 selectors) with A4-safe margins and 11pt typography, wired into mkdocs.yml extra_css with zero new strict warnings over the 191-line Phase 34 baseline.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-13T17:33:00Z
- **Completed:** 2026-04-13T17:35:00Z
- **Tasks:** 2
- **Files modified:** 3 (1 created in carambus_master, 1 modified in carambus_master, 1 created in carambus_api)

## Accomplishments

- Captured the Phase 35 D-09 mkdocs strict baseline (191 WARNING log lines, exit code 1) to `.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt` BEFORE any edits to carambus_master
- Created `docs/stylesheets/print.css` (3102 bytes) with a single `@media print` block hiding all 10 chrome selectors from D-02, forcing A4 @page margins, 11pt typography, black-on-white legibility, and suppressing link styling per D-05
- Registered the new stylesheet in `mkdocs.yml` `extra_css` with a single additive line — nav and `nav_translations` blocks byte-for-byte untouched (D-07a atomic-commit gate preserved for Plan 02)
- Verified post-edit `mkdocs build --strict` returns 191 WARNING log lines (delta = 0 vs baseline) — zero new strict warnings introduced, satisfying D-09/D-09a

## Task Commits

Each task was committed atomically. Because print.css and mkdocs.yml live in the carambus_master repo but BASELINE.txt lives in carambus_api, commits are split cross-repo per `feedback_scenario_edits_in_current_dir.md`:

1. **Task 1: Record mkdocs strict baseline BEFORE edits** — `5135f29f` (chore, carambus_api)
2. **Task 2a: Create print.css + wire mkdocs.yml** — `57e9cc36` (feat, carambus_master)
2. **Task 2b: Record post-edit baseline** — `622ae89d` (chore, carambus_api)

## Files Created/Modified

- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/stylesheets/print.css` (created, 3102 bytes) — Shared `@media print` stylesheet
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml` (modified, +1 line) — `extra_css` list now references `stylesheets/print.css`
- `.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt` (created) — Pre-edit + post-edit mkdocs strict warning counts

### Exact one-line diff applied to mkdocs.yml

```diff
--- a/mkdocs.yml
+++ b/mkdocs.yml
@@ -227,6 +227,7 @@ markdown_extensions:
 # Extra CSS and JS
 extra_css:
   - stylesheets/extra.css
+  - stylesheets/print.css
 
 extra_javascript:
   - javascripts/mathjax.js
```

### Baseline numbers

- **Pre-edit warning_log_lines:** 191 (exit code 1)
- **Post-edit warning_log_lines:** 191 (exit code 1)
- **Delta:** 0 (zero new warnings — D-09 gate satisfied)
- **Phase 34 documented baseline:** 94 warnings / 191 WARNING log lines per `34-VERIFICATION.md` — matches exactly

## Decisions Made

None beyond the plan — all CSS selectors, typography values, and page margins were taken verbatim from the plan's Step A CSS block, which was itself locked by `35-CONTEXT.md` D-02 / D-02a / D-02b / D-05. No planner discretion exercised at execution time.

## Deviations from Plan

None — plan executed exactly as written. Task 1 and Task 2 completed in order, all acceptance criteria and the automated verify check passed on the first try. No auto-fixes required under Rules 1–3, no architectural decisions under Rule 4.

## Issues Encountered

None. mkdocs was already installed in the environment, baseline capture succeeded on the first run, and post-edit strict build matched the baseline exactly.

## Known Stubs

None. print.css is a complete, self-contained `@media print` block; nothing references markdown files that don't exist yet. Plan 02 will add the quick-reference markdown files that will automatically inherit this stylesheet.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Plan 02 (skeleton + nav entry) is UNBLOCKED.** The print.css infrastructure is in place, so when Plan 02 creates `docs/managers/tournament-quick-reference.{de,en}.md`, those pages will immediately inherit the print stylesheet without any additional wiring.
- **D-09 gate baseline captured:** All downstream plans in Phase 35 must run `mkdocs build --strict` and verify their post-edit count stays ≤ 191 (the value recorded in `35-01-BASELINE.txt`).
- **No content gate blocks Plan 02:** mkdocs.yml `nav:` and `nav_translations` blocks are byte-for-byte unchanged, preserving the D-07a atomic-commit gate for Plan 02 to consume.

## Self-Check: PASSED

- Files verified on disk:
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/stylesheets/print.css
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml (contains `stylesheets/print.css`)
- Commits verified in git history:
  - FOUND: 5135f29f (carambus_api, Task 1)
  - FOUND: 57e9cc36 (carambus_master, Task 2 artifacts)
  - FOUND: 622ae89d (carambus_api, Task 2 post-edit baseline)
- Verify commands: all passed (PRINT_CSS_EXISTS, HAS_MEDIA_PRINT, HAS_SIDEBAR, MKDOCS_WIRED, BASELINE_UPDATED, all 10 D-02 selectors present, @page + A4 + 11pt + text-decoration: none all matched)

---

*Phase: 35-printable-quick-reference-card*
*Completed: 2026-04-13*
