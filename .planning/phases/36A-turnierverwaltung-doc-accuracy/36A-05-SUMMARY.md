---
phase: 36A-turnierverwaltung-doc-accuracy
plan: 05
subsystem: docs
tags: [tournament-management, troubleshooting, doc-accuracy, bilingual, mkdocs, block-7]

requires:
  - phase: 36A-turnierverwaltung-doc-accuracy
    plan: 04
    provides: Block 6 glossary rewrite (Trainingsmodus entry established; TS-4 fallback pointer target exists)
provides:
  - TS-1 (PDF upload) honest framing — ClubCloud positioned as equal backup, not "more reliable"
  - TS-2 (Players missing from CC) rewritten as three realistic triggers (early sync / Nachmeldung / never registered)
  - TS-3 (Wrong mode) — fictional "Modus ändern" / "Change mode" button removed; points to Reset link with running-tournament warning
  - TS-4 (Tournament already started) — DB-Admin recovery myth removed; honest fallback to Trainingsmodus + paper protocol
  - 6 new troubleshooting recipes (Endrangliste fehlt, CSV-Upload, Spieler-Rückzug, English labels, Nachstoß vergessen, Shootout)
  - "Mehr zur Technik" / "More on the architecture" section completely removed (architectural monologue); single-line dev-docs pointer retained
affects: [36A-06, 36A-07]

tech-stack:
  added: []
  patterns:
    - bilingual mirror discipline (DE authoritative, EN translated)
    - admonition-callout pattern (`!!! warning`) for reset danger in TS-3
    - numbered emergency-fix list pattern in TS-4 (UNDO / Reset / Traditional method)
    - per-edit grep verification with positive-and-negative acceptance gates
    - forward-link cross-referencing appendix anchors (#appendix-no-invitation, #appendix-nachmeldung, #appendix-rangliste-manual, #appendix-cc-csv-upload) that Plan 06 owns

key-files:
  created:
    - .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-05-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "TS-3 new text uses paraphrase 'Ein separater Button zum nachträglichen Wechseln des Turniermodus' (DE) / 'A separate button that would switch the tournament mode afterwards' (EN) — deliberately avoids the literal 'Modus ändern' / 'Change mode' strings so the negative grep gates pass without stranding reader context. plan-checker iteration 1 flagged this requirement."
  - "TS-4 keeps a forward-pointing line about future safety dialogs ('Sicherheitsabfrage vor dem Reset ... Parameter-Verifikationsdialog vor dem Start') as v7.1+ follow-up features — makes the honest-but-grim recovery story actionable by framing the workarounds as temporary until the UI catches up."
  - "Mehr zur Technik removal: replaced entire two-paragraph section with a single-line italic pointer (*Für weiterführende technische Details siehe die [Entwickler-Dokumentation]*). The section title is gone (negative grep 0) but readers still have one click to the developer docs if they need architecture. Honors the volunteer-persona filter while not pretending the dev docs don't exist."
  - "DE authoritative, EN derived: continuing the 36A pattern, Task 2 translated from the freshly-updated DE file rather than independently rewriting from the review notes. German technical terms (Nachstoß, Shootout, Freilos, Trainingsmodus) kept as-is in EN where appropriate."

patterns-established:
  - "Troubleshooting-block rewrite pattern: 4 existing recipes rewritten + 6 new recipes appended + 1 section deleted in a single task per language, all verified by positive+negative grep gates. Same pattern will apply to other manager doc troubleshooting sections."

requirements-completed: [DOC-ACC-02, DOC-ACC-04, DOC-ACC-06]

duration: 8min
completed: 2026-04-14
---

# Phase 36A Plan 05: Block 7 Troubleshooting + Mehr-zur-Technik Removal Summary

**Tournament-management Problembehebung/Troubleshooting section rewritten: 4 existing recipes rewritten (PDF upload honest framing, Players-missing three-trigger story, Wrong-mode fictional button removed, Tournament-already-started DB-Admin recovery myth removed), 6 new recipes added (Endrangliste, CSV-Upload, Spieler-Rückzug, English labels, Nachstoß, Shootout), and the architectural monologue "Mehr zur Technik" / "More on the architecture" section completely removed in favour of a one-line developer-docs pointer.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-14
- **Completed:** 2026-04-14
- **Tasks:** 2/2
- **Files modified:** 2
- **Findings addressed:** F-36-51..F-36-58 (8 findings from Block 7, excluding F-36-55 which is deferred to 36B and F-36-56 which was already handled in Plan 04)

## Accomplishments

### Troubleshooting section rewrites (DE + EN)

- **F-36-51:** TS-1 ("Einladungs-PDF konnte nicht hochgeladen werden" / "Invitation upload failed") — removed unfair PDF-bashing. Before: "ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger als der PDF-Upload" (implies PDF is unreliable). After: honest framing — PDF parser works reliably when the standard template is reused; ClubCloud is an equivalent backup for template deviations. Forward-links to the Plan-06 `#appendix-no-invitation` appendix.
- **F-36-52:** TS-2 ("Spieler nicht in der ClubCloud-Meldeliste" / "Player not in ClubCloud") — re-framed from "sync sometimes delivers incomplete results" (F-03/F-04 bug story) to three realistic triggers: (1) sync ran before close-of-registration, (2) player registered late on tournament day, (3) player was never registered. Fix path differentiates between "real player missing" (add by DBU) and "CC data incomplete" (ask club sports officer).
- **F-36-53:** TS-3 ("Falscher Turniermodus gewählt" / "Wrong mode selected") — removed fictional "Modus ändern" / "Change mode" button that the original text promised. New text points to the real "Zurücksetzen des Turnier-Monitors" / "Reset tournament monitor" link and documents (via paraphrase, not literal string) that no separate mode-switching button exists. Added `!!! warning` admonition block about reset danger when tournament is already running, linking to TS-4 for alternatives.
- **F-36-54:** TS-4 ("Turnier wurde bereits gestartet" / "Tournament already started") — removed the DB-Admin recovery myth ("Wenden Sie sich an einen Carambus-Admin mit Datenbankzugang"). New text honestly states: no technical recovery path exists (not even for a developer), and documents a three-option emergency fix (UNDO individual matches / Reset whole tournament / Traditional method: paper protocol + ClubCloud + Trainingsmodus scoreboard). Cross-references the Trainingsmodus glossary entry established in Plan 04.

### 6 new troubleshooting recipes (DE + EN) — F-36-58

- **ts-endrangliste-missing** — Final ranking not auto-calculated by Carambus; manual ClubCloud workflow via `#appendix-rangliste-manual` (Plan-06 owned).
- **ts-csv-upload** — CSV upload requires ClubCloud participant list finalised; CC-API finalisation not implemented in Carambus. Forward-links `#appendix-cc-csv-upload` (Plan-06 owned).
- **ts-player-withdraws** — No clean mid-tournament withdrawal support; workaround uses Freilos concept from Plan-04 glossary.
- **ts-english-labels** — Missing i18n entries in start form; provides a translation table (3 labels documented) as bridge until i18n fix ships.
- **ts-nachstoss-forgotten** — Nachstoß correction before-confirm works, after-confirm has no clean path; manual correction + ClubCloud + staff briefing.
- **ts-shootout-needed** — Shootout not supported at all; do it outside Carambus, enter result manually in ClubCloud.

### "Mehr zur Technik" / "More on the architecture" removal (DE + EN) — F-36-57

- Entire `<a id="architecture"></a>` section (two paragraphs about LocalProtector, distributed API/local-server split, CableReady) deleted.
- Replaced with a single-line italic pointer: `*Für weiterführende technische Details siehe die [Entwickler-Dokumentation](../developers/index.md).*` (DE) and `*For further technical details, see the [developer documentation](../developers/index.md).*` (EN).
- The `architecture` anchor itself is also removed from both files — no internal link in the walkthrough references it (verified via grep), so no dangling anchor links result from the removal.

## Findings Addressed

| Finding | Tier | Block | Description | Where applied |
|---------|------|-------|-------------|---------------|
| F-36-51 | A | 7 | TS-1 PDF-bashing ("ClubCloud zuverlässiger") | Troubleshooting — TS-1 rewrite DE+EN |
| F-36-52 | A | 7 | TS-2 re-framing (3 realistic triggers, not F-03/F-04 bug story) | Troubleshooting — TS-2 rewrite DE+EN |
| F-36-53 | A | 7 | TS-3 fictional "Modus ändern" / "Change mode" button + reset warning | Troubleshooting — TS-3 rewrite DE+EN |
| F-36-54 | A | 7 | TS-4 DB-Admin recovery myth + honest Trainingsmodus fallback | Troubleshooting — TS-4 rewrite DE+EN |
| F-36-55 | C | 7 | NEW recipe stubs | **Deferred to 36B** (not in this plan's scope per plan context) |
| F-36-56 | C | 7 | Trainingsmodus glossary entry | **Already handled in Plan 04** (verified — no duplication) |
| F-36-57 | B | 7 | "Mehr zur Technik" section removal | Architecture section — removed DE+EN |
| F-36-58 | A | 7 | 6 new troubleshooting recipes | Troubleshooting — 6 recipes appended DE+EN |

## Task Commits

1. **Task 1: Rewrite Problembehebung + remove Mehr-zur-Technik in DE file** — `0fff0384` (docs)
2. **Task 2: Mirror Block 7 changes to tournament-management.en.md** — `e52d616e` (docs)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — 95 insertions, 19 deletions; Problembehebung section (lines 337-446) rewritten with 4 updated TS recipes + 6 new TS recipes; architecture section (formerly lines 378-383) deleted and replaced with a single italic pointer line
- `docs/managers/tournament-management.en.md` — 94 insertions, 19 deletions; mirror of DE edits with idiomatic English translations; German technical terms (Nachstoß, Shootout, Freilos, Trainingsmodus) preserved where natural

## Decisions Made

- **TS-3 paraphrase technique for literal-string avoidance:** The plan-checker iteration 1 flagged that the negative grep gates (`! grep -F "Modus ändern"`, `! grep -F "Change mode"`) must pass, but the recipe still needs to explain that no such button exists. Solution: paraphrase the absent feature ("Ein separater Button zum nachträglichen Wechseln des Turniermodus" / "A separate button that would switch the tournament mode afterwards") rather than quote the literal absent button name. Reader context preserved; grep gates pass; doc is no longer making a fictional UI promise.
- **TS-4 forward-looking sentence retained:** The original plan text includes a forward-looking sentence about planned safety dialogs ("Eine Sicherheitsabfrage vor dem Reset bei laufendem Turnier sowie ein Parameter-Verifikationsdialog vor dem Start sind als Folge-Features für eine spätere Phase eingeplant"). Kept verbatim because it frames the current emergency-fix options as temporary-pending-UI-improvements — honest but not fatalistic. Same pattern in EN: "A safety dialog before reset while a tournament is running, and a parameter verification dialog before start, are planned as follow-up features for a later phase".
- **Architecture section: one-line pointer instead of full removal:** The plan offered two options — delete entirely or leave a minimal pointer. Chose pointer because the walkthrough-as-primary-doc stance doesn't require pretending dev docs don't exist; a volunteer user who accidentally wants architecture gets one click to the right place without breaking the narrative flow of the manager doc. The section heading, anchor, and architectural monologue are all gone; only a single italic pointer line remains.
- **Six new recipes appended after TS-4, before architecture-removal line:** Chronological-by-failure-mode ordering rather than severity-ordered. TS-4 is the last of the "existing 4" recipes, so the 6 new ones come immediately after it in a natural block, followed by the `---` separator and the one-line pointer. Ordering within the 6 follows the plan's ordering (Endrangliste, CSV-Upload, Withdraws, English labels, Nachstoß, Shootout).
- **DE authoritative, EN derived:** Continuing the 36A pattern, Task 2 translated from the freshly-updated DE file rather than independently rewriting from the review notes. German technical terms (Nachstoß, Shootout, Freilos, Trainingsmodus) kept in EN where appropriate (Nachstoß remains in EN because it is a discipline-specific carom rule with no English equivalent).

## Deviations from Plan

None — plan executed exactly as written after the plan-checker iteration 1 paraphrase fix was already folded into the plan before execution.

**Total deviations:** 0
**Impact on plan:** All positive and negative acceptance criteria for both DE and EN files pass on first verification.

## Issues Encountered

- **PreToolUse READ-BEFORE-EDIT hook:** The hook fires on every Edit attempt regardless of recent reads, same as in Plans 36A-01..04. Each Edit was still applied successfully on first attempt — the hook reminders are non-blocking notifications; continuing to work around them by acknowledging and moving forward.

## Self-Check: PASSED

**Files exist:**
- FOUND: docs/managers/tournament-management.de.md
- FOUND: docs/managers/tournament-management.en.md
- FOUND: .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-05-SUMMARY.md (this file)

**Commits exist:**
- FOUND: 0fff0384 (Task 1 — DE troubleshooting + Mehr-zur-Technik removal)
- FOUND: e52d616e (Task 2 — EN mirror)

**Acceptance criteria status (DE file):**
- grep "ts-endrangliste-missing" = 1 (≥1 required) PASS
- grep "ts-csv-upload" = 1 (≥1 required) PASS
- grep "ts-shootout-needed" = 1 (≥1 required) PASS
- grep "ts-player-withdraws" = 1 (≥1 required) PASS
- grep "ts-english-labels" = 1 (≥1 required) PASS
- grep "ts-nachstoss-forgotten" = 1 (≥1 required) PASS
- grep -F "Mehr zur Technik" = 0 (must be 0) PASS
- grep -F "## Mehr zur Technik" = 0 (must be 0) PASS
- grep -F "Modus ändern" = 0 (must be 0) PASS
- grep -F "Carambus-Admin mit Datenbankzugang" = 0 (must be 0) PASS
- grep -F "ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger" = 0 (must be 0) PASS
- grep "Trainingsmodus" in TS-4 = match at line 391 (≥1 in TS-4 region) PASS
- grep "appendix-rangliste-manual" = 2 (≥2 required — 1 in Plan-04 Teilnehmerliste + 1 in new TS-endrangliste) PASS

**Acceptance criteria status (EN file):**
- grep "ts-endrangliste-missing" = 1 (≥1 required) PASS
- grep "ts-csv-upload" = 1 (≥1 required) PASS
- grep "ts-shootout-needed" = 1 (≥1 required) PASS
- grep "ts-player-withdraws" = 1 (≥1 required) PASS
- grep "ts-english-labels" = 1 (≥1 required) PASS
- grep "ts-nachstoss-forgotten" = 1 (≥1 required) PASS
- grep -F "## More on the architecture" = 0 (must be 0) PASS
- grep -F "Change mode" = 0 (must be 0) PASS
- grep -F "Carambus admin with database access" = 0 (must be 0) PASS
- grep -F "ClubCloud route is more reliable in practice" = 0 (must be 0) PASS
- grep "training mode" in EN TS-4 = match at line 393 (≥1 required) PASS

**Cross-file anchor parity (structural):**
- ts-invitation-upload: DE=1 EN=1 PASS
- ts-player-not-in-cc: DE=1 EN=1 PASS
- ts-wrong-mode: DE=1 EN=1 PASS
- ts-already-started: DE=1 EN=1 PASS
- ts-endrangliste-missing: DE=1 EN=1 PASS
- ts-csv-upload: DE=1 EN=1 PASS
- ts-player-withdraws: DE=1 EN=1 PASS
- ts-english-labels: DE=1 EN=1 PASS
- ts-nachstoss-forgotten: DE=1 EN=1 PASS
- ts-shootout-needed: DE=1 EN=1 PASS

## Next Plan Readiness

- **Plan 36A-06 (Appendix creation):** Ready and now has additional forward-link debt to resolve. The new TS recipes in Plan 05 reference `#appendix-no-invitation`, `#appendix-nachmeldung`, `#appendix-rangliste-manual`, and `#appendix-cc-csv-upload` — all four are Plan-06-owned targets. `appendix-rangliste-manual` is referenced twice now (once in Plan-04 Teilnehmerliste glossary entry, once in TS-endrangliste) which reinforces Plan 06's mandate to actually create that anchor. mkdocs strict will continue to emit broken-link warnings for these anchors until Plan 06 closes them — acceptable mid-wave state.
- **Plan 36A-07 (i18n/reflow):** The ts-english-labels recipe (new in this plan) documents 3 specific English labels (Tournament manager checks results before acceptance / Assign games as tables become available / auto_upload_to_cc) that are candidates for i18n fixes in Plan 07 if that plan scopes to i18n corrections. If Plan 07 does ship i18n fixes, this TS recipe may need to be updated or removed — note for Plan 07 planner.
- **Phase 36B carryover:** F-36-55 (NEW recipe stubs for additional failure modes beyond the 6 added here) was explicitly deferred to 36B per the plan context. The 6 recipes added in this plan are the minimum honesty-restoration set; 36B can extend further if more edge cases surface.

---
*Phase: 36A-turnierverwaltung-doc-accuracy*
*Plan: 05 (Block 7 Troubleshooting + Mehr-zur-Technik Removal)*
*Completed: 2026-04-14*
