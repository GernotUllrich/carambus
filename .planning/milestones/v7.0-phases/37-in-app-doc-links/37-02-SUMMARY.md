---
phase: 37-in-app-doc-links
plan: 02
subsystem: docs
tags: [mkdocs, attr_list, anchors, i18n, tournament-management]

# Dependency graph
requires:
  - phase: 34-task-first-doc-rewrite
    provides: "Rewritten tournament-management.{de,en}.md with Schritt/Step 3-7 headings that match 1:1 across locales"
  - phase: 35-doc-audit-post-rewrite
    provides: "mkdocs baseline (191 WARNING line budget, attr_list extension already enabled)"
provides:
  - "Stable {#seeding-list} anchor on Schritt 3 / Step 3 in both locales"
  - "Stable {#participants} anchor on Schritt 4 / Step 4 in both locales"
  - "Stable {#mode-selection} anchor on Schritt 6 / Step 6 in both locales"
  - "Stable {#start-parameters} anchor on Schritt 7 / Step 7 in both locales"
  - "Locale-agnostic anchor IDs (English kebab-case) usable by Ruby mkdocs_link helper"
affects: [37-03-wizard-partial, 37-04-form-help-links, 37-05-test-plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "attr_list explicit {#id} anchors on translated markdown heading pairs"
    - "Identical English kebab-case IDs across DE and EN doc files"

key-files:
  created:
    - .planning/phases/37-in-app-doc-links/37-02-SUMMARY.md
  modified:
    - docs/managers/tournament-management.de.md
    - docs/managers/tournament-management.en.md

key-decisions:
  - "Appended exactly 4 {#anchor} attrs on 4 target headings per file (8 edits total) per D-06..D-09; no prose changes"
  - "Anchor IDs are English-only kebab-case and identical across DE/EN so Ruby helper stays locale-agnostic"
  - "mkdocs.yml was NOT modified — the attr_list extension was already enabled at line 248"

patterns-established:
  - "Heading anchor convention: append ' {#kebab-case-id}' after the visible heading text in both locale files"
  - "Delta-0 warnings gate: mkdocs --strict build must not introduce any new WARNING lines vs Phase 35 baseline"

requirements-completed:
  - LINK-02
  - LINK-04

# Metrics
duration: 8min
completed: 2026-04-14
---

# Phase 37 Plan 02: Stable Doc Anchors Summary

**Added 4 identical English kebab-case {#anchor} attrs to matching Schritt/Step 3-7 headings in `tournament-management.de.md` and `tournament-management.en.md`, enabling locale-agnostic deep links from the Ruby `mkdocs_link` helper while leaving all prose untouched.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-14T20:44:00Z
- **Completed:** 2026-04-14T20:52:00Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- 4 stable anchors added to `tournament-management.de.md` on Schritt 3/4/6/7 headings (`{#seeding-list}`, `{#participants}`, `{#mode-selection}`, `{#start-parameters}`)
- 4 identical anchors added to `tournament-management.en.md` on Step 3/4/6/7 headings
- `mkdocs build --strict` passes with **0 warnings, 0 errors, exit 0** — cleanly under the Phase 35 baseline of 191 warnings (delta: -191)
- Generated HTML verified: `<h3 id="seeding-list">`, `<h3 id="participants">`, `<h3 id="mode-selection">`, `<h3 id="start-parameters">` render in both `site/managers/tournament-management/index.html` (DE) and `site/en/managers/tournament-management/index.html` (EN)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add 4 stable anchors to tournament-management.de.md** — `101eb05d` (docs)
2. **Task 2: Add 4 stable anchors to tournament-management.en.md** — `9088870e` (docs)
3. **Task 3: Run mkdocs build --strict and verify no new warnings** — no commit (verification-only task; mkdocs build output is gitignored under `site/`)

**Plan metadata:** (to be added by final commit)

## Files Created/Modified

- `docs/managers/tournament-management.de.md` — 4 heading lines edited (`+4 / -4` numstat); no prose changes
- `docs/managers/tournament-management.en.md` — 4 heading lines edited (`+4 / -4` numstat); no prose changes

## Decisions Made

None beyond the plan and context file. Followed D-06..D-09 exactly: 4 anchors, English kebab-case, identical IDs across both locales, heading-line-only edits. `mkdocs.yml` was not touched because `attr_list` is already enabled at line 248.

## Deviations from Plan

None — plan executed exactly as written. All 8 heading edits (4 per file) applied verbatim from the plan's find/replace strings. No Rule 1/2/3 auto-fixes were required.

## Issues Encountered

None during execution. One cosmetic quirk: after each Edit tool call, a stale PreToolUse "READ-BEFORE-EDIT" reminder fired even though every Edit had already succeeded (runtime confirmed "updated successfully"). This was a hook-ordering artifact, not a real failure — all edits landed on the first attempt as verified by post-edit `grep` and the clean `mkdocs --strict` build.

## mkdocs Strict Build Evidence

```text
$ mkdocs build --strict > /tmp/mkdocs-37-02-build.log 2>&1
EXIT=0
WARNINGS=0
ERRORS=0
```

Generated HTML anchor extraction:

```text
site/managers/tournament-management/index.html:
  <h3 id="seeding-list">Schritt 3: Setzliste übernehmen oder erzeugen...
  <h3 id="participants">Schritt 4: Teilnehmerliste prüfen und ergänzen (Wizard Schritt 3)...
  <h3 id="mode-selection">Schritt 6: Turniermodus auswählen...
  <h3 id="start-parameters">Schritt 7: Start-Parameter und Tischzuordnung ausfüllen...

site/en/managers/tournament-management/index.html:
  <h3 id="seeding-list">Step 3: Take over or generate the seeding list...
  <h3 id="participants">Step 4: Review and add participants (Wizard Step 3)...
  <h3 id="mode-selection">Step 6: Select tournament mode...
  <h3 id="start-parameters">Step 7: Start parameters and table assignment...
```

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Ready for Plan 37-03 (wizard partial):** `mkdocs_link(path, anchor: 'seeding-list' | 'participants' | 'mode-selection' | 'start-parameters')` calls will now resolve to real `id=` attributes in both locales.
- **Ready for Plan 37-04 (form help links):** the 4 anchors cover all 4 form contexts from D-15 (parse_invitation → seeding-list, define_participants → participants, finalize_modus → mode-selection, tournament_monitor → start-parameters).
- **LINK-04 floor cleared:** 4 stable deep-link anchors ≥ 3 required.
- No blockers for downstream waves.

## Self-Check: PASSED

- `docs/managers/tournament-management.de.md` — FOUND, contains all 4 new anchors (grep confirmed 1 match per ID)
- `docs/managers/tournament-management.en.md` — FOUND, contains all 4 new anchors (grep confirmed 1 match per ID)
- Commit `101eb05d` — FOUND in `git log`
- Commit `9088870e` — FOUND in `git log`
- `site/managers/tournament-management/index.html` — generated by clean `mkdocs --strict` run with all 4 `<h3 id="...">` attributes present
- `site/en/managers/tournament-management/index.html` — generated by clean `mkdocs --strict` run with all 4 `<h3 id="...">` attributes present

---
*Phase: 37-in-app-doc-links*
*Completed: 2026-04-14*
