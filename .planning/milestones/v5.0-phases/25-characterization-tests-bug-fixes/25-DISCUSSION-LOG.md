# Phase 25: Characterization Tests & Bug Fixes - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 25-Characterization Tests & Bug Fixes
**Areas discussed:** Test organization, VCR cassette strategy, Bug fix ordering, SSL fix scope

---

## Test Organization

| Option | Description | Selected |
|--------|-------------|----------|
| One file per scraper | umb_scraper_test.rb + umb_scraper_v2_test.rb | |
| Split by concern | Separate files per concern (future, archive, detail) | |
| You decide | Claude picks based on method count and complexity | ✓ |

**User's choice:** You decide
**Notes:** None

---

## VCR Cassette Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Live recording | Record against live UMB site | |
| Fixture HTML files | Craft fixture HTML matching UMB structure | |
| Hybrid | Live where possible, fixture HTML for broken endpoints | ✓ |

**User's choice:** Hybrid
**Notes:** UMB site returned HTTP 500 on /Reports/ during Phase 24; live recording won't work for those

---

## Bug Fix Ordering

| Option | Description | Selected |
|--------|-------------|----------|
| Bugs first | Fix all 3 bugs before writing tests | |
| Tests first | Characterize current (broken) behavior, then fix | |
| Interleave | Write tests, fix bugs as they block test setup | ✓ |

**User's choice:** Interleave
**Notes:** Natural flow — don't force a rigid order

---

## SSL Fix Scope

| Option | Description | Selected |
|--------|-------------|----------|
| All scrapers | Normalize across all scrapers | |
| UMB only | Only fix UMB scrapers | |
| Shared helper | Extract Umb::HttpClient early from Phase 26 plan | ✓ |

**User's choice:** Shared helper
**Notes:** Pull Umb::HttpClient forward from Phase 26; other scrapers adopt later in their own phases

---

## Claude's Discretion

- Test file naming and organization
- Which methods are "critical paths" worth characterizing
- VCR strategy per endpoint
- Interleaving order of tests and bug fixes
