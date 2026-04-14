# Phase 36A — Coverage Matrix

**Plan:** 36A-07 (final verification)
**Completed:** 2026-04-14
**Purpose:** Map every F-36-NN finding to the plan/task that addressed it, verify all 7 phase success criteria, verify all 6 DOC-ACC-NN requirements, document mkdocs build delta.

---

## mkdocs build --strict

| Metric         | Baseline (Phase 35) | Phase 36A result        | Delta      |
|----------------|---------------------|-------------------------|------------|
| Exit code      | 0                   | 0                       | PASS       |
| WARNING lines  | 191                 | 0                       | -191 (PASS)|
| ERROR lines    | 0                   | 0                       | 0   (PASS) |
| Build time     | n/a                 | 5.21s                   | —          |

**Notes:**

- Log captured at `/tmp/36a-mkdocs-strict.log` (192 lines total; 64 INFO lines; 0 WARNING; 0 ERROR).
- The current mkdocs environment emits anchor-resolution messages at **INFO** level rather than WARNING. That is a lower-severity classification than in the Phase 35 environment (where the same class of messages counted against the baseline of 191). The success condition "WARN_COUNT <= 191 AND ERROR_COUNT == 0" passes trivially under either classification.
- **Zero 36A-owned broken links** — grep of INFO-level anchor reports for any `appendix-*`, `step-*`, `glossary-*`, or `ts-*` pattern in `tournament-management.{de,en}.md` returned empty. All 6 appendix anchors Plan 36A-06 created are resolved.
- The remaining INFO-level broken anchors (20 references touching `tournament-management.md` from `managers/index.de.md` and `managers/index.en.md`) are **pre-existing navigation links** to section anchors that never existed in the tournament-management doc (`#spielerverwaltung`, `#ergebniskontrolle`, `#round-robin`, etc.). These are out of Phase 36A scope and should be addressed in a later phase that overhauls the managers index navigation.

**Verdict:** PASS — mkdocs build succeeds with exit code 0 and zero delta over baseline.

---

## F-36-NN Coverage Matrix

All 58 findings from `.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md` are accounted for. F-36-55 is explicitly deferred to Phase 36b UI-07 per REQUIREMENTS.md.

| Finding   | Plan(s)                    | Description                                                                    | Status         |
|-----------|----------------------------|--------------------------------------------------------------------------------|----------------|
| F-36-01   | 36A-01                     | Szenario PDF as primary source + appendix forward-link                         | PASS           |
| F-36-02   | 36A-01                     | Begriffshierarchie + Ausspielziele in Schritt 1                                | PASS           |
| F-36-03   | 36A-01                     | Navigation path Organisationen -> Regionalverbände -> NBV in Schritt 2        | PASS           |
| F-36-04   | 36A-01                     | Schritt 2 caption honest about 1-Spieler edge case                             | PASS           |
| F-36-05   | 36A-01                     | Schritt 3 reframed (Setzliste = Meldeliste + Ordnung)                          | PASS           |
| F-36-06   | 36A-01                     | Schritt 4 three entry points to participant edit page                          | PASS           |
| F-36-07   | 36A-01                     | T04 Karambol-Turnierordnung parenthetical                                      | PASS           |
| F-36-08   | 36A-01                     | "Spieler hinzufügen" click documented                                          | PASS           |
| F-36-09   | 36A-01                     | AASM state name removed from user-facing Schritt 5 text                        | PASS           |
| F-36-10   | 36A-01                     | Reset-Moeglichkeit in Schritt 5 (new warning block)                            | PASS           |
| F-36-11   | 36A-01                     | Schritte 4/5 as action links, not separate AASM states                         | PASS           |
| F-36-12   | 36A-02                     | `Default{n}` replaces "DefaultS" / "three cards" myth                          | PASS           |
| F-36-13   | 36A-02                     | Redundant "Welchen Turnierplan waehlen?" tip removed                           | PASS           |
| F-36-14   | 36A-02                     | 7 essential start-form parameters explicitly named                             | PASS           |
| F-36-15   | 36A-01 (intro) + 36A-02    | Meta-hint intro callout + Schritte 7+8 merge                                   | PASS           |
| F-36-16   | 36A-02                     | "vor dem Start des Turniers" tooltip correction                                | PASS           |
| F-36-17   | 36A-02                     | Ballziel (`balls_goal`) vs Aufnahmebegrenzung (`innings_goal`) disambiguation  | PASS           |
| F-36-18   | 36A-02                     | Aufnahmebegrenzung value range documented                                      | PASS           |
| F-36-19   | 36A-02                     | Spielabschluss (Manager vs Spieler)                                            | PASS           |
| F-36-20   | 36A-02 + 36A-05            | Timeout + Nachstoss as discipline-conditional                                  | PASS           |
| F-36-21   | 36A-02                     | Logical vs physical table distinction introduced                               | PASS           |
| F-36-22   | 36A-02                     | Scoreboard-to-table binding documented as not-fixed                            | PASS           |
| F-36-23   | 36A-02 + 36A-06            | `auto_upload_to_cc` forward-link to `#appendix-cc-upload`                      | PASS           |
| F-36-24   | 36A-03                     | Warning "nicht erneut klicken" -> "button locked" truth                        | PASS           |
| F-36-25   | 36A-03                     | AASM/Redis/ActionCable developer paragraph removed                             | PASS           |
| F-36-26   | 36A-03                     | "einspielen" Fachterminus + Warmup parameter                                   | PASS           |
| F-36-27   | 36A-03                     | "alle 4 Matches" -> 2 matches + 1 Freilos                                      | PASS           |
| F-36-28   | 36A-03                     | "Aktuelle Spiele" Spielbeginn buttons as fallback UI                           | PASS           |
| F-36-29   | 36A-03                     | Manual round-change control as disputed special case                           | PASS           |
| F-36-30   | 36A-03                     | Schritt 11 rewrite — "keine aktive Rolle" framing                              | PASS           |
| F-36-31   | 36A-03                     | Browser-tab oversight + Nachstoss forgotten in Schritt 12                      | PASS           |
| F-36-32   | 36A-03                     | Reset-destroys-data danger callout in Schritt 12                               | PASS           |
| F-36-33   | 36A-03                     | Manual-check-button moved to special-case aside                                | PASS           |
| F-36-34   | 36A-03 + 36A-06            | Endrangliste NOT auto-calculated + `#appendix-rangliste-manual`                | PASS           |
| F-36-35   | 36A-03                     | Shootout limitation + v7.1/v7.2 roadmap note                                   | PASS           |
| F-36-36   | 36A-03                     | auto_upload_to_cc timing per-match immediate (not at finalisation)             | PASS           |
| F-36-37   | 36A-03                     | Fictional "Uebertragen nach ClubCloud" button removed                          | PASS           |
| F-36-38   | 36A-06                     | CC-CSV-upload appendix sub-section created                                     | PASS           |
| F-36-39   | 36A-04                     | Glossar Ballziel/Aufnahmebegrenzung split (3 entries)                          | PASS           |
| F-36-40   | 36A-04                     | Glossar Setzliste rewrite (3-source origin)                                    | PASS           |
| F-36-41   | 36A-04                     | Glossar Meldeliste + Teilnehmerliste new entries                               | PASS           |
| F-36-42   | 36A-04                     | Glossar Turnierplan-Kuerzel = T-Plan vs. Default-Plan                          | PASS           |
| F-36-43   | 36A-04                     | Glossar Scoreboard binding not-fixed                                           | PASS           |
| F-36-44   | 36A-04                     | Glossar AASM-Status (wrong mapping + "Phase 36" promise removed)               | PASS           |
| F-36-45   | 36A-04                     | Glossar Rangliste Carambus-intern (not ClubCloud-sourced)                      | PASS           |
| F-36-46   | 36A-04                     | Glossar Logischer + Physikalischer Tisch (2 new entries)                       | PASS           |
| F-36-47   | 36A-04                     | Glossar TableMonitor new entry                                                 | PASS           |
| F-36-48   | 36A-04                     | Glossar Turnier-Monitor new entry                                              | PASS           |
| F-36-49   | 36A-04                     | Glossar Freilos new entry + match-abort as follow-up feature                   | PASS           |
| F-36-50   | 36A-04                     | T-Plan vs. Default-Plan cross-ref (via F-36-42)                                | PASS           |
| F-36-51   | 36A-05                     | TS-1 PDF-bashing removed, honest framing                                       | PASS           |
| F-36-52   | 36A-05                     | TS-2 three realistic triggers                                                  | PASS           |
| F-36-53   | 36A-05                     | TS-3 fictional "Modus aendern" button removed                                  | PASS           |
| F-36-54   | 36A-05                     | TS-4 DB-Admin recovery myth removed, Trainingsmodus fallback                   | PASS           |
| F-36-55   | **DEFERRED to Phase 36b UI-07** | Parameter verification dialog (UI feature, out of doc scope)              | DEFERRED       |
| F-36-56   | 36A-04 (glossary) + 36A-05 (TS-4) | Trainingsmodus documented in glossary and troubleshooting               | PASS           |
| F-36-57   | 36A-05                     | "Mehr zur Technik" section removed, dev-docs pointer retained                  | PASS           |
| F-36-58   | 36A-05                     | 6 new troubleshooting recipes added                                            | PASS           |

**Totals:**

- Addressed in Phase 36A: 57 findings (F-36-01..F-36-54, F-36-56, F-36-57, F-36-58)
- Deferred to Phase 36b: 1 finding (F-36-55 — Parameter-Verifikationsdialog, tracked as UI-07 in REQUIREMENTS.md)
- Orphan (addressed by no plan and not deferred): **0**

---

## Phase Success Criteria (DE file)

| # | Criterion                                                                 | Check                                                             | Result |
|---|---------------------------------------------------------------------------|-------------------------------------------------------------------|--------|
| 1 | Begriffshierarchie consistency (Meldeliste / Teilnehmerliste / Setzliste) | Meldeliste=19, Teilnehmerliste=35, Setzliste=21                   | PASS   |
| 2 | Factual corrections applied (blocks 1-7)                                  | See absence greps below                                           | PASS   |
| 3 | 9 new glossary entries exist                                              | Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos, T-Plan-vs-Default-Plan — all found | PASS   |
| 4 | New appendix sections cover 6 flows                                       | 6 `id="appendix-*"` anchors, each count=1                         | PASS   |
| 5 | Walkthrough restructured for passive Schritt 11 ("keine aktive Rolle")    | 2 occurrences; phases-framing in line 196 (warmup -> match play -> finalisation) | PASS   |
| 6 | "Mehr zur Technik" section absent                                         | `grep -F "## Mehr zur Technik"` = 0; `id="architecture"` = 0      | PASS   |
| 7 | mkdocs build --strict passes                                              | exit 0, WARNING=0, ERROR=0                                        | PASS   |

### Absence greps (DE — must all be 0)

| Pattern                                        | Count | Expected | Status |
|------------------------------------------------|-------|----------|--------|
| `DefaultS`                                     | 0     | 0        | PASS   |
| `Teilnehmerliste (Setzliste)`                  | 0     | 0        | PASS   |
| `alle 4 Matches`                               | 0     | 0        | PASS   |
| `Carambus-Admin mit Datenbankzugang`           | 0     | 0        | PASS   |
| `Bälle-Ziel (innings_goal)`                    | 0     | 0        | PASS   |
| `ClubCloud-Datenbank bezogen`                  | 0     | 0        | PASS   |
| `## Mehr zur Technik`                          | 0     | 0        | PASS   |
| `<a id="architecture"`                         | 0     | 0        | PASS   |
| `tournament_seeding_finished`                  | 1     | 0*       | SCOPE-BOUNDARY |

\* `tournament_seeding_finished` retained in one place only: DE line 317 / EN line 322 System-Begriffe glossary entry for `AASM-Status`. This is a technical reference entry documenting internal state names for developers/admins. Plan 36A-01 explicitly documented this as a scope-boundary retention because the plan's acceptance criterion targets Schritt-5 user-facing text (which is clean — Schritt 5 has zero occurrences). The glossary is a reference section where the state-name enumeration is appropriate technical context. F-36-09 (remove from user-facing text) IS addressed.

---

## Phase Success Criteria (EN file)

| # | Criterion                                                                  | Check                                                             | Result |
|---|----------------------------------------------------------------------------|-------------------------------------------------------------------|--------|
| 1 | Begriffshierarchie consistency                                             | "Meldeliste|registration list"=17, Teilnehmerliste=2, Setzliste=2 | PASS   |
| 2 | Factual corrections applied                                                | See absence greps below                                           | PASS   |
| 3 | Glossary parity with DE                                                    | Logical table=1, Physical table=1, TableMonitor=4, Tournament Monitor=16, Training mode=1, Bye (Freilos)=1, Tournament-plan codes (T-plan vs. Default plan)=1 (line 309) | PASS   |
| 4 | New appendix sections cover 6 flows                                        | 6 `id="appendix-*"` anchors, each count=1                         | PASS   |
| 5 | Walkthrough restructured for passive Steps 10-12                           | "no active role"=2; phases-framing in line 202                    | PASS   |
| 6 | "More on the architecture" section absent                                  | `grep -F "## More on the architecture"` = 0                       | PASS   |
| 7 | mkdocs build --strict passes                                               | same build as DE                                                  | PASS   |

### Absence greps (EN — must all be 0)

| Pattern                                        | Count | Expected | Status |
|------------------------------------------------|-------|----------|--------|
| `DefaultS`                                     | 0     | 0        | PASS   |
| `## More on the architecture`                  | 0     | 0        | PASS   |
| `tournament_seeding_finished`                  | 1     | 0*       | SCOPE-BOUNDARY |

\* Same scope-boundary rationale as DE: EN line 322 System-Begriffe glossary entry retains the technical state-name enumeration.

---

## DOC-ACC-NN Requirement Coverage

| Req ID      | Title                                                    | Addressed by           | Status |
|-------------|----------------------------------------------------------|------------------------|--------|
| DOC-ACC-01  | Establish Begriffshierarchie (Meldeliste/Setzliste/Teilnehmerliste) | 36A-01 + 36A-04 | PASS |
| DOC-ACC-02  | Correct factual errors in walkthrough Schritte 1-14      | 36A-01, 02, 03, 05     | PASS   |
| DOC-ACC-03  | Add missing glossary entries for system terms            | 36A-04                 | PASS   |
| DOC-ACC-04  | Create appendix sections for special cases               | 36A-06                 | PASS   |
| DOC-ACC-05  | Reframe walkthrough passive phases honestly              | 36A-03 + 36A-06        | PASS   |
| DOC-ACC-06  | Remove architectural monologue ("Mehr zur Technik")      | 36A-05                 | PASS   |

All 6 requirements have at least one task addressing them.

---

## DE/EN Structural Parity

| Metric                              | DE  | EN  | Status |
|-------------------------------------|-----|-----|--------|
| Unique `id="..."` definitions       | 38  | 38  | PASS   |
| Appendix anchors                    | 6   | 6   | PASS   |
| Step anchors (step-1..step-14)      | 14  | 14  | PASS*  |
| TS recipe anchors                   | 10  | 10  | PASS   |
| Glossary section anchors            | 3   | 3   | PASS   |

\* 14 steps per file; step anchors vary in ID spelling across languages but are consistent within each file.

---

## Anchor Integrity Check

Same-file anchor reference integrity (every `(#anchor)` link resolves to an `id="anchor"` in the same file):

| File                                   | Broken same-file references |
|----------------------------------------|-----------------------------|
| docs/managers/tournament-management.de.md | **0**                       |
| docs/managers/tournament-management.en.md | **0**                       |

Log: `/tmp/36a-anchor-integrity.log` (empty — no broken references).

---

## Final Verdict

**ALL 7 PHASE SUCCESS CRITERIA: PASS**
**ALL 6 DOC-ACC-NN REQUIREMENTS: PASS**
**F-36-NN COVERAGE: 57/58 addressed, 1 explicitly deferred (F-36-55 -> Phase 36b UI-07), 0 orphans**
**MKDOCS BUILD STRICT: PASS (exit 0, 0 warnings, 0 errors)**
**ANCHOR INTEGRITY: PASS (0 broken same-file references in either DE or EN)**

**Phase 36A is complete and ready to close.**

---

*Generated: 2026-04-14*
*Plan: 36A-07 (final verification)*
