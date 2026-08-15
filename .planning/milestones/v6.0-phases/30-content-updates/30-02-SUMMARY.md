---
phase: 30-content-updates
plan: 02
subsystem: documentation
tags: [services, developer-guide, bilingual, de, en, namespaces]

requires: []
provides:
  - "German developer guide with Extrahierte Services section listing all 35 services across 7 namespaces"
  - "English developer guide with Extracted Services section listing all 35 services across 7 namespaces"
affects: [30-content-updates]

tech-stack:
  added: []
  patterns:
    - "One table per namespace in developer guide services section"
    - "DE primary language, EN translation in same commit"

key-files:
  created: []
  modified:
    - docs/developers/developer-guide.de.md
    - docs/developers/developer-guide.en.md

key-decisions:
  - "Services section inserted after Architektur / Architecture section, before Erste Schritte / Getting Started"
  - "Used verified count of 35 services (not 37 as stated in REQUIREMENTS.md) per RESEARCH.md findings"
  - "Umb:: section includes cross-reference links to dedicated umb-scraping docs"
  - "PdfParser:: sub-services grouped within Umb:: table (not a separate 8th namespace)"

patterns-established:
  - "Service tables: columns are Service Class | File | Description"

requirements-completed:
  - UPDATE-02

duration: 12min
completed: 2026-04-12
---

# Phase 30 Plan 02: Services Section in Developer Guide Summary

**Added 35-service inventory across 7 namespace tables to both German and English developer guides, with file paths and one-liner descriptions for every extracted service.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-12T22:42:00Z
- **Completed:** 2026-04-12T22:54:48Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Inserted `## Extrahierte Services` section in `developer-guide.de.md` after the Architektur section
- Inserted `## Extracted Services` section in `developer-guide.en.md` after the Architecture section
- All 35 services listed with file path and one-liner description across 7 namespace tables (TableMonitor, RegionCc, Tournament, TournamentMonitor, League, PartyMonitor, Umb)
- Both table-of-contents updated to include the new section at position 3

## Task Commits

1. **Task 1: Add services section to developer guide (DE + EN)** - `aec3f76f` (docs)

## Files Created/Modified

- `docs/developers/developer-guide.de.md` - Added `## Extrahierte Services` section with 7 namespace tables (2+10+3+4+4+2+10 = 35 rows) and updated table of contents
- `docs/developers/developer-guide.en.md` - Added `## Extracted Services` section with identical structure translated to English and updated table of contents

## Decisions Made

- Inserted services section after Architektur/Architecture (before Erste Schritte/Getting Started) — logical position per RESEARCH.md guidance
- Used 35 as the verified service count (REQUIREMENTS.md said "37" but RESEARCH.md confirmed 35 actual files)
- Umb:: PdfParser sub-services grouped in the Umb:: table rather than a separate namespace (7 namespaces total, not 8)

## Deviations from Plan

None — plan executed exactly as written. Descriptions sourced from RESEARCH.md verified inventory.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Both developer guides now have a complete services inventory
- Phase 30 plan 03 (if any) can reference the services section as existing
- `bin/check-docs-coderef.rb` can be run to verify no stale class references were introduced

---

*Phase: 30-content-updates*
*Completed: 2026-04-12*
