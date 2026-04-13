# Phase 32: Nav, i18n & Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 32-nav-i18n-verification
**Areas discussed:** Bilingual gap resolution, Nav registration, Strict build target, Final verification pass

---

## Bilingual Gap Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Translate all gaps | Full translations for all 17 gaps, no stubs | ✓ |
| Translate important, stub rest | Full for key docs, stubs for thin content | |
| Selective (SC-2 only) | Only audit.json findings | |

**User's choice:** Translate all gaps

---

## Nav Registration for services/

| Option | Description | Selected |
|--------|-------------|----------|
| New Services subsection under Developers | Services: block after UMB Scraping, with nav_translations | ✓ |
| Flat entries in Developers | Top-level entries without subsection | |
| You decide | Claude's discretion | |

**User's choice:** New Services subsection under Developers

---

## Strict Build Zero-Warning Target

| Option | Description | Selected |
|--------|-------------|----------|
| Fix all warnings | All 29 regardless of origin — clean baseline | ✓ |
| Fix only Phase 28-31 related | Only v6.0 milestone warnings | |
| Fix nav + missing file only | Only SC-3 categories | |

**User's choice:** Fix all warnings

---

## Final Verification Pass

| Option | Description | Selected |
|--------|-------------|----------|
| Full sweep | All 4 scripts must report zero: links, translations, coderefs, strict build | ✓ |
| Incremental only | Only verify Phase 32 changes | |
| You decide | Claude's discretion | |

**User's choice:** Full sweep

---

## Claude's Discretion

- Operation ordering
- Orphan page handling strategy
- nav_translations DE label phrasing
- Whether to reorganize existing nav

## Deferred Ideas

None
