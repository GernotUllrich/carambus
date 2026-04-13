---
phase: 28-audit-triage
plan: 01
subsystem: infra
tags: [ruby, mkdocs, documentation, audit, i18n, git-diff]

# Dependency graph
requires: []
provides:
  - bin/check-docs-translations.rb: reports missing .en.md/.de.md pairs across docs/
  - bin/check-docs-coderef.rb: detects stale class identifiers from git diff v1.0..v5.0 in docs
  - rake mkdocs:check: CI-ready strict-mode mkdocs build validation task
  - mkdocs.yml exclude_docs: archive/ and obsolete/ excluded from site build and search index
affects:
  - 28-02  # audit runner uses these scripts to produce the staleness inventory

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Audit script pattern: class-based Ruby stdlib-only, DOCS_ROOT constant, ANSI colors, --help, exit 0/1"
    - "Git diff strategy: build stale identifier set from v1.0..v5.0 --diff-filter=D/R, search docs full-text"
    - "mkdocs strict: build to temp dir, cleanup after, exit 1 on any warning"

key-files:
  created:
    - bin/check-docs-translations.rb
    - bin/check-docs-coderef.rb
  modified:
    - lib/tasks/mkdocs.rake
    - mkdocs.yml

key-decisions:
  - "Full-text scan (not code-fence-only) in coderef checker: stale identifier set is tiny (3 project-unique names from git), so false positives are impossible — full-text catches headings and prose references"
  - "Temp dir for mkdocs:check: builds to /tmp/mkdocs-check-{pid} to avoid polluting site/ directory, cleaned up unconditionally after build"

patterns-established:
  - "Audit scripts: follow check-docs-links.rb pattern exactly (class-based, DOCS_ROOT, ANSI, --help, exit 0/1)"
  - "Git diff identifier extraction: snake_case + CamelCase both added to identifier set for completeness"

requirements-completed:
  - AUDIT-02
  - AUDIT-03

# Metrics
duration: 3min
completed: 2026-04-12
---

# Phase 28 Plan 01: Audit Tools Summary

**Three audit tools created: translation gap checker, stale code reference detector, and CI-ready mkdocs strict-build task — plus archive exclusion from search indexing**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-12T19:03:52Z
- **Completed:** 2026-04-12T19:06:32Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created `bin/check-docs-translations.rb` — reports MISSING_EN/MISSING_DE gaps across all docs, with `--nav-only` and `--exclude-archives` modes
- Created `bin/check-docs-coderef.rb` — uses `git diff --diff-filter=D/R v1.0 v5.0` to build stale identifier set then scans docs full-text; finds `UmbScraperV2` and `TournamentMonitorSupport` references in active docs
- Added `rake mkdocs:check` — strict-mode build to temp dir, no site/ artifacts left, exits non-zero on any warning (70 warnings currently in docs)
- Added `exclude_docs: archive/**, obsolete/**` to mkdocs.yml — prevents archive content from being built into site or indexed by search

## Task Commits

1. **Task 1: Create bin/check-docs-translations.rb and bin/check-docs-coderef.rb** - `326b2277` (feat)
2. **Task 2: Add mkdocs:check rake task and fix archive search indexing** - `093708f2` (feat)

**Plan metadata:** committed with SUMMARY.md below

## Files Created/Modified

- `bin/check-docs-translations.rb` - Translation coverage checker (class DocsTranslationChecker, DOCS_ROOT, --nav-only, --exclude-archives, exit 0/1)
- `bin/check-docs-coderef.rb` - Stale code reference detector (class DocsCoderefChecker, git diff v1.0..v5.0, --json, --exclude-archives, exit 0/1)
- `lib/tasks/mkdocs.rake` - Added 5th task `mkdocs:check` (strict mode, temp dir, FileUtils.rm_rf cleanup)
- `mkdocs.yml` - Added `exclude_docs: | archive/** obsolete/**` after site_dir line

## Decisions Made

- **Full-text scan over code-fence-only**: The RESEARCH.md warned about false positives from broad CamelCase extraction (Pitfall 1). This plan inverts the approach — build a tiny, specific identifier set from git history (3 entries) and scan for those exact strings. With project-unique identifiers like `UmbScraperV2`, false positives are impossible. Full-text catches prose and heading references that code-fence-only scanning would miss.
- **Temp dir for mkdocs:check**: Builds to `/tmp/mkdocs-check-{pid}` instead of the default `site/` directory. Prevents polluting the working tree. Temp dir is cleaned up unconditionally after each run.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All three audit tools are runnable and produce actionable output
- Phase 28 Plan 02 (audit runner) can now invoke these scripts to produce the full staleness inventory
- Current findings: 24 translation gaps (21 missing EN, 3 missing DE), 6 stale code reference occurrences, 70 mkdocs strict-mode warnings

---
*Phase: 28-audit-triage*
*Completed: 2026-04-12*

## Self-Check: PASSED

- bin/check-docs-translations.rb: FOUND
- bin/check-docs-coderef.rb: FOUND
- lib/tasks/mkdocs.rake: FOUND
- mkdocs.yml: FOUND
- 28-01-SUMMARY.md: FOUND
- Commit 326b2277 (Task 1): FOUND
- Commit 093708f2 (Task 2): FOUND
