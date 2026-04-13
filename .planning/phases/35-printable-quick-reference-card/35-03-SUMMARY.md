---
phase: 35-printable-quick-reference-card
plan: 03
subsystem: docs
tags: [docs, checklist, bilingual-prose, task-list, mkdocs-strict, f-nn-forward-refs]

# Dependency graph
requires:
  - phase: 35-printable-quick-reference-card
    plan: 02
    provides: bilingual skeleton with four locked English anchors (#before, #during, #after, #scoreboard-shortcuts)
  - phase: 34-task-first-doc-rewrite
    provides: walkthrough anchors #step-2-load-clubcloud through #step-14-upload (read-only source of deep-link targets)
  - phase: 33-ux-review-wizard-audit
    provides: F-09, F-12, F-14, F-19 UX findings cited by warning/tip callouts
provides:
  - Before / During / After checklist prose in both DE and EN files
  - Four mandatory `<!-- ref: F-NN -->` forward-reference callouts per file (F-09, F-12, F-14, F-19)
  - 13 deep-links per language to Phase 34 walkthrough anchors, all pre-verified to exist
affects:
  - 35-04-PLAN.md (scoreboard-shortcuts H2 is still empty, ready for Plan 04 cheat sheet)
  - 36-small-ux-fixes (will grep for `<!-- ref: F-NN -->` to atomically remove/update callouts post-fix, per D-06a)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-04 task-list syntax: `- [ ] Text` for all Before/During/After items (no HTML input, no Unicode ☐)"
    - "D-06 admonition callouts with trailing `<!-- ref: F-NN -->` HTML comment on its own line inside the block"
    - "D-05a anchor pre-verification: grep loop confirms every tournament-management.md#step-N-* target exists BEFORE writing the link"
    - "Bilingual parity: DE and EN have byte-identical item counts and F-NN ref sets"

key-files:
  created:
    - .planning/phases/35-printable-quick-reference-card/35-03-SUMMARY.md
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md
    - .planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt

key-decisions:
  - "F-14 callout attached to the 'Start form filled in' item (step 7 start-form), per D-06b — bug is about English/garbled labels on the start form page"
  - "F-12 attached to 'Tournament mode selected' (step 6 mode-selection) — bug is about unclear plan selection on the mode-selection page"
  - "F-09 attached to 'Participant list finalised' (step 5 finish-seeding) — bug is about the irreversible AASM click"
  - "F-19 attached to 'Results uploaded to ClubCloud' (step 14 upload) — the only remaining 'wait, don't re-click' moment in the day-of After flow"
  - "Laptop shutdown item placed at end of After section (not Before) — matches chronological day-of flow"

requirements-completed:
  - QREF-01

# Metrics
duration: ~3min
completed: 2026-04-13
---

# Phase 35 Plan 03: Before/During/After Checklist Prose Summary

**DE and EN tournament-quick-reference files now carry complete Before/During/After checklists (10/6/5 items each, 21 total per language) with all four mandatory F-NN callouts (F-09, F-12, F-14, F-19) wired as admonitions, all 13 deep-links to Phase 34 walkthrough anchors pre-verified, scoreboard-shortcuts placeholder untouched for Plan 04, and mkdocs strict warning count unchanged at 191.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-13T17:44:24Z
- **Completed:** 2026-04-13T17:47:00Z
- **Tasks:** 2
- **Files modified:** 3 (2 carambus_master, 1 carambus_api)
- **Commits:** 2 (carambus_master)

## Accomplishments

- Replaced DE Before placeholder (`_(Checkliste folgt in Plan 35-03.)_`) with 10 task-list items and three admonition callouts (F-09 warning, F-12 tip, F-14 tip)
- Replaced DE During placeholder with 6 task-list items and four deep-links (steps 10-12 plus free-form items)
- Replaced DE After placeholder with 5 task-list items and one admonition callout (F-19 warning) at the upload step
- Mirrored the structure verbatim in the EN file with identical item counts and identical F-NN placement
- All 13 deep-link targets pre-verified in both `tournament-management.de.md` and `tournament-management.en.md` via explicit grep loop (D-05a)
- All 4 F-IDs (F-09, F-12, F-14, F-19) verified to exist in `33-UX-FINDINGS.md` with their Phase 33 descriptions
- Scoreboard-shortcuts H2 section left untouched in both files — Plan 04's territory (placeholder strings `_(Tastenkürzel-Tabelle und ASCII-Button-Leiste folgen in Plan 35-04.)_` and `_(Shortcut table and ASCII button strip TBD in Plan 35-04.)_` still present)
- Ran `mkdocs build --strict` after each file edit: 191 WARNING log lines both times (delta 0 vs Plan 02 post-edit, delta 0 vs D-09 ceiling)
- Recorded post-plan-03 metrics and commit hashes in `35-01-BASELINE.txt`

## Item Counts Per Section Per Language

| Section | DE items | EN items | D-04a range | Status |
|---|---|---|---|---|
| Before  | 10 | 10 | 8-10 | MAX (on ceiling) |
| During  | 6  | 6  | 6-8  | MIN |
| After   | 5  | 5  | 5-7  | MIN |
| **Total** | **21** | **21** | **19-25** | in range |

DE/EN parity verified:
```
$ grep -c '^- \[ \]' .../tournament-quick-reference.de.md
21
$ grep -c '^- \[ \]' .../tournament-quick-reference.en.md
21
```

## F-NN Callouts Inventory

| F-ID | DE title | EN title | Admonition | Attached item | Section | Source (33-UX-FINDINGS.md) |
|---|---|---|---|---|---|---|
| F-09 | Endgültiger Klick | Irreversible click | `!!! warning` | Teilnehmerliste abgeschlossen / Participant list finalised | Before | finish_seeding has no confirmation — irreversible AASM click |
| F-12 | Welchen Plan wählen? | Which plan to pick? | `!!! tip` | Turniermodus ausgewählt / Tournament mode selected and confirmed | Before | mode-selection page has no recommended-default explanation |
| F-14 | Englische Feldbezeichnungen | English field labels | `!!! tip` | Start-Formular ausgefüllt / Start form filled in | Before | Severe i18n regression on the start form — English/garbled labels |
| F-19 | Warten, nicht erneut klicken | Wait — do not re-click | `!!! warning` | Ergebnisse nach ClubCloud hochgeladen / Results uploaded to ClubCloud | After | Transient tournament_started_waiting_for_monitors state is invisible (Tier 3 — blocked-needs-test-plan) |

DE/EN ref parity verified:
```
$ diff <(grep -oE 'ref: F-[0-9]+' .../de.md | sort) <(grep -oE 'ref: F-[0-9]+' .../en.md | sort)
(empty)
```

Each callout uses a trailing `<!-- ref: F-NN -->` HTML comment on its own line inside the admonition block, matching Phase 34's forward-reference pattern. Phase 36 will grep for these markers to atomically remove/update callouts once the underlying bugs are fixed (D-06a).

## Deep-Link Inventory

All 13 deep-links appear in both DE and EN files, pointing to their respective language's `tournament-management.{de,en}.md` mirror. Each target anchor was verified to exist via grep before the link was written (D-05a).

| Section | Item | Anchor | Verified in DE | Verified in EN |
|---|---|---|---|---|
| Before | ClubCloud sync | `#step-2-load-clubcloud` | yes | yes |
| Before | Seeding & participants | `#step-4-participants` | yes | yes |
| Before | Finalise participant list | `#step-5-finish-seeding` | yes | yes |
| Before | Mode selection | `#step-6-mode-selection` | yes | yes |
| Before | Start form | `#step-7-start-form` | yes | yes |
| Before | Tables assigned | `#step-8-tables` | yes | yes |
| Before | Tournament started | `#step-9-start` | yes | yes |
| During | Warm-up phase | `#step-10-warmup` | yes | yes |
| During | Release match | `#step-11-release-match` | yes | yes |
| During | Live monitor | `#step-12-monitor` | yes | yes |
| After  | All results entered | `#step-13-finalize` | yes | yes |
| After  | Upload to ClubCloud | `#step-14-upload` | yes | yes |

Pre-verification loop output (all 13 anchors present in both language files):
```
step-2-load-clubcloud   DE=1 EN=1
step-3-seeding-list     DE=1 EN=1
step-4-participants     DE=1 EN=1
step-5-finish-seeding   DE=1 EN=1
step-6-mode-selection   DE=1 EN=1
step-7-start-form       DE=1 EN=1
step-8-tables           DE=1 EN=1
step-9-start            DE=1 EN=1
step-10-warmup          DE=1 EN=1
step-11-release-match   DE=1 EN=1
step-12-monitor         DE=1 EN=1
step-13-finalize        DE=1 EN=1
step-14-upload          DE=1 EN=1
```

No new Phase 34 anchors were created; Plan 35 is read-only toward Phase 34 output (CONTEXT §D-05a).

## mkdocs strict Warning Counts

| Stage | WARNING log lines | Delta vs baseline |
|---|---|---|
| Plan 01 baseline | 191 | 0 |
| Plan 02 post-edit | 191 | 0 |
| Plan 03 post-DE-edit | 191 | 0 |
| Plan 03 post-EN-edit | 191 | 0 |
| **Phase 35 ceiling (D-09)** | **191** | — |

D-09 gate SATISFIED: zero new warnings added by Plan 03, zero warnings reference `tournament-quick-reference` in the build output.

## Scoreboard-Shortcuts Placeholder Sentinel (Plan 04 territory)

Plan 03 explicitly did NOT touch the `<a id="scoreboard-shortcuts"></a>` H2 section. Both files still contain their Plan 02 placeholder bodies verbatim:

- DE: `_(Tastenkürzel-Tabelle und ASCII-Button-Leiste folgen in Plan 35-04.)_`
- EN: `_(Shortcut table and ASCII button strip TBD in Plan 35-04.)_`

Verified:
```
$ grep -c 'Tastenkürzel-Tabelle und ASCII-Button-Leiste folgen in Plan 35-04' .../de.md
1
$ grep -c 'Shortcut table and ASCII button strip TBD in Plan 35-04' .../en.md
1
```

T-35-10 (scoreboard-shortcuts tampering) threat mitigated by design.

## Task Commits

1. **Task 1 (carambus_master):** `079338e6` — `docs(35-03): fill DE quick-reference Before/During/After checklists`
2. **Task 2 (carambus_master):** `867b097c` — `docs(35-03): fill EN quick-reference Before/During/After checklists`

carambus_api-side SUMMARY + STATE + ROADMAP + BASELINE update will land in a follow-up metadata commit.

## Files Created/Modified

- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md` (modified, +41/-5) — Before/During/After prose with F-09/F-12/F-14 (Before) + F-19 (After)
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md` (modified, +41/-5) — EN mirror
- `.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt` (modified, +6 lines) — post_plan_03 metrics + commit SHAs

## Decisions Made

- **F-14 placement:** Attached to the start-form item (step 7) rather than the tables/scoreboards area. The F-14 finding in 33-UX-FINDINGS.md specifically targets the tournament start form's English/garbled parameter labels — the mode-selection F-12 callout already covers the "which plan" confusion, so F-14 naturally belongs one item down where the start-form labels actually appear.
- **F-12 and F-14 separated, not shared:** The planner allowed either separate callouts or a shared block for F-12/F-14. Chose separate — they target different pages (mode-selection vs start-form) and a shared callout would either dilute the per-step anchoring or force an awkward "applies to next two items" phrasing. Each item gets its own adjacent callout.
- **F-19 title — "Warten, nicht erneut klicken" / "Wait — do not re-click":** Directly describes the risk (volunteers double-clicking due to invisible transient state) in imperative voice, following the F-09 pattern ("Endgültiger Klick" / "Irreversible click").
- **Laptop shutdown in After:** The skeleton Plan 02 wrote "Laptop plugged in" at the top of Before, so the symmetrical end-of-day counterpart "Laptop sauber herunterfahren, Strom trennen" / "Laptop shut down cleanly, power disconnected" goes at the bottom of After — chronologically correct and keeps Before at 10 items (D-04a ceiling) without overflow.
- **Tip vs warning admonition:** Used `!!! tip` for F-12 (recommended-default guidance) and F-14 (label ambiguity workaround) because they're non-destructive coping strategies. Used `!!! warning` for F-09 (irreversible action) and F-19 (user may actively make things worse by clicking again). This matches mkdocs-material's semantic distinction between tip (advisory) and warning (risk).

## Deviations from Plan

None — plan executed exactly as written. Tasks 1 and 2 completed in order; all automated verify checks and acceptance criteria passed on first run. No auto-fixes under Rules 1–3, no architectural decisions under Rule 4. Both mkdocs strict runs returned 191 WARNING lines on the first attempt.

## Issues Encountered

None. Both Write operations, both mkdocs strict builds, and both atomic commits succeeded on the first try. The pre-Task-1 anchor pre-verification loop and F-ID pre-verification both returned clean (no missing anchors, no missing F-IDs), so no escalation was needed.

## Known Stubs

Exactly one intentional stub remains in both files — the scoreboard-shortcuts H2 placeholder. This is Plan 04's territory and will be filled when Plan 04 executes.

| File | Line | Placeholder | Resolved by |
|---|---|---|---|
| tournament-quick-reference.de.md | 65 | `_(Tastenkürzel-Tabelle und ASCII-Button-Leiste folgen in Plan 35-04.)_` | Plan 35-04 |
| tournament-quick-reference.en.md | 65 | `_(Shortcut table and ASCII button strip TBD in Plan 35-04.)_` | Plan 35-04 |

Not a defect — Plan 03's scope explicitly excludes the scoreboard-shortcuts section per the phase plan partition.

## Threat Model Verification

- **T-35-08 (Spoofing of Phase 34 anchors):** Mitigated. All 13 deep-link targets pre-verified via grep loop on both DE and EN `tournament-management.md` files before any link was written. No new anchors invented.
- **T-35-09 (F-NN information disclosure):** Mitigated. HTML comments `<!-- ref: F-NN -->` are inert at render time; the rendered mkdocs site shows only the admonition body text, never the ref marker. F-NN IDs are internal planning references tracked in `.planning/` (carambus_api repo only).
- **T-35-10 (Scoreboard-shortcuts H2 tampering):** Mitigated. Both Plan 02 placeholder strings still present in the files (verified by grep); Plan 03 did not touch the H2 section.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Plan 35-04 (scoreboard shortcut cheat sheet) is UNBLOCKED.** The `#scoreboard-shortcuts` H2 anchor is still present with its Plan 02 placeholder body; Plan 04 can replace that body in-place with the markdown table + ASCII keycap strip per D-03.
- **Plan 35-05 (validation) is UNBLOCKED** with respect to Before/During/After prose. Plan 05 will still want to re-verify mkdocs strict after Plan 04's content lands.
- **D-09 ceiling carried forward:** 191 WARNING log lines remains the ceiling for Plans 35-04 and 35-05.
- **Phase 36 forward-reference hook:** When Phase 36 fixes F-09, F-12, F-14, or F-19, it must grep `tournament-quick-reference.{de,en}.md` for `<!-- ref: F-NN -->` and either remove the admonition or restate it, per D-06a. This grep target is now live.

## Self-Check: PASSED

- Files verified on disk:
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md (21 task-list items, all 4 F-NN callouts present, scoreboard placeholder intact)
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md (21 task-list items, all 4 F-NN callouts present, scoreboard placeholder intact)
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt (post_plan_03 metrics recorded)
- Commits verified in git history:
  - FOUND: 079338e6 (carambus_master, DE file, Task 1)
  - FOUND: 867b097c (carambus_master, EN file, Task 2)
- Verify commands: DE/EN item-count diff empty, DE/EN ref-F diff empty, DE/EN anchor diff empty, section counts within D-04a ranges, mkdocs strict delta 0 after both edits

---

*Phase: 35-printable-quick-reference-card*
*Completed: 2026-04-13*
