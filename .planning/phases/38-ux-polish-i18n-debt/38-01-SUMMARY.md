---
phase: 38-ux-polish-i18n-debt
plan: 01
type: execute
status: complete
subsystem: ui
tags: [ui, css, tailwind, darkmode, i18n, uat, wizard, tooltip]

requires:
  - phase: 36B-ui-cleanup-kleine-features
    provides: "Phase 36B Wizard Header Test 1 baseline (FIX-03 + FIX-04) + Gap register (G-01, G-03, G-05)"
  - phase: 37-in-app-doc-links
    provides: "mkdocs_link placement inside <details> help block (D-11) — made G-01 user-visible"
provides:
  - "G-01 dark-mode info banner fix: Tailwind dark: variants replacing inline style= on _wizard_steps_v2.html.erb"
  - "G-01 specificity audit closure: dropped hostile .step-info class that was overriding dark:text-green-100 via html.dark .step-info color rule"
  - "G-03 tooltip affordance: new components/tooltip.css registered via @import, applies to all 16 tournament_monitor.html.erb tooltipped labels + all future ones"
  - "G-05 / I18N-01 EN warmup translation: en.yml:844-846 Warm-up / Warm-up Player A / Warm-up Player B"
  - "UX-POL-03 manual UAT artifact: 38-UX-POL-03-UAT.md confirming Phase 36B Test 1 retest + G-01 contrast"
affects:
  - 38-02-tournament-views-i18n-audit (Wave 2 follow-on, uses same wizard/monitor surface)
  - 39-dtp-parameter-ranges (DATA-01 spin-off, unrelated file surface)

tech-stack:
  added: []
  patterns:
    - "Tailwind dark: variants are the default for all new wizard-surface color fixes (NOT inline style= attributes, NOT bare CSS in tournament_wizard.css)"
    - "Component CSS files live under app/assets/stylesheets/components/ and register via @import in application.tailwind.css alongside existing components/*.css imports"
    - "When a legacy CSS class (e.g., .step-info) carries a dark-mode color rule that conflicts with a Tailwind dark: utility, DROP the legacy class entirely rather than bumping specificity — preserves the Tailwind-first migration direction"
    - "Manual UAT artifacts for deferred retests follow the Phase 36B *-HUMAN-UAT.md template and live in the phase directory with frontmatter status/phase/source/completed/result"

key-files:
  created:
    - app/assets/stylesheets/components/tooltip.css
    - .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
  modified:
    - app/views/tournaments/_wizard_steps_v2.html.erb
    - app/assets/stylesheets/tournament_wizard.css
    - app/assets/stylesheets/application.tailwind.css
    - config/locales/en.yml

key-decisions:
  - "D-03 Tailwind dark: variants for G-01 info banner (bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100)"
  - "D-04 tournament_wizard.css .step-help p specificity audit — resolved via Task 1 class-drop instead of @apply bump"
  - "D-06 new components/tooltip.css registered via @import (pattern match with 14+ existing component files)"
  - "D-07 broad [data-controller~=\"tooltip\"] selector — audit of 16 sites in tournament_monitor.html.erb showed all are <span> wrappers, no form controls nested, broad rule safe"
  - "D-09 exact en.yml:844-846 values: warmup/warmup_a/warmup_b → Warm-up / Warm-up Player A / Warm-up Player B"
  - "D-10 en.yml:387 training: Training preserved — different semantic (practice-tournament concept, not scoreboard warm-up phase)"
  - "D-17 5-criteria UAT artifact (4 required Phase 36B Test 1 + 1 bonus G-01 contrast) as close-gate for Plan 38-01"
  - "Revision: drop step-info class from info banner (class-escape) instead of !important or @apply — preserves Tailwind-first direction"

patterns-established:
  - "Class-escape over specificity-bump: when legacy CSS class color rules fight Tailwind dark: utilities, drop the legacy class"
  - "Components CSS @import pattern: new surface-specific affordance rules go in components/*.css not in tournament_wizard.css"
  - "Manual UAT artifact structure: frontmatter (status/phase/source/completed/result) + per-criterion result+observation blocks + Traceability + Screenshot Evidence sections"

requirements-completed:
  - UX-POL-01
  - UX-POL-02
  - UX-POL-03
  - I18N-01

commits:
  - 65609f67
  - 05b38b45
  - d814762b
  - d91079b3
  - e727b4a3

files_modified:
  - app/views/tournaments/_wizard_steps_v2.html.erb
  - app/assets/stylesheets/tournament_wizard.css
  - app/assets/stylesheets/components/tooltip.css
  - app/assets/stylesheets/application.tailwind.css
  - config/locales/en.yml

files_created:
  - app/assets/stylesheets/components/tooltip.css
  - .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md

tests_run:
  - "bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb (pass, pre-existing trailing-newline warning ignored)"
  - "bundle exec rails runner I18n smoke test for warmup keys (pass)"
  - "Manual UAT per UX-POL-03 (pass after revision commit e727b4a3)"

duration: "~2h (including revision + human re-verification)"
completed: 2026-04-15
---

# Plan 38-01: Quick Wins Bundle — Summary

**Dark-mode Tailwind fix for the wizard info banner + tooltip affordance CSS + EN warm-up translation + deferred Phase 36B Test 1 retest, all shipped as one commit-coherent bundle closing four v7.1 requirements.**

## What Was Built

Plan 38-01 shipped four small, independent fixes plus one manual UAT retest that collectively close the four smallest Phase 36B UAT follow-up gaps under v7.1 milestone:

1. **G-01 / UX-POL-01 (dark-mode contrast):** Replaced the inline `style="background: #dff0d8; …"` attribute on the Schritt 1 info banner ("Es sind bereits N Spieler vorhanden") with Tailwind dark: variants (`bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100`). Audited `tournament_wizard.css:287-295` (`html.dark .step-help p` rule) for specificity conflicts with the Tailwind dark utility.
2. **G-03 / UX-POL-02 (tooltip affordance):** Added a new `app/assets/stylesheets/components/tooltip.css` with a global `[data-controller~="tooltip"]` selector applying `cursor: help` + `border-bottom: 1px dashed currentColor`. Registered via `@import` in `application.tailwind.css`. Auto-applies to all 16 tooltipped labels on `tournament_monitor.html.erb` without touching any ERB.
3. **G-05 / I18N-01 (EN warm-up translation):** Three-line edit in `config/locales/en.yml:844-846`: `warmup: Warm-up`, `warmup_a: Warm-up Player A`, `warmup_b: Warm-up Player B`. Left `en.yml:387 training: Training` untouched (different semantic per CONTEXT.md D-10).
4. **UX-POL-03 (manual UAT retest):** Human ran the four required Phase 36B Test 1 criteria plus the bonus G-01 contrast check against `carambus_bcw`. All four required criteria passed first try; the bonus criterion required a revision commit (see Deviations) before passing. UAT artifact `38-UX-POL-03-UAT.md` records the fail → revision → re-pass narrative.

## Performance

- **Duration:** ~2h (including the human revision loop)
- **Tasks:** 5 (4 code fixes + 1 manual UAT)
- **Files modified:** 4
- **Files created:** 2 (`components/tooltip.css`, UAT artifact)

## Task Commits

1. **Task 1: G-01 dark-mode Tailwind class replacement** — `65609f67` (fix) + `e727b4a3` (fix, revision)
2. **Task 2: tournament_wizard.css specificity audit** — `05b38b45` (fix)
3. **Task 3: components/tooltip.css affordance rule** — `d814762b` (feat)
4. **Task 4: en.yml warm-up translation** — `d91079b3` (fix)
5. **Task 5: manual UAT artifact** — committed with this SUMMARY.md in the final plan-metadata commit

## Key Decisions Honored

- **D-03** — Tailwind class set for the G-01 info banner: `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100`. Matches the seed fix sketch verbatim.
- **D-04** — Audited `tournament_wizard.css` `.step-help p` via DevTools — which surfaced the real conflict at a different site (`.step-info`, see Deviations).
- **D-06** — New `components/tooltip.css` registered via `@import` in `application.tailwind.css` alongside existing `components/*.css` imports, matching the established 14+ file pattern.
- **D-07** — Broad `[data-controller~="tooltip"]` selector kept after audit: all 16 tooltip sites in `tournament_monitor.html.erb` are `<span>` wrappers with no nested form controls, so the broad rule is safe without narrowing.
- **D-09** — Exact `en.yml:844-846` warmup values applied verbatim.
- **D-10** — `en.yml:387 training: Training` preserved untouched — different semantic (practice-tournament concept, not scoreboard warm-up phase).
- **D-17** — UAT artifact structure follows Phase 36B UAT template: frontmatter (`status: complete`, `result: pass`), per-criterion result+observation blocks, Traceability section with commit hashes, Screenshot Evidence section.
- **D-18** — Task 5 (manual UAT) positioned as final task, gates the plan close.

## Deviations from Plan

### 1. [Rule 1 — Bug fix] G-01 CSS specificity revision (drop `.step-info` class)

- **Found during:** Task 5 (human UAT bonus criterion 5)
- **Issue:** Task 1 added `dark:text-green-100` to a `<div>` that still carried the legacy `step-info` class. The rule `html.dark .step-info { color: #d1d5db }` at `tournament_wizard.css:227-235` has specificity `(0, 2, 1)` — one class + one type. Tailwind's compiled `.dark .dark\:text-green-100` has specificity `(0, 2, 0)` — two classes. `(0, 2, 1) > (0, 2, 0)`, so the legacy rule won and the banner text stayed `#d1d5db` in dark mode. First-pass UAT screenshot captured the unreadable light-gray-on-light-green state.
- **Fix:** Dropped the `step-info` class from the info banner div at `_wizard_steps_v2.html.erb:170`; replaced with `text-sm` (preserves the 0.875rem font-size without the hostile color-override rule). Class-escape over specificity-bump preserves the Tailwind-first migration direction.
- **Files modified:** `app/views/tournaments/_wizard_steps_v2.html.erb`
- **Verification:** Human re-verified the Schritt 1 info banner in dark mode on `carambus_bcw` after the revision + Tailwind rebuild — now renders dark green translucent background with readable light-green text.
- **Committed in:** `e727b4a3` (revision commit)

### 2. [Rule 1 — Pre-existing bug] ERB interpolation bug (`#{…}` → `<%= … %>`)

- **Found during:** Task 5 (human UAT, same first-pass failure)
- **Issue:** The info banner at `_wizard_steps_v2.html.erb:170` had the literal text `#{non_local_seedings_count}` inside the banner body — Ruby string interpolation syntax, which is not valid inside an ERB body. This rendered as literal placeholder text to the user. Pre-existing bug (not introduced by Plan 38-01), but it was on the same line the Task 1 fix was editing, so the revision fixed both.
- **Fix:** Replaced `#{non_local_seedings_count}` with `<%= non_local_seedings_count %>` in the same revision.
- **Files modified:** `app/views/tournaments/_wizard_steps_v2.html.erb`
- **Verification:** Human confirmed correct player count rendered in the banner on re-verification.
- **Committed in:** `e727b4a3` (same revision commit as deviation 1 above)

### 3. [Rule 3 — Blocking / build-cache] Tailwind build refresh (`yarn build:css`)

- **Found during:** Task 5 diagnosis
- **Issue:** During Tasks 1-4, the Tailwind watcher was not running, so `dark:bg-green-900/30`, `dark:text-green-100`, and `dark:border-green-500` were all absent from the built `app/assets/builds/application.css`. Even if specificity had been right, the dark variants would not have reached the browser.
- **Fix:** Ran `yarn build:css` after the revision commit — the rebuild confirmed all three dark: utilities are now in the built CSS.
- **Files modified:** `app/assets/builds/application.css` (gitignored, not committed)
- **Verification:** Built CSS grep confirmed the dark: classes present post-rebuild.
- **Committed in:** N/A (gitignored build artifact; no commit needed)

### 4. [Minor — traceability] Task 4 smoke test command path mispath

- **Found during:** Task 4 verification
- **Issue:** The plan's smoke test command for Task 4 referenced `activerecord.attributes.game.state.training` as the protected I18n path for the `training: Training` key. The actual path at `en.yml:387` is under `home.index.training`. The key at `en.yml:387` is a different semantic from the warmup keys either way (per CONTEXT.md D-10), so the verification intent is preserved, but the smoke test command path was off.
- **Fix:** No code change needed — the warmup keys are correctly edited and the `training: Training` key at `en.yml:387` is correctly left untouched. Recorded here for traceability.
- **Files modified:** none
- **Verification:** `grep -n "training: Training" config/locales/en.yml` still returns the original line unchanged.
- **Committed in:** N/A

---

**Total deviations:** 4 (2 auto-fixed bugs, 1 build-cache blocking fix, 1 minor plan mispath for traceability)
**Impact on plan:** All deviations were correctness-preserving fixes needed to actually close UX-POL-01. No scope creep — the revision commit `e727b4a3` stayed inside the same file surface as Task 1.

## Requirements Closed

- **UX-POL-01** (G-01 dark-mode contrast) — 2 commits: `65609f67` (initial) + `e727b4a3` (revision)
- **UX-POL-02** (G-03 tooltip affordance) — `d814762b`
- **UX-POL-03** (Phase 36B Wizard Header Test 1 retest) — UAT artifact `38-UX-POL-03-UAT.md`, passed after revision
- **I18N-01** (G-05 EN warm-up translation) — `d91079b3`

## Issues Encountered

- CSS specificity + stale Tailwind build cache combo caused the first-pass UAT failure for bonus criterion 5. Resolved via revision commit `e727b4a3` + `yarn build:css` rebuild. See Deviations 1-3.

## Follow-up / Not Addressed

- **I18N-02** (Plan 38-02, Wave 2) — tournament views i18n audit still pending in Phase 38 Wave 2
- **DATA-01** (Phase 39) — DTP-backed `Discipline#parameter_ranges` rewrite, spun off to new Phase 39 per CONTEXT.md §"DATA-01 → Phase 39"
- **Pre-existing erblint warning** at `_wizard_steps_v2.html.erb:404` (trailing newline) — not fixed; out of scope for Phase 38 and pre-dates Plan 38-01
- **Doc deployment hardening (G-02 follow-up)** — remains a v7.1 backlog item from Phase 36B

## Next Phase Readiness

Plan 38-02 (tournament views i18n audit) is the next Wave 2 plan in Phase 38. It operates on a different file surface (23 ERB files in `app/views/tournaments/` minus `_wizard_steps_v2.html.erb`) so no blockers carry over from Plan 38-01.

---
*Phase: 38-ux-polish-i18n-debt*
*Plan: 01*
*Completed: 2026-04-15*
