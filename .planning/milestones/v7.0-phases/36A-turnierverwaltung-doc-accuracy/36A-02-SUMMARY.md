---
phase: 36A-turnierverwaltung-doc-accuracy
plan: 02
subsystem: docs
tags: [tournament-management, walkthrough, doc-accuracy, bilingual, mkdocs, block-3]

requires:
  - phase: 36A-turnierverwaltung-doc-accuracy
    plan: 01
    provides: Block 1+2 baseline (Schritte 1-5 corrected, intro callout, forward links)
provides:
  - Schritt 6 (Mode selection) with dynamic `Default{n}` plan framing (no more "three cards" / "DefaultS" myth)
  - Schritte 7+8 merged into one parametrisation page (info callout)
  - 7 essential start-form parameters explicitly named: Tischzuordnung, Ballziel (balls_goal), Aufnahmebegrenzung (innings_goal), Spielabschluss, auto_upload_to_cc, Timeout, Nachstoß
  - Ballziel vs. Aufnahmebegrenzung disambiguation (correct i18n keys)
  - Logical-vs-physical table mapping concept introduced (step-8-tables now sub-section)
  - Scoreboard-to-table binding documented as not-fixed (manual selection at scoreboard)
  - auto_upload_to_cc forward link to #appendix-cc-upload (Plan 36A-06)
  - Tip-block correction: "before starting the tournament" (not "after")
affects: [36A-03, 36A-04, 36A-05, 36A-06, 36A-07]

tech-stack:
  added: []
  patterns:
    - bilingual mirror discipline (DE first, EN translated 1:1)
    - block-scoped grep verification (per-finding)
    - forward links to Plan 36A-06 appendix anchors
    - Rule 3 auto-extension: glossary/troubleshooting DefaultS→Default{n} for doc-wide consistency

key-files:
  created:
    - .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-02-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "Step-8 anchor preserved: despite demoting Schritt 8 to an H4 sub-section of Schritt 7, the `<a id=\"step-8-tables\"></a>` anchor is kept so existing forward links (from Plan 36A-01 and earlier) continue to work without churn"
  - "Rule 3 extension: glossary/troubleshooting references to DefaultS/Default5 were also updated to Default{n} even though they live outside Block-3 line range — necessary for internal consistency and to satisfy the plan's explicit `! grep -F DefaultS` verify"
  - "Ballziel uses `balls_goal` key (not `innings_goal`): the plan's must_haves correctly disambiguate these as TWO parameters; the old wizard text mixed them up, this plan fixes the mix-up"
  - "DE authoritative, EN derived: Task 2 used the freshly-updated DE text as translation source, following Plan 36A-01's pattern"

patterns-established:
  - "Block-3-style doc rewrite: large region replacement (~27 lines) executed as one Edit, then verification by multi-criteria grep (10+ patterns per file)"

requirements-completed: [DOC-ACC-02]

duration: 22min
completed: 2026-04-14
---

# Phase 36A Plan 02: Block 3 Factual Corrections Summary

**Tournament-management walkthrough Schritte 6-8 rewritten: dynamic `Default{n}` plan framing replaces the "three cards with DefaultS" myth, Schritte 7+8 merged into one parametrisation page, the 7 essential start-form parameters are explicitly listed with correct i18n keys, `balls_goal`/`innings_goal` disambiguated, logical-vs-physical table mapping introduced, and `auto_upload_to_cc` documented with forward link to the appendix.**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-04-14
- **Completed:** 2026-04-14
- **Tasks:** 2/2
- **Files modified:** 2
- **Findings addressed:** F-36-12..F-36-23 (12 findings)

## Accomplishments

- Schritt 6 first paragraph (DE+EN) rewritten: "one or more cards" + dynamic `Default{n}` replaces the incorrect "three cards with DefaultS" claim
- Redundant "Welchen Turnierplan wählen?" / "Which tournament plan should I pick?" tip block removed (F-36-13)
- Schritt 7 renamed "Start-Parameter und Tischzuordnung ausfüllen" / "Start parameters and table assignment"
- New info callout "Schritte 7 und 8 leben auf derselben Seite" / "Steps 7 and 8 live on the same page" — honest about the UI being one page
- Vague "ca. 15 Feldern" / "approximately 15 fields" removed
- 7 essential parameters bullet-listed with explicit i18n keys:
  1. Tischzuordnung (cross-ref to sub-section)
  2. Ballziel (`balls_goal`) — target caroms, 150 typical
  3. Aufnahmebegrenzung (`innings_goal`) — max innings, 50 typical, 0=unlimited
  4. Spielabschluss (Manager vs Spieler)
  5. `auto_upload_to_cc` — with forward link to `#appendix-cc-upload`
  6. Timeout-Kontrolle
  7. Nachstoß — discipline-conditional rule variant
- "Bälle vor" clarified as individual handicap parameter, not general target
- Schritt 8 demoted to `#### Tischzuordnung (Unter-Abschnitt von Schritt 7)` — anchor `step-8-tables` preserved
- Logical-vs-physical table mapping explained with BG Hamburg example
- Scoreboard binding documented as not-fixed, selected manually at the scoreboard, routed via TableMonitor of the logical table
- Tip-block correction: "nach dem Turnier" → "vor dem Start des Turniers" / "after the tournament" → "before starting the tournament"
- Rule-3 extension: glossary and troubleshooting references to DefaultS/Default5 also updated to `Default{n}` for doc-wide consistency (DE lines 252, 254, 295; EN lines 262, 264, 303)

## Findings Addressed

| Finding  | Tier | Description                                                       | Where applied                                      |
|----------|------|-------------------------------------------------------------------|----------------------------------------------------|
| F-36-12  | A    | DefaultS → `Default{n}` (dynamic plan)                            | DE Edit 1 (Schritt 6); EN Edit 1 (Step 6) + glossary/TS |
| F-36-13  | A    | Remove redundant "Welchen Turnierplan wählen?" tip block          | DE Edit 1; EN Edit 1                               |
| F-36-14  | A    | Tip-block "check after the tournament" → "before starting"        | DE Edit 3; EN Edit 3                               |
| F-36-15  | META | Merge Schritte 7+8 into one parametrisation page                  | DE Edit 3 (info callout + sub-section); EN Edit 3 |
| F-36-16  | A    | Remove "ca. 15 Feldern" / "approximately 15 fields" vague claim   | DE Edit 3; EN Edit 3                               |
| F-36-17  | A    | Ballziel is `balls_goal` (distinct from `innings_goal`)           | DE Edit 3 (Ballziel bullet); EN Edit 3             |
| F-36-18  | A    | Aufnahmebegrenzung is `innings_goal` (distinct parameter)         | DE Edit 3 (Aufnahmebegrenzung bullet); EN Edit 3   |
| F-36-19  | A    | Spielabschluss (manager vs player) documented                     | DE Edit 3; EN Edit 3                               |
| F-36-20  | A    | Timeout control + Nachstoß documented as discipline-conditional   | DE Edit 3; EN Edit 3                               |
| F-36-21  | A    | Logical-vs-physical table distinction introduced                  | DE Edit 3 (Tischzuordnung sub-section); EN Edit 3  |
| F-36-22  | A    | Scoreboard-table binding documented as not-fixed                  | DE Edit 3 (Scoreboard-Verbindung); EN Edit 3       |
| F-36-23  | A    | `auto_upload_to_cc` parameter with forward link to appendix       | DE Edit 3; EN Edit 3                               |

## Task Commits

1. **Task 1: Apply Block 3 corrections to tournament-management.de.md** — `e8fd1a11` (docs)
2. **Task 2: Mirror Block 3 corrections to tournament-management.en.md** — `5216e089` (docs)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — 32 insertions, 23 deletions; Schritte 6-8 region (~lines 103-160) rewritten; glossary (252, 254) + troubleshooting (295) updated for Default{n} consistency
- `docs/managers/tournament-management.en.md` — 36 insertions, 27 deletions; Steps 6-8 mirror; glossary (262, 264) + troubleshooting (303) updated

## Decisions Made

- **Step-8 anchor preserved:** Even though Schritt 8 is now an H4 sub-section of Schritt 7 (not a separate H3), the `<a id="step-8-tables"></a>` anchor is kept so existing forward links from Schritt 7 body ("siehe Abschnitt unten") and any other documents that link to `#step-8-tables` continue to resolve. mkdocs strict build stays green on this anchor.
- **Rule 3 glossary/troubleshooting extension:** The plan's automated verify uses `! grep -F "DefaultS"` which would fail because lines 252/254/295 of the DE glossary+troubleshooting still named `DefaultS` / `Default5`. These references are out of Block-3 line range but within the same file. I applied a minimal consistency fix (replace with `Default{n}`) because (a) the plan's `must_haves.truths[0]` says "uses `Default{n}` wording" — this is a doc-wide invariant, not scoped to Schritt 6-8 only; (b) leaving contradictory DefaultS references in the glossary would confuse volunteers reading both sections; (c) the plan's verify gate explicitly forbids DefaultS. This is Rule 3 (blocking verify) + Rule 1 (internal inconsistency bug).
- **`balls_goal` vs `innings_goal` key assignment:** Plan's `must_haves` is explicit — `balls_goal` = Ballziel (target caroms), `innings_goal` = Aufnahmebegrenzung (inning limit). This matches actual Rails model columns. The old doc had these swapped (it named `innings_goal` as "Bälle vor" which is a category error).
- **DE authoritative, EN derived:** Task 2 used the freshly-updated DE file as the translation source rather than re-deriving from OLD EN. Same pattern as Plan 36A-01.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking verify] Glossary/troubleshooting `DefaultS`/`Default5` references**
- **Found during:** Task 1 DE verification grep
- **Issue:** After rewriting Schritt 6 per plan, `grep -c DefaultS` still returned 3 (lines 252, 254, 295 — glossary entries + troubleshooting problem statement). The plan's `<automated>` verify gate was `! grep -F "DefaultS"` which would fail.
- **Fix:** Updated all three out-of-block references to `Default{n}` (line 252: Turniermodus glossary entry; line 254: Turnierplan-Kürzel glossary entry — also fixed stray "Default5" typo; line 295: ts-wrong-mode troubleshooting problem statement). Same three-site fix applied to EN (lines 262, 264, 303).
- **Files modified:** docs/managers/tournament-management.de.md (Edit after main Block-3 edit); docs/managers/tournament-management.en.md (same)
- **Commits:** e8fd1a11 (DE) and 5216e089 (EN) — folded into the task commits
- **Rationale:** Rule 3 (verify gate would otherwise fail) + Rule 1 (internal factual inconsistency: it would be wrong for the wizard to say "Default{n}" while the glossary says "DefaultS"). The plan's must_haves.truths[0] treats `Default{n}` as a doc-wide invariant, so this is within plan intent even though line ranges are technically outside Block 3.

### Verification Artifacts

**2. [Verification artifact] grep "before starting the tournament" returned 0 (EN) due to line wrap**
- **Found during:** Task 2 verification grep
- **Issue:** The replacement text `"verify the settings **before starting the tournament**"` wraps across two lines in the admonition (lines 139-140), so a single-line `grep -c` returned 0 even though content is present.
- **Fix:** Confirmed via multiline grep `before starting\s+the tournament` — matches at lines 139-140. No content change needed. Same pattern as Plan 36A-01 "Zurücksetzen des Turnier-Monitors" artifact.
- **Files modified:** none (content is correct; grep artifact only)
- **Committed in:** N/A

---

**Total deviations:** 2 (one Rule-3 auto-fix, one verification artifact)
**Impact on plan:** All acceptance criteria satisfied. Block 3 factual corrections are complete and doc-wide consistent.

## Self-Check: PASSED

**Files exist:**
- FOUND: docs/managers/tournament-management.de.md
- FOUND: docs/managers/tournament-management.en.md
- FOUND: .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-02-SUMMARY.md

**Commits exist:**
- FOUND: e8fd1a11 (Task 1 — DE)
- FOUND: 5216e089 (Task 2 — EN)

**Acceptance criteria status (DE file):**
- grep "balls_goal" = 1 (≥1 required) PASS
- grep "Default{n}" = 5 (≥1 required) PASS
- grep "logischen Tisch" = 4 (≥2 required) PASS
- grep "auto_upload_to_cc" = 2 (≥1 required) PASS
- grep "appendix-cc-upload" = 1 (≥1 required) PASS
- grep -F "DefaultS" = 0 (must be 0) PASS
- grep -F "Bälle vor** / **Bälle-Ziel" = 0 (must be 0) PASS
- grep -F "ca. 15 Feldern" = 0 (must be 0) PASS
- grep -F "Welchen Turnierplan wählen?" = 0 (must be 0) PASS
- grep "step-8-tables" = 1 (≥1 required, anchor preserved) PASS

**Acceptance criteria status (EN file):**
- grep "balls_goal" = 1 (≥1 required) PASS
- grep "Default{n}" = 5 (≥1 required) PASS
- grep "logical table" = 4 (≥3 required) PASS
- grep "auto_upload_to_cc" = 2 (≥1 required) PASS
- grep "appendix-cc-upload" = 1 (≥1 required) PASS
- grep -F "DefaultS" = 0 (must be 0) PASS
- grep -F "Which tournament plan to choose?" = 0 (must be 0) PASS
- grep -F "approximately 15 fields" = 0 (must be 0) PASS
- grep -F "verify the settings after the tournament" = 0 (must be 0) PASS
- multiline grep "before starting\\s+the tournament" matches (line-wrap artifact; content present) PASS
- grep "step-8-tables" = 1 (≥1 required, anchor preserved) PASS

## Next Plan Readiness

- **Plan 36A-03 (next block of findings):** Ready. Block 3 has established the Schritte-7+8-merged structure; later blocks can build on `#step-7-start-form` as a stable anchor.
- **Plan 36A-06 (Appendix):** The `#appendix-cc-upload` forward link added in Block 3 is the third outstanding anchor Plan 06 needs to create (alongside the three from Plan 36A-01). Acceptable mid-wave state; mkdocs strict will emit warnings until Plan 06 closes them.

---
*Phase: 36A-turnierverwaltung-doc-accuracy*
*Plan: 02 (Block 3 Factual Corrections — Schritte 6+7+8)*
*Completed: 2026-04-14*
