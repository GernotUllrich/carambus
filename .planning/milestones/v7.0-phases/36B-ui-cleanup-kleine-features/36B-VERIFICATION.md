---
phase: 36B-ui-cleanup-kleine-features
verified: 2026-04-14T18:30:00Z
status: human_needed
score: 10/10 must-haves verified
overrides_applied: 0
requirements_covered: [FIX-01, FIX-03, FIX-04, UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07]
re_verification:
  initial: true
human_verification:
  - test: "Wizard header visual check (FIX-04 + FIX-03)"
    where: "carambus_bcw (LOCAL context) — open any tournament show page"
    expected: |
      - Large colored AASM state badge is the visually dominant element in the header
        (e.g., orange for new_tournament, blue for accreditation_finished, green for tournament_started)
      - Six wizard bucket chips render below the badge with the active bucket highlighted
      - Progress bar and "Schritt N von 6" text are gone
      - No numeric prefixes (1., 2., etc.) appear in any step card header
    why_human: "Visual prominence and color-state correlation — can only be assessed by eye"
  - test: "Active step help block auto-opens (FIX-01)"
    where: "carambus_bcw — open a tournament in any non-closed state"
    expected: |
      - The active step's <details> help block is already open
      - Non-active steps' help blocks are collapsed
      - The troubleshooting 'Turnier nicht gefunden?' block stays closed by default
    why_human: "DOM default-open state varies with step transitions; UAT validates real-world flow"
  - test: "Parameter form tooltips (UI-01)"
    where: "carambus_bcw — navigate to Turnier-Monitor parameter form (before start)"
    expected: |
      - Hovering any of the 16 parameter labels shows a dark Tailwind tooltip card with German explanatory text
      - Keyboard-focus (Tab to a label) also opens the tooltip
      - No tooltip flashes before or below viewport edges unexpectedly
      - admin_controlled row is gone entirely (no label, no checkbox)
    why_human: "Tooltip positioning, animation, contrast, and hover UX are visual-only"
  - test: "German parameter labels (UI-02)"
    where: "carambus_bcw — Turnier-Monitor parameter form (DE locale)"
    expected: |
      - Every label reads in German (no 'Timeout (Sek.)' with the parenthetical English,
        no 'GD has prio on inter-group-comparisons', no 'Assign Games as Tables become available',
        no 'Tournament Manager checks results')
      - Switching to EN locale shows the English equivalents
    why_human: "i18n resolution at render time depends on cookies/URL-prefix; manual spot-check in both locales"
  - test: "Dead-code _current_games table (UI-04)"
    where: "carambus_bcw — open Turnier-Monitor page for a running tournament"
    expected: |
      - The 'Aktuelle Spiele' table shows only read-only columns (table, player, balls, innings, HS, GD, sets, current inning)
      - No set_balls input field, no +1/-1/+10/-10 buttons, no undo/next buttons
      - The 'OK?' / 'wait_check' state-display link still works
      - Table-exchange up/down arrows still render (they are NOT inning input)
    why_human: "Column-count consistency between thead and tbody on real data must be verified in-browser"
  - test: "Reset confirmation modal (UI-06)"
    where: "carambus_bcw — open a tournament and click any Reset button"
    expected: |
      - A Tailwind modal appears (not a native browser confirm) with title, body, Cancel, and Confirm buttons
      - Body text shows current AASM state + number of games played inline
      - Cancel closes the modal without resetting; Confirm triggers the reset action
      - Modal is always shown regardless of AASM state (not just tournament_started+)
      - Works on both primary reset (show.html.erb) and force-reset (finalize_modus.html.erb)
    why_human: "System test currently skips due to pre-existing tournaments(:local) fixture 500 — manual UAT is the only way to confirm end-to-end"
  - test: "Parameter verification modal (UI-07)"
    where: "carambus_bcw — open Turnier-Monitor parameter form, set balls_goal out of range (e.g., 99999), submit"
    expected: |
      - The start form submit re-renders the page with the shared confirmation modal auto-opening
      - Modal shows out-of-range values and asks for explicit confirmation
      - Cancel closes the modal without starting; Confirm passes the hidden override and starts the tournament
      - In-range values submit straight through to start_tournament! with no modal
      - No inline <script> runs — everything is Stimulus-driven
    why_human: "System test skips due to fixture discipline polymorphic resolution issue — same class as reset test. Manual UAT required"
  - test: "admin_controlled removal end-to-end (UI-03)"
    where: "carambus_bcw — open Turnier-Monitor for tournament in play, confirm last game of round at scoreboard"
    expected: |
      - No 'Tournament Manager checks results before acceptance' / 'Rundenwechsel manuell bestätigen' checkbox in the parameter form
      - When the last game of a round is confirmed at the scoreboard, the round auto-advances without manual intervention
      - This behavior holds regardless of whether admin_controlled was previously true on an imported global record
    why_human: "Runtime auto-advance of round requires a live scoreboard; cannot be unit-tested"
---

# Phase 36b: UI Cleanup & Kleine Features — Verification Report

**Phase Goal:** UI cleanup items from the Phase 36 doc review are implemented, plus the remaining original FIX-01/03/04 items, plus two small safety/verification features that reduce the risk of irreversible mistakes during tournament setup.

**Verified:** 2026-04-14T18:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | FIX-01: Active wizard step help block renders open by default | VERIFIED | `grep -c "if wizard_step_status" app/views/tournaments/_wizard_steps_v2.html.erb` = 8 (baseline 5 + 3 new `<details<%= ' open' if ...%>>`); `grep -c "status == :active" app/views/tournaments/_wizard_step.html.erb` = 3 (1 new on details, 2 pre-existing action-button checks) |
| 2 | FIX-03: Bucket chips replace bare "Schritt N von 6" and per-step number prefixes | VERIFIED | `grep -c 'Schritt.*von 6' _wizard_steps_v2.html.erb` = 0; `grep -c '<span class="step-number">' _wizard_step{,s_v2}.html.erb` = 0; `wizard_bucket_chips` helper defined and called once from partial; `WIZARD_BUCKETS` frozen constant present |
| 3 | FIX-04: AASM state badge is dominant visual element | VERIFIED | `wizard_state_badge_class` and `wizard_state_badge_label` helpers defined in `tournament_wizard_helper.rb`; partial calls `wizard_state_badge_class(tournament)` once; `progress-bar` div removed (grep = 0); visual prominence deferred to human UAT |
| 4 | UI-01: Parameter form has Stimulus-powered tooltips (16 fields) | VERIFIED | `app/javascript/controllers/tooltip_controller.js` exists with `textContent` only (no `innerHTML`), declares `static values = { content: String }`; `grep -c 'data-controller="tooltip"' tournament_monitor.html.erb` = 16; `grep -c 'data-tooltip-content-value'` = 16 |
| 5 | UI-02: All parameter labels localized under tournaments.monitor_form.labels.* | VERIFIED | `grep -c 'tournaments.monitor_form.labels' tournament_monitor.html.erb` = 16 (17 - 1 admin_controlled row deleted by plan 03); DE + EN both have 17 labels + 17 tooltips under `tournaments.monitor_form.{labels,tooltips}` (verified via `YAML.load_file` dig); no hardcoded English/German literals remain in parameter rows |
| 6 | UI-03: admin_controlled checkbox removed from UI + gate unconditional-true + column preserved (D-11) | VERIFIED | `grep -c 'admin_controlled' tournament_monitor.html.erb` = 0; `grep -c 'admin_controlled' tournament_reflex.rb` = 0 (hash key gone); `grep -c '!admin_controlled' tournament.rb` = 0; `Tournament#player_controlled?` body is `true` (line 386); `grep -c 'admin_controlled' tournament.rb` = 5 (schema + attribute list + create_tournament_local + before_save + comment — D-11 reversibility preserved); tournament_test.rb PASSES (4 runs, 11 assertions, 0 failures) |
| 7 | UI-04: Manual-input UI removed from _current_games table | VERIFIED | None of set_balls / TableMonitorReflex#{minus_one,minus_ten,add_one,add_ten,undo,next_step} match in `_current_games.html.erb`; table-exchange up/down arrows preserved; read-only player name + score columns preserved |
| 8 | UI-05: _wizard_steps.html.erb deleted; _wizard_step.html.erb (singular) preserved | VERIFIED | `test ! -f app/views/tournaments/_wizard_steps.html.erb` passes (file gone); `git ls-files _wizard_steps.html.erb` returns empty; `_wizard_step.html.erb` (singular) still exists and is still rendered by `_wizard_steps_v2.html.erb` for steps 3/4/5 (3 render calls matched by Task 1 gate) |
| 9 | UI-06: Reset confirmation modal wired to all reset buttons via shared Stimulus modal | VERIFIED | `confirmation_modal_controller.js` + `_confirmation_modal.html.erb` exist (7 textContent, no innerHTML, autoOpenValue + hiddenOverrideNameValue); layout renders partial once (`grep -c shared/confirmation_modal application.html.erb` = 1); show.html.erb has 2 `confirmation-modal#open` triggers; finalize_modus.html.erb has 1; `tournament_reset_confirmation_test.rb` exists (skips cleanly per plan 05 deviation #3 — pre-existing fixture issue, documented) |
| 10 | UI-07: Server-side parameter verification gate runs before start_tournament! with Stimulus modal trigger | VERIFIED | `Discipline#parameter_ranges` defined (line 92) with `DISCIPLINE_PARAMETER_RANGES` constant; `UI_07_FIELDS` is class-level in TournamentsController (line 26, `grep -c '^  UI_07_FIELDS'` = 1); server-side check at line 311 runs BEFORE `start_tournament!` at line 379; `render :tournament_monitor and return` path at line 315 on failure; `hidden_field_tag :parameter_verification_confirmed` in form = 1; `render "shared/confirmation_modal", auto_open: true, ...` call = 1; `grep -c '<script' tournament_monitor.html.erb` = 0 (Stimulus-first enforced); `ruby -c tournaments_controller.rb` = Syntax OK (no dynamic constant assignment error); `discipline_test.rb` PASSES (4 runs, 26 assertions, 0 failures) |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Level 1 (exists) | Level 2 (substantive) | Level 3 (wired) | Level 4 (data flows) | Status |
|----------|----------|------------------|-----------------------|-----------------|----------------------|--------|
| `app/views/tournaments/_wizard_steps_v2.html.erb` | Rewritten header + conditional open details | YES | YES (state badge + bucket chips + 8 `if wizard_step_status` checks) | YES (rendered from `show.html.erb:35`) | YES (consumes `tournament.state` via helpers) | VERIFIED |
| `app/views/tournaments/_wizard_step.html.erb` | Shared partial, step-number span removed, `status == :active` on details | YES | YES | YES (3 render calls from v2 for steps 3/4/5) | YES | VERIFIED |
| `app/helpers/tournament_wizard_helper.rb` | 3 new helpers + WIZARD_BUCKETS constant | YES | YES (all 3 methods present, constant frozen) | YES (called from `_wizard_steps_v2.html.erb`) | YES | VERIFIED |
| `app/javascript/controllers/tooltip_controller.js` | Stimulus tooltip controller with textContent | YES | YES (46 lines, `textContent` only, lifecycle hooks) | YES (16 `data-controller="tooltip"` matches in ERB) | YES (consumes `data-tooltip-content-value`) | VERIFIED |
| `app/views/tournaments/tournament_monitor.html.erb` | i18n labels + tooltips + no admin_controlled + UI-07 wiring + no inline script | YES | YES (16 tooltips, 16 label refs, hidden_field_tag, conditional modal render) | YES (form submits to `/tournaments/:id/start`) | YES (verification_failure + discipline ranges flow in) | VERIFIED |
| `config/locales/de.yml` | tournaments.monitor_form.{labels,tooltips} namespaces | YES | YES (17 labels + 17 tooltips) | YES (ERB references via `t()`) | YES | VERIFIED |
| `config/locales/en.yml` | Parallel EN namespace | YES | YES (17 labels + 17 tooltips) | YES | YES | VERIFIED |
| `app/models/tournament.rb` | player_controlled? unconditional true, column preserved | YES | YES (`def player_controlled?` returns `true`, D-11 attribute list + create_tournament_local + before_save intact — 5 admin_controlled refs) | YES (called from `_current_games.html.erb`) | N/A (returns constant, not dynamic) | VERIFIED |
| `app/reflexes/tournament_reflex.rb` | ATTRIBUTE_METHODS without admin_controlled | YES | YES (hash has 16 keys, admin_controlled gone; define_method loop unchanged) | YES (parameter reflexes still auto-register) | YES | VERIFIED |
| `app/views/tournament_monitors/_current_games.html.erb` | Manual-input cells removed | YES | YES (single-row header, 0 manual-input reflex handlers, preserved state-display + up/down arrows) | YES (still rendered from tournament_monitors page) | YES | VERIFIED |
| `app/javascript/controllers/confirmation_modal_controller.js` | Shared Stimulus modal with auto_open + hidden_override | YES | YES (166 lines, 7 textContent, autoOpenValue + hiddenOverrideNameValue declared, open/cancel/confirm methods) | YES (consumed by layout + show.html.erb + finalize_modus + tournament_monitor) | YES | VERIFIED |
| `app/views/shared/_confirmation_modal.html.erb` | Shared partial with 7 locals | YES | YES (aria-modal + whitespace-pre-line body + data-values wiring) | YES (rendered from layout + tournament_monitor) | YES | VERIFIED |
| `app/views/layouts/application.html.erb` | Renders confirmation_modal once | YES | YES (1 render call above `yield :javascript`) | YES | YES | VERIFIED |
| `app/views/tournaments/show.html.erb` | 2 reset-button confirmation triggers | YES | YES (2 `confirmation-modal#open` data-actions) | YES | YES | VERIFIED |
| `app/views/tournaments/finalize_modus.html.erb` | 1 force-reset confirmation trigger | YES | YES (1 `confirmation-modal#open` data-action) | YES | YES | VERIFIED |
| `app/models/discipline.rb` | parameter_ranges method + constants | YES | YES (DISCIPLINE_PARAMETER_RANGES composed via transform_values, method returns hash or {}) | YES (called from TournamentsController#verify_tournament_start_parameters) | YES | VERIFIED |
| `app/controllers/tournaments_controller.rb` | UI_07_FIELDS class-level + verification gate in #start | YES | YES (class-level constant at line 26, gate at line 311, helpers at 988/1015) | YES (gate runs before AASM `start_tournament!` at 379) | YES | VERIFIED |
| `test/models/tournament_test.rb` | player_controlled? regression test | YES | YES (4 assertions including true/false/nil admin_controlled) | YES (PASSES) | YES | VERIFIED |
| `test/models/discipline_test.rb` | parameter_ranges unit tests | YES | YES (4 tests, 26 assertions — shape + Freie Partie + unknown + no-raise sweep) | YES (PASSES) | YES | VERIFIED |
| `test/system/tournament_reset_confirmation_test.rb` | Capybara system test (UI-06) | YES | YES (3 tests — open/cancel/confirm with visit_tournament_or_skip helper) | PARTIAL (skips cleanly per plan 05 deviation #3 — pre-existing fixture issue) | N/A | VERIFIED (per D-20 tests exist; skip documented) |
| `test/system/tournament_parameter_verification_test.rb` | Capybara system test (UI-07) | YES | YES (4 tests — in-range/out-of-range/cancel/confirm with robust selectors) | PARTIAL (skips cleanly — same fixture polymorphic issue as UI-06) | N/A | VERIFIED (tests exist; skip documented) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `_wizard_steps_v2.html.erb` | `tournament_wizard_helper.rb` | `wizard_state_badge_class(tournament)`, `wizard_bucket_chips(tournament)` | WIRED | 1 + 1 call each, helpers defined and exercised |
| `_wizard_steps_v2.html.erb` | `wizard_step_status(tournament, N) == :active` on `<details open=...>` | conditional open attribute | WIRED | 8 `if wizard_step_status` in v2 (5 baseline + 3 new) |
| `_wizard_step.html.erb` | `status == :active` on `<details open=...>` | already-available `status` local | WIRED | 1 new details-level check, 2 pre-existing action-button checks |
| `tournament_monitor.html.erb` | `tooltip_controller.js` | `data-controller="tooltip"` + `data-tooltip-content-value="<%= t(...) %>"` | WIRED | 16 triggers, content from i18n |
| `tournament_monitor.html.erb` | `de.yml` / `en.yml` | `t('tournaments.monitor_form.labels.*')` + `t('tournaments.monitor_form.tooltips.*')` | WIRED | 16 label refs + 16 tooltip refs; YAML dig confirms 17+17 per locale |
| `tournament_reflex.rb` ATTRIBUTE_METHODS | auto-generated change handlers | `define_method` loop at 50-72 | WIRED | `admin_controlled` key removed, 16 other keys auto-register handlers |
| `tournament.rb#player_controlled?` | callers in `_current_games.html.erb` | unconditional-true gate | WIRED | Returns `true` regardless of admin_controlled; callers (lines 133, 135) now take "OK?" path always |
| `tournament_monitor.html.erb` | `shared/_confirmation_modal.html.erb` (auto_open instance) | `render "shared/confirmation_modal", auto_open: true, ...` with `hidden_override_name: "parameter_verification_confirmed"` | WIRED | Conditional render guarded by `@verification_failure.present?`; separate from layout-level click-trigger instance |
| `tournaments_controller.rb#start` | `Discipline#parameter_ranges` | `verify_tournament_start_parameters(@tournament, params)` at line 312 | WIRED | Called server-side BEFORE `start_tournament!`; pre-flight check gated on `params[:parameter_verification_confirmed] != "1"` |
| `show.html.erb` + `finalize_modus.html.erb` | `confirmation_modal_controller.js` | `data-action="click->confirmation-modal#open"` + `data-confirmation-modal-*-param` attributes | WIRED | 2 triggers in show, 1 in finalize_modus, forms targeted by id |
| `application.html.erb` layout | `_confirmation_modal.html.erb` partial | `render "shared/confirmation_modal"` at bottom of body | WIRED | 1 render call above `yield :javascript`, so every page has exactly one click-trigger instance |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|----------------------|--------|
| `_wizard_steps_v2.html.erb` header badge | `wizard_state_badge_label(tournament)` | `tournament.state` AASM attribute (real DB column) | YES — 9-branch case/when maps all AASM states to German labels | FLOWING |
| `_wizard_steps_v2.html.erb` bucket chips | `wizard_bucket_chips(tournament)` | `wizard_status_text(tournament)` which maps internal step to 1 of 6 labels | YES — derived from `wizard_current_step` which reads real tournament state | FLOWING |
| `tournament_monitor.html.erb` tooltip cards | `data-tooltip-content-value="<%= t('tournaments.monitor_form.tooltips.#{field}') %>"` | Rails i18n YAML (DE/EN) | YES — 17 concrete German + 17 English strings loaded from config/locales/*.yml | FLOWING |
| `tournament_monitor.html.erb` auto-open modal | `@verification_failure[:body_text]` | `build_verification_failure_payload(failures)` with failures from `verify_tournament_start_parameters` | YES — real per-discipline range comparison via `range.cover?(value.to_i)` | FLOWING |
| `Tournament#player_controlled?` | (constant) | hardcoded `true` | YES — intentional unconditional return per D-10 | FLOWING |
| `_current_games.html.erb` read-only rows | player name / balls / innings / HS / GD / sets | `TableMonitor.includes(...)` query → `tm.data[gp.role]` | YES — unchanged from pre-phase; manual-input cells removed, data source unchanged | FLOWING |
| Shared confirmation modal body | `auto_open_body` Stimulus value | `@verification_failure[:body_text]` built from server-side range failures | YES — real out-of-range `field: value (erwartet: range)` lines | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `tournaments_controller.rb` parses (no dynamic constant assignment error) | `ruby -c app/controllers/tournaments_controller.rb` | Syntax OK | PASS |
| Helper module parses | `ruby -c app/helpers/tournament_wizard_helper.rb` | Syntax OK | PASS |
| Tournament model parses | `ruby -c app/models/tournament.rb` | Syntax OK | PASS |
| Reflex parses | `ruby -c app/reflexes/tournament_reflex.rb` | Syntax OK | PASS |
| Discipline model parses | `ruby -c app/models/discipline.rb` | Syntax OK | PASS |
| Tooltip JS uses textContent only | `node -e ... src.includes('innerHTML')` | false (no innerHTML); textContent present; `static values = { content: String }` present | PASS |
| Confirmation modal JS uses textContent only | `node -e ... textContent matches` | innerHTML=false; textContent=7; autoOpenValue=true; hiddenOverrideNameValue=true | PASS |
| No inline `<script>` in tournament_monitor.html.erb | `grep -c '<script'` | 0 | PASS |
| No inline `<script>` in _confirmation_modal.html.erb | `grep -c '<script'` | 0 | PASS |
| tournament_test.rb unit tests pass (UI-03 D-10 regression) | `bin/rails test test/models/tournament_test.rb` | 4 runs, 11 assertions, 0 failures, 0 errors, 0 skips | PASS |
| discipline_test.rb unit tests pass (UI-07 ranges) | `bin/rails test test/models/discipline_test.rb` | 4 runs, 26 assertions, 0 failures, 0 errors, 0 skips | PASS |
| UI_07_FIELDS is class-level (not in a def body) | `grep -c '^  UI_07_FIELDS' app/controllers/tournaments_controller.rb` | 1 | PASS |
| Server-side verification gate runs BEFORE start_tournament! | `grep -n 'verify_tournament_start_parameters\|start_tournament!'` | Gate at 311, start_tournament! at 379 (gate precedes) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| FIX-01 | 36B-01 | Active wizard step help block open by default | SATISFIED | 3 new `<details<%= ' open' if wizard_step_status(tournament, N) == :active %>>` in v2 + 1 in singular partial using `status == :active`; troubleshooting block stays closed |
| FIX-03 | 36B-01 | Step names (6 bucket chips) replace bare numbers | SATISFIED | `wizard_bucket_chips` helper + `WIZARD_BUCKETS` constant; 0 `Schritt.*von 6`; 0 `<span class="step-number">` inner elements |
| FIX-04 | 36B-01 | AASM state badge dominant over progress bar | SATISFIED | `wizard_state_badge_class` + `wizard_state_badge_label` helpers; badge rendered at px-6 py-3 text-2xl font-bold; `progress-bar` removed from header (grep = 0); **visual prominence human-verified below** |
| UI-01 | 36B-02 | Parameter form tooltips via Stimulus | SATISFIED | `tooltip_controller.js` exists (textContent-only XSS mitigation); 16 `data-controller="tooltip"` triggers; tooltip content from `tournaments.monitor_form.tooltips.*` |
| UI-02 | 36B-02 | Start-form labels in German (i18n) | SATISFIED | 16 labels wired to `tournaments.monitor_form.labels.*`; DE and EN YAML both contain 17 labels + 17 tooltips (admin_controlled kept for D-11 reversibility); no hardcoded English/German literals remain |
| UI-03 | 36B-03 | Remove manual round-change feature | SATISFIED | Checkbox gone from ERB (grep=0); Reflex handler gone (grep=0); `Tournament#player_controlled?` unconditional true; D-11 column + attribute-list preserved (5 refs); regression test passes |
| UI-04 | 36B-04 | Dead-code manual input removed | SATISFIED | 0 matches for set_balls/minus_one/minus_ten/add_one/add_ten/undo/next_step in `_current_games.html.erb`; single-row header; state-display link and up/down arrows preserved |
| UI-05 | 36B-04 | Unused partial deleted | SATISFIED | `_wizard_steps.html.erb` (plural) deleted via git rm; `_wizard_step.html.erb` (singular) preserved — still used for steps 3/4/5 |
| UI-06 | 36B-05 | Reset confirmation dialog | SATISFIED | Shared Stimulus modal infrastructure complete; 3 reset buttons wired (2 in show, 1 in finalize_modus); `_confirmation_modal.html.erb` partial + layout registration; system test exists (skips on pre-existing fixture issue — documented as plan 05 deviation #3); **end-to-end UX human-verified below** |
| UI-07 | 36B-06 | Parameter verification dialog | SATISFIED | `Discipline#parameter_ranges` + `UI_07_FIELDS` class-level constant + server-side verification gate in `#start` running BEFORE `start_tournament!`; no inline `<script>` (Stimulus-first); unit tests PASS; system test exists (skips on fixture polymorphic issue); **end-to-end UX human-verified below** |

**Orphan check:** All 10 requirement IDs (FIX-01, FIX-03, FIX-04, UI-01..07) appear in at least one plan's `requirements:` frontmatter. No orphans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No blocking anti-patterns detected | — | — |

**Notes:**
- Pre-existing erblint warnings in `tournament_monitor.html.erb` (1 blank-line-in-style, 6 autocomplete-attribute-missing) are baseline and out of scope per every plan's Scope Boundary rule. Not caused by Phase 36b edits.
- Pre-existing standardrb violations in `tournaments_controller.rb` and `discipline.rb` (outside phase-edited line ranges) are baseline and out of scope.
- System tests for UI-06 and UI-07 currently skip cleanly because the `tournaments(:local)` fixture has a pre-existing polymorphic organizer/discipline resolution bug (already whitelisted by `TournamentsControllerTest` for `[200, 302, 500]` status codes). Per plan 05 deviation #3 and plan 06's fixture note, this is strictly out of scope for Phase 36b and fixing it would touch other test files. D-21 already defers visual regression to manual UAT; the skipped system tests add structural coverage that will activate automatically when a future fixture-cleanup phase repairs the polymorphic FK.

### Constraint Checks

| Constraint | Result | Evidence |
|-----------|--------|----------|
| Edits stay in carambus_api only (not carambus_master/bcw/phat) | PASS | `git log` in sibling scenarios shows no 36B commits (carambus_master latest: `0a611635 Merge ...`; carambus_bcw latest: `5e32136b chore: complete v1.0 milestone`) |
| No new CSS files (Tailwind utilities only) | PASS | `git diff --name-status` for CSS files across 36B commits returns empty |
| No new inline `<script>` blocks | PASS | `grep -c '<script'` = 0 in tournament_monitor.html.erb and _confirmation_modal.html.erb |
| `admin_controlled` column NOT dropped (D-11) | PASS | No migration in db/migrate/; column still referenced 5× in tournament.rb (schema comment + attribute-delegation list + create_tournament_local + before_save persistence) |
| 4 `organizer.is_a?(Region)` branches preserved (plan 01 expected 4) | PASS | `grep -c 'organizer.is_a?(Region)' _wizard_steps_v2.html.erb` = 4 |

### Human Verification Required

See `human_verification` array in frontmatter for the full list. Summary: 8 items need manual UAT in `carambus_bcw` (LOCAL context, since `carambus_api` is API-mode in dev):

1. **Wizard header visual (FIX-03 + FIX-04)** — dominant colored state badge + 6 bucket chips
2. **Active help auto-open (FIX-01)** — `<details open>` on the current step only
3. **Parameter form tooltips (UI-01)** — Tailwind hover cards on 16 labels
4. **German labels (UI-02)** — spot-check DE + EN locales
5. **Dead-code table (UI-04)** — read-only current games, no input cells
6. **Reset confirmation modal (UI-06)** — full open/cancel/confirm flow on 3 reset buttons
7. **Parameter verification modal (UI-07)** — out-of-range triggers modal, in-range goes straight through
8. **admin_controlled runtime (UI-03)** — auto-advance of round at scoreboard

Per CONTEXT.md D-21, visual regression for FIX-01/03/04/UI-01/02/04/05 was deliberately deferred to manual UAT during planning. UI-06 and UI-07 additionally have automated system tests that currently skip on pre-existing fixture issues, making human UAT the authoritative validation for those two safety features.

### Gaps Summary

**No gaps found.** All 10 observable truths are verified against the live codebase; all 21 required artifacts exist, are substantive, are wired, and carry real data flow; all 11 key links are connected; all 10 requirement IDs are covered by at least one plan with working implementation; no blocker anti-patterns were detected; all 13 behavioral spot-checks pass (including the critical `ruby -c` on `tournaments_controller.rb` that would catch the UI-07 class-level constant scoping bug); all constraint checks pass (edits stay in carambus_api, no CSS, no inline scripts, D-11 column preserved).

The phase achieved its goal: the 10 UI cleanup items plus the 3 original FIX items plus the 2 safety features are all implemented in the codebase. The only remaining validation is human UAT for visual / UX concerns that planning explicitly deferred per D-21 and for the two safety-feature end-to-end flows whose Capybara coverage is blocked by a pre-existing fixture issue outside this phase's scope.

**Status: human_needed** — automated verification is complete; awaiting human UAT in `carambus_bcw`.

---

*Verified: 2026-04-14T18:30:00Z*
*Verifier: Claude (gsd-verifier)*
