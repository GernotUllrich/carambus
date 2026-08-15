---
status: complete
phase: 38-ux-polish-i18n-debt
source: [38-01-quick-wins-bundle-PLAN.md]
completed: 2026-04-15T14:10:00Z
result: pass
tags: [uat, ux-pol-03, wizard-header-retest, dark-mode]
---

# Phase 38 — UX-POL-03 Manual UAT (Phase 36B Wizard Header Test 1 Retest)

This UAT is the Phase 36B Wizard Header Test 1 retest that was explicitly deferred
until the G-01 dark-mode contrast fix had landed. Phase 36B UAT Test 1 was marked
`issue` not because the header criteria failed, but because the user was distracted
by the unreadable info banner (G-01) while on the Test 1 screen. Plan 38-01 closes
UX-POL-03 by re-running the four required header criteria plus a bonus G-01
confirmation against `carambus_bcw` after Tasks 1-4 of Plan 38-01 shipped.

Traceability back to the source plan: `38-01-quick-wins-bundle-PLAN.md` Task 5
(`UX-POL-03` final task, gate for closing Plan 38-01).

## Setup

Per CLAUDE.md and the `scenario-management` skill, `carambus_api` runs in
API-mode in dev; manual tournament walkthroughs must run against
`carambus_bcw` (LOCAL context). The human tester switched to the
`carambus_bcw` checkout, pulled the 5 Plan 38-01 source files from the
`carambus_api` working tree, started the `carambus_bcw` dev server
(`foreman start -f Procfile.dev`), and opened a tournament in
`new_tournament` / `accreditation_finished` state to render the wizard.

Files pulled from `carambus_api` into `carambus_bcw` for the UAT:

- `app/views/tournaments/_wizard_steps_v2.html.erb`
- `app/assets/stylesheets/tournament_wizard.css`
- `app/assets/stylesheets/components/tooltip.css` (new file)
- `app/assets/stylesheets/application.tailwind.css` (added `@import` line)
- `config/locales/en.yml`

## Test 1: Wizard Header Visual Check (UX-POL-03)

This is the explicit retest of Phase 36B UAT Test 1 "Wizard header visual check
(FIX-04 + FIX-03)", deferred until G-01 landed. Four required criteria from
`38-CONTEXT.md` §D-17.

### Criterion 1 — Dominant AASM state badge
result: pass
observation: |
  The wizard header displays a large colored AASM state badge as the visually
  dominant element at the top of the header. Orange badge for `new_tournament`,
  blue for `accreditation_finished` (both confirmed on different tournaments in
  the UAT session). The badge is clearly the focal point, not the step list.

### Criterion 2 — 6 bucket chips present
result: pass
observation: |
  Exactly six wizard bucket chips render below the badge, with the chip
  corresponding to the current AASM state highlighted. All six present — not
  five, not seven. Chip labels match the Phase 36B target vocabulary.

### Criterion 3 — NO "Schritt N von 6" text
result: pass
observation: |
  Browser Ctrl-F search for the literal string "Schritt" on the wizard page
  returns only the individual step card headings ("Schritt 1: …", "Schritt 2:
  …", etc.) — zero occurrences of the removed progress indicator phrase
  "Schritt N von 6" (or "Step N of 6"). The old progress bar is also gone.

### Criterion 4 — NO numeric prefix on step labels
result: pass
observation: |
  The wizard step card headings do NOT have numeric prefixes like "1.", "2.",
  "3." on the action label itself. Each step card shows "Schritt N: <action>"
  where the "Schritt N:" is the structural card title from Phase 36B FIX-03
  and the `<action>` is the bare action label (e.g., "Meldeliste importieren"),
  not "1. Meldeliste importieren".

## Bonus: G-01 Dark-Mode Contrast Confirmation (UX-POL-01)

This is the bonus fifth criterion from `38-CONTEXT.md` §D-17 — it ties the
retest directly to the G-01 fix having actually landed at runtime, not just
in the source tree.

### First pass — result: fail

evidence: /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 13.38.38.png

observation: |
  After pulling Plan 38-01 Tasks 1-4 into `carambus_bcw` and restarting the
  dev server, the Schritt 1 info banner ("Es sind bereits N Spieler
  vorhanden") rendered unreadable in dark mode. DevTools inspection showed:
    - Text color: `rgb(209, 213, 219)` (= `#d1d5db`, Tailwind `text-gray-300`)
    - Background: `rgb(240, 253, 244)` (= `#f0fdf4`, Tailwind `bg-green-50`)
  A light-gray-on-light-green WCAG fail — the same class of bug Phase 36B G-01
  was meant to close. Additionally, the banner rendered the literal text
  `#{non_local_seedings_count}` (as a string, not interpolated) because of an
  ERB body-interpolation bug that predated Plan 38-01.

diagnosis: |
  Two independent issues stacked on the same banner:

  1. **CSS specificity conflict.** Task 1 of Plan 38-01 added
     `dark:text-green-100` to a `<div>` that also carried the legacy
     `step-info` class. The selector `html.dark .step-info { color: #d1d5db }`
     at `app/assets/stylesheets/tournament_wizard.css:227-235` has specificity
     `(0, 2, 1)` — one class + one type. Tailwind's compiled
     `.dark .dark\:text-green-100 { color: … }` utility has specificity
     `(0, 2, 0)` — two classes, no type. `(0, 2, 1) > (0, 2, 0)`, so the
     legacy rule won and the banner text stayed `#d1d5db` in dark mode
     regardless of the dark-mode Tailwind utility.
  2. **Stale Tailwind build.** The Tailwind watcher had not been running
     during Plan 38-01 Tasks 1-4, so even the classes that would have won
     specificity were missing from the built `app/assets/builds/application.css`.
     Grep for `dark:bg-green-900/30`, `dark:text-green-100`, and
     `dark:border-green-500` in the built CSS returned zero matches.

### Revision — commit `e727b4a3`

observation: |
  Revision commit `e727b4a3` ("fix(38): drop .step-info on info banner to
  defeat dark-mode color override (G-01 revision / UX-POL-01)") applied two
  fixes on top of Task 1:

  (a) Dropped the hostile `step-info` class from the info banner div at
      `_wizard_steps_v2.html.erb:170`, replacing it with `text-sm` (preserves
      the 0.875rem font-size without the color-override rule). This escapes
      the `html.dark .step-info { color: #d1d5db }` selector entirely —
      Tailwind's `dark:text-green-100` now wins because the legacy selector
      no longer matches the element.
  (b) Fixed the pre-existing ERB bug where `#{non_local_seedings_count}`
      (Ruby string interpolation, not valid in ERB body) was rendering as
      literal placeholder text; replaced with `<%= non_local_seedings_count %>`.

  After the revision commit, `yarn build:css` was run to refresh
  `app/assets/builds/application.css` — the rebuild confirmed that
  `dark:bg-green-900/30`, `dark:text-green-100`, and `dark:border-green-500`
  are now all present in the built CSS (they were all absent before). The
  built CSS file is gitignored and does not need committing.

### Second pass — result: pass

observation: |
  After the revision commit `e727b4a3` landed and Tailwind CSS was rebuilt,
  the human re-ran the Schritt 1 wizard view in dark mode and approved the
  bonus criterion. The info banner now renders with a dark green translucent
  background (`bg-green-50 dark:bg-green-900/30`), a visible dark-green
  border (`border border-green-600 dark:border-green-500`), and readable
  light-green text (`text-green-900 dark:text-green-100`). The
  `non_local_seedings_count` variable now interpolates correctly into the
  banner text. WCAG contrast ratio visually passes (no DevTools measurement
  captured for the second pass — textual approval only).

  No second-pass screenshot was saved; the first-pass failure screenshot
  remains on record as evidence for the fail → revision → re-pass
  narrative.

## G-03 Sanity Check (UX-POL-02)

result: pass

observation: |
  The 16 tooltipped labels on `tournament_monitor.html.erb` now show a
  dashed underline + `cursor: help` affordance on hover, per the new
  `components/tooltip.css` attribute selector `[data-controller~="tooltip"]`.
  Labels are visually distinguished from static text, closing G-03. The
  sanity check was covered under the human's "everything else approved"
  confirmation during the second-pass re-verification (no separate
  screenshot captured).

## G-05 Sanity Check (I18N-01)

result: pass

observation: |
  The scoreboard warm-up state renders as "Warm-up" / "Warm-up Player A" /
  "Warm-up Player B" under `?locale=en` — the old "Training" / "Training
  Player A" / "Training Player B" values from Phase 36B G-05 are gone. This
  is the `table_monitor.status.warmup*` subtree at `config/locales/en.yml:844-846`
  only; the separate `activerecord.attributes.game.state.training: Training`
  key at `en.yml:387` is intentionally preserved (different semantic — the
  practice-tournament concept, per CONTEXT.md D-10). Covered under the same
  "everything else approved" second-pass confirmation.

## Summary

| Metric            | Value                       |
|-------------------|-----------------------------|
| Required criteria | 4 passed, 0 failed          |
| Bonus criterion   | 1 passed (after revision)   |
| Sanity checks     | 2 passed                    |
| Total             | 7 passed, 0 issues, 0 pending |
| Result            | pass                        |

## Traceability

- **Plan:** `38-01-quick-wins-bundle-PLAN.md` (Task 5 — final gate for closing Plan 38-01)
- **Requirements closed:** UX-POL-01, UX-POL-02, UX-POL-03, I18N-01
- **Initial-attempt commits (Tasks 1-4):**
  - `65609f67` — fix(38): replace inline info banner style with dark-mode Tailwind variants (G-01 / UX-POL-01)
  - `05b38b45` — fix(38): audit tournament_wizard.css .step-help p specificity (G-01 / UX-POL-01)
  - `d814762b` — feat(38): add components/tooltip.css affordance rule (G-03 / UX-POL-02)
  - `d91079b3` — fix(38): correct EN warmup translations (G-05 / I18N-01)
- **Revision commit (G-01 specificity / ERB fix):**
  - `e727b4a3` — fix(38): drop .step-info on info banner to defeat dark-mode color override (G-01 revision / UX-POL-01)
- **Source gap:** Phase 36B `G-01` (dark-mode contrast), `G-03` (tooltip affordance), `G-05` (warm-up EN translation), and Phase 36B UAT Test 1 retest (header badge / bucket chips / removed "Schritt N von 6" text / removed numeric prefix on step labels)
- **Phase 36B UAT template:** `.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md`

## Screenshot Evidence

- **First-pass fail (bonus criterion 5, G-01 dark mode):**
  `/Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 13.38.38.png`
  Shows the Schritt 1 info banner rendering unreadable light-gray text
  (`rgb(209, 213, 219)` = `#d1d5db`) on a light-green background
  (`rgb(240, 253, 244)` = `#f0fdf4`), plus the literal
  `#{non_local_seedings_count}` placeholder text in place of the player count.
- **Second-pass re-approval:** textual approval only; no screenshot captured.

---

*Phase: 38-ux-polish-i18n-debt*
*UAT completed: 2026-04-15*
*Plan: 38-01-quick-wins-bundle-PLAN.md*
