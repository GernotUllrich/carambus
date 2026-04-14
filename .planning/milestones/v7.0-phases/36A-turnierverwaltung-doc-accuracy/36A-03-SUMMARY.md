---
phase: 36A-turnierverwaltung-doc-accuracy
plan: 03
subsystem: docs
tags: [tournament-management, walkthrough, doc-accuracy, bilingual, mkdocs, block-4, block-5]

requires:
  - phase: 36A-turnierverwaltung-doc-accuracy
    plan: 02
    provides: Block 3 baseline (Schritte 6-8 corrected, Default{n} doc-wide consistency, auto_upload_to_cc forward link)
provides:
  - Schritt 9 warning rewritten (button-is-locked truth instead of "nicht erneut klicken" myth)
  - Schritt 9 AASM/Redis/ActionCable developer paragraph replaced with table-feedback check
  - Schritt 10 uses "einspielen" Fachterminus with Warmup parameter explanation
  - Schritt 10 factually correct round-1 layout (2 matches + Freilos for 5 players, not 4 matches)
  - Schritt 10 documents "Aktuelle Spiele" Spielbeginn buttons as fallback UI
  - Schritt 11 complete rewrite — "Spielbetrieb läuft (Scoreboards steuern alles)"; Turnierleiter has no active role
  - Schritte 10-11-12 reframed as phases (warmup → match play → finalisation)
  - Schritt 12 browser-tab oversight workflow + Nachstoß error source + Reset-destroys-data danger callout
  - Schritt 13 honest disclosure: Endrangliste NOT auto-calculated (forward link to #appendix-rangliste-manual)
  - Schritt 13 Shootout/Stechen limitation called out with v7.1+ roadmap note
  - Schritt 14 corrected auto_upload_to_cc timing (per-match immediate, not at finalisation)
  - Schritt 14 fictional "Ergebnisse nach ClubCloud übertragen" button removed + CSV batch path documented
  - Glossary "Tisch-Warmup" entry updated to drop "Spielbeginn freigeben" stale back-reference
  - Troubleshooting ts-already-started de-jargonised (no more "AASM-Event start_tournament!")
affects: [36A-04, 36A-05, 36A-06, 36A-07]

tech-stack:
  added: []
  patterns:
    - bilingual mirror discipline (DE first, EN translated 1:1)
    - per-edit grep verification for Block-scoped doc edits
    - forward links to Plan 36A-06 appendix anchors
    - Rule-1 auto-extension: glossary/troubleshooting cleanup for internal consistency with rewritten walkthrough

key-files:
  created:
    - .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-03-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "Schritt 11 is now an H3 section that explicitly says the manager has no active role — a deliberate walkthrough-structure pivot; Schritt 11 stays as a numbered step for continuity of step numbering 1-14 even though the manager does nothing in it"
  - "Cosmetic EN-only note 'Turnierphase: playing group untranslated EN/DE mix' from old Step 10 prose was dropped; the plan's NEW Step 10 text does not preserve it, and the note belongs to a later Block 6/7 i18n-findings plan"
  - "Rule-1 auto-fix: glossary Tisch-Warmup and troubleshooting ts-already-started references were updated for consistency with the rewritten walkthrough (same pattern as Plan 36A-02 DefaultS glossary cleanup)"
  - "DE authoritative, EN derived: Task 2 used the freshly-updated DE text as translation source, continuing the 36A pattern"

patterns-established:
  - "Walkthrough-as-phases pattern: Schritte 10-11-12 explicitly framed as three phases (warmup → match play → finalisation), not three manager actions. This pattern will be used by later 36A plans when documenting other passive-observation walkthrough regions"

requirements-completed: [DOC-ACC-02, DOC-ACC-05]

duration: 18min
completed: 2026-04-14
---

# Phase 36A Plan 03: Block 4+5 Factual Corrections Summary

**Tournament-management walkthrough Schritte 9-14 rewritten: AASM/Redis developer jargon replaced with table-feedback check, Schritt 11 honestly states Turnierleiter has NO active role during match play, Endrangliste-not-calculated + Shootout-not-supported limitations disclosed with forward links, and the fictional "Ergebnisse nach ClubCloud übertragen" button removed in favour of the CSV batch path documentation.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-04-14
- **Completed:** 2026-04-14
- **Tasks:** 2/2
- **Files modified:** 2
- **Findings addressed:** F-36-24..F-36-38 (15 findings across Blocks 4 and 5)

## Accomplishments

- Schritt 9 warning callout "nicht erneut klicken" replaced with truthful "button is locked during the operation" framing
- Schritt 9 developer paragraph (AASM event `start_tournament!`, Redis, ActionCable) removed from user-facing text; replaced with practical "check the table scoreboards for correct round-1 pairings" guidance
- Schritt 10 wording "Spieler die Tische und Bälle ausprobieren" → "die Spieler sich einspielen" (Fachterminus) + Warmup parameter (5 min typical) documented
- Schritt 10 factually incorrect "alle 4 Matches" fixed: with 5 participants in Round 1 there are 2 matches with 2 players each + 1 Freilos player
- Schritt 10 "Aktuelle Spiele" table Spielbeginn buttons documented as fallback UI not needed in standard flow
- Schritt 11 complete rewrite: new title "Spielbetrieb läuft (Scoreboards steuern alles)" / "Match play (the scoreboards drive everything)"; explicit statement that the Turnierleiter has no active role; Schritte 10/11/12 reframed as three phases (warmup → match play → finalisation), not three manager actions; manual round-change control demoted to a "disputed special case" note
- Schritt 12 renamed to "Beobachten und bei Bedarf eingreifen" / "Observe and intervene as needed"
- Schritt 12 browser-tab oversight workflow documented (open individual table scoreboards in separate browser tabs from the Tournament Monitor)
- Schritt 12 common error source "Nachstoß vergessen am Scoreboard" added
- Schritt 12 danger callout "Reset zerstört bei laufendem Turnier alle Daten" documents the data-loss risk + notes that a safety dialog is planned for a follow-up phase
- Schritt 12 manual-check-button no longer endorsed; documented as "part of the special operating mode from Step 11 and likely to be removed"
- Schritt 13 renamed to "Turnier abschließen" / "Conclude the tournament"
- Schritt 13 honest warning callout: Carambus does NOT auto-calculate the Endrangliste; maintenance happens manually in ClubCloud (forward link to `#appendix-rangliste-manual`)
- Schritt 13 second warning callout: Shootout/Stechen is not supported in current Carambus version; must be run outside Carambus with manual ClubCloud entry; planned as critical feature for v7.1/v7.2
- Schritt 14 renamed to "Ergebnisse in die ClubCloud übertragen" / "Transfer results to ClubCloud"
- Schritt 14 corrected auto_upload_to_cc timing: each individual result is uploaded immediately at match end, NOT at finalisation (prerequisite: participant list must be finalised in ClubCloud); forward link to `#appendix-cc-upload`
- Schritt 14 removed the fictional "Ergebnisse nach ClubCloud übertragen" / "Upload results to ClubCloud" button; documented the CSV batch path via ClubCloud admin interface (forward link to `#appendix-cc-csv-upload`)
- Glossary "Tisch-Warmup" / "Table warmup" entry updated: no longer references the defunct "Spielbeginn freigeben" / "release each match" phrase
- Troubleshooting "ts-already-started" de-jargonised: no more "AASM-Event start_tournament!" in user-facing cause text; stale back-reference to "Hinweiskasten nicht erneut klicken" removed

## Findings Addressed

| Finding  | Tier | Block | Description                                                                 | Where applied                                |
|----------|------|-------|-----------------------------------------------------------------------------|----------------------------------------------|
| F-36-24  | A    | 4     | Warning "nicht erneut klicken" misleading (button is locked)                | Edit 1 (DE + EN)                             |
| F-36-25  | A    | 4     | AASM/Redis/ActionCable developer paragraph → table-feedback check            | Edit 1 (DE + EN)                             |
| F-36-26  | A+C  | 4     | Warmup wording: "ausprobieren" → "einspielen" + parameter explanation        | Edit 2 (DE + EN)                             |
| F-36-27  | A    | 4     | "alle 4 Matches" factually wrong — 5 players = 2 matches + Freilos          | Edit 2 (DE + EN)                             |
| F-36-28  | A    | 4     | "Aktuelle Spiele" input UI documented as fallback, not standard              | Edit 2 (DE + EN)                             |
| F-36-29  | A+B  | 4     | Manual round-change control demoted to "disputed special case"              | Edit 3 (DE + EN)                             |
| F-36-30  | A    | 4     | Schritt 11 complete rewrite — manager has no active role (META finding)     | Edit 3 (DE + EN)                             |
| F-36-31  | C    | 4     | New content: Nachstoß error source + browser-tab oversight workflow         | Edit 4 (DE + EN)                             |
| F-36-32  | A+B  | 5     | Reset is destructive at tournament run-time — danger callout added          | Edit 4 (DE + EN)                             |
| F-36-33  | A    | 5     | Manual-check-button moved to special-case aside (likely to be removed)      | Edit 4 (DE + EN)                             |
| F-36-34  | A+B+C| 5     | Endrangliste NOT auto-calculated → warning + forward link to appendix       | Edit 5 (DE + EN)                             |
| F-36-35  | B+C  | 5     | Shootout not supported → warning callout + v7.1/v7.2 roadmap note           | Edit 5 (DE + EN)                             |
| F-36-36  | A    | 5     | auto_upload_to_cc timing: per-match immediate, not at finalisation          | Edit 6 (DE + EN)                             |
| F-36-37  | A    | 5     | Fictional "Übertragen nach ClubCloud" button removed                        | Edit 6 (DE + EN)                             |
| F-36-38  | C    | 5     | CSV-upload appendix forward link added (#appendix-cc-csv-upload)            | Edit 6 (DE + EN)                             |

## Task Commits

1. **Task 1: Apply Block 4+5 corrections to tournament-management.de.md** — `e15c88dc` (docs)
2. **Task 2: Mirror Block 4+5 corrections to tournament-management.en.md** — `21823dfc` (docs)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — 66 insertions, 27 deletions; Schritte 9-14 region (~lines 160-254) rewritten; glossary Tisch-Warmup + troubleshooting ts-already-started de-jargonised
- `docs/managers/tournament-management.en.md` — 64 insertions, 30 deletions; mirror of DE edits; glossary Table warmup + troubleshooting ts-already-started de-jargonised

## Decisions Made

- **Schritt 11 stays as a numbered step despite passive content:** Even though the new Schritt 11 explicitly says the Turnierleiter has no active role, it remains as a numbered section rather than being merged into Schritt 10 or 12. This preserves the 1-14 step numbering promised by the walkthrough intro callout (added by Plan 36A-01) and gives the reader an anchor to jump to when thinking "what happens during match play". The walkthrough-as-phases framing lives inside the Schritt-11 body rather than in a structural change.
- **Cosmetic EN-only note dropped:** The old EN Step 10 had a cosmetic note "Turnierphase: playing group untranslated EN/DE mix — this is a known cosmetic issue". The plan's NEW Step 10 text does not preserve it, and Block 6/7 (i18n findings, later 36A plan) is the appropriate home for untranslated-label notes. Dropped it here, flagged in decisions.
- **Rule-1 auto-fix extends to glossary + troubleshooting:** Same pattern as Plan 36A-02 DefaultS cleanup. The plan's acceptance criteria have absence-grep gates for `Spielbeginn freigeben` and `AASM-Event`/`AASM event`, and both phrases survived in out-of-Block content areas (glossary Tisch-Warmup entry, troubleshooting ts-already-started Cause text). Left unchanged, these would have (a) failed the plan verify gate and (b) created internal inconsistencies — the rewritten walkthrough no longer says "Spielbeginn freigeben" or references the AASM event in user-facing text, so linking to those phrases from the glossary/troubleshooting would contradict the new walkthrough. Auto-fixed both to match the new walkthrough language.
- **DE authoritative, EN derived:** Continuing the 36A pattern, Task 2 translated from the freshly-updated DE file rather than independently rewriting from the review notes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Internal consistency] Glossary `Tisch-Warmup` / `Table warmup` entry still referenced "Spielbeginn freigeben" / "release each match"**
- **Found during:** Task 1 and Task 2 verification grep (positive `Spielbeginn freigeben` / `AASM event` counts)
- **Issue:** The walkthrough rewrite removes the phrase "Spielbeginn freigeben" and the title "Release each match", but the glossary entry for Tisch-Warmup still linked to `#step-11-release-match` with the old label, producing an internal consistency break: reader clicks the glossary link expecting to land on "Release each match" but arrives at "Match play (the scoreboards drive everything)".
- **Fix:** Rewrote the glossary entries (DE line 284 / EN line 289) to reference the new Schritt 11 framing ("automatically moves into match play" / "geht der Tisch automatisch in den Spielbetrieb über"). The `#step-11-release-match` anchor itself is preserved for backward compatibility with any existing external links.
- **Files modified:** docs/managers/tournament-management.de.md, docs/managers/tournament-management.en.md
- **Committed in:** e15c88dc (DE) and 21823dfc (EN), folded into the task commits
- **Rationale:** Rule 1 (internal factual inconsistency — stale label on a live link) + Rule 3 (plan's `! grep -F "Spielbeginn freigeben"` verify gate would otherwise fail).

**2. [Rule 1 - Internal consistency] Troubleshooting `ts-already-started` still referenced "AASM event `start_tournament!`" + stale "warning callout advises against clicking again" back-reference**
- **Found during:** Task 1 and Task 2 verification grep (positive `AASM-Event` / `AASM event` counts)
- **Issue:** The Schritt 9 rewrite removes the AASM/Redis/ActionCable developer paragraph and the "nicht erneut klicken" warning text. The troubleshooting `ts-already-started` cause description still said "The AASM event `start_tournament!` … is irreversible" and its Fix paragraph ended with "The warning callout in Step 9 explicitly advises against clicking again or navigating back" — both back-references pointed at text that no longer exists.
- **Fix:** Rewrote the Cause paragraph as plain-language ("The tournament start in Step 9 is irreversible") and deleted the trailing sentence about the non-existent warning callout. Preserved the technical F-19 / Tier 3 Finding reference for the design rationale.
- **Files modified:** docs/managers/tournament-management.de.md, docs/managers/tournament-management.en.md
- **Committed in:** e15c88dc (DE) and 21823dfc (EN), folded into the task commits
- **Rationale:** Rule 1 (dead back-references) + Rule 3 (plan's `grep "AASM-Event"` / `grep "AASM event"` verify gate would otherwise fail).

**3. [Scope drop] Cosmetic EN-only note about "Turnierphase: playing group" untranslated label**
- **Found during:** Task 2 Step-10 re-read
- **Issue:** The old EN Step 10 prose had an extra sentence: "Note: The label 'Turnierphase: playing group' in the monitor header is an untranslated EN/DE mix — this is a known cosmetic issue and does not affect functionality." The plan's NEW Step 10 text for EN does not include this note, so applying the plan verbatim dropped it.
- **Fix:** None — the note belongs to a later i18n-findings plan (Block 6/7) and was deliberately not preserved.
- **Files modified:** docs/managers/tournament-management.en.md (the note is gone from Step 10)
- **Committed in:** 21823dfc
- **Rationale:** This is scope-boundary handling, not a bug. The note was a Block-6 (Glossar/i18n) concern that happened to live in Block-4 territory in the old text; moving it out of Block 4 during a Block-4 rewrite is appropriate.

---

**Total deviations:** 3 (two Rule-1 auto-fixes for internal consistency, one scope-boundary drop)
**Impact on plan:** All acceptance criteria for both DE and EN files pass. The Block 4+5 walkthrough restructure is complete and internally consistent with the glossary + troubleshooting sections that reference it.

## Issues Encountered

- None blocking. The PreToolUse READ-BEFORE-EDIT hook fires before every Edit attempt regardless of recent reads — each Edit was preceded by a fresh Read of the relevant range to satisfy the hook. Same pattern as Plans 36A-01 and 36A-02.

## Self-Check: PASSED

**Files exist:**
- FOUND: docs/managers/tournament-management.de.md
- FOUND: docs/managers/tournament-management.en.md
- FOUND: .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-03-SUMMARY.md (this file)

**Commits exist:**
- FOUND: e15c88dc (Task 1 — DE)
- FOUND: 21823dfc (Task 2 — EN)

**Acceptance criteria status (DE file):**
- grep "einspielen" = 2 (≥1 required) PASS
- grep "appendix-rangliste-manual" = 1 (≥1 required) PASS
- grep "appendix-cc-upload" = 2 (≥1 required) PASS
- grep "appendix-cc-csv-upload" = 1 (≥1 required) PASS
- grep "Shootout" = 2 (≥1 required) PASS
- grep "Browser-Tab" = 1 (≥1 required) PASS
- grep "Nachstoß" = 3 (≥1 required) PASS
- grep "Reset zerstört" = 1 (≥1 required) PASS
- grep -F "alle 4 Matches" = 0 (must be 0) PASS
- grep -F "manuell auf der Turnier-Detailseite anstoßen (Schaltfläche" = 0 (must be 0) PASS
- grep -F "AASM-Event" = 0 (must be 0 — auto-fixed) PASS
- grep -F "Spielbeginn freigeben" = 0 (must be 0 — auto-fixed) PASS
- grep -F "Endrangliste zu berechnen" = 0 (must be 0) PASS
- grep -F "Klicken Sie den Button nicht erneut" = 0 (must be 0) PASS

**Acceptance criteria status (EN file):**
- grep "einspielen" = 1 (≥1 required) PASS
- grep "appendix-rangliste-manual" = 1 (≥1 required) PASS
- grep "appendix-cc-upload" = 2 (≥1 required) PASS
- grep "appendix-cc-csv-upload" = 1 (≥1 required) PASS
- grep "Shootout" = 2 (≥1 required) PASS
- grep "Browser-tab oversight" = 1 (≥1 required) PASS
- grep "Nachstoß forgotten" = 1 (≥1 required) PASS
- grep -F "all 4 matches" = 0 (must be 0) PASS
- grep -F "you can manually trigger the upload on the tournament detail page" = 0 (must be 0) PASS
- grep -F "you can trigger the upload manually from the tournament detail page" = 0 (must be 0 — old EN wording different from plan pattern, also removed) PASS
- grep -F "AASM event" = 0 (must be 0 — auto-fixed) PASS
- grep -F "Step 11: Release" = 0 (must be 0) PASS
- grep -F "to calculate the final standings" = 0 (must be 0) PASS

**Cross-file appendix anchor parity:**
- `appendix-rangliste-manual`: DE=1, EN=1 PASS
- `appendix-cc-upload`: DE=2, EN=2 PASS (Plan 36A-02 added 1 each; Plan 36A-03 adds another 1 each)
- `appendix-cc-csv-upload`: DE=1, EN=1 PASS (new this plan)

## Next Plan Readiness

- **Plan 36A-04 (next block of findings):** Ready. Block 4+5 establishes the walkthrough-as-phases framing and the honest-limitation-disclosure pattern (Endrangliste, Shootout). Later blocks can build on these as stable anchors.
- **Plan 36A-06 (Appendix):** Owns the creation of the new `#appendix-rangliste-manual` and `#appendix-cc-csv-upload` anchors forward-linked from this plan's Schritte 13 and 14 (plus the `#appendix-cc-upload` anchor originally forward-linked by Plan 36A-02). mkdocs strict will emit broken-link warnings for three anchors until Plan 06 closes them — acceptable mid-wave state.
- **Block 6/7 i18n plan:** Should revisit the dropped "Turnierphase: playing group" cosmetic note and decide where it lives (likely in a dedicated known-cosmetic-i18n-issues section).

---
*Phase: 36A-turnierverwaltung-doc-accuracy*
*Plan: 03 (Blocks 4+5 Factual Corrections — Schritte 9-14)*
*Completed: 2026-04-14*
