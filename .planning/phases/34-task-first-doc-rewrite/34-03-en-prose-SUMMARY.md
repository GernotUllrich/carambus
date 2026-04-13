---
phase: 34-task-first-doc-rewrite
plan: 03
subsystem: docs
tags: [mkdocs, markdown, EN, carambus_master, tournament-management, walkthrough, glossary, troubleshooting]

# Dependency graph
requires:
  - plan: 34-01
    provides: "Frozen H2/H3/anchor skeleton for tournament-management.en.md and index.en.md"
provides:
  - "Full EN prose for tournament-management.en.md: 14-step task-first walkthrough, 18-term glossary (grouped), 4-case troubleshooting, architecture tail"
  - "Rewritten index.en.md Quick Start: 10-step teaser linking into walkthrough anchors (DOC-05)"
  - "4 mandatory Phase 33 callouts embedded with <!-- ref: F-NN --> comments for Phase 36 grepping (D-02a)"
affects:
  - "34-02 (DE prose): parallel plan, no file overlap — structural parity confirmed"
  - "35-quick-reference-card: walkthrough anchors stable, card can condense from this content"
  - "37-in-app-doc-links: anchor slugs are stable English-based IDs established in 34-01"
  - "36-small-ux-fixes: can grep <!-- ref: F-09/F-12/F-14/F-19 --> to remove obsolete callouts atomically"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Admonition callouts with trailing <!-- ref: F-NN --> HTML comments for Phase 36 atomic removal (D-02a)"
    - "Glossary entries with wizard-step cross-references via #step-N-slug fragment links"
    - "Troubleshooting cases using bold-label format: **Problem:** / **Cause:** / **Fix:**"
    - "Index Quick Start as 10-step teaser condensing 14 walkthrough steps with anchor deep-links"

key-files:
  created: []
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md

key-decisions:
  - "mkdocs build --strict: 191 warnings before and after — zero new warnings introduced (all 191 are pre-existing stale links in unrelated doc sections, matching DE plan 34-02 baseline)"
  - "Translation workflow: adaptive manual translation from DE reference (34-02 already landed), not literal — idiomatic EN throughout"
  - "NDM Freie Partie kept in German in scenario framing per plan constraint (D-04a-EN); 'Class 1–3' translated, discipline name preserved"
  - "All three tasks (walkthrough, glossary, troubleshooting + architecture tail) written as progressive edits to same file, committed atomically in carambus_master per Task 3 commit instruction"
  - "Bilingual parity confirmed: same 14 steps, same 18 glossary terms, same 4 troubleshooting cases, same anchor slugs as DE file"

requirements-completed: [DOC-01, DOC-03, DOC-04, DOC-05]

# Metrics
duration: 30min
completed: 2026-04-13
---

# Phase 34 Plan 03: EN Prose Summary

**14-step task-first EN walkthrough with NDM Freie Partie scenario, 18-term grouped glossary, 4-case Problem/Cause/Fix troubleshooting, and 10-step Quick Start teaser — bilingual parity with DE file confirmed**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-04-13
- **Tasks:** 3 (Task 1: walkthrough + tail, Task 2: glossary, Task 3: troubleshooting + index + commit)
- **Files modified:** 2 (in carambus_master)

## Line Count

| File | Before | After |
|------|--------|-------|
| tournament-management.en.md | 157 lines (skeleton) | 259 lines |
| index.en.md | skeleton Quick Start (10 placeholder lines) | Quick Start section updated (10 real steps) |

## Accomplishments

- 14-step task-first walkthrough written with concrete click-level prose, addressing reader as "you" (imperative style throughout)
- Scenario section uses exact D-04a-EN framing: generic NBV NDM Freie Partie Class 1–3, 5 participants, 2 tables; "Freie Partie" kept in German per plan constraint
- 4 mandatory admonition callouts present with exact `<interfaces>` wording and trailing `<!-- ref: F-NN -->` comments (F-09, F-12, F-14, F-19)
- Glossary complete: 10 Karambol terms + 4 Wizard terms + 4 System terms = 18 entries total, each with DE original in parentheses for bilingual searchability
- 4 troubleshooting cases with Problem/Cause/Fix, grounded in Phase 33 findings (F-03/F-04, F-13, F-19)
- 2-paragraph "More on the architecture" tail block links to `../developers/index.md`
- index.en.md Quick Start: 10 teaser steps with `#step-N-*` fragment links into walkthrough anchors
- All placeholder bodies (`_(content TBD in Plan 34-03)_`, `_(TBD)_`) removed
- Zero new mkdocs build --strict warnings introduced

## Admonitions Added

| Ref | Type | Step | Opening text |
|-----|------|------|-------------|
| F-09 | `!!! warning` | Step 5 — Close participant list | "Closing the participant list is final" |
| F-12 | `!!! tip` | Step 6 — Select tournament mode | "Which tournament plan should I pick?" |
| F-14 | `!!! tip` | Step 7 — Fill in start parameters | "English field labels on the start form" |
| F-19 | `!!! warning` | Step 9 — Start the tournament | "Wait — do not click again" |

## Glossary Terms Defined

**Karambol terms (10):** Straight Rail (Freie Partie), Balkline/Cadre (35/2 47/1 47/2 71/2), Three-Cushion (Dreiband), One-Cushion (Einband), Inning (Aufnahme), Target balls/innings_goal (Bälle-Ziel), High run/HS (Höchstserie), General average/GD (Generaldurchschnitt), Playing round (Spielrunde), Table warmup (Tisch-Warmup)

**Wizard terms (4):** Seeding list (Setzliste), Tournament mode (Turniermodus), Tournament-plan codes (T04 T05 Default5), Scoreboard

**System terms (4):** ClubCloud, AASM status (AASM-Status), DBU number (DBU-Nummer), Ranking (Rangliste)

## Commit in carambus_master

- **SHA:** `1bbe1f28`
- **Message:** `docs(34-03): EN prose — walkthrough, glossary, troubleshooting, Quick Start teaser`
- **Files:** docs/managers/tournament-management.en.md, docs/managers/index.en.md
- **Net change:** +167 / -64 lines

## Translation Workflow

Adaptive manual translation from the DE reference file (plan 34-02 already landed at `0505ed50`). The DE file was used as the primary structural and content reference. No automated DeepL/OpenAI pass was used — direct EN authoring preserved idiomatic phrasing and avoided literal-translation artifacts. Karambol terminology kept DE originals in parentheses throughout for bilingual volunteer searchability.

## mkdocs build --strict Result

**No new warnings introduced.** Warning count: 191 before and 191 after our changes (same baseline as DE plan 34-02). All 191 warnings are pre-existing stale cross-links in unrelated doc sections (players/, administrators/, decision-makers/, developers/). The `managers/index.en.md` INFO-level messages referencing old `tournament-management.en.md` anchors (e.g., `#player-management`, `#round-robin`) are pre-existing stale links from the deeper body of that file — they are INFO-level (not WARNING-level) and were present before this plan.

## Bilingual Parity Check

| Item | DE (34-02) | EN (34-03) | Parity |
|------|-----------|-----------|--------|
| Walkthrough steps | 14 | 14 | OK |
| Glossary terms | 18 | 18 | OK |
| Troubleshooting cases | 4 | 4 | OK |
| Admonition callouts | 4 | 4 | OK |
| Anchor slugs (step-N-*) | 14 | 14 | OK (English-based in both) |
| Glossary anchors | 3 | 3 | OK |
| Troubleshooting anchors | 4 | 4 | OK |
| Index Quick Start steps | 10 | 10 | OK |
| Architecture tail paragraphs | 2 | 2 | OK |

**Structural drift from DE file: zero.**

## Deviations from Plan

None — plan executed exactly as written. All three tasks completed in progressive file edits and committed atomically per Task 3's commit instruction.

## Known Stubs

None — all placeholder bodies from the skeleton have been replaced with real prose. The `../developers/index.md` link in the "More on the architecture" tail block points to an existing file.

## Threat Flags

None — docs-only changes, no new code surface.

## Self-Check

- `tournament-management.en.md`: FOUND (259 lines) ✓
- `index.en.md`: FOUND (Quick Start updated with 10 real steps) ✓
- Commit `1bbe1f28`: FOUND in carambus_master git log ✓
- All 4 `<!-- ref: F-NN -->` comments: PRESENT ✓
- All 14 `id="step-..."` anchors: PRESENT (14) ✓
- All glossary anchor IDs (glossary-karambol, glossary-wizard, glossary-system): PRESENT ✓
- All 4 troubleshooting anchor IDs: PRESENT ✓
- No placeholder strings remaining: CONFIRMED ✓
- mkdocs build --strict: 191 warnings (all pre-existing, zero new) ✓
- index.en.md step 1 = "Sync tournament from ClubCloud" (not "Create tournament"): CONFIRMED ✓
- index.en.md has 10 `#step-` fragment links: CONFIRMED (10) ✓

## Self-Check: PASSED
