---
status: complete
phase: 36B-ui-cleanup-kleine-features
source: [36B-VERIFICATION.md]
started: 2026-04-14T18:30:00Z
updated: 2026-04-15T00:55:00Z
completed: 2026-04-15T00:55:00Z
---

## Current Test

ALL TESTS COMPLETE (7 pass, 1 issue, 0 pending).
See Summary section for final counts and Gaps section for 6 follow-up findings.

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
result: pass

### 3. Parameter form tooltips (UI-01)
where: carambus_bcw — Turnier-Monitor parameter form (before start)
expected: |
  - Hovering any of the 16 parameter labels shows a dark Tailwind tooltip card with German explanatory text
  - Keyboard-focus (Tab to a label) also opens the tooltip
  - No tooltip flashes before or below viewport edges unexpectedly
  - admin_controlled row is gone entirely (no label, no checkbox)
result: pass
notes: |
  Functionality confirmed working (tooltip hover, German text, dark card).
  Follow-up Gap G-03: tooltip-carrying labels have no visual affordance and blend with
  non-interactive text. User: "Tooltip sollte optisch besser von den anderen Label-Texten
  abgehoben werden. So ist das Augenpulver."
evidence: /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.34.41.png

### 4. German parameter labels (UI-02)
where: carambus_bcw — Turnier-Monitor parameter form (DE locale)
expected: |
  - Every label reads in German (no English literals)
  - Switching to EN locale shows the English equivalents
result: pass
notes: |
  Parameter form labels pass. User also observed a broader issue: "vieles auf der
  Seite ist DE-only (war auch vorher schon so)" — other elements on tournament_monitor
  (and the surrounding wizard page) still have hardcoded German. This is PRE-EXISTING
  debt, NOT introduced by Phase 36B (UI-02 only scoped the 16 parameter labels) and
  should not block Test 4. Logged as Gap G-04 for future i18n coverage work.

### 5. Dead-code _current_games table (UI-04)
where: carambus_bcw — open Turnier-Monitor page for a running tournament
expected: |
  - The "Aktuelle Spiele" table shows only read-only columns
  - No set_balls input field, no +1/-1/+10/-10 buttons, no undo/next buttons
  - The "OK?" / "wait_check" state-display link still works
  - Table-exchange up/down arrows still render
result: pass
notes: |
  UI-04 confirmed: read-only table, no input/buttons, state-label link works,
  exchange arrows render. User also flagged two separate observations while on
  this page:
  (1) EN locale shows game state as "Training" — should be "Warmup". Logged as
      Gap G-05 (same string appears in the scoreboard view too — not scoped to
      _current_games).
  (2) "Scoreboards anzeigen" correctly navigates to the table scores view. The
      user noted "Hier war die Erwartung möglicherweise etwas anders" — confirmed
      as expectation mismatch on tester side, NOT a code defect. No gap logged.
evidence:
  - /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.49.05.png (Current Games table with "Training")
  - /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.51.32.png (Scoreboard view T1/T2)

### 6. Reset confirmation modal (UI-06)
where: carambus_bcw — open a tournament and click any Reset button
expected: |
  - A Tailwind modal appears (not a native browser confirm) with title, body, Cancel, and Confirm buttons
  - Body text shows current AASM state + number of games played inline
  - Cancel closes the modal without resetting; Confirm triggers the reset action
  - Modal is always shown regardless of AASM state
  - Works on both primary reset (show.html.erb) and force-reset (finalize_modus.html.erb)
result: pass

### 7. Parameter verification modal (UI-07)
where: carambus_bcw — parameter form, set balls_goal out of range (e.g., 99999), submit
expected: |
  - The start form submit re-renders with the shared confirmation modal auto-opening
  - Modal shows out-of-range values and asks for explicit confirmation
  - Cancel closes; Confirm passes the hidden override and starts the tournament
  - In-range values submit straight through to start_tournament! with no modal
  - No inline <script> runs — everything is Stimulus-driven
result: pass
notes: |
  Modal flow works (out-of-range → modal; in-range → straight start; cancel/confirm
  both wired correctly; no inline <script>). User flagged a separate concern: the
  value ranges themselves were derived from one specific scenario and need rework
  to cover youth/elite/handicap tournaments and non-carom disciplines. Logged as
  Gap G-06. NOT a Phase 36B regression — the mechanism works; the DATA is too narrow.

### 8. admin_controlled removal end-to-end (UI-03)
where: carambus_bcw — Turnier-Monitor for tournament in play, confirm last game of round at scoreboard
expected: |
  - No "Rundenwechsel manuell bestätigen" checkbox in the parameter form
  - Round auto-advances without manual intervention when the last game of a round is confirmed
  - Behavior holds regardless of whether admin_controlled was previously true on an imported global record
result: pass

## Summary

total: 8
passed: 7
issues: 1
pending: 0
skipped: 0
blocked: 0

cross_phase_gaps: 1  # G-02 affects Phases 34, 35, 36a, 37 — FIXED by commit 7cf16114
follow_up_gaps: 5   # G-01, G-03, G-04, G-05, G-06 (all non-regression, candidate for v7.1 micro-phase)
completion: |
  7 of 8 tests passed outright. Test 1 marked "issue" per workflow convention (user
  flagged G-01 dark-mode bug while on Test 1 rather than explicitly negating Test 1
  criteria); header-specific criteria (badge dominance, 6 chips, no "Schritt N von 6",
  no numeric prefixes) should be retested after G-01 is fixed.
  All 6 gaps are NON-REGRESSIONS (pre-existing bugs or polish follow-ups) that do NOT
  block v7.0 milestone completion. G-02 was fixed inline during this UAT session.

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

resolution: |
  RESOLVED by commit 7cf16114 ("docs(G-02): rebuild public/docs with v7.0 phase 34/35/36a/37
  source changes") on 2026-04-15. Ran `bin/rails mkdocs:build` → 257 files changed,
  +70,891 / −14,984 lines. All 4 Phase 37 anchors confirmed in both DE and EN HTML:
  id="seeding-list", id="participants", id="mode-selection", id="start-parameters".
  Phase 34 "Durchführung Schritt für Schritt" heading present. User to re-verify by
  refreshing the wizard in carambus_bcw and clicking a doc link.
  The hardening follow-up (rake guard / pre-commit hook / CI check) remains open as a
  v7.1 backlog item — this commit is the tactical fix, not the structural one.

### G-03: Tooltip-carrying labels have no visual affordance (UI-01 follow-up)
severity: low (UX polish; Test 3 passed functionally)
scope: `app/views/tournaments/tournament_monitor.html.erb` (all 16 parameter label triggers) and the shared Stimulus `tooltip_controller.js` wrapper
found_during: Test 3 (Parameter form tooltips / UI-01)
evidence: /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.34.41.png

observation: |
  Tooltips function correctly (dark card, German text, hover + focus trigger). But the
  labels that CARRY tooltips look visually identical to any static text on the page —
  there's no affordance hint (no dashed underline, no cursor: help, no ⓘ icon) telling
  a 2×/year volunteer "this label has more help if you hover it". The volunteer has to
  hover everywhere to discover which labels are interactive, which the user described
  as "Augenpulver" (literally: eye-powder / eye-strain).

user_quote: |
  "Tooltip sollte optisch besser von den anderen Label-Texten abgehoben werden.
  So ist das Augenpulver. Ansonsten pass."

fix_sketch:
  Option A (minimal, zero-cost): add `cursor: help` + dashed underline via a CSS class
    applied to the `data-controller="tooltip"` wrapper.
    CSS:
      [data-controller~="tooltip"] {
        cursor: help;
        border-bottom: 1px dashed currentColor;
        padding-bottom: 1px;
      }
    This auto-applies to all 16 tooltipped labels without touching ERB.

  Option B (more explicit): prepend a small ⓘ icon before each label via the tooltip
    controller's initial render. Slightly more code but more visible.

  Option C (Tailwind utility approach): add `underline decoration-dotted underline-offset-4
    decoration-gray-400 cursor-help` classes to the tooltip trigger spans in the ERB.
    Matches existing Tailwind conventions but requires touching 16 sites (or a partial).

  Recommended: Option A — global CSS rule on the attribute selector. One change, affects
  all existing and future tooltip-carrying elements, no ERB touching, no JS changes.
  Add to `app/assets/stylesheets/application.tailwind.css` or create a small
  `app/assets/stylesheets/tooltip.css` imported alongside tournament_wizard.css.

  Care: option A might accidentally apply to nested elements if a tooltip wrapper
  contains a form control. Scope with `[data-controller~="tooltip"] > span, label`
  or similar if testing shows bleed.

fix_estimate: ~15 LOC, single CSS change, no tests needed beyond visual confirmation.
  Could be rolled into a v7.1 "UX polish" micro-phase alongside G-01.

relationship_to_g01: |
  G-01 (dark-mode contrast) and G-03 (tooltip affordance) are both small UX polish
  items found during Phase 36b human UAT. Recommend rolling both into one v7.1-v7.1
  micro-phase: "v7.0 UX polish debt" with a ~2-3 plan structure.

### G-04: Pre-existing DE-only hardcoded strings across tournament_monitor surrounds
severity: low (pre-existing, NOT a Phase 36B regression — Phase 36B's UI-02 scope was
  explicitly "the 16 parameter labels", which passed Test 4)
scope: `app/views/tournaments/tournament_monitor.html.erb` (non-parameter sections),
  `app/views/tournaments/show.html.erb`, various wizard-adjacent partials, possibly
  `_wizard_steps_v2.html.erb` static headings not yet i18n'd
found_during: Test 4 (German parameter labels / UI-02)

observation: |
  While testing Test 4, the user confirmed all 16 parameter labels are correctly
  i18n'd in both DE and EN (UI-02 works). But they noted the broader Turnier-Monitor
  page still contains many hardcoded German strings outside the scope of UI-02.
  These did not regress — they were already hardcoded before v7.0.
  User quote: "pass - aber vieles auf der Seite ist DE-only (war auch vorher schon so)"

out_of_scope_confirmation: |
  Phase 36B's UI-02 requirement text reads:
  "Full i18n conversion for every label in tournament_monitor.html.erb" — which Phase 36b
  interpreted (per D-07) as specifically the parameter form labels. Headings, buttons,
  status strings, and other page chrome were NOT in scope. This is consistent with the
  36B-CONTEXT.md decision boundary.

follow_up:
  - Catalog the specific DE-only strings on tournament_monitor + surrounding views
    (grep for literal German words: "Aktuelle", "Turnier", "Starte", "zurück", etc.
    outside `t('...')` calls)
  - Create a v7.1 or later i18n coverage plan covering the full Turnier-Monitor page
    and adjacent wizard partials
  - Not urgent — DE is the primary locale for 2×/year volunteers anyway; EN coverage
    gaps here mostly affect admins who are already English-comfortable in the shell.

relationship: |
  G-01, G-03, G-04 are all small UX-polish or i18n debt items that emerged from Phase 36B
  human UAT but do NOT fail the Phase 36B acceptance criteria. They're candidates for a
  single v7.1 "UX polish & i18n debt" micro-phase.

### G-05: EN translation value "Training" should be "Warmup" for game/state warmup labels
severity: low (pre-existing translation bug; not Phase 36B scope)
scope: `config/locales/en.yml:844-846` — `table_monitor.status.warmup`, `warmup_a`, `warmup_b`
found_during: Test 5 (Dead-code _current_games table / UI-04)
evidence:
  - /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.49.05.png (Current Games table showing "Training" state label)
  - /Users/gullrich/Desktop/Bildschirmfoto 2026-04-15 um 00.51.32.png (Scoreboard T1 showing "Training" state label)

observation: |
  In locale=en, the carom warm-up game phase renders as "Training" on both the
  Turnier-Monitor "Current Games" table AND the scoreboard view. "Training" in
  English means practice/coaching — wrong for a pre-match warm-up. The correct
  English term is "Warmup" (or "Warm-up").
  User quote: "Die Spiele erscheinen im Status 'Training' (locale=en) - da sollte
  'Warmup' stehen"

root_cause: |
  config/locales/en.yml:844-846 has the wrong English values:
    table_monitor:
      status:
        warmup: Training           # ← should be "Warmup" or "Warm-up"
        warmup_a: Training Player A  # ← should be "Warm-up Player A"
        warmup_b: Training Player B  # ← should be "Warm-up Player B"

  German equivalents at config/locales/de.yml:864-866 are fine:
    warmup: Spielbeginn
    warmup_a: Einstoßen Spieler A
    warmup_b: Einstoßen Spieler B

  Note: there is a separate key `activerecord.attributes.game.state.training: Training`
  at en.yml:387 which is actually a DIFFERENT game mode ("Training Game" = practice
  tournament, not warm-up phase). That key is correct and should NOT be touched.

fix:
  Single-file edit, 3 lines:
    config/locales/en.yml:844  warmup: Warm-up
    config/locales/en.yml:845  warmup_a: Warm-up Player A
    config/locales/en.yml:846  warmup_b: Warm-up Player B

  (Hyphenated "Warm-up" is the standard English spelling. "Warmup" without hyphen
  is also acceptable; either will read correctly. Recommend hyphenated for formality.)

estimate: ~5 minutes including a smoke test of switching locale=en on the scoreboard
  and confirming "Warm-up" renders.

out_of_scope_confirmation: |
  Phase 36B's UI-02 was about i18n-ing the 16 parameter LABELS in tournament_monitor.html.erb.
  State translation VALUES like warmup/warmup_a/warmup_b are a different concern and were
  never in Phase 36B scope. This is a pre-existing bug that was surfaced (not caused) by
  the human UAT.

candidate_phase: |
  Fold into the same v7.1 "UX polish & i18n debt" micro-phase as G-01, G-03, G-04.
  G-05 is the smallest of the four (3-line fix) and could be the first plan in that
  micro-phase — zero-risk warm-up for the larger items.

### G-06: Discipline#parameter_ranges derived from one specific scenario, need rework
severity: medium (UI-07 verification modal triggers on values users may legitimately set)
scope: `app/models/discipline.rb:66-94` — `UI_07_DISCIPLINE_SPECIFIC_RANGES` and
  `UI_07_SHARED_RANGES` constants feeding `Discipline#parameter_ranges`
found_during: Test 7 (Parameter verification modal / UI-07)
user_quote: "the value ranges need rework - they were derived from a very specific case"

current_state: |
  Ranges are hardcoded for carom disciplines only (Freie Partie, Cadre, Einband,
  Dreiband, 5-Kegel-Billard). Pool, Snooker, and Biathlon have no entries, so
  `parameter_ranges` returns `{}` (no validation) for those. Shared defaults:
    time_out_warm_up_first_min: 1..10
    time_out_warm_up_follow_up_min: 0..5
    sets_to_play: 1..7
    sets_to_win: 1..4
  Discipline-specific examples:
    Freie Partie → balls_goal: 50..500, innings_goal: 20..80, timeout: 30..90
    Dreiband → balls_goal: 10..80, innings_goal: 20..80, timeout: 30..90
    Einband → balls_goal: 30..200, innings_goal: 15..60, timeout: 30..90

issues_observed:
  - Ranges were derived from ONE specific tournament example (per user's note)
  - No youth tournament (lower balls_goal, shorter innings)
  - No elite/pro tournament (possibly higher/different targets)
  - No handicap tournament (wide balls_goal spread — winner/loser differ by 3x or more)
  - No team-league matches (shorter formats, tighter innings)
  - No Pool, Snooker, Biathlon, Kegel coverage at all (silently no-check)
  - String-keyed by exact German discipline name — brittle (typos silently disable the check)
  - Dreiband balls_goal 10..80 is narrow — elite tournaments can set 40-50; amateur 15-25
  - timeout 30..90 is the same across all carom disciplines — unlikely correct

recommendations:
  Short-term (next pass, low risk):
    - Widen ranges: balls_goal_min lower (youth), balls_goal_max higher (handicap outliers)
    - Add Pool, Snooker, Biathlon, Kegel entries (even if wide — at least gives warnings on typos)
    - Replace string key with `discipline_id` or a symbol so name typos don't silently disable

  Medium-term (proper data model):
    - Move to a `discipline_parameter_ranges` database table with columns
      (discipline_id, attribute, min_value, max_value, tournament_type) so different
      tournament types (youth, elite, handicap, team) can have their own profiles
    - The Discipline model's `parameter_ranges` becomes a lookup with optional
      `tournament_type:` filter
    - Tournament model gains a `tournament_type` attribute (or reuses an existing
      classification) so the modal picks the right profile automatically

  Long-term (data-driven):
    - Populate ranges from historical tournament data (min/max of actually-used values
      per discipline across completed tournaments) rather than ad-hoc constants
    - Could be a Rake task that refreshes ranges nightly from Tournament table

out_of_scope_confirmation: |
  Phase 36B's UI-07 scope was "add the verification mechanism + plausibility check".
  The mechanism works (Test 7 pass). The DATA it checks against is a separate concern
  that was never expected to be exhaustive in the first pass. CONTEXT D-17 explicitly
  says "First-pass implementation can hardcode the ranges per discipline in the
  Discipline model (constant or method body); future refinement may move to a database
  column or config." — so this is an acknowledged follow-up, not a missed requirement.

candidate_phase: |
  Rolls into the v7.1 "UX polish & i18n debt" micro-phase as a medium-sized item.
  Or stands alone as "Discipline parameter ranges v2: data-driven and tournament-typed"
  if the database refactor path is taken. Estimate 1-3 plans depending on which
  recommendation tier is chosen.
