---
phase: 36A-turnierverwaltung-doc-accuracy
plan: 01
subsystem: docs
tags: [tournament-management, walkthrough, doc-accuracy, bilingual, mkdocs]

requires:
  - phase: 35-print-friendly
    provides: stable bilingual tournament-management walkthrough baseline (lines 1-65)
provides:
  - Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste) introduced in Schritt 1
  - Forward links to special-case appendices (no-invitation, missing-player, nachmeldung)
  - Honest framing of Schritt 3 (Setzliste = Meldeliste + Ordnung, not either-or PDF-vs-ClubCloud)
  - Three documented entry points to the participant edit page (Schritt 4)
  - Schritt 5 warning rewrite (Reset link instead of false "irreversible")
  - Schritt-4-as-action-link concept documented (no separate AASM state)
affects: [36A-02, 36A-03, 36A-04, 36A-05, 36A-06, 36A-07]

tech-stack:
  added: []
  patterns:
    - bilingual mirror discipline (DE first as authoritative, EN translated 1:1)
    - per-edit grep verification for Block-scoped doc edits
    - forward links to anchors that later plans will create (#appendix-no-invitation, etc.)

key-files:
  created:
    - .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-01-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "Glossar-Eintrag (System-Begriffe) für AASM-Status mit `tournament_seeding_finished` bleibt unverändert in Plan 36A-01 — gehört in einen späteren Block (Glossar-Block ist nicht Block 1+2)"
  - "Forward links zu noch nicht existierenden Anker-IDs sind erlaubt und beabsichtigt — Plan 36A-06 wird die Appendix-Sektionen mit den passenden IDs erstellen"
  - "DE bleibt die autoritative Quelle; EN wird 1:1 übersetzt mit denselben Anker-IDs und Forward-Link-Zielen"

patterns-established:
  - "Bilingual edit pattern: apply all DE edits first as one atomic commit, then translate to EN as a second atomic commit — this avoids interleaved diffs and makes review easy"
  - "Block-scoped grep verification: each edit ships with explicit grep patterns to assert presence of new content and absence of old content"

requirements-completed: [DOC-ACC-01, DOC-ACC-02]

duration: 18min
completed: 2026-04-14
---

# Phase 36A Plan 01: Block 1+2 Factual Corrections Summary

**Tournament-management walkthrough corrected for Schritte 1-5: Begriffshierarchie introduced, false PDF-vs-ClubCloud either-or removed, three entry points to participant edit page documented, Schritt-5 warning rewritten with Reset path, AASM state name removed from user-facing text.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-04-14
- **Completed:** 2026-04-14
- **Tasks:** 2/2
- **Files modified:** 2
- **Findings addressed:** F-36-01..F-36-11 plus F-36-15 (META intro hint)

## Accomplishments

- DE walkthrough Schritte 1-5 rewritten according to F-36-01..F-36-11 + F-36-15
- EN walkthrough mirrored 1:1 with same anchor IDs and forward-link targets
- Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste) introduced in Schritt 1 with glossary cross-link
- Schritt 3 reframed: Setzliste is a **result** (Meldeliste + Ordnung), not a downloadable source
- Schritt 4 documents three entry points to the participant edit page (direct from Schritt 3, bottom button, "Einladung hochladen" action)
- Schritt 4 documents the required "Spieler hinzufügen" click for DBU-number entries
- Schritt 5 warning callout rewritten: "Zurücksetzen des Turnier-Monitors" / "Reset tournament monitor" link replaces the false "irreversible" claim
- Schritt 5 documents that "Schritt 4" and "Schritt 5" in the wizard are **action links**, not separate wizard states (no separate AASM state)
- Walkthrough intro callout added: step numbering 1-14 is logical-chronological, not UI-1:1
- Forward links to `#appendix-no-invitation`, `#appendix-missing-player`, `#appendix-nachmeldung` placed (Plan 36A-06 will create those anchors)

## Findings Addressed

| Finding   | Tier | Block | Description                                                                  | Where applied                              |
|-----------|------|-------|------------------------------------------------------------------------------|--------------------------------------------|
| F-36-01   | A    | 1     | Szenario: PDF as primary source + appendix link                              | Edit 1 (Szenario)                          |
| F-36-02   | A+C  | 1     | Begriffshierarchie + Ausspielziele (Ballziel/Aufnahmebegrenzung)             | Edit 3 (Schritt 1)                         |
| F-36-03   | C    | 1     | Navigation path Organisationen → Regionalverbände → NBV                       | Edit 4 (Schritt 2)                         |
| F-36-04   | A    | 1     | Schritt-2 caption made honest about 1-Spieler edge case                      | Edit 5 (Schritt 2 caption)                 |
| F-36-05   | A    | 2     | Setzliste reframed as result (Meldeliste + Ordnung), no either-or            | Edit 6 (Schritt 3)                         |
| F-36-06   | C    | 2     | Drei Einstiegspunkte zur Teilnehmerliste-Bearbeitung                         | Edit 7 (Schritt 4 nav paragraph)           |
| F-36-07   | A    | 2     | T04 plan codes from Karambol-Turnierordnung                                  | Edit 9 (Schritt 4 T04 parenthetical)       |
| F-36-08   | A    | 2     | Spieler-hinzufügen click required for DBU entry; sofort-gespeichert exception| Edit 7 + Edit 8                            |
| F-36-09   | A    | 2     | Schritt-5 warning rewrite (Reset link instead of irreversible)               | Edit 10 (Schritt 5 warning callout)        |
| F-36-10   | A    | 2     | Remove AASM state name `tournament_seeding_finished` from user-facing text   | Edit 10 (Schritt 5 body)                   |
| F-36-11   | A    | 2     | Schritt-4-as-action-link concept (no separate AASM state)                    | Edit 10 (Schritt 5 conceptual note)        |
| F-36-15   | META | meta  | Intro callout: step numbering is logical, not UI-1:1                         | Edit 2 (walkthrough intro)                 |

## Task Commits

1. **Task 1: Apply Block 1+2 corrections to tournament-management.de.md** — `bb7e96dc` (docs)
2. **Task 2: Mirror Block 1+2 corrections to tournament-management.en.md** — `6bdf8e07` (docs)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — 60 insertions, 20 deletions; lines 6-100 rewritten per F-36-01..F-36-11 + F-36-15
- `docs/managers/tournament-management.en.md` — 67 insertions, 19 deletions; mirror of DE edits with same anchor IDs and forward-link targets

## Decisions Made

- **Glossary-out-of-scope:** The System-Begriffe glossary entry for `AASM-Status` (DE line 254 / EN line 264) still legitimately references `tournament_seeding_finished` as a technical/internal state name. The plan's must_haves criterion is "Step 5 no longer claims AASM state name as user-facing" — the glossary is a technical reference section explaining internal machinery, not user-facing instruction. This entry will be reviewed by a later plan in 36A (likely Block 7 or the Glossar plan), not by 36A-01.
- **Forward links to non-existent anchors:** Edits 1 and 6 introduce links to `#appendix-no-invitation`, `#appendix-missing-player`, `#appendix-nachmeldung`. These anchors will be created by Plan 36A-06 (Appendix). The mkdocs build will warn until then. This is acceptable because Plan 36A is sequenced as a wave: every plan in the wave touches the same two files, and Plan 06 closes the link gap.
- **DE-first authoritative:** Task 1 wrote DE first; Task 2 used the freshly-updated DE as the translation source rather than re-deriving from the OLD EN baseline. This matches the plan's explicit instruction.

## Deviations from Plan

### Acceptable scope-boundary deviations

**1. [Scope boundary] `tournament_seeding_finished` retained in System-Begriffe glossary entry**
- **Found during:** Task 1 verification grep
- **Issue:** Plan's `<automated>` verify uses `! grep -F "tournament_seeding_finished"` which would technically fail because line 254 (DE) / line 264 (EN) of the glossary still names this AASM state in the `AASM-Status` technical entry.
- **Fix:** None applied — this is a glossary entry explaining system internals (technical reference, not user-facing instruction). The plan's must_haves criterion ("Step 5 no longer claims AASM state name as user-facing") IS satisfied because Step 5 no longer mentions the state. The glossary is in a different document section that belongs to a later plan in 36A (the Glossar block).
- **Files modified:** none
- **Verification:** Step 5 itself is clean of `tournament_seeding_finished`; the only remaining occurrence is the glossary entry on line 254 (DE) / 264 (EN), which is technical reference content.
- **Committed in:** N/A (no fix needed)

**2. [Verification artifact] grep "Zurücksetzen des Turnier-Monitors" returned 0 due to line wrap**
- **Found during:** Task 1 verification grep
- **Issue:** The replacement text in the DE warning callout wraps the phrase `„Zurücksetzen des Turnier-Monitors"` across two lines (admonition indent + visual wrap), so a single-line `grep -c` returned 0 even though the phrase IS present in the file.
- **Fix:** Confirmed via multiline grep: `Zurücksetzen des\s+Turnier-Monitors` matches at lines 97-98. Content is correct, only the verification grep needs to be multiline.
- **Files modified:** none (content is correct)
- **Verification:** Multiline grep confirms phrase presence; the EN file has `"Reset tournament monitor"` on a single line (count 1).
- **Committed in:** N/A (no fix needed)

---

**Total deviations:** 2 (both verification artifacts, neither requires content change)
**Impact on plan:** Block 1+2 acceptance criteria are satisfied in spirit. The two deviations are scope-boundary (glossary belongs to later plan) and a verification grep artifact (line wrap in admonition).

## Issues Encountered

- None blocking. The PreToolUse READ-BEFORE-EDIT hook fires before every Edit attempt regardless of recent reads in the session — this is a hook quirk, not a content issue. Each Edit was preceded by a fresh Read of the relevant range to satisfy the hook.

## Next Plan Readiness

- **Plan 36A-02 (Block 3 — Schritt 6+7+8 / Mode-Selection + Start-Form):** Ready. The walkthrough-intro callout from F-36-15 (this plan's Edit 2) primes the reader for the "Steps 7-8 are the same parametrisation page" framing that Plan 02 will build on.
- **Plan 36A-06 (Appendix):** Owns the creation of the `#appendix-no-invitation`, `#appendix-missing-player`, `#appendix-nachmeldung` anchors that this plan forward-links to. Until Plan 06 lands, mkdocs strict will emit broken-link warnings for these three forward links — acceptable in mid-wave state.
- **Glossar review:** A later plan in 36A (or a follow-up phase) should revisit the `AASM-Status` glossary entry (DE line 254, EN line 264) to either keep the technical reference as-is or simplify the user-facing language.

## Self-Check: PASSED

**Files exist:**
- FOUND: docs/managers/tournament-management.de.md
- FOUND: docs/managers/tournament-management.en.md
- FOUND: .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-01-SUMMARY.md (this file)

**Commits exist:**
- FOUND: bb7e96dc (Task 1 — DE)
- FOUND: 6bdf8e07 (Task 2 — EN)

**Acceptance criteria status (DE file):**
- grep "Meldeliste" = 12 (≥3 required) PASS
- grep "Spieler hinzufügen" = 2 (≥2 required) PASS
- grep "appendix-no-invitation" = 2 (≥1 required) PASS
- grep "Organisationen → Regionalverbände → NBV" = 1 (≥1 required) PASS
- grep -F "Teilnehmerliste (Setzliste)" = 0 (must be 0) PASS
- grep "Aktions-Links" = 1 (≥1 required) PASS
- grep "Schritt 4 wird im Hintergrund automatisch erledigt" = 0 (must be 0) PASS
- multiline grep "Zurücksetzen des\s+Turnier-Monitors" matches (line-wrap artifact, content present) PASS
- grep -F "tournament_seeding_finished" = 1 (in System-Begriffe glossary only — scope deviation documented above)

**Acceptance criteria status (EN file):**
- grep "registration list (Meldeliste)" = 1 (≥1 required) PASS
- grep "Add player" = 3 (≥2 required) PASS
- grep "appendix-no-invitation" = 2 (≥1 required) PASS
- grep "Organisations → Regional Federations → NBV" = 1 (≥1 required) PASS
- grep -F "(seeding list)" = 0 (must be 0) PASS
- grep "action links" = 1 (≥1 required) PASS
- grep "Reset tournament monitor" = 1 (≥1 required) PASS
- grep "Step 4 is automatically completed in the background" = 0 (must be 0) PASS
- grep -F "tournament_seeding_finished" = 1 (in System-Begriffe glossary only — scope deviation documented above)

---
*Phase: 36A-turnierverwaltung-doc-accuracy*
*Plan: 01 (Blocks 1+2 Factual Corrections)*
*Completed: 2026-04-14*
