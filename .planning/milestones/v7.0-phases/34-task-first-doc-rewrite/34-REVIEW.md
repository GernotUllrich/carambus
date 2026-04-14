---
phase: 34-task-first-doc-rewrite
reviewed: 2026-04-13T00:00:00Z
depth: quick
files_reviewed: 4
files_reviewed_list:
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
  - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md
summary:
  critical: 0
  warning: 18
  info: 3
  total: 21
status: issues_found
---

# Phase 34: Code Review Report

**Reviewed:** 2026-04-13
**Depth:** quick
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed four end-user mkdocs files for the task-first doc rewrite. The two task-oriented files (`tournament-management.de.md` / `tournament-management.en.md`) are internally clean: all internal anchors resolve, admonition syntax is valid mkdocs-material, heading hierarchy is consistent, and DE/EN parity is structurally matched (both have 14 step sections, identical anchor set, 4 callout boxes referencing the same F-codes).

The two `index.*.md` files carry over numerous hash-anchor deep links into `tournament-management.md` that do NOT exist as anchors in the target file. These are dead fragment links — the page will still load, but browsers will not scroll to the expected section and the implied section does not exist on the walkthrough page at all. This is the dominant finding of the review.

Image assets referenced (`images/tournament-wizard-overview.png`, `images/tournament-wizard-mode-selection.png`, `images/tournament-monitor-landing.png`) were not verified on disk — out of scope for quick depth.

## Warnings

### WR-01: Broken anchor `#player-management` in index.de.md

**File:** `docs/managers/index.de.md:64`
**Issue:** Link `tournament-management.md#spielerverwaltung` points to an anchor that does not exist in `tournament-management.de.md`. The walkthrough file has no "Spielerverwaltung" section at all.
**Fix:** Either remove the deep link (`→ [Turnierverwaltung](tournament-management.md)`) or add the target section to `tournament-management.de.md` as part of the task-first rewrite scope.

### WR-02: Broken anchor `#player-management` in index.en.md

**File:** `docs/managers/index.en.md:64`
**Issue:** Link `tournament-management.md#player-management` points to an anchor that does not exist in `tournament-management.en.md`.
**Fix:** Same as WR-01 — remove the fragment or add the section.

### WR-03: Broken anchor `#ergebniskontrolle` in index.de.md

**File:** `docs/managers/index.de.md:75`
**Issue:** Link `tournament-management.md#ergebniskontrolle` references a non-existent anchor. The walkthrough has no result-control section; the closest real anchor is `#step-12-monitor`.
**Fix:** Retarget to `#step-12-monitor` or remove the fragment.

### WR-04: Broken anchor `#result-control` in index.en.md

**File:** `docs/managers/index.en.md:75`
**Issue:** Link `tournament-management.md#result-control` references a non-existent anchor.
**Fix:** Retarget to `#step-12-monitor` or remove the fragment.

### WR-05: Broken anchor `#round-robin` in index.de.md

**File:** `docs/managers/index.de.md:133`
**Issue:** `tournament-management.md#round-robin` does not exist. The walkthrough does not contain format-specific sub-sections.
**Fix:** Remove the fragment so the link becomes `tournament-management.md`, or add a format explainer section in the walkthrough.

### WR-06: Broken anchor `#round-robin` in index.en.md

**File:** `docs/managers/index.en.md:133`
**Issue:** `tournament-management.md#round-robin` does not exist in the EN walkthrough.
**Fix:** Same as WR-05.

### WR-07: Broken anchor `#ko-system` in index.de.md

**File:** `docs/managers/index.de.md:153`
**Issue:** `tournament-management.md#ko-system` does not exist in the DE walkthrough.
**Fix:** Remove the fragment or add the section.

### WR-08: Broken anchor `#knockout-system` in index.en.md

**File:** `docs/managers/index.en.md:153`
**Issue:** `tournament-management.md#knockout-system` does not exist in the EN walkthrough.
**Fix:** Remove the fragment or add the section.

### WR-09: Broken anchor `#schweizer-system` in index.de.md

**File:** `docs/managers/index.de.md:169`
**Issue:** `tournament-management.md#schweizer-system` does not exist.
**Fix:** Remove the fragment or add the section.

### WR-10: Broken anchor `#swiss-system` in index.en.md

**File:** `docs/managers/index.en.md:169`
**Issue:** `tournament-management.md#swiss-system` does not exist.
**Fix:** Remove the fragment or add the section.

### WR-11: Broken anchor `#gruppenphasen` in index.de.md

**File:** `docs/managers/index.de.md:185`
**Issue:** `tournament-management.md#gruppenphasen` does not exist.
**Fix:** Remove the fragment or add the section.

### WR-12: Broken anchor `#group-phases` in index.en.md

**File:** `docs/managers/index.en.md:185`
**Issue:** `tournament-management.md#group-phases` does not exist.
**Fix:** Remove the fragment or add the section.

### WR-13: Broken anchor `#spielplan-erstellen` in index.de.md

**File:** `docs/managers/index.de.md:204`
**Issue:** `tournament-management.md#spielplan-erstellen` does not exist. The walkthrough treats schedule creation implicitly through the wizard steps, not as a standalone section.
**Fix:** Retarget to `#walkthrough` or remove the fragment.

### WR-14: Broken anchor `#create-schedule` in index.en.md

**File:** `docs/managers/index.en.md:204`
**Issue:** `tournament-management.md#create-schedule` does not exist.
**Fix:** Retarget to `#walkthrough` or remove the fragment.

### WR-15: Broken anchor `#live-monitoring` in index.de.md and index.en.md

**File:** `docs/managers/index.de.md:220`, `docs/managers/index.en.md:220`
**Issue:** `tournament-management.md#live-monitoring` does not exist in either language. The closest real anchors are `#step-10-warmup` or `#step-12-monitor`.
**Fix:** Retarget to `#step-12-monitor` or remove the fragment.

### WR-16: Broken anchor `#ergebnisse-korrigieren` / `#correct-results`

**File:** `docs/managers/index.de.md:239`, `docs/managers/index.en.md:239`
**Issue:** Neither `#ergebnisse-korrigieren` nor `#correct-results` exist in the walkthrough file.
**Fix:** Remove the fragment or add the section.

### WR-17: Broken anchor `#statistiken-reports` / `#statistics-reports`

**File:** `docs/managers/index.de.md:255`, `docs/managers/index.en.md:255`
**Issue:** Neither `#statistiken-reports` nor `#statistics-reports` exist in the walkthrough file. The walkthrough has no statistics/reports section at all.
**Fix:** Remove the fragment, point to an existing section, or create the section.

### WR-18: Unverified sibling-file links in both index files

**File:** `docs/managers/index.de.md:53,85,95,105,115,397-401,423-429`, `docs/managers/index.en.md` (same lines)
**Issue:** Both index files link to sibling pages (`league-management.md`, `admin-roles.md`, `search-filters.md`, `table-reservation.md`, `single-tournament.md`, `clubcloud-integration.md`) and to `../reference/glossary.md`. These files were not part of the review scope and their existence was not verified. If any are missing, every link breaks.
**Fix:** Verify all sibling pages exist in `docs/managers/` (and glossary in `docs/reference/`). This is a pre-merge sanity check the orchestrator or a mkdocs-strict build should cover.

## Info

### IN-01: EN walkthrough has two extra inline "Note:" paragraphs not in DE

**File:** `docs/managers/tournament-management.en.md:129`, `docs/managers/tournament-management.en.md:143`
**Issue:** The EN version includes two extra inline notes (untranslated "Turnierphase: playing group" label note and "no success flash after Spielbeginn click" note) that have no counterpart in the DE version. These appear deliberate — they document known UI quirks observed during the Phase 33 audit — but the DE version should either include equivalents or both versions should be aligned.
**Fix:** Either add equivalent German notes after lines 129 and 143 in `tournament-management.de.md`, or drop the two EN notes for strict parity. Recommend adding to DE since the information is useful to DE readers too.

### IN-02: Glossary entry self-links to its own anchor

**File:** `docs/managers/tournament-management.de.md:182`, `docs/managers/tournament-management.en.md:184`
**Issue:** The "Dreiband" / "Three-Cushion" glossary entry links `[Karambol](#glossary-karambol)` back to the section heading that contains it. This is a harmless circular link but likely unintended — the author probably meant to cross-reference a different term.
**Fix:** Replace with a concrete cross-link (e.g., to another glossary entry) or remove the hyperlink and leave the word as plain text.

### IN-03: Trailing blank lines at EOF in index files

**File:** `docs/managers/index.de.md:437-443`, `docs/managers/index.en.md:437-443`
**Issue:** Both index files end with 6-7 trailing blank lines after the final italic tip paragraph. Harmless but noisy.
**Fix:** Trim trailing blank lines to one newline.

---

_Reviewed: 2026-04-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_
