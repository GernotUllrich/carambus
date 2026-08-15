---
phase: 36A-turnierverwaltung-doc-accuracy
plan: 04
subsystem: docs
tags: [tournament-management, glossary, doc-accuracy, bilingual, mkdocs, block-6]

requires:
  - phase: 36A-turnierverwaltung-doc-accuracy
    plan: 03
    provides: Blocks 4+5 walkthrough corrections (Schritte 9-14, glossary Tisch-Warmup/Table warmup, troubleshooting ts-already-started)
provides:
  - Ballziel/Aufnahmebegrenzung split — correct field names (balls_goal vs innings_goal) and a new "Bälle vor" handicap-value entry
  - Setzliste rewrite with three-source origin (invitation / Carambus-internal / NOT from ClubCloud)
  - New Meldeliste and Teilnehmerliste entries that complete the Begriffshierarchie from Plan 01
  - Turnierplan-Kürzel rewrite as T-Plan vs. Default-Plan (not "T04/T05/Default5")
  - Scoreboard entry clarifies binding is manual at the scoreboard, not automatic
  - AASM-Status entry corrected — wizard Schritte are not 1:1 AASM states; "Phase 36 will make status badge prominent" promise removed
  - Rangliste corrected — Carambus-internal (not ClubCloud-sourced)
  - Six new system-term entries: Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos
  - Rule-1 auto-fix: Freie Partie entry link text updated from "Bälle-Ziele" → "Ballziele" for consistency with rewritten entry
affects: [36A-05, 36A-06, 36A-07]

tech-stack:
  added: []
  patterns:
    - bilingual mirror discipline (DE authoritative, EN translated)
    - per-edit grep verification with positive-and-negative acceptance gates
    - German technical terms in parentheses in EN entries (e.g., "Target balls (Ballziel, balls_goal)")
    - Rule-1 auto-fix: in-section stale-label cleanup for internal consistency with rewritten entries

key-files:
  created:
    - .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-04-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "Meldeliste placed BEFORE Setzliste in the Wizard-Begriffe subsection: the plan specified Setzliste + Meldeliste + Teilnehmerliste but gave a temporal ordering narrative (Meldeliste = before seeding close, Setzliste = after seeding close, Teilnehmerliste = at tournament day). The existing Setzliste entry was rewritten in place; Meldeliste was inserted above it and Teilnehmerliste below it, giving readers the same top-down chronological flow the walkthrough uses in Schritt 1."
  - "Freilos/Bye walkthrough link to #glossary-wizard left as-is even though the new entry lives in glossary-system: the anchor still resolves to the broader glossary section, and the entry is reachable by scrolling. Fixing the link target from #glossary-wizard → #glossary-system would be a pre-existing scope item from Plan 03 (which added the walkthrough text before the Freilos entry existed) — not in this plan's block."
  - "Rule-1 auto-fix extended to the Freie Partie entry: it referenced `[Bälle-Ziele](#glossary-karambol)` with the old German term. After the rewrite, the karambol section has a `Ballziel` entry (singular, without umlaut on the hyphen) — the old link label would have been internally inconsistent with the entry it points at. Fixed to `[Ballziele](#glossary-karambol)` (plural of Ballziel)."
  - "DE authoritative, EN derived: continuing the 36A pattern, Task 2 translated from the freshly-updated DE file rather than independently rewriting from the review notes."

patterns-established:
  - "Glossary block rewrite pattern: for a block-level glossary change (as opposed to a single-entry tweak), the executor applies 8 sequenced Edits — 7 entry rewrites + 1 block-append — each verified by positive/negative grep gates. Same pattern will apply to future glossary blocks in other manager docs."

requirements-completed: [DOC-ACC-01, DOC-ACC-03]

duration: 14min
completed: 2026-04-14
---

# Phase 36A Plan 04: Block 6 Glossary Rewrite Summary

**Tournament-management glossary rewritten with 7 corrected entries (Ballziel/Aufnahmebegrenzung split, Setzliste 3-source origin, T-Plan vs. Default-Plan, Scoreboard binding, AASM-Status, Rangliste) plus 6 new entries (Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos) — completing the conceptual anchor that the walkthrough corrections in Plans 01-03 forward-link into.**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-04-14
- **Completed:** 2026-04-14
- **Tasks:** 2/2
- **Files modified:** 2
- **Findings addressed:** F-36-39..F-36-50 (12 findings from Block 6)

## Accomplishments

### Karambol-Begriffe subsection (DE + EN)

- **F-36-39 + F-36-17:** Split the wrong merged "Bälle-Ziel (innings_goal)" entry into three separate entries:
  - **Ballziel (`balls_goal`)** / **Target balls (Ballziel, `balls_goal`)** — the actual point target, with correct field name
  - **Aufnahmebegrenzung (`innings_goal`)** / **Inning limit (Aufnahmebegrenzung, `innings_goal`)** — maximum innings per match, with correct field name and "empty or 0 = unlimited" documented
  - **Bälle vor (Vorgabe-Wert)** / **"Bälle vor" (handicap value)** — individual handicap value per player, disambiguated from the general target-balls parameter
- **Aufnahme entry** updated to cross-reference the new Ballziel and Aufnahmebegrenzung entries (removing the now-duplicated inning-limit text)
- **Rule-1 auto-fix:** Freie Partie entry link text `[Bälle-Ziele]` → `[Ballziele]` for internal consistency with the rewritten entry

### Wizard-Begriffe subsection (DE + EN)

- **F-36-40 + F-36-41:** Rewrote the Setzliste entry with three-source origin:
  1. **Official seeding list from the invitation** (normal case, from the regional sports officer's spreadsheets)
  2. **Carambus-internal seeding list** (fallback case without invitation, from Carambus-internal rankings via "Sort by ranking" in Step 4)
  3. **NOT from ClubCloud** — ClubCloud only carries registration lists
- **F-36-41:** Added two new neighbour entries completing the Begriffshierarchie from Plan 01:
  - **Meldeliste** / **Registration list (Meldeliste)** — snapshot of the seeding list at the close of registration; comes from ClubCloud; provisional until tournament day
  - **Teilnehmerliste** / **Participant list (Teilnehmerliste)** — who actually shows up on tournament day; finalised shortly before tournament start; cross-ref to `#appendix-nachmeldung`
- **F-36-42 + F-36-50:** Rewrote Turnierplan-Kürzel as "T-Plan vs. Default-Plan" with explicit distinction:
  - **T-nn** (T04, T05, …) — predefined plans from the Carom Tournament Regulations with fixed match structure and fixed table count
  - **`Default{n}`** — dynamically generated round-robin plan where `{n}` is the participant count; table count is computed from the participant count
- **F-36-43:** Rewrote Scoreboard entry — binding to physical table is NOT fixed, operator picks the table at the scoreboard, binding established via TableMonitor of the logical table; re-selection possible when needed

### System-Begriffe subsection (DE + EN)

- **F-36-44:** Corrected AASM-Status entry — removed the wrong "Schritt 4 erledigt = tournament_seeding_finished" mapping (Schritte 4 and 5 are action links on a single state's page, not separate states); removed the stale "Phase 36 will make this status badge prominent" promise, replaced with "open improvement area"
- **F-36-45:** Corrected Rangliste entry — now correctly described as Carambus-internal (updated per player from Carambus's own tournament results), not sourced from ClubCloud database; serves as default sort criterion when no official seeding list from invitation is available
- **F-36-46:** Added **Logischer Tisch** / **Logical table (Logischer Tisch)** — TournamentPlan-internal table identity; mapped to physical tables at tournament start (Step 7)
- **F-36-46:** Added **Physikalischer Tisch** / **Physical table (Physikalischer Tisch)** — concrete numbered playing table in the venue; the only form visible from players' perspective
- **F-36-47:** Added **TableMonitor** — technical record/automaton that drives activity at a logical table during a match (match assignments, score capture, round changes); from players' perspective: a bot deciding which match runs at which table
- **F-36-48:** Added **Turnier-Monitor** / **Tournament Monitor (Turnier-Monitor)** — top-level component that coordinates all TableMonitors of a tournament; both technical coordinator and overview page opened from Step 9 onwards
- **NEW beyond plan findings:** Added **Trainingsmodus** / **Training mode (Trainingsmodus)** — scoreboard operating mode outside tournament context; used as fallback when a running tournament cannot be continued in Carambus (cross-ref to #ts-already-started)
- **F-36-49:** Added **Freilos** / **Bye (Freilos)** — odd-participant-count bye explanation; explicitly noted that mid-tournament match abort is NOT properly supported in current Carambus version (deferred to v7.1+)

## Findings Addressed

| Finding | Tier | Block | Description | Where applied |
|---------|------|-------|-------------|---------------|
| F-36-39 | A | 6 | Ballziel/Aufnahmebegrenzung verwechselt (balls_goal vs innings_goal); "Bälle-Ziel" → "Ballziel" | Karambol subsection — 3 new/rewritten entries |
| F-36-40 | A | 6 | Setzliste-Definition — 3 sources, NOT from ClubCloud | Wizard subsection — entry rewritten |
| F-36-41 | A | 6 | Meldeliste + Teilnehmerliste als eigene Einträge | Wizard subsection — 2 new entries |
| F-36-42 | A | 6 | "Default5" ist falsch — `Default{n}` als Template | Wizard subsection — Turnierplan-Kürzel rewrite |
| F-36-43 | A | 6 | Scoreboard-Verbindung ist NICHT fest vorgegeben | Wizard subsection — Scoreboard entry rewrite |
| F-36-44 | A | 6 | AASM-Status: Schritt 4 ist kein eigener State; "Phase 36" false promise entfernen | System subsection — AASM-Status rewrite |
| F-36-45 | A | 6 | Rangliste — Carambus-intern, nicht aus ClubCloud | System subsection — Rangliste rewrite |
| F-36-46 | C | 6 | Logische vs. physikalische Tische (2 neue Einträge) | System subsection — 2 new entries |
| F-36-47 | C | 6 | TableMonitor fehlt | System subsection — 1 new entry |
| F-36-48 | C | 6 | Turnier-Monitor eigener Eintrag | System subsection — 1 new entry |
| F-36-49 | C | 6 | Freilos fehlt (Match-Abbruch-Feature zu v7.1+ deferred) | System subsection — 1 new entry |
| F-36-50 | A | 6 | T-Plan vs. Default-Plan Cross-ref | Wizard subsection — abgedeckt durch F-36-42 |

**Note on F-36-49 Tier B:** The Feature-Gap (Match-Abbruch / Freilos-Handling implementation) is explicitly deferred to v7.1+ backlog as noted in the plan's objective. Only the Tier C glossary entry was added.

## Task Commits

1. **Task 1: Rewrite glossary in tournament-management.de.md** — `51c459a3` (docs)
2. **Task 2: Mirror glossary rewrite to tournament-management.en.md** — `e89137e0` (docs)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — 35 insertions, 8 deletions; glossary section (lines 260-322) rewritten with 7 corrected entries + 8 new entries (Bälle vor, Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos); Aufnahme entry updated; Freie Partie entry link text auto-fixed
- `docs/managers/tournament-management.en.md` — 34 insertions, 7 deletions; mirror of DE edits with German technical terms preserved in parentheses

## Decisions Made

- **Meldeliste placed BEFORE Setzliste in the Wizard-Begriffe subsection:** The plan specified Setzliste + Meldeliste + Teilnehmerliste as three parallel new entries, but the temporal narrative (Meldeliste = at registration close; Setzliste = after seeding; Teilnehmerliste = at tournament day) reads better when ordered chronologically top-down. The existing Setzliste entry was rewritten in place, Meldeliste inserted above, Teilnehmerliste below — giving readers the same top-down flow that the walkthrough uses in Schritt 1.
- **Freilos/Bye walkthrough anchor link left as #glossary-wizard:** Plan 03 added the walkthrough sentence "der fünfte Spieler hat in dieser Runde [Freilos](#glossary-wizard)" before the Freilos glossary entry existed. After this plan, the Freilos entry lives in `#glossary-system`, not `#glossary-wizard`. The link target is slightly imprecise (user lands in wizard subsection, entry is one subsection down) but the anchor still resolves to a live section and the reader can scroll. Fixing this is a Plan-03 scope item, not Plan 04.
- **Rule-1 auto-fix on the Freie Partie entry:** The karambol-begriffe Freie Partie entry linked to `[Bälle-Ziele](#glossary-karambol)`, but after the rewrite the target entry is named "Ballziel" (without "Bälle-" prefix). The link label would have been an internal inconsistency: reader clicks "Bälle-Ziele" and lands on a section with no matching bold-term entry. Auto-fixed to `[Ballziele]` (plural form of Ballziel) while leaving the anchor unchanged. Same pattern as Plan 36A-02 DefaultS cleanup and Plan 36A-03 Tisch-Warmup cleanup.
- **DE authoritative, EN derived:** Continuing the 36A pattern, Task 2 translated from the freshly-updated DE file rather than independently rewriting from the review notes. German technical terms are preserved in parentheses (e.g., "Target balls (Ballziel, `balls_goal`)", "Bye (Freilos)") to maintain the bilingual cross-reference that 36A established.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Internal consistency] Freie Partie entry still referenced "Bälle-Ziele" after the merged Bälle-Ziel entry was replaced with separate Ballziel / Aufnahmebegrenzung entries**
- **Found during:** Task 1 verification (acceptance criteria grep explicitly checked for `Bälle-Ziel (innings_goal)` but not for the plural form `Bälle-Ziele`; visual re-read of the karambol section found the stale link label)
- **Issue:** The Freie Partie entry (line 266 DE) used `[Bälle-Ziele](#glossary-karambol)` as link label. After the rewrite, the matching entry in the karambol-begriffe subsection is named "Ballziel" (`balls_goal`). The old label "Bälle-Ziele" no longer appears as a bold term anywhere in the glossary, so the forward link label is semantically stale.
- **Fix:** Changed `[Bälle-Ziele](#glossary-karambol)` → `[Ballziele](#glossary-karambol)` (plural form of Ballziel, matching the new entry name). Anchor unchanged.
- **Files modified:** docs/managers/tournament-management.de.md (line 266)
- **Committed in:** 51c459a3 (folded into Task 1 commit)
- **Rationale:** Rule 1 (internal factual inconsistency — stale label pointing at a renamed entry). Same pattern as Plan 36A-02 DefaultS cleanup and Plan 36A-03 Tisch-Warmup cleanup.
- **Note:** The EN equivalent line (Straight Rail entry at line 271 EN) already reads "Target balls for NDM classes typically range…" without a Markdown link, so no EN equivalent fix was required.

---

**Total deviations:** 1 (Rule-1 auto-fix for internal consistency)
**Impact on plan:** All positive and negative acceptance criteria for both DE and EN files pass. The Block 6 glossary rewrite is complete and internally consistent with the walkthrough corrections from Plans 01-03.

## Issues Encountered

- **PreToolUse READ-BEFORE-EDIT hook:** The hook fires on every Edit attempt regardless of recent reads, as in Plans 36A-01, 02, 03. Each Edit was still applied successfully on first attempt — the hook reminders are non-blocking notifications.
- **DE/EN Freilos/Bye parity gap:** DE has 2 occurrences of "Freilos" (walkthrough + glossary), EN has 1 occurrence of "Bye (Freilos)" because the EN walkthrough phrasing uses lowercase "bye" inline. Both languages have the glossary entry; the walkthrough links still resolve. Parity is structural, not textual.

## Self-Check: PASSED

**Files exist:**
- FOUND: docs/managers/tournament-management.de.md
- FOUND: docs/managers/tournament-management.en.md
- FOUND: .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-04-SUMMARY.md (this file)

**Commits exist:**
- FOUND: 51c459a3 (Task 1 — DE glossary rewrite)
- FOUND: e89137e0 (Task 2 — EN glossary rewrite)

**Acceptance criteria status (DE file):**
- grep "Ballziel" = 8 (≥3 required) PASS
- grep "Aufnahmebegrenzung" = 4 (≥3 required) PASS
- grep "Meldeliste" = 15 (≥4 required) PASS
- grep "Teilnehmerliste" = 22 (≥6 required) PASS
- grep "Logischer Tisch" = 1 (≥1 required) PASS
- grep "Physikalischer Tisch" = 1 (≥1 required) PASS
- grep "TableMonitor" = 4 (≥2 required) PASS
- grep "Turnier-Monitor" = 17 (≥3 required) PASS
- grep "Trainingsmodus" = 1 (≥1 required) PASS
- grep "Freilos" = 2 (≥2 required) PASS
- grep "Default{n}" = 5 (≥2 required) PASS
- grep "T-Plan vs. Default-Plan" = 1 (≥1 required) PASS
- grep -F "Default5" = 0 (must be 0) PASS
- grep -F "DefaultS" = 0 (must be 0) PASS
- grep -F "Bälle-Ziel (innings_goal)" = 0 (must be 0) PASS
- grep -F "ClubCloud-Datenbank bezogen" = 0 (must be 0) PASS
- grep -F "Phase 36 wird dieses Status-Badge" = 0 (must be 0) PASS

**Acceptance criteria status (EN file):**
- grep "Target balls (Ballziel" = 1 (≥1 required) PASS
- grep "Inning limit" = 2 (≥1 required) PASS
- grep "Registration list (Meldeliste)" = 2 (≥1 required) PASS
- grep "Logical table" = 1 (≥1 required) PASS
- grep "Physical table" = 1 (≥1 required) PASS
- grep "TableMonitor" = 4 (≥1 required) PASS
- grep "Training mode" = 1 (≥1 required) PASS
- grep "Bye (Freilos)" = 1 (≥1 required) PASS
- grep "Default{n}" = 5 (≥2 required) PASS
- grep -F "Default5" = 0 (must be 0) PASS
- grep -F "sourced from the ClubCloud database" = 0 (must be 0) PASS
- grep -F "Phase 36 will make this status badge more prominent" = 0 (must be 0) PASS

**Cross-file glossary parity (structural):**
- Logischer Tisch / Logical table: DE=1, EN=1 PASS
- TableMonitor: DE=4, EN=4 PASS
- Trainingsmodus / Training mode: DE=1, EN=1 PASS
- Freilos / Bye: DE=2, EN=1 PASS (structural parity — both have glossary entry; DE walkthrough uses "Freilos" directly, EN walkthrough uses inline "bye" which isn't counted as a term occurrence)

## Next Plan Readiness

- **Plan 36A-05 (next wave):** Ready. The glossary now defines every term that Plans 01-03 forward-link into (Meldeliste, Teilnehmerliste, Ballziel, Aufnahmebegrenzung, TableMonitor, Freilos, Logischer/Physikalischer Tisch). Later plans can reference these entries confidently.
- **Plan 36A-06 (Appendix):** The Teilnehmerliste entry adds a forward link to `#appendix-nachmeldung`, joining the existing `#appendix-no-invitation`, `#appendix-missing-player`, `#appendix-rangliste-manual`, `#appendix-cc-upload`, and `#appendix-cc-csv-upload` anchors that Plan 06 is responsible for creating. mkdocs strict will continue to emit broken-link warnings for these six anchors until Plan 06 closes them — acceptable mid-wave state.
- **Plan 36A-07 (i18n/reflow):** Should revisit the DE/EN Freilos/Bye walkthrough link target (`#glossary-wizard` → `#glossary-system`) if it decides to enforce exact anchor-to-entry precision. Not blocking.

---
*Phase: 36A-turnierverwaltung-doc-accuracy*
*Plan: 04 (Block 6 Glossary Rewrite)*
*Completed: 2026-04-14*
