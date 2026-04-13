---
phase: 30-content-updates
plan: 01
subsystem: documentation
tags: [umb, scraping, bilingual, mkdocs, docs-rewrite]

requires: []
provides:
  - "umb-scraping-implementation.de.md and .en.md: accurate Umb:: architecture docs covering 10 services"
  - "umb-scraping-methods.de.md and .en.md: method reference for 3 scraper entry points and 3 PDF parser methods"
affects: [phase-30-02, any future Umb:: feature work]

tech-stack:
  added: []
  patterns:
    - "Bilingual doc pair pattern: .de.md (German primary) + .en.md (English translation), nav entries unchanged"
    - "Umb:: architecture: POROs for pure algorithms, ApplicationService for DB side effects"

key-files:
  created:
    - docs/developers/umb-scraping-implementation.de.md
    - docs/developers/umb-scraping-implementation.en.md
    - docs/developers/umb-scraping-methods.de.md
    - docs/developers/umb-scraping-methods.en.md
  modified: []

key-decisions:
  - "Nothing salvageable in old docs — entire content replaced (old docs were planning-era drafts describing deleted code)"
  - "35 services documented (not 37 as stated in requirements) — verified count matches actual files on disk"
  - "Umb::PdfParser:: treated as sub-group of Umb:: namespace (not separate 8th namespace)"

patterns-established:
  - "PORO vs ApplicationService split in Umb:: namespace: DisciplineDetector, DateHelpers, PdfParser/* are POROs; scrapers + PlayerResolver are ApplicationService"
  - "parse_pdfs: false default on DetailsScraper — opt-in PDF pipeline"

requirements-completed: [UPDATE-01]

duration: 8min
completed: 2026-04-12
---

# Phase 30 Plan 01: UMB Scraping Docs Rewrite Summary

**Stale UmbScraperV2 planning docs replaced with accurate bilingual Umb:: namespace documentation — 4 files covering 10 services, 3 entry points, and 3 PDF parser output contracts**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-12T22:48:00Z
- **Completed:** 2026-04-12T22:56:06Z
- **Tasks:** 2
- **Files modified:** 4 created, 2 removed

## Accomplishments

- Replaced a 727-line stale planning document (`umb-scraping-implementation.md`) with two accurate bilingual files documenting the 10-service Umb:: namespace
- Replaced a 307-line stale Rake task reference (`umb-scraping-methods.md`) with two accurate bilingual files documenting entry points and PDF parser output contracts
- Translation check confirms umb-scraping docs no longer appear as gaps in `bin/check-docs-translations.rb` output

## Task Commits

1. **Task 1: Rewrite umb-scraping-implementation as bilingual pair** - `a8b8d86f` (docs)
2. **Task 2: Rewrite umb-scraping-methods as bilingual pair** - `a239128b` (docs)

## Files Created/Modified

- `docs/developers/umb-scraping-implementation.de.md` - German architecture overview: 10-service table, PORO vs ApplicationService split, data flow diagram, 3 entry points
- `docs/developers/umb-scraping-implementation.en.md` - English translation of architecture overview
- `docs/developers/umb-scraping-methods.de.md` - German method reference: 3 scraper signatures with parameters, 3 PDF parser output contracts, supporting services table
- `docs/developers/umb-scraping-methods.en.md` - English translation of method reference
- `docs/developers/umb-scraping-implementation.md` - Removed (stale UmbScraperV2 planning doc)
- `docs/developers/umb-scraping-methods.md` - Removed (stale Rake task reference)

## Decisions Made

- Both old files contained zero salvageable content — they described a deleted monolith (`UmbScraperV2`) and pre-refactoring Rake tasks
- Service count documented as 35 (not 37 as stated in requirements) — verified by RESEARCH.md against actual file counts
- `Umb::PdfParser::` presented as sub-group within the Umb:: namespace table rather than a separate 8th namespace entry

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

None — both docs wire to actual class names and method signatures verified against source files.

## Threat Flags

None — documentation-only changes, no new code surface.

## Self-Check

- [x] `docs/developers/umb-scraping-implementation.de.md` exists
- [x] `docs/developers/umb-scraping-implementation.en.md` exists
- [x] `docs/developers/umb-scraping-methods.de.md` exists
- [x] `docs/developers/umb-scraping-methods.en.md` exists
- [x] Neither old `.md` file exists
- [x] Zero `UmbScraperV2` references in new files
- [x] All 10 Umb:: class names present in implementation docs
- [x] `parse_pdfs:` parameter documented in methods docs
- [x] Commits `a8b8d86f` and `a239128b` verified in git log

## Self-Check: PASSED

## Next Phase Readiness

- Phase 30 Plan 02 can proceed — umb-scraping docs are now accurate and bilingual
- The bilingual pair pattern established here (German primary, English translation, same nav entry) applies to any future doc additions in this phase

---
*Phase: 30-content-updates*
*Completed: 2026-04-12*
