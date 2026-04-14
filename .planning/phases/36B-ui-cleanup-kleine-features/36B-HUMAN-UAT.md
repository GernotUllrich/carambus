---
status: partial
phase: 36B-ui-cleanup-kleine-features
source: [36B-VERIFICATION.md]
started: 2026-04-14T18:30:00Z
updated: 2026-04-14T18:30:00Z
---

## Current Test

number: 2
name: Active step help block auto-opens (FIX-01)
expected: |
  - The active step's <details> help block is already open
  - Non-active steps' help blocks are collapsed
  - The troubleshooting "Turnier nicht gefunden?" block stays closed by default
awaiting: user response

## Tests

### 1. Wizard header visual check (FIX-04 + FIX-03)
where: carambus_bcw (LOCAL context) — open any tournament show page
expected: |
  - Large colored AASM state badge is the visually dominant element in the header
    (orange for new_tournament, blue for accreditation_finished, green for tournament_started)
  - Six wizard bucket chips render below the badge with the active bucket highlighted
  - Progress bar and "Schritt N von 6" text are gone
  - No numeric prefixes (1., 2., etc.) appear in any step card header
result: issue
severity: medium
observation: |
  Header badge/chips not explicitly negated by the tester but a separate dark-mode contrast
  bug was found while inspecting Schritt 2 "Setzliste aus Einladung übernehmen" (see Gap G-01).
  Header-specific criteria (badge, chips, progress-bar removal, no numeric prefixes) still need
  explicit confirmation — retest after G-01 is fixed.
evidence: /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.04.50.png

### 2. Active step help block auto-opens (FIX-01)
where: carambus_bcw — open a tournament in any non-closed state
expected: |
  - The active step's <details> help block is already open
  - Non-active steps' help blocks are collapsed
  - The troubleshooting "Turnier nicht gefunden?" block stays closed by default
result: [pending]

### 3. Parameter form tooltips (UI-01)
where: carambus_bcw — Turnier-Monitor parameter form (before start)
expected: |
  - Hovering any of the 16 parameter labels shows a dark Tailwind tooltip card with German explanatory text
  - Keyboard-focus (Tab to a label) also opens the tooltip
  - No tooltip flashes before or below viewport edges unexpectedly
  - admin_controlled row is gone entirely (no label, no checkbox)
result: [pending]

### 4. German parameter labels (UI-02)
where: carambus_bcw — Turnier-Monitor parameter form (DE locale)
expected: |
  - Every label reads in German (no English literals)
  - Switching to EN locale shows the English equivalents
result: [pending]

### 5. Dead-code _current_games table (UI-04)
where: carambus_bcw — open Turnier-Monitor page for a running tournament
expected: |
  - The "Aktuelle Spiele" table shows only read-only columns
  - No set_balls input field, no +1/-1/+10/-10 buttons, no undo/next buttons
  - The "OK?" / "wait_check" state-display link still works
  - Table-exchange up/down arrows still render
result: [pending]

### 6. Reset confirmation modal (UI-06)
where: carambus_bcw — open a tournament and click any Reset button
expected: |
  - A Tailwind modal appears (not a native browser confirm) with title, body, Cancel, and Confirm buttons
  - Body text shows current AASM state + number of games played inline
  - Cancel closes the modal without resetting; Confirm triggers the reset action
  - Modal is always shown regardless of AASM state
  - Works on both primary reset (show.html.erb) and force-reset (finalize_modus.html.erb)
result: [pending]

### 7. Parameter verification modal (UI-07)
where: carambus_bcw — parameter form, set balls_goal out of range (e.g., 99999), submit
expected: |
  - The start form submit re-renders with the shared confirmation modal auto-opening
  - Modal shows out-of-range values and asks for explicit confirmation
  - Cancel closes; Confirm passes the hidden override and starts the tournament
  - In-range values submit straight through to start_tournament! with no modal
  - No inline <script> runs — everything is Stimulus-driven
result: [pending]

### 8. admin_controlled removal end-to-end (UI-03)
where: carambus_bcw — Turnier-Monitor for tournament in play, confirm last game of round at scoreboard
expected: |
  - No "Rundenwechsel manuell bestätigen" checkbox in the parameter form
  - Round auto-advances without manual intervention when the last game of a round is confirmed
  - Behavior holds regardless of whether admin_controlled was previously true on an imported global record
result: [pending]

## Summary

total: 8
passed: 0
issues: 1
pending: 7
skipped: 0
blocked: 0

cross_phase_gaps: 1  # G-02 affects Phases 34, 35, 36a, 37

## Gaps

### G-01: Dark-mode contrast in wizard step `<details>` help block and inline-styled info banners
severity: medium
scope: all wizard steps (Step 2 observed) — affects any step that renders the `<details>` help block or an inline-styled `.step-info` info banner
found_during: Test 1 (user hit this while on Test 1; the bug is also Test 2 territory since FIX-01 auto-opens the block)
evidence: /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.04.50.png

observation: |
  Schritt 2 "Setzliste aus Einladung übernehmen" in dark mode — the "Info text" inside
  the step card is not readable. The user reported "Info Text im dark mode nicht lesbar".

root_cause_candidates:
  - app/views/tournaments/_wizard_steps_v2.html.erb:167
    The "Es sind bereits N Spieler vorhanden" banner hardcodes an inline
    `style="background: #dff0d8; ..."` (light green) on a `<div class="step-info mt-2">`.
    Meanwhile app/assets/stylesheets/tournament_wizard.css:233-234 applies
    `html.dark .step-info { color: #d1d5db; }` (light gray). In dark mode this renders
    light-gray text on a light-green background — WCAG fail, visually invisible.
  - app/views/tournaments/_wizard_steps_v2.html.erb:183-194
    The `<details>` help body `<p>` with `<strong>` tags. `tournament_wizard.css:287-295`
    has `html.dark .step-help p { color: #d1d5db; }` which *should* give 8.5:1 on the
    `wizard-step-active` dark navy bg (#1e3a8a) — but the screenshot suggests something
    is overriding or the rule isn't reaching this `<p>`. Inspect in DevTools to confirm
    whether .step-help p actually wins specificity, or whether a Tailwind reset
    (application.tailwind.css) clobbers the plain-CSS color.
  - More broadly: every inline-styled light background hardcoded in ERB across the
    wizard partials (e.g., `_wizard_steps_v2.html.erb:215` blue-gradient, line 268
    test link, line 373 Begriffserklärung uses Tailwind dark: classes which DO work).
    Audit all inline `style="background: ..."` declarations and either wrap them with
    conditional `dark:bg-*` Tailwind classes or add matching `dark:text-*` overrides.

fix_sketch:
  1. Replace the inline `style="background: #dff0d8; ..."` at line 167 with Tailwind
     classes `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500
     text-green-900 dark:text-green-100` so the banner has correct contrast in both modes.
  2. Audit `tournament_wizard.css` for `.step-help p` to confirm the dark-mode rule
     actually takes effect (specificity, source order vs Tailwind reset). If not,
     bump specificity or convert to a Tailwind `@apply` directive in application.tailwind.css.
  3. Do the same audit for lines 215 and 268 in `_wizard_steps_v2.html.erb`.

impact_on_phase_37: |
  Phase 37 added a `mkdocs_link` call inside the same `<details>` help block
  (D-11 placement). The doc link text uses the i18n string with an emoji prefix;
  if the `<details>` body text is unreadable in dark mode, the new doc link is
  ALSO unreadable in dark mode. Fixing G-01 is a prerequisite for Phase 37's
  in-app doc links to be usable by dark-mode volunteers.

### G-02: Cross-phase doc deployment gap — `public/docs/` never rebuilt since Phase 33
severity: **high** (blocks the entire v7.0 doc work from reaching users)
scope: Phases 34, 35, 36a, 37 — every phase that touched `docs/**/*.md` source files
found_during: Test 2 (user clicked a Phase 37 wizard doc link and saw the old Mar-18 document)
symptom: |
  The user clicked the "📖 Detailanleitung im Handbuch" link added by Phase 37
  in the Turnierverwaltung wizard. Expected: rewritten walkthrough with task-first
  structure (Phase 34) + 58 corrections (Phase 36a) + deep-link anchor `#seeding-list`
  (Phase 37). Actual: the pre-v7.0 Mar 18 document.
  User quote: "Der Link auf die Turnierverwaltung zeigt das alte Dokument. Sieht so
  aus als ob mkdocs build nicht gelaufen ist"

root_cause: |
  Rails serves `/docs/*` from `public/docs/*` (git-tracked). The build flow is:
  1. Edit source `.md` files in `docs/`
  2. Run `bin/rails mkdocs:build` which runs `mkdocs build` (→ `site/`) AND then
     `FileUtils.cp_r(Dir.glob("site/*"), public/docs)` (see lib/tasks/mkdocs.rake:29)
  3. Commit `public/docs/` changes

  Last `public/docs/` commit: `77d4528d "fix rails rendered docs"` on 2026-03-18.
  Since then, the following commits edited doc source files WITHOUT a follow-up rebuild:
    - e3e509ba docs(managers): apply 30 review findings + Du-form to .de.md (Phase 36a)
    - 475628d6 docs(managers): mirror DE review findings to .en.md (Phase 36a)
    - 9b4c8ebe docs(36A-06): add Anhang section with 6 sub-sections (DE)
    - 5dd6b0be docs(36A-06): mirror Appendix section (EN)
    - e52d616e docs(36A-05): rewrite Block 7 troubleshooting + remove architecture (EN)
    - 0fff0384 docs(36A-05): rewrite Block 7 troubleshooting + remove Mehr-zur-Technik (DE)
    - 101eb05d docs(37-02): add 4 stable anchors to .de.md (Phase 37)
    - 9088870e docs(37-02): add 4 stable anchors to .en.md (Phase 37)
    - plus Phase 34 (task-first rewrite) and Phase 35 (Quick-Reference Card) changes
      earlier in the v7.0 timeline.

  Phase 37's Plan 37-02 ran raw `mkdocs build --strict` which writes to `site/` only —
  it never copied to `public/docs/`. The `site/managers/tournament-management/index.html`
  (Apr 14 22:51) HAS the 4 stable anchors; the `public/docs/...index.html` (Mar 18 02:58)
  does NOT. Rails serves the stale public/docs copy.

fix_path:
  1. Run `bin/rails mkdocs:build` — this rebuilds `site/` AND copies to `public/docs/`
  2. Verify `grep -c 'id="seeding-list"' public/docs/managers/tournament-management/index.html` ≥ 1
  3. Verify `grep -c 'id="seeding-list"' public/docs/en/managers/tournament-management/index.html` ≥ 1
  4. Verify Phase 34 structural changes are present (e.g., Du-form headings)
  5. `git add public/docs/` — expect ~600 files changed (big diff, but mechanical)
  6. Commit: `docs(37): rebuild public/docs with v7.0 phase 34/35/36a/37 source changes`
  7. User refreshes browser and re-verifies Phase 37 LINK-02 reaches the rewritten doc

validation_gap: |
  Plan 37-02 Task 3 verified `mkdocs build --strict` passes with 0 warnings.
  That verification was incomplete — it never checked whether the build artifact
  actually reaches `public/docs/`. The `site/` vs `public/docs/` distinction was
  invisible to the plan checker and gsd-verifier both, because neither spot-checked
  the served HTML file.

  This is a **gsd-verifier false positive**: Phase 37 was marked PHASE COMPLETE while
  users cannot actually click through to the rewritten doc. Goal-backward verification
  should have simulated a real request to `/docs/managers/tournament-management/` and
  asserted the rewritten content is served, not just that the source `.md` files contain
  the anchors.

  Follow-up: Phase 37 verification criteria should be amended to include:
  - `public/docs/managers/tournament-management/index.html` contains `id="seeding-list"`
  - Plus the equivalent for `.en` path
  - Plus a `curl` or `bin/rails runner` check against a live Rails server rendering
    the docs_page or a direct public-file fetch

impact_on_phase_36b_uat: |
  Does NOT block the 8 visual UAT tests — those are about the wizard UI, not the docs.
  But tests that click through the doc link (Phase 37 follow-up UAT) are all blocked
  until G-02 is fixed. Fix G-02 before running any /gsd-verify-work for Phase 37.

related_cleanup:
  - lib/tasks/mkdocs.rake should probably become a post-commit hook or a `rails docs:build`
    task that's part of the pre-commit gate for any change under `docs/**/*.md`.
  - Alternatively: drop `public/docs/` from git entirely and have CI/deploy run the copy.
    The current hybrid — git-tracked built artifact — is fragile because human discipline
    is required to run the rebuild on every source change.
  - Capture this as a follow-up plan for v7.1 milestone (new phase: "Doc deployment
    hardening" — add rake guard + CI check that fails if `docs/**/*.md` mtime > public/docs/).
