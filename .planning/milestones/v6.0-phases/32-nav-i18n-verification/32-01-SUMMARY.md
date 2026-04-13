---
phase: 32-nav-i18n-verification
plan: "01"
subsystem: docs
tags: [mkdocs, i18n, nav, documentation, warnings]

# Dependency graph
requires:
  - phase: 31-services-docs
    provides: "Bilingual .de.md/.en.md service pages in docs/developers/services/"
provides:
  - "mkdocs.yml with Services nav block (8 Phase 31 pages wired into nav)"
  - "expanded exclude_docs covering internal/**, studies/**, changelog/**"
  - "9 nav_translations entries for new Services nav labels"
  - "7 broken links in visible docs fixed across 5 files"
affects: [32-nav-i18n-verification, plan-02, plan-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cross-language doc links must use plain .md suffix (not .de.md/.en.md) for mkdocs-static-i18n resolution"
    - "Files in internal/, studies/, changelog/ excluded from mkdocs build via exclude_docs to suppress warnings"

key-files:
  created: []
  modified:
    - mkdocs.yml
    - docs/developers/developer-guide.en.md
    - docs/developers/rake-tasks-debugging.de.md
    - docs/developers/rake-tasks-debugging.en.md
    - docs/reference/api.de.md
    - docs/reference/api.en.md

key-decisions:
  - "Replace lib/tasks/obsolete/README.md hyperlinks with plain text (file outside docs root, not renderable by mkdocs)"
  - "Replace broken API.md link with self-referential note (the api pages are the API reference)"
  - "Cross-language link fix: developer-guide.en.md line 455 changed from .de.md to plain .md suffix"

patterns-established:
  - "Nav entries always use plain .md paths; mkdocs-static-i18n plugin resolves to correct .de.md/.en.md"
  - "Links to files outside docs root (../../lib/...) must be converted to plain text, not hyperlinks"

requirements-completed: [DOC-03]

# Metrics
duration: 15min
completed: 2026-04-13
---

# Phase 32 Plan 01: Nav & Broken Link Fixes Summary

**Services nav block with 8 Phase 31 pages wired into mkdocs.yml, exclude_docs expanded to eliminate 24 orphan warnings, and 7 broken cross-doc links fixed — reducing strict build warnings from 62 to 5**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-13T00:14:00Z
- **Completed:** 2026-04-13T00:29:27Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added Services subsection under Developers nav with all 8 Phase 31 service pages and video-crossref
- Expanded exclude_docs to cover internal/**, studies/**, changelog/** — eliminating 24 of 32 unique strict-build warnings
- Added 9 nav_translations entries in the DE locale block for new Services nav labels
- Fixed 7 broken links across 5 visible doc files (cross-language suffix bug, out-of-docs-root links, missing API.md)

## Task Commits

Each task was committed atomically:

1. **Task 1: Update mkdocs.yml — exclude_docs, Services nav block, nav_translations** - `cb680dce` (feat)
2. **Task 2: Fix 7 broken links in visible docs** - `4d43c5d1` (fix)

## Files Created/Modified

- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/mkdocs.yml` - expanded exclude_docs (5 patterns), Services nav block (8 entries), 9 DE nav_translations entries
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/docs/developers/developer-guide.en.md` - fixed cross-language link at line 455 (.de.md -> .md)
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/docs/developers/rake-tasks-debugging.de.md` - replaced 3 out-of-docs-root hyperlinks with plain text
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/docs/developers/rake-tasks-debugging.en.md` - replaced 3 out-of-docs-root hyperlinks with plain text
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/docs/reference/api.de.md` - removed broken API.md link, replaced with "siehe oben"
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/docs/reference/api.en.md` - removed broken API.md link, replaced with "see above"

## Decisions Made

- **lib/tasks/obsolete/README.md links**: Replaced 6 hyperlinks (3 DE, 3 EN) with plain text + path note. The file exists in the project repo but is outside the docs root and cannot be rendered by mkdocs.
- **API.md link**: Replaced with a self-referential note ("see above / siehe oben"). The api.de.md and api.en.md pages are themselves the API reference; the target API.md never existed in docs/.
- **Cross-language suffix fix**: Changed `developer-guide.de.md#operations` to `developer-guide.md#operations` in the EN file — plain .md paths are required for mkdocs-static-i18n cross-language linking.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Remaining 5 warnings after fixes are all from the single Bucket C issue: missing `managers/table-reservation.de.md` (nav reference + 2 link occurrences in administrators/index.de.md + 2 in managers/index.de.md). This is explicitly deferred to Plan 02 per the plan's success criteria.

## Known Stubs

None.

## Threat Flags

None - only documentation config and markdown content changes; no new network endpoints, auth paths, or schema changes.

## Next Phase Readiness

- Plan 02 (translation gap closure) can proceed: Services nav is wired, exclude_docs is expanded, broken links in visible docs are resolved
- Remaining 5 warnings all stem from missing `managers/table-reservation.de.md` — Plan 02 creates this file
- After Plan 02, `mkdocs build --strict` should exit clean (0 warnings)

## Self-Check: PASSED

- `cb680dce` exists: confirmed
- `4d43c5d1` exists: confirmed
- mkdocs.yml contains Services nav block: confirmed (grep returns 4 matches for "Services:")
- mkdocs.yml exclude_docs covers internal/**, studies/**, changelog/**: confirmed
- All 5 broken-link checks return 0: confirmed

---
*Phase: 32-nav-i18n-verification*
*Completed: 2026-04-13*
