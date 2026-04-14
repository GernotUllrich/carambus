---
phase: 36A-turnierverwaltung-doc-accuracy
plan: 06
subsystem: docs
tags: [tournament-management, appendix, doc-accuracy, bilingual, mkdocs, forward-link-resolution]

requires:
  - phase: 36A-turnierverwaltung-doc-accuracy
    plan: 05
    provides: Block 7 troubleshooting section and Mehr-zur-Technik removal left the dev-docs pointer line as the file-end anchor; this plan inserts the Anhang section between the last TS recipe and that pointer
provides:
  - New top-level "Anhang: Spezialfälle und vertiefende Abläufe" (DE) / "Appendix: special cases and deeper-dive flows" (EN) section with 6 sub-sections
  - Anchor definitions: appendix-no-invitation, appendix-missing-player, appendix-nachmeldung, appendix-cc-upload, appendix-cc-csv-upload, appendix-rangliste-manual (each defined exactly once in both files)
  - Resolution of all forward-link debt accumulated by Plans 36A-01, 36A-03, 36A-04, and 36A-05
  - First-pass ClubCloud-upload and CC-CSV-upload content flagged "to be expanded in Phase 36c via PREP-04"
affects: [36A-07]

tech-stack:
  added: []
  patterns:
    - bilingual mirror discipline (DE authoritative, EN translated in same session)
    - horizontal-rule convention alignment (`---` matches surrounding file style; plan-doc `***` example converted on insertion)
    - "first-pass with forward-work pointer" disclaimer pattern (PREP-04 in Phase 36c)
    - appendix-as-alternative-flow container (keeps linear walkthrough clean; special cases live in Anhang)
    - recipe structure inside each appendix: Wann / Vorgehen (numbered list) / Hinweis pattern

key-files:
  created:
    - .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-06-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "Insertion point chosen between the last TS recipe (ts-shootout-needed) and the single-line dev-docs pointer that Plan 05 left as the file-end anchor. Structure: TS-shootout -> existing `---` separator -> new Anhang section with 6 sub-sections -> new `---` separator -> unchanged dev-docs pointer line. The pointer remains the final line of both files."
  - "Horizontal rules inserted as `---` (not `***` as shown in the plan body). The plan explicitly acknowledges this conversion in its note at lines 67-68 — the existing files use `---` everywhere, so the Anhang follows suit for internal consistency."
  - "PREP-04 deferral notes placed at the TOP of appendix-cc-upload and appendix-cc-csv-upload sub-sections (blockquote admonition style). This makes the first-pass nature visible on the first line of each sub-section, preventing readers from mistaking the current content for the complete version."
  - "All 6 appendix anchors use a single `<a id=\"...\">` definition (no second definition or duplicate headings). This keeps mkdocs strict happy and means the grep count of `id=\"appendix-*\"` is exactly 1 per file per anchor — the parity check produces a clean DE=1/EN=1 matrix."
  - "DE authoritative, EN derived: continuing the 36A pattern, Task 2 translated directly from the freshly-inserted DE Anhang. German technical terms preserved where natural (DBU-Nummer, ClubCloud, auto_upload_to_cc, Nachstoß, Shootout, Freilos)."

patterns-established:
  - "Appendix-creation plan pattern: single 'add a new major section' plan following N rewrite plans that forward-link to not-yet-existing anchors. Earlier plans (01, 03, 04, 05) can safely forward-reference anchors owned by a later plan in the same phase as long as the later plan is scheduled and contains exactly those anchor creations. Plan 36A-06 is the canonical example."
  - "First-pass with PREP deferral: when SME knowledge is partial at plan time, write the known facts in full recipe form AND flag the section with a clear 'to be expanded in Phase X via PREP-Y' callout. This lets the authoring phase ship complete forward-link resolution while deferring depth to a later phase."

requirements-completed: [DOC-ACC-04, DOC-ACC-05]

duration: 5min
completed: 2026-04-14
---

# Phase 36A Plan 06: Anhang / Appendix Section Creation Summary

**New top-level "Anhang" / "Appendix" section inserted into both tournament-management doc files with 6 sub-sections (no-invitation, missing-player, late-registration, CC-upload two paths, CC-CSV-upload detail, manual-final-ranking), resolving all forward-link debt from Plans 36A-01..05 and satisfying DOC-ACC-04 (new appendix sections) plus DOC-ACC-05 (linear walkthrough stays clean while special cases live in appendix).**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-14
- **Completed:** 2026-04-14
- **Tasks:** 2/2
- **Files modified:** 2
- **Requirements addressed:** DOC-ACC-04, DOC-ACC-05

## Accomplishments

### Anhang section inserted (DE) — Task 1

- 6 sub-sections with anchor definitions, inserted between the `ts-shootout-needed` recipe and the existing dev-docs pointer line at the end of the file
- Content structure: `<a id="appendix">` top-level H2 heading + 6 `<a id="appendix-*">` H3 sub-sections
- PREP-04 deferral note prominently placed at the top of `appendix-cc-upload` and `appendix-cc-csv-upload` in blockquote format
- Dev-docs pointer line preserved as the final line of the file
- File growth: +114 lines (no deletions)

### Appendix section mirrored (EN) — Task 2

- Exact mirror of DE structure: same 6 anchors, same ordering, same PREP-04 disclaimers
- German technical terms retained where natural (DBU, ClubCloud, auto_upload_to_cc, Nachstoß, Shootout, Freilos)
- Dev-docs pointer line preserved as the final line of the file
- File growth: +114 lines (no deletions)

## Findings Addressed

| Finding/Source | Block | Description | Where applied |
|---------|-------|-------------|---------------|
| F-36-01 (appendix list) | 36-DOC-REVIEW Block 1+ | 5 alternative-flow recipes + 1 manual-Rangliste recipe | New Anhang section (both files) |
| F-36-05 | Block 2 | "keine Einladung" alternative flow | appendix-no-invitation |
| F-36-23 | Block 6 | ClubCloud-upload two-path story | appendix-cc-upload |
| F-36-37 | Block 7 | CC-upload permission problem (Club-Sportwart gap) | appendix-cc-upload (permission-problem paragraph) |
| F-36-38 | Block 7 | CSV-upload detail + error messages | appendix-cc-csv-upload |
| F-36-34 | Block 7 | Manual final-ranking in ClubCloud | appendix-rangliste-manual |
| — (Plan-01 forward links) | 36A-01 | #appendix-no-invitation, #appendix-missing-player, #appendix-nachmeldung | All 3 resolved |
| — (Plan-03 forward links) | 36A-03 | #appendix-nachmeldung (from walkthrough Schritt 4) | Resolved |
| — (Plan-04 forward links) | 36A-04 | #appendix-rangliste-manual (from glossary entry) | Resolved |
| — (Plan-05 forward links) | 36A-05 | #appendix-cc-upload, #appendix-cc-csv-upload, #appendix-rangliste-manual (from TS recipes) | All 3 resolved |

## Task Commits

1. **Task 1: Add Anhang section to tournament-management.de.md** — `9b4c8ebe` (docs)
2. **Task 2: Mirror Anhang section to tournament-management.en.md** — `5dd6b0be` (docs)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — +114 insertions, 0 deletions; new Anhang section inserted between existing `---` separator after TS-shootout and dev-docs pointer line
- `docs/managers/tournament-management.en.md` — +114 insertions, 0 deletions; mirrored Appendix section with same placement

## Decisions Made

- **Insertion point:** After the existing `---` separator that Plan 05 left between the last TS recipe and the dev-docs pointer, the new Anhang section is inserted, followed by a new `---` separator and then the unchanged dev-docs pointer line. This preserves the Plan-05 structural promise that the dev-docs pointer remains the last line of the file.
- **Horizontal rule style:** The plan body uses `***` inside its example fenced code block but explicitly notes at lines 67-68 that the docs file convention is `---`. Both render identically in mkdocs, so the insertion used `---` for consistency with the surrounding file content. No Rule-1 deviation — the plan author anticipated the conversion.
- **PREP-04 note placement:** The deferral admonition is placed at the top of each CC-upload sub-section (not at the bottom) so readers see the first-pass status immediately on entry. This follows the mkdocs `!!! note` / blockquote admonition pattern already established in other parts of the doc.
- **Anchor uniqueness:** Each of the 6 appendix anchors is defined exactly once (via `<a id="appendix-*">` right before its H3 heading). Total occurrence counts across the file are 2-5 per anchor because earlier plans also forward-reference them — only the single `<a id=...>` counts as the definition. The parity matrix shows DE=1/EN=1 for all 6 `id="..."` definitions.

## Deviations from Plan

None — plan executed exactly as written.

**Rule-3 note (horizontal rule style):** The plan body used `***` inside its example code block but the plan itself explicitly flagged the need to convert to `---` on insertion (lines 67-68). This was anticipated, not a deviation — executed as the plan instructed.

**Total deviations:** 0
**Impact on plan:** All positive acceptance criteria for both DE and EN files pass on first verification.

## Issues Encountered

- **PreToolUse READ-BEFORE-EDIT hook:** The hook fired twice (once per Edit) with a reminder despite files having been read earlier in the session. Same as Plans 36A-01..05. Both Edits were applied successfully on the first attempt — the hook reminders are non-blocking notifications and do not reject already-read files.

## Self-Check: PASSED

**Files exist:**
- FOUND: docs/managers/tournament-management.de.md
- FOUND: docs/managers/tournament-management.en.md
- FOUND: .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-06-SUMMARY.md (this file)

**Commits exist:**
- FOUND: 9b4c8ebe (Task 1 — DE Anhang insertion)
- FOUND: 5dd6b0be (Task 2 — EN Appendix mirror)

**Acceptance criteria status (DE file):**
- grep "appendix-no-invitation" = 4 (>=2 required) PASS
- grep "appendix-missing-player" = 2 (>=2 required) PASS
- grep "appendix-nachmeldung" = 5 (>=2 required) PASS
- grep "appendix-cc-upload" = 5 (>=2 required) PASS
- grep "appendix-cc-csv-upload" = 4 (>=2 required) PASS
- grep "appendix-rangliste-manual" = 3 (>=2 required) PASS
- grep "## Anhang" = 1 (>=1 required) PASS
- grep "PREP-04" = 3 (>=2 required) PASS
- grep "Club-Sportwart" = 9 (>=3 required) PASS
- Final line = dev-docs pointer PASS

**Acceptance criteria status (EN file):**
- grep "appendix-no-invitation" = 4 (>=2 required) PASS
- grep "appendix-missing-player" = 2 (>=2 required) PASS
- grep "appendix-nachmeldung" = 5 (>=2 required) PASS
- grep "appendix-cc-upload" = 5 (>=2 required) PASS
- grep "appendix-cc-csv-upload" = 4 (>=2 required) PASS
- grep "appendix-rangliste-manual" = 3 (>=2 required) PASS
- grep "## Appendix" = 1 (>=1 required) PASS
- grep "PREP-04" = 3 (>=2 required) PASS
- grep "club sports officer" = 9 (>=3 required) PASS
- Final line = dev-docs pointer PASS

**Cross-file anchor definition parity:**
- appendix-no-invitation: DE=1 EN=1 PASS
- appendix-missing-player: DE=1 EN=1 PASS
- appendix-nachmeldung: DE=1 EN=1 PASS
- appendix-cc-upload: DE=1 EN=1 PASS
- appendix-cc-csv-upload: DE=1 EN=1 PASS
- appendix-rangliste-manual: DE=1 EN=1 PASS

## Known Stubs

None — all 6 appendices contain complete, actionable content. The CC-upload and CC-CSV sub-sections are explicitly flagged as "first-pass to be expanded in Phase 36c via PREP-04" but are not stubs: each contains a complete who/when/where/how recipe with a non-trivial error-message catalogue.

## Next Plan Readiness

- **Plan 36A-07 (final pass / i18n / reflow):** Ready. All forward-link debt from Plans 01-06 is now resolved — mkdocs strict broken-anchor warnings for `#appendix-*` should drop to zero when the build is re-run. Plan 07 can perform its final-pass verification pass against clean forward-link state.
- **Phase 36c PREP-04 (future):** The CC-upload and CC-CSV sub-sections in this plan will be expanded with CC admin screenshots, exact menu paths, and full error-message catalogue. The existing content provides the skeleton; PREP-04 will fill it in without restructuring. The `<a id="appendix-cc-upload">` and `<a id="appendix-cc-csv-upload">` anchors are stable targets that PREP-04 can build on.

---
*Phase: 36A-turnierverwaltung-doc-accuracy*
*Plan: 06 (Anhang / Appendix section creation)*
*Completed: 2026-04-14*
