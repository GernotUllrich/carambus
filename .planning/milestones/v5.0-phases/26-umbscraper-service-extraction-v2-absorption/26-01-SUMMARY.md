---
phase: 26-umbscraper-service-extraction-v2-absorption
plan: "01"
subsystem: umb-scraper
tags: [extraction, services, pdf, player-resolution, date-parsing, discipline-detection]
dependency_graph:
  requires: []
  provides:
    - Umb::HttpClient#fetch_pdf_text
    - Umb::DisciplineDetector.detect
    - Umb::DateHelpers module
    - Umb::PlayerResolver#resolve
  affects:
    - app/services/umb/http_client.rb
tech_stack:
  added: []
  patterns:
    - PORO class method for stateless algorithm (DisciplineDetector)
    - module_function for shared utility module (DateHelpers)
    - Instance service with DB side-effects (PlayerResolver)
key_files:
  created:
    - app/services/umb/discipline_detector.rb
    - app/services/umb/date_helpers.rb
    - app/services/umb/player_resolver.rb
    - test/services/umb/discipline_detector_test.rb
    - test/services/umb/date_helpers_test.rb
    - test/services/umb/player_resolver_test.rb
  modified:
    - app/services/umb/http_client.rb
    - test/services/umb/http_client_test.rb
decisions:
  - "cross-month date ranges (day-first format) required Pattern B in parse_month_day_range"
  - "PDF::Reader stubbed via Minitest::Mock in tests — no real PDF fixture needed"
  - "DisciplineDetector adds %dreiband% broad fallback to cover plain 'Dreiband' fixture records"
  - "parse_month_day_range runs before parse_day_range_with_month to avoid ambiguous regex match on cross-month strings"
metrics:
  duration_minutes: 35
  completed_date: "2026-04-12"
  tasks_completed: 2
  files_created: 6
  files_modified: 2
  test_runs: 100
  test_assertions: 180
  test_failures: 0
---

# Phase 26 Plan 01: Foundation Services (HttpClient + DisciplineDetector + DateHelpers + PlayerResolver) Summary

**One-liner:** Extracted four leaf-node foundation services from UmbScraper V1/V2 with TDD — PDF download, discipline DB lookup, date parsing, and caps+mixed player resolution.

## What Was Built

Four independently testable service files extracted from the 2133-line `UmbScraper` (V1) and 585-line `UmbScraperV2`, establishing the foundation layer that all higher-level scrapers (FutureScraper, ArchiveScraper, PdfParser) will depend on.

### Umb::HttpClient#fetch_pdf_text (added to existing class)

New instance method that downloads a PDF URL via the existing `fetch_url` transport and extracts text using `PDF::Reader`. Returns nil on HTTP errors, blank responses, or malformed PDF content (T-26-02 mitigation). Replaces per-scraper `download_pdf` methods in V1 and V2.

### Umb::DisciplineDetector (new PORO)

Class method `detect(tournament_name)` consolidates two duplicate discipline methods from V1:
- `find_discipline_from_name` (line 1211) — detailed ILIKE DB lookup with discipline-specific fallback chains
- `determine_discipline_from_name` (line 1468) — simple string-to-name map as secondary fallback

Strategy: DB lookup first (more accurate), string map second (broader coverage), nil if neither matches. No hardcoded default discipline.

### Umb::DateHelpers (new module)

`module_function` module extracting all date parsing from V1:
- `parse_date_range` — dispatcher with cross-month-first ordering fix
- `parse_single_date` — single date via `Date.parse`
- `parse_day_range_with_month` — same-month ranges ("18-21 Dec 2025", "December 18-21, 2025")
- `parse_month_day_range` — cross-month ranges, both "Feb 26 - Mar 1, 2026" (month-first) and "28 January - 2 February 2025" (day-first)
- `parse_date` — specific UMB formats (dd-Month-yyyy, ISO, European)
- `enhance_date_with_context` — adds month/year context to bare day ranges
- `parse_month_name` — month name to number (1-12) with abbreviations

Dead code `parse_full_month_range` (always returned nil) not extracted.

### Umb::PlayerResolver (new service)

Instance service consolidating V1 `find_or_create_international_player` and V2's superior `find_player_by_caps_and_mixed` strategy:

1. Lookup by `umb_player_id` (fastest)
2. Lookup by caps+mixed name — tries Western order (caps=lastname), Asian order (caps=firstname), then full-name partial match
3. Create new `Player` with `international_player: true` if not found

Public method `find_by_caps_and_mixed` also available for direct use by scrapers.

## Test Results

```
100 runs, 180 assertions, 0 failures, 0 errors, 0 skips
```

- `test/services/umb/http_client_test.rb`: 13 tests (8 existing fetch_url + 5 new fetch_pdf_text)
- `test/services/umb/discipline_detector_test.rb`: 5 tests
- `test/services/umb/date_helpers_test.rb`: 22 tests
- `test/services/umb/player_resolver_test.rb`: 10 tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Cross-month day-first date ranges not parsed**
- **Found during:** Task 1 GREEN phase
- **Issue:** `parse_month_day_range` only handled month-first format ("Feb 26 - Mar 1, 2026"). Day-first format ("28 January - 2 February 2025") returned nil because regex expected letter-first.
- **Fix:** Added Pattern B to `parse_month_day_range` matching `(\d{1,2})\s+([A-Za-z]+)\s*-\s*(\d{1,2})\s+([A-Za-z]+)[\s,]*(\d{4})`.
- **Files modified:** `app/services/umb/date_helpers.rb`
- **Commit:** c0272b2d

**2. [Rule 1 - Bug] parse_month_day_range never reached for cross-month strings**
- **Found during:** Task 1 GREEN phase (second iteration)
- **Issue:** `parse_day_range_with_month` was called first and partially matched "28 January - 2 February 2025" (treating "January - 2" as "day_range - month"), producing wrong result.
- **Fix:** Swapped order in `parse_date_range` dispatcher — `parse_month_day_range` runs first (more specific), then `parse_day_range_with_month`.
- **Files modified:** `app/services/umb/date_helpers.rb`
- **Commit:** c0272b2d

**3. [Rule 1 - Bug] DisciplineDetector returned nil for plain "Dreiband" fixture**
- **Found during:** Task 1 GREEN phase
- **Issue:** The 3-Cushion detection chain only queried `%dreiband%groß%`, `%dreiband%gross%`, etc. Test fixtures have `name: "Dreiband"` (plain, no qualifier) which none of those ILIKE patterns matched.
- **Fix:** Added `%dreiband%` as a broad fallback before the "Karambol" ultimate fallback.
- **Files modified:** `app/services/umb/discipline_detector.rb`
- **Commit:** c0272b2d

**4. [Rule 2 - Missing critical functionality] PDF::Reader stub for test isolation**
- **Found during:** Task 1 test writing
- **Issue:** The plan called for "WebMock stubs + minimal PDF fixture" but constructing a valid PDF binary in-memory with correct xref byte offsets is fragile and format-sensitive.
- **Fix:** Used `Minitest::Mock` to stub `PDF::Reader.new` instead of constructing a real binary. The malformed-PDF test uses a real non-PDF string which triggers the actual PDF::Reader error path.
- **Files modified:** `test/services/umb/http_client_test.rb`
- **Commit:** c0272b2d

## Known Stubs

None — all methods are fully implemented with real DB queries and real PDF::Reader integration.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced. The `fetch_pdf_text` outbound HTTP path was already covered by T-26-01/T-26-02 in the plan's threat model; T-26-02 mitigation (StandardError rescue) is implemented.

## Self-Check

Checking created files exist:

- FOUND: app/services/umb/http_client.rb
- FOUND: app/services/umb/discipline_detector.rb
- FOUND: app/services/umb/date_helpers.rb
- FOUND: app/services/umb/player_resolver.rb
- FOUND: commit c0272b2d
- FOUND: commit 86386490

## Self-Check: PASSED
