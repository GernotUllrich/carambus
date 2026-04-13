---
phase: 35-printable-quick-reference-card
plan: 02
subsystem: docs
tags: [mkdocs, bilingual-skeleton, nav-translations, d-07a, d-08a, atomic-commit]

# Dependency graph
requires:
  - phase: 35-printable-quick-reference-card
    plan: 01
    provides: print.css infrastructure + 191-line post-edit strict baseline (ceiling for D-09)
  - phase: 34-task-first-doc-rewrite
    provides: Phase 34 walkthrough anchors (#walkthrough) used for cross-links + English-based anchor convention
provides:
  - Bilingual quick-reference skeleton files with four fixed English anchors (#before, #during, #after, #scoreboard-shortcuts)
  - mkdocs.yml nav entry under Managers (between Tournament Management and League Management)
  - mkdocs.yml DE nav_translations label (Turnier-Schnellreferenz)
affects:
  - 35-03-PLAN.md (will fill in Before/During/After checklist items under locked anchors)
  - 35-04-PLAN.md (will fill in scoreboard shortcut cheat sheet under #scoreboard-shortcuts)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-07a atomic commit gate: file creation + mkdocs.yml nav + nav_translations in a single commit (3 files, zero other touches)"
    - "D-08a bilingual skeleton hard gate: placeholder-only skeleton commits before any prose (mirrors Phase 34 D-05)"
    - "D-08 English-based anchor slugs via inline <a id='...'></a> tags on their own line above translated H2 headings (carried from Phase 34 D-05a)"

key-files:
  created:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml
    - .planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt

key-decisions:
  - "DE nav label = 'Turnier-Schnellreferenz' (planner discretion per D-07a — hyphenated-compound pattern matching Liga-Management, ClubCloud-Integration)"
  - "Placeholder bodies use _(...)_ markers explicitly referencing Plans 35-03 / 35-04 so the D-08a gate is visually obvious"
  - "H2 headings translated per language but anchors byte-identical English slugs (#before, #during, #after, #scoreboard-shortcuts)"

requirements-completed:
  - QREF-01

# Metrics
duration: ~4min
completed: 2026-04-13
---

# Phase 35 Plan 02: Bilingual Skeleton + mkdocs Nav Summary

**Bilingual tournament-quick-reference.{de,en}.md skeleton landed with four byte-identical English anchors plus mkdocs nav entry and Turnier-Schnellreferenz DE label in a single atomic carambus_master commit — D-07a atomicity gate and D-08a bilingual skeleton hard gate both satisfied, mkdocs strict warnings unchanged at 191.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-13T17:38:55Z
- **Completed:** 2026-04-13T17:42:00Z
- **Tasks:** 3
- **Files created:** 2 (carambus_master)
- **Files modified:** 2 (1 carambus_master, 1 carambus_api)
- **Atomic commit:** 2db7c09e (carambus_master, 3 files, +52/-0)

## Accomplishments

- Created `tournament-quick-reference.de.md` with H1 + four H2 sections anchored via English slugs (`#before`, `#during`, `#after`, `#scoreboard-shortcuts`) and a single cross-link to `tournament-management.md#walkthrough`; placeholder bodies only — zero checklist items, zero prose, zero callouts (D-08a hard gate)
- Created `tournament-quick-reference.en.md` mirror with byte-identical anchor IDs; DE/EN anchor-diff empty
- Inserted one-line mkdocs.yml nav entry under Managers between `Tournament Management` and `League Management` (line 142, D-07b insertion position)
- Inserted one-line mkdocs.yml `plugins.i18n.nav_translations` DE label `Tournament Quick Reference: Turnier-Schnellreferenz` between Tournament Management and League Management DE labels (line 66)
- Committed all 3 carambus_master files in a single atomic commit (`2db7c09e`) with `D-07a` and `D-08a` both cited in the commit message body — zero other files touched (D-07a atomicity gate)
- Re-ran `mkdocs build --strict` → 191 WARNING log lines (delta = 0 vs Plan 01 post-edit baseline), zero new warnings reference `tournament-quick-reference` (D-09 gate)
- Recorded `post_plan_02_warning_log_lines: 191` and `plan_02_commit_sha: 2db7c09e` in `35-01-BASELINE.txt`

## Anchor List (D-08 verification)

| Anchor slug | DE heading | EN heading |
|---|---|---|
| `#before` | Vor dem Turniertag-Start (ca. 2 Stunden vorher) | Before the Tournament Starts (about 2 hours ahead) |
| `#during` | Während des Turniers | During the Tournament |
| `#after` | Nach der letzten Partie | After the Final Match |
| `#scoreboard-shortcuts` | Scoreboard-Kürzel (Griffbereit) | Scoreboard Keyboard Shortcuts (Within Arm's Reach) |

DE/EN anchor parity verified:
```
$ diff <(grep -oE '<a id="[^"]+"' .../tournament-quick-reference.de.md | sort) \
       <(grep -oE '<a id="[^"]+"' .../tournament-quick-reference.en.md | sort)
(empty)
```

## Task Commits

Per the D-07a atomicity gate, Tasks 1, 2, and 3 share a single atomic commit in carambus_master. The carambus_api-side SUMMARY and BASELINE update will land in a separate follow-up commit.

1. **Tasks 1 + 2 + 3 (atomic, carambus_master):** `2db7c09e` — `docs(35-02): add bilingual quick-reference skeleton + mkdocs nav`

## Files Created/Modified

- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md` (created, 25 lines / +25 insertions) — DE skeleton, 4 anchors, placeholder bodies
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md` (created, 25 lines / +25 insertions) — EN mirror, byte-identical anchors
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml` (modified, +2/-0) — nav entry + DE label
- `.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt` (modified, +4 lines) — post_plan_02 metrics + commit SHA

### Exact mkdocs.yml diff

```diff
--- a/mkdocs.yml
+++ b/mkdocs.yml
@@ -63,6 +63,7 @@ plugins:
             Managers: Für Turniermanager
             Manager Guide: Manager-Leitfaden
             Tournament Management: Turnierverwaltung
+            Tournament Quick Reference: Turnier-Schnellreferenz
             League Management: Liga-Management
             Single Tournament: Einzelturnier
             Table Reservation: Tischreservierung
@@ -138,6 +139,7 @@ nav:
   - Managers:
       - managers/index.md
       - Tournament Management: managers/tournament-management.md
+      - Tournament Quick Reference: managers/tournament-quick-reference.md
       - League Management: managers/league-management.md
       - Single Tournament: managers/single-tournament.md
       - Table Reservation: managers/table-reservation.md
```

Exactly +2 insertions, 0 deletions, no reorder of any other line — matches Plan 02 output spec.

### mkdocs strict gate (D-09)

- **Plan 01 post-edit baseline:** 191 WARNING log lines
- **Plan 02 post-edit count:** 191 WARNING log lines
- **Delta:** 0
- **Plan 35 ceiling (from 35-01-BASELINE.txt):** 191
- **Gate:** SATISFIED (no new warnings, none referencing `tournament-quick-reference`)

## D-07a and D-08a Hard Gate Confirmation

**D-07a (atomic commit gate):** ✓ SATISFIED
- `git log -1 --name-only` on commit `2db7c09e` lists exactly three files: `docs/managers/tournament-quick-reference.de.md`, `docs/managers/tournament-quick-reference.en.md`, `mkdocs.yml`
- No other files touched; commit message body cites `D-07a atomicity gate`

**D-08a (bilingual skeleton hard gate):** ✓ SATISFIED
- Both skeleton files contain zero task-list items (`grep -c '^- \[ \]'` returns 0 for both)
- Both skeleton files contain zero `<!-- ref: F-NN -->` forward-reference callouts (prose-gated for 35-03)
- Both files contain only placeholder bodies matching `_(.*folgt.*)_` / `_(.*TBD.*)_` patterns
- Commit message body cites `D-08a bilingual skeleton hard gate: prose follows in Plan 35-03 ... Skeleton must commit before any prose`

**D-07b (insertion position):** ✓ SATISFIED
- nav entry at mkdocs.yml:142 between Tournament Management (:141) and League Management (:143)
- nav_translations entry at mkdocs.yml:66 between Tournament Management (:65) and League Management (:67)

## Decisions Made

- **DE nav label:** `Turnier-Schnellreferenz` (not `Turnier-Quick-Reference-Karte`) — shorter, follows hyphenated-compound pattern used elsewhere in nav_translations (Liga-Management, ClubCloud-Integration)
- **Placeholder marker wording:** `_(... folgt in Plan 35-03/04.)_` (DE) and `_(... TBD in Plan 35-03/04.)_` (EN) — explicit plan references make the D-08a gate visually obvious in the committed files
- **Cross-link in H1 intro only:** Single link to `tournament-management.md#walkthrough` — not per-H2 — to keep the skeleton lean; per-item deep-links per D-05/D-05b are a Plan 35-03 concern

## Deviations from Plan

None — plan executed exactly as written. Tasks 1, 2, and 3 completed in order; all automated verify checks and acceptance criteria passed on the first run. No auto-fixes under Rules 1–3, no architectural decisions under Rule 4.

## Issues Encountered

None. All three file operations, the mkdocs strict build, and the atomic commit succeeded on first try.

## Known Stubs

The two skeleton files are intentional stubs — placeholder bodies marking locked anchors for prose work in Plans 35-03 and 35-04. This is the D-08a bilingual skeleton hard gate: anchors land first so downstream plans can target them atomically. Not a defect.

| File | Line | Placeholder | Resolved by |
|---|---|---|---|
| tournament-quick-reference.de.md | 5 | `_(Prosa folgt in Plan 35-03. Scoreboard-Kürzelliste folgt in Plan 35-04.)_` | Plans 35-03, 35-04 |
| tournament-quick-reference.de.md | 10 | `_(Checkliste folgt in Plan 35-03.)_` under `#before` | Plan 35-03 |
| tournament-quick-reference.de.md | 15 | `_(Checkliste folgt in Plan 35-03.)_` under `#during` | Plan 35-03 |
| tournament-quick-reference.de.md | 20 | `_(Checkliste folgt in Plan 35-03.)_` under `#after` | Plan 35-03 |
| tournament-quick-reference.de.md | 25 | `_(Tastenkürzel-Tabelle und ASCII-Button-Leiste folgen in Plan 35-04.)_` | Plan 35-04 |
| tournament-quick-reference.en.md | 5 | `_(Prose content lands in Plan 35-03. Scoreboard shortcut cheat sheet lands in Plan 35-04.)_` | Plans 35-03, 35-04 |
| tournament-quick-reference.en.md | 10 | `_(Checklist content TBD in Plan 35-03.)_` under `#before` | Plan 35-03 |
| tournament-quick-reference.en.md | 15 | `_(Checklist content TBD in Plan 35-03.)_` under `#during` | Plan 35-03 |
| tournament-quick-reference.en.md | 20 | `_(Checklist content TBD in Plan 35-03.)_` under `#after` | Plan 35-03 |
| tournament-quick-reference.en.md | 25 | `_(Shortcut table and ASCII button strip TBD in Plan 35-04.)_` | Plan 35-04 |

All stubs are plan-tracked and will be resolved in Plans 35-03 (checklist prose) and 35-04 (scoreboard shortcut cheat sheet).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Plan 35-03 (Before/During/After checklist prose) is UNBLOCKED.** The D-08a skeleton hard gate is satisfied: the bilingual anchors are committed, so Plan 03 can safely insert task-list items under each `#before` / `#during` / `#after` heading without touching the anchor IDs.
- **Plan 35-04 (scoreboard shortcut cheat sheet) is UNBLOCKED.** The `#scoreboard-shortcuts` anchor is committed and ready to receive the markdown table + ASCII keycap strip per D-03.
- **D-09 ceiling carried forward:** Plans 03, 04, and 05 all must keep post-edit mkdocs strict warning count ≤ 191 (recorded in `35-01-BASELINE.txt`).
- **Nav entry reachability:** Both `managers/tournament-quick-reference.md` (resolves to `.en.md` by default) and the DE locale (resolves to `.de.md` via mkdocs-static-i18n) are reachable in the Managers sidebar between Tournament Management and League Management.

## Self-Check: PASSED

- Files verified on disk:
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml (contains both `Tournament Quick Reference: managers/tournament-quick-reference.md` and `Tournament Quick Reference: Turnier-Schnellreferenz`)
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt (contains `post_plan_02_warning_log_lines: 191` and `plan_02_commit_sha: 2db7c09e`)
- Commits verified in git history:
  - FOUND: 2db7c09e (carambus_master, 3 files, atomic)
- Verify commands: DE/EN anchor diff empty, nav+nav_translations counts both 1, mkdocs strict delta 0, commit message contains both D-07a and D-08a

---

*Phase: 35-printable-quick-reference-card*
*Completed: 2026-04-13*
