---
phase: 34-task-first-doc-rewrite
plan: 01
subsystem: docs
tags: [mkdocs, markdown, bilingual, carambus_master, tournament-management]

# Dependency graph
requires:
  - phase: 33-ux-review-wizard-audit
    provides: "14-step wizard walkthrough (UX-04), confirmed canonical partial (_wizard_steps_v2), 24 UX findings"
provides:
  - "Frozen H2/H3/anchor skeleton for tournament-management.{de,en}.md (14-step walkthrough structure)"
  - "English-based anchor slugs for all sections (D-05a) enabling Phase 37 deep-links"
  - "Corrected Quick Start in index.{de,en}.md — step 1 is now Sync-from-ClubCloud (DOC-05)"
  - "D-05 hard gate commit in carambus_master (84608dbf) — Wave 2 plans 34-02 and 34-03 are unblocked"
affects:
  - "34-02 (DE prose): must write against this skeleton's H2/H3 structure"
  - "34-03 (EN prose): must write against this skeleton's H2/H3 structure"
  - "35-quick-reference-card: depends on stable walkthrough anchors from this plan"
  - "37-in-app-doc-links: Phase 37 LINK-04 deep-links to #walkthrough, #step-N-* anchors committed here"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bilingual skeleton gate: structure committed before any prose, enforcing parallel DE/EN authoring"
    - "English-based anchor slugs via <a id='slug'></a> HTML tags above each H2/H3, identical across both language files"
    - "Placeholder bodies follow plan-reference convention: _(Inhalt folgt in Plan 34-02)_ / _(content TBD in Plan 34-03)_"

key-files:
  created: []
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md

key-decisions:
  - "Anchor convention: <a id='slug'></a> HTML tags (not comment-based) immediately above each H2/H3 for reliable Phase 37 deep-linking"
  - "mkdocs build --strict fails with 94 warnings pre-existing before this plan — our changes introduce zero new warnings; failure is out of scope (pre-existing)"
  - "D-05 gate satisfied: all four files committed atomically before any prose plans begin"

patterns-established:
  - "Cross-repo doc commits: edit files via absolute paths in carambus_master, commit from carambus_master, SUMMARY.md committed separately in carambus_api"

requirements-completed: [DOC-01, DOC-02, DOC-05]

# Metrics
duration: 25min
completed: 2026-04-13
---

# Phase 34 Plan 01: Bilingual Skeleton Summary

**Bilingual H2/H3/anchor skeleton for tournament-management.{de,en}.md committed in carambus_master — 14-step walkthrough structure with English-based `<a id>` anchors, identical across both languages, D-05 gate satisfied**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-13
- **Completed:** 2026-04-13
- **Tasks:** 3
- **Files modified:** 4 (in carambus_master)

## Accomplishments

- Both `tournament-management.{de,en}.md` fully replaced with identical H2/H3/anchor skeleton: Scenario / Walkthrough (14 steps) / Glossary (3 subsections) / Troubleshooting (4 cases) / More on the architecture
- All 26 required anchor IDs committed (`<a id="...">` style): scenario, walkthrough, step-1-invitation through step-14-upload, glossary-karambol, glossary-wizard, glossary-system, ts-invitation-upload, ts-player-not-in-cc, ts-wrong-mode, ts-already-started, architecture
- Quick Start sections in `index.{de,en}.md` replaced — step 1 is now "Turnier aus ClubCloud synchronisieren" / "Sync tournament from ClubCloud" (DOC-05 compliance), link points to `#walkthrough`
- D-05 hard gate satisfied: single atomic commit `84608dbf` in carambus_master before any prose plan runs

## Task Commits

Tasks 1 and 2 (file writes) and Task 3 (commit) were executed as a single atomic commit in carambus_master per plan instructions:

1. **Task 1: Write bilingual tournament-management skeleton (DE + EN)** - written, verified, included in gate commit
2. **Task 2: Rewrite index.{de,en}.md Quick Start skeleton** - written, verified, included in gate commit
3. **Task 3: Commit the bilingual skeleton gate** - `84608dbf` in carambus_master (`docs(34-01): bilingual H2/H3 skeleton for task-first rewrite`)

## Files Created/Modified

- `carambus_master/docs/managers/tournament-management.de.md` — fully replaced: 317 lines → 130 lines, task-first, identical anchor skeleton
- `carambus_master/docs/managers/tournament-management.en.md` — fully replaced: 317 lines → 130 lines, task-first, identical anchor skeleton
- `carambus_master/docs/managers/index.de.md` — Quick Start section only: replaced "Turnier anlegen" step 1 with "Turnier aus ClubCloud synchronisieren"
- `carambus_master/docs/managers/index.en.md` — Quick Start section only: replaced "Create tournament" step 1 with "Sync tournament from ClubCloud"

## Anchor Slugs Committed

All slugs are English-based per D-05a, set via `<a id="slug"></a>` HTML anchor tags:

| Slug | Section |
|------|---------|
| `scenario` | H2 Scenario/Szenario |
| `walkthrough` | H2 Walkthrough/Durchführung |
| `step-1-invitation` | H3 Step 1 |
| `step-2-load-clubcloud` | H3 Step 2 |
| `step-3-seeding-list` | H3 Step 3 |
| `step-4-participants` | H3 Step 4 |
| `step-5-finish-seeding` | H3 Step 5 |
| `step-6-mode-selection` | H3 Step 6 |
| `step-7-start-form` | H3 Step 7 |
| `step-8-tables` | H3 Step 8 |
| `step-9-start` | H3 Step 9 |
| `step-10-warmup` | H3 Step 10 |
| `step-11-release-match` | H3 Step 11 |
| `step-12-monitor` | H3 Step 12 |
| `step-13-finalize` | H3 Step 13 |
| `step-14-upload` | H3 Step 14 |
| `glossary` | H2 Glossary/Glossar |
| `glossary-karambol` | H3 Karambol terms |
| `glossary-wizard` | H3 Wizard terms |
| `glossary-system` | H3 System terms |
| `troubleshooting` | H2 Troubleshooting/Problembehebung |
| `ts-invitation-upload` | H3 TS case 1 |
| `ts-player-not-in-cc` | H3 TS case 2 |
| `ts-wrong-mode` | H3 TS case 3 |
| `ts-already-started` | H3 TS case 4 |
| `architecture` | H2 More on the architecture/Mehr zur Technik |

## Anchor Convention Chosen

`<a id="slug"></a>` HTML anchor tags immediately above each H2 and H3, used consistently across all four files. This was chosen over comment-based anchors (`<!-- anchor: slug -->`) for reliable deep-link targeting in Phase 37 wizard UI.

## mkdocs build --strict Result

**Pre-existing failure — not introduced by this plan.** `mkdocs build --strict` exits with 94 warnings both before and after our changes. The warnings are stale cross-links in unrelated files (players/, administrators/, decision-makers/, developers/ sections) and pre-existing anchor links in `managers/index.en.md` pointing to old `tournament-management.en.md` sections that never had those anchors. Our skeleton files introduce zero new warnings.

## Decisions Made

- Used `<a id="slug">` over `<!-- anchor: slug -->` (Claude's discretion per D-05a) — HTML anchors are directly linkable; comment-based anchors require mkdocs plugin support
- Glossary term lists in skeleton follow D-03 exactly (10 Karambol terms + 4 Wizard terms + 4 System terms), with `_(Definition folgt)_` placeholders only — no definitions added (D-05 gate)
- Troubleshooting H3s include Problem/Ursache/Lösung structure labels as placeholders per D-07 format — ready for Wave 2 prose fill-in

## Deviations from Plan

None — plan executed exactly as written. The mkdocs strict failure is pre-existing (94 warnings before and after, verified via git stash round-trip).

## Issues Encountered

`mkdocs build --strict` was already failing with 94 warnings before this plan's changes. Verified via `git stash` / `git stash pop` round-trip — warning count unchanged at 94. Pre-existing stale anchor links in index files and other doc sections are out of scope per deviation rules ("Pre-existing warnings in unrelated files are out of scope").

## Known Stubs

By design — this entire plan is skeleton-only per D-05:
- `tournament-management.de.md`: all section bodies are `_(Inhalt folgt in Plan 34-02)_` placeholders
- `tournament-management.en.md`: all section bodies are `_(content TBD in Plan 34-03)_` placeholders
- `index.de.md` Quick Start: steps 2–10 are `_(Schritt N — folgt)_` placeholders
- `index.en.md` Quick Start: steps 2–10 are `_(step N — TBD)_` placeholders

These stubs are intentional and will be resolved in plans 34-02 (DE prose) and 34-03 (EN prose).

## Next Phase Readiness

- Plans 34-02 and 34-03 (Wave 2) are unblocked — D-05 gate commit `84608dbf` exists in carambus_master
- Phase 37 deep-linking is unblocked — all anchor slugs are stable and English-based
- Phase 35 quick-reference card is unblocked — walkthrough anchor structure is frozen
- No blockers

---
*Phase: 34-task-first-doc-rewrite*
*Completed: 2026-04-13*
