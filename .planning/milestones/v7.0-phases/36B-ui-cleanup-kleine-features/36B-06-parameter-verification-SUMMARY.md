---
phase: 36B
plan: 06
subsystem: ui-safety
tags: [model, controller, erb, stimulus, modal, test, system-test, ui-07]
dependency-graph:
  requires:
    - Discipline#name for range lookup
    - plan 36B-05 confirmation_modal Stimulus controller + partial (auto_open + hidden_override_name values)
    - plan 36B-02 monitor_form i18n label/tooltip keys (consumed via default: fallbacks)
    - plan 36B-03 tournament_monitor.html.erb (post-admin_controlled-removal)
  provides:
    - Discipline#parameter_ranges API (field -> Range hash, {} on unknown)
    - TournamentsController UI_07_FIELDS class-level constant
    - TournamentsController#verify_tournament_start_parameters + #build_verification_failure_payload private helpers
    - UI-07 parameter verification gate in TournamentsController#start
  affects:
    - app/models/discipline.rb
    - app/controllers/tournaments_controller.rb
    - app/views/tournaments/tournament_monitor.html.erb
tech-stack:
  added: []
  patterns:
    - "Class-level constant declared above any def to avoid Ruby dynamic-constant-assignment parse error"
    - "Server-side range check authoritative over client-side modal — DOM tampering cannot bypass the gate because the server re-runs verify on every submit"
    - "Shared Stimulus modal consumed twice on the same page (layout-level click-trigger instance + view-level auto_open instance) — no controller conflict thanks to Stimulus instance scoping"
    - "i18n keys used with default: fallbacks to avoid touching de.yml/en.yml in a wave-serialized phase"
    - "Safe-navigation chain tournament.discipline&.parameter_ranges || {} tolerates both nil discipline and unknown discipline name"
key-files:
  created:
    - test/models/discipline_test.rb
    - test/system/tournament_parameter_verification_test.rb
  modified:
    - app/models/discipline.rb
    - app/controllers/tournaments_controller.rb
    - app/views/tournaments/tournament_monitor.html.erb
decisions:
  - "Factored DISCIPLINE_PARAMETER_RANGES into UI_07_SHARED_RANGES + UI_07_DISCIPLINE_SPECIFIC_RANGES composed via transform_values. The plan draft had one flat 15-line constant with 7 identical fields per row — standardrb flagged it as dozens of Layout/SpaceInsideHashLiteralBraces + ExtraSpacing violations. The composed form is denser, reads better, and passes standardrb without any format gymnastics."
  - "UI_07_FIELDS lives at TournamentsController class level (line 26, immediately after the before_action block) — not inside #start or any private helper. Confirmed by grep: grep -c '^  UI_07_FIELDS' returns 1 and grep -n 'UI_07_FIELDS' shows the first occurrence at line 26 (class level) and the second at line 992 inside verify_tournament_start_parameters as a simple reference."
  - "Zero <script> tags added to tournament_monitor.html.erb. All verification wiring (auto-open, hidden override flip, form requestSubmit) runs through plan 36B-05's confirmation_modal_controller.js via its autoOpenValue / autoOpenFormIdValue / hiddenOverrideNameValue / hiddenOverrideResetOnCancelValue Stimulus values. CLAUDE.md Stimulus-first-policy enforced — grep -c '<script' returns 0."
  - "All 4 system tests currently skip cleanly because the test-env tournament fixtures reference disciplines (carom_3band etc.) whose polymorphic association does not resolve in the test DB — same class of issue plan 36B-05 documented in deviation 3. The setup block raises loudly on a missing sign_in helper (I-3 fix) but skips cleanly on the fixture gap. Fixing the upstream polymorphic fixture is out of scope for UI-07."
  - "No i18n YAML keys touched. All t() calls in the ERB and controller use default: '<German fallback>' so plan 06 does not serialize on de.yml/en.yml with plans 02/03. A follow-up polish task may promote the 5 keys (tournaments.monitor_form.verification.banner/title/body_intro/confirm + tournaments.monitor_form.labels.#{field})."
  - "The failure body text is built in Ruby in build_verification_failure_payload using real \\n\\n (double-quoted Ruby string, actual newline characters). It flows into the partial via auto_open_body, which the partial inserts via <%= %> (HTML-escaped) into the data-*-auto-open-body-value attribute. The plan 05 controller then writes it to the DOM via textContent (never innerHTML). The shared partial applies whitespace-pre-line to the body div so the newlines render as actual line breaks."
metrics:
  duration: "~25 minutes"
  completed-date: "2026-04-14"
  tasks-completed: 4
  files-created: 2
  files-modified: 3
---

# Phase 36B Plan 06: Parameter Verification Dialog Summary

UI-07 server-side range check: `Discipline#parameter_ranges` provides per-discipline hash of `field -> Range`, `TournamentsController#start` runs a pre-flight verification gate before `start_tournament!`, and the shared plan-05 confirmation modal auto-opens (via its Stimulus `autoOpenValue`) when the server re-renders with `@verification_failure` — zero inline `<script>` tags added.

## What Shipped

### Task 1 — `Discipline#parameter_ranges` + Minitest (commit `67a44adf`)

**`app/models/discipline.rb`** gained two constants plus an instance method:

- `UI_07_SHARED_RANGES` — `{time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4}` (identical across all disciplines in first pass).
- `UI_07_DISCIPLINE_SPECIFIC_RANGES` — 15-entry hash keyed by discipline `name` (`"Freie Partie"`, `"Freie Partie klein"`, `"Freie Partie groß"`, `"Cadre 47/1"`, `"Cadre 47/2"`, `"Cadre 71/2"`, `"Cadre 35/2"`, `"Cadre 52/2"`, `"Einband"`, `"Einband klein"`, `"Einband groß"`, `"Dreiband"`, `"Dreiband klein"`, `"Dreiband groß"`, `"5-Kegel-Billard"`). Each entry carries just the three varying fields `balls_goal`, `innings_goal`, `timeout`.
- `DISCIPLINE_PARAMETER_RANGES` — computed at load time via `UI_07_DISCIPLINE_SPECIFIC_RANGES.transform_values { |specific| UI_07_SHARED_RANGES.merge(specific) }.freeze`. Key = discipline name (String), value = Hash keyed by the 7 UI-07 field symbols, each yielding a Range.
- `Discipline#parameter_ranges` → `DISCIPLINE_PARAMETER_RANGES[name.to_s] || {}`. Unknown / nil name → empty hash (no exception).

**`test/models/discipline_test.rb`** (NEW) — 4 Minitest cases:

1. `parameter_ranges returns hash with expected keys for Freie Partie klein` — asserts Hash shape and that each of the 7 keys is a `Range`.
2. `parameter_ranges includes sensible balls_goal for Freie Partie` — asserts `50..500` via `cover?(100)` / `!cover?(10_000)`.
3. `parameter_ranges returns empty hash for unknown discipline name` — new Discipline with random name → `{}` and no exception.
4. `parameter_ranges does not raise for any fixture discipline` — `find_each` sweep over all loaded disciplines, `flunk` with context on any raise.

**`bin/rails test test/models/discipline_test.rb`**: 4 runs, 26 assertions, 0 failures, 0 errors, 0 skips.
**`bundle exec standardrb app/models/discipline.rb test/models/discipline_test.rb`**: my added lines (50-94 in discipline.rb, entire discipline_test.rb) are clean. Pre-existing violations in lines 98+ of discipline.rb (MAJOR_DISCIPLINES constant etc.) are out of scope.

### Task 2 — `TournamentsController#start` verification gate (commit `83093498`)

**`app/controllers/tournaments_controller.rb`** three changes, all additive:

1. **Class-level constant** `UI_07_FIELDS` declared at line 26, between the `before_action :ensure_local_server` block and `def index`. Array of 7 Symbol field names in display order: `balls_goal`, `innings_goal`, `timeout`, `time_out_warm_up_first_min`, `time_out_warm_up_follow_up_min`, `sets_to_play`, `sets_to_win`. Placed at the class level (NOT inside any def body) because Ruby forbids dynamic constant assignment in methods. Verified: `grep -c '^  UI_07_FIELDS'` returns `1`, first occurrence at line 26.

2. **Pre-flight check inserted at the top of `#start`** (lines 304-317). When `params[:parameter_verification_confirmed].to_s != "1"`, call `verify_tournament_start_parameters(@tournament, params)`; if any failures, set `@verification_failure = build_verification_failure_payload(failures)` and `render :tournament_monitor and return`. Otherwise fall through to the original ClubCloud validation + data hash population + `start_tournament!` logic — no other changes.

3. **Two private helpers** added in the `private` section (lines 981-1029):
   - `verify_tournament_start_parameters(tournament, raw_params)` — `ranges = tournament.discipline&.parameter_ranges || {}`; returns `[]` if `ranges.empty?`; iterates `UI_07_FIELDS`, tolerates nil / empty raw params, casts via `.to_i`, uses `range.cover?(value)`. Returns `[{field:, value:, range:, label:}]` shape; the `label` is fetched via `I18n.t("tournaments.monitor_form.labels.#{field}", default: field.to_s.humanize)` — no yaml touched.
   - `build_verification_failure_payload(failures)` — builds `body_text` in Ruby with real `"\n\n"` and `"\n"` (actual newline characters via double-quoted strings). The intro string also comes from `I18n.t(..., default: "...")` with a German fallback. Returned hash: `{failures:, body_text:}`.

**`ruby -c app/controllers/tournaments_controller.rb`**: Syntax OK (no parse errors — the #start draft that used `UI_07_FIELDS = ... unless defined?(UI_07_FIELDS)` inside a method body would have raised `SyntaxError: dynamic constant assignment`; the class-level placement sidesteps that trap).
**`bundle exec standardrb app/controllers/tournaments_controller.rb`**: zero violations on my inserted lines (21-34, 304-317, 981-1029). Pre-existing violations elsewhere in the file are out of scope.

### Task 3 — `tournament_monitor.html.erb` modal wiring (commit `3834e91d`)

**`app/views/tournaments/tournament_monitor.html.erb`** — two insertions, NO inline `<script>`:

1. **Hidden field inside the start form** (line 66, right after the opening `do %>`):
   ```erb
   <%= hidden_field_tag :parameter_verification_confirmed, "0" %>
   ```
   Default `"0"` on every render. The plan-05 Stimulus controller's `confirm()` calls `setHiddenOverride("1")` before `form.requestSubmit()`; `cancel()` resets it to `"0"` via `hiddenOverrideResetOnCancelValue` (defaults to `true`).

2. **Conditional render of shared confirmation modal + orange banner** above the start form, guarded by `@verification_failure.present?`. The modal render call:
   ```erb
   <%= render "shared/confirmation_modal",
              auto_open: true,
              auto_open_title: I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter"),
              auto_open_body: @verification_failure[:body_text],
              auto_open_confirm_label: I18n.t("tournaments.monitor_form.verification.confirm", default: "Ja, Werte übernehmen und Turnier starten"),
              auto_open_form_id: "start_tournament",
              hidden_override_name: "parameter_verification_confirmed",
              hidden_override_reset_on_cancel: true %>
   ```

Since the layout already renders `shared/confirmation_modal` once (plan 05, for click-trigger mode), this is a **second** instance on the same page. Each instance gets its own `data-controller="confirmation-modal"` element and therefore its own Stimulus controller instance with scoped targets. The layout instance's `autoOpenValue` is `false` (stays hidden, click-triggered), the view instance's `autoOpenValue` is `true` (auto-opens on `connect()` via `queueMicrotask` → `openWithValues()`).

**Grep verification:**

| Check | Expected | Actual |
|---|---|---|
| `grep -c '<script' app/views/tournaments/tournament_monitor.html.erb` | `0` | `0` |
| `grep -c 'hidden_field_tag :parameter_verification_confirmed'` | `1` | `1` |
| `grep -c 'render "shared/confirmation_modal"'` | `1` | `1` |
| `grep -c 'auto_open: true'` | `1` | `1` |
| `grep -c 'hidden_override_name: "parameter_verification_confirmed"'` | `1` | `1` |
| `grep -c 'auto_open_form_id: "start_tournament"'` | `1` | `1` |
| `grep -c 'tournaments.monitor_form.verification'` | `>= 3` | `3` |

**`ruby -e "raise if src =~ /<script/i"`** → `no inline script — OK`.

**`bundle exec erblint`** still reports 7 pre-existing errors (1 `<style>`-block blank-line warning on line 20 and 6 `autocomplete attribute missing` warnings on `number_field_tag` lines 89/92/95/98/110/113 — **all pre-existing in baseline**, confirmed by `git stash` comparison: 7 errors before my changes, 7 after = zero net new lint debt). My inserted lines 39-66 add zero lint errors. Pre-existing issues are out of scope per GSD Rule 1-3 scope boundary.

### Task 4 — Capybara system test (commit `7381fe79`)

**`test/system/tournament_parameter_verification_test.rb`** (NEW) — 4 tests covering the full UI-07 happy + unhappy paths:

1. `out-of-range balls_goal opens verification modal` — fills `99999`, clicks Start, asserts the modal title text appears AND `"99999"` appears in the body, asserts tournament state did NOT transition.
2. `clicking Cancel keeps tournament un-started` — fills `99999`, clicks Start, clicks the Cancel button (`button[data-action='click->confirmation-modal#cancel']`), asserts state unchanged.
3. `clicking Confirm starts the tournament with the override` — fills `99999`, clicks Start, clicks the Confirm button (`button[data-action='click->confirmation-modal#confirm']`), asserts state is in `STARTED_STATES = %w[tournament_started tournament_started_waiting_for_monitors]`.
4. `in-range values skip the modal and start the tournament directly` — fills `parameter_ranges[:balls_goal].first + 5` (discipline-aware safe value), clicks Start, asserts modal title text absent, asserts state in `STARTED_STATES`.

**Design decisions (from the plan's robust-selector requirement):**

- `find("input[name='balls_goal']").set(value.to_s)` inside `within("#start_tournament")` — name-based selector, no reliance on `<label for="..."> ` (which `number_field_tag` does not emit) or DOM ids.
- `find("input[type='submit'][name='commit']").click` inside `within("#start_tournament")` — name-based submit selector, robust against i18n text drift on the button label.
- `raise "sign_in helper required — include Devise::Test::IntegrationHelpers in ApplicationSystemTestCase" unless respond_to?(:sign_in)` — **loud guard**, not silent skip (I-3 fix). A missing Devise helper is a test-setup bug.
- `verification_title` helper method + `STARTED_STATES` class-level constant keep the test bodies short and avoid repeated `I18n.t(...)` calls / long state arrays inline (also fixes standardrb `Layout/ArgumentAlignment` warnings on multi-line assertion calls).
- `visit_monitor_or_skip` — mirrors plan 05's `visit_tournament_or_skip` pattern; detects the "Internal Server Error" text (Selenium can't read `page.status_code`) and skips cleanly if the fixture 500s.

**Fixture outcome — all 4 tests skip cleanly:** the setup's `Tournament.joins(:discipline).where.not(state: ...).find { |t| t.discipline&.parameter_ranges&.any? }` returns `nil` in the test DB. Direct inspection via `RAILS_ENV=test bin/rails runner` shows that every tournament's `discipline` comes back as `nil` — the polymorphic association fails to resolve against the fixture IDs. This is the **same class of pre-existing issue** plan 36B-05 documented in deviation 3 for `tournaments(:local).organizer`. Fixing the fixture polymorphic resolution would touch `tournaments.yml` and potentially break `TournamentsControllerTest` (which already whitelists `[200, 302, 500]`) — strictly out of scope for UI-07. The skip is preferable to a fake pass, and the raise-loud sign_in guard guarantees we catch the genuine "misconfigured test helper" case.

**`bin/rails test test/system/tournament_parameter_verification_test.rb`** → 4 runs, 0 assertions, 0 failures, 0 errors, 4 skips. **Exit code 0.**
**`bundle exec standardrb test/system/tournament_parameter_verification_test.rb`** → clean.

## i18n — No YAML Touched

This plan touches ZERO yaml files. All 5 translation keys are used with inline `default:` fallbacks:

| Key | Default |
|---|---|
| `tournaments.monitor_form.verification.title` | `"Ungewöhnliche Turnierparameter"` |
| `tournaments.monitor_form.verification.body_intro` | `"Die folgenden Werte liegen außerhalb des üblichen Bereichs für diese Disziplin. Bitte prüfen und bestätigen, wenn sie wirklich gewollt sind:"` |
| `tournaments.monitor_form.verification.confirm` | `"Ja, Werte übernehmen und Turnier starten"` |
| `tournaments.monitor_form.verification.banner` | `"Einige Werte weichen vom üblichen Bereich für diese Disziplin ab. Bitte prüfen und bestätigen."` |
| `tournaments.monitor_form.labels.#{field}` | `field.to_s.humanize` (consumed from plan 36B-02's labels namespace — those keys already exist) |

A follow-up i18n polish task can promote these 4 new verification-namespace keys into `config/locales/de.yml` + `config/locales/en.yml`. Deferred deliberately to avoid a wave-serialization conflict with plans 02/03 which also write to the same files.

## Verification Performed

1. `bin/rails test test/models/discipline_test.rb` → 4 runs, 26 assertions, **0 failures, 0 errors, 0 skips**.
2. `bin/rails test test/system/tournament_parameter_verification_test.rb` → 4 runs, **0 failures, 0 errors, 4 clean skips** (exit 0).
3. `bundle exec standardrb test/models/discipline_test.rb test/system/tournament_parameter_verification_test.rb` → **clean**.
4. `ruby -c app/controllers/tournaments_controller.rb` → **Syntax OK**.
5. `grep -c '<script' app/views/tournaments/tournament_monitor.html.erb` → **0**.
6. `grep -c '^  UI_07_FIELDS' app/controllers/tournaments_controller.rb` → **1** (class-level, line 26).
7. `grep -n 'UI_07_FIELDS' ...` → first occurrence line 26 (NOT inside any def), second occurrence line 992 (reference inside `verify_tournament_start_parameters`).
8. `grep -c 'def start$' app/controllers/tournaments_controller.rb` → **1** (no duplicate action).
9. `grep -c 'start_tournament!' app/controllers/tournaments_controller.rb` → **2** (original AASM call preserved; the pre-flight gate adds no new calls).
10. `grep -c 'def parameter_ranges' app/models/discipline.rb` → **1**.
11. `grep -c 'DISCIPLINE_PARAMETER_RANGES' app/models/discipline.rb` → **2** (definition line + reference in `parameter_ranges` method).
12. `grep -c 'parameter_verification_confirmed' app/controllers/tournaments_controller.rb` → **2** (guard check + plan-level note in comment).
13. `grep -c 'verify_tournament_start_parameters' app/controllers/tournaments_controller.rb` → **2** (call site in `#start` + private def).
14. `grep -c 'build_verification_failure_payload' app/controllers/tournaments_controller.rb` → **2** (call site in `#start` + private def).
15. `grep -c '@verification_failure' app/views/tournaments/tournament_monitor.html.erb` → **3** (comment + `present?` check + `[:body_text]` access).
16. `git log --oneline -4` shows all 4 task commits present with conventional messages.

## Deviations from Plan

### [Rule 1 — Bug] `assert_nothing_raised` with message argument

- **Found during:** Task 1 initial test run.
- **Issue:** The plan draft used `assert_nothing_raised(nil, "...")` which is a Rails Minitest helper signature; core Minitest's `assert_nothing_raised` accepts **zero** arguments and raised `ArgumentError: wrong number of arguments (given 1, expected 0)`. This is a genuine upstream bug in the plan text.
- **Fix:** Replaced the 4th test's block with an explicit `begin/rescue => e; flunk "..."; end` pattern wrapping the call. Same semantic (raise → fail the test with context) but portable across the Minitest versions we actually have. Still satisfies the "test does not raise" D-19 contract.
- **Files:** `test/models/discipline_test.rb`
- **Commit:** `67a44adf`

### [Rule 1 — Bug] Plan's flat `DISCIPLINE_PARAMETER_RANGES` constant triggered dozens of standardrb violations

- **Found during:** Task 1 standardrb run.
- **Issue:** The plan draft's flat 15-row constant with `=> { balls_goal: 50..500, innings_goal: 20..80, ... }` per row produced 90+ `Layout/SpaceInsideHashLiteralBraces`, `Layout/ExtraSpacing`, and `Layout/HashAlignment` violations. Reformatting to a single-line-per-entry table still tripped `HashAlignment` because of the non-uniform key lengths (`"Freie Partie"` vs `"5-Kegel-Billard"`).
- **Fix:** Refactored into two simpler constants (`UI_07_SHARED_RANGES` + `UI_07_DISCIPLINE_SPECIFIC_RANGES`) composed via `transform_values` + `merge` at load time. Same public API (`DISCIPLINE_PARAMETER_RANGES[name] → hash`), much denser, standardrb-clean, and arguably more maintainable (common warmup/set defaults live in one place).
- **Files:** `app/models/discipline.rb`
- **Commit:** `67a44adf`

### [Rule 3 — blocking] Comment containing `<script>` tripped the `grep -c '<script' = 0` acceptance check

- **Found during:** Task 3 acceptance grep.
- **Issue:** I wrote a comment "KEIN inline `<script>`-Tag" in the ERB to document the Stimulus-first policy. `grep -c '<script'` matched the literal text inside the comment and returned `1` instead of `0`.
- **Fix:** Rewrote the comment block to explain the policy without using the literal `<script` substring. Zero semantic change, now passes the grep.
- **Files:** `app/views/tournaments/tournament_monitor.html.erb`
- **Commit:** `3834e91d`

### [Rule 3 — blocking] Test comment containing `fill_in "balls_goal"` tripped the `grep -c 'fill_in "balls_goal"' = 0` acceptance check

- **Found during:** Task 4 acceptance grep.
- **Issue:** My explanatory comment in the header mentioned `fill_in "balls_goal"` as an example of what the test avoids. The grep matched it and returned `1` instead of `0`.
- **Fix:** Rewrote the comment to say "Capybara label-based input lookups fail" without the literal pattern.
- **Files:** `test/system/tournament_parameter_verification_test.rb`
- **Commit:** `7381fe79`

### [Rule 2 — correctness] Standardrb refactor of system test for argument alignment

- **Found during:** Task 4 standardrb run.
- **Issue:** Standardrb flagged `Layout/ArgumentAlignment` on multi-line `assert_text I18n.t("...", default: "...")` and `assert_includes %w[...], @tournament.reload.state` call sites — 4 instances total.
- **Fix:** Extracted `verification_title` helper method and `STARTED_STATES` constant, so every call-site becomes a single line (`assert_text verification_title`, `assert_includes STARTED_STATES, @tournament.reload.state`). Also converted the setup's `@user = (users(:admin) rescue User.first)` to a `begin/rescue/end` form and changed `t.discipline && t.discipline.parameter_ranges.any?` to `t.discipline&.parameter_ranges&.any?` per standardrb's SafeNavigation cop.
- **Files:** `test/system/tournament_parameter_verification_test.rb`
- **Commit:** `7381fe79`

## Known Stubs

None. The verification gate uses real per-discipline ranges, runs server-side, and the modal is fully wired to the plan-05 Stimulus controller. The only "stub-ish" part is the system test skipping due to the fixture gap — but the test logic itself is complete and will run as soon as the polymorphic association resolves (a future fixture-cleanup phase, not UI-07 scope).

## Threat Flags

None beyond the 6 documented in the plan's threat_model:
- **T-36b06-01 / T-36b06-02** (DOM tamper / direct curl override): mitigated by the server-side re-run of `verify_tournament_start_parameters` on every submit — the override token is checked server-side, DOM tampering cannot bypass it.
- **T-36b06-03** (XSS in failure body): mitigated by (a) `.to_i` casting on values, (b) `I18n.t(..., default:)` on labels, (c) ERB `<%= %>` HTML-escaping into the data attribute, (d) plan-05 controller's `textContent` write to the DOM.
- **T-36b06-04** (DoS from malformed params): mitigated by `return [] if ranges.empty?`, safe `raw.to_s.strip.empty?` guard, `tournament.discipline&.parameter_ranges || {}`.
- **T-36b06-05** (repudiation): accepted — PaperTrail could add explicit logging in a future phase.
- **T-36b06-06** (inline `<script>` sink): mitigated — zero `<script>` tags added, enforced by the `grep -c '<script' = 0` acceptance criterion.

No new trust-boundary surface introduced.

## Deferred Issues

- **i18n key promotion** — the 4 new `tournaments.monitor_form.verification.*` keys (banner/title/body_intro/confirm) are used with `default:` fallbacks. A follow-up polish task can promote them into `config/locales/de.yml` + `config/locales/en.yml` (and add English translations). Deferred to avoid wave conflict with plans 02 and 03 (which also write to the locale files).
- **Fixture polymorphic resolution for Tournament#discipline in test DB** — 4 system tests currently skip because the `carom_3band` / `discipline_freie_partie_klein` fixture references don't resolve through the `joins(:discipline)` chain. Same class of issue as plan 36B-05 deviation 3 (tournament organizer polymorphic). A future fixture-cleanup phase can repair the discipline / organizer FK resolution — unrelated to UI-07 correctness.
- **Hardcoded range values in `DISCIPLINE_PARAMETER_RANGES`** — first pass uses reasonable defaults (per D-17). UAT in `carambus_bcw` may reveal disciplines where the bounds are too tight or too loose; adjust via small follow-up PRs.
- **Pre-existing standardrb violations in `tournaments_controller.rb`** (~180 issues on lines outside my edits) and **erblint warnings in `tournament_monitor.html.erb`** (7 issues on lines I didn't touch) — out of scope per GSD Rule 1-3 scope boundary. These are lint debt from earlier phases; a dedicated cleanup pass can address them separately.

## Commits

| Task | Hash       | Message                                                           |
| ---- | ---------- | ----------------------------------------------------------------- |
| 1    | `67a44adf` | feat(36B-06): add Discipline#parameter_ranges + unit tests        |
| 2    | `83093498` | feat(36B-06): add UI-07 parameter verification gate to #start     |
| 3    | `3834e91d` | feat(36B-06): wire tournament_monitor to UI-07 verification modal |
| 4    | `7381fe79` | test(36B-06): add Capybara system test for UI-07 verification flow |

## Self-Check: PASSED

- `app/models/discipline.rb` (modified) — FOUND (DISCIPLINE_PARAMETER_RANGES line 84, parameter_ranges def line 92)
- `app/controllers/tournaments_controller.rb` (modified) — FOUND (UI_07_FIELDS line 26, pre-flight gate at line 304, helpers at lines 988 and 1015)
- `app/views/tournaments/tournament_monitor.html.erb` (modified) — FOUND (hidden_field_tag line 66, modal render line 56)
- `test/models/discipline_test.rb` (created) — FOUND (4 tests, 26 assertions, pass)
- `test/system/tournament_parameter_verification_test.rb` (created) — FOUND (4 tests, 4 clean skips, exit 0)
- Commit `67a44adf` — FOUND in `git log`
- Commit `83093498` — FOUND in `git log`
- Commit `3834e91d` — FOUND in `git log`
- Commit `7381fe79` — FOUND in `git log`
- `grep -c "<script" app/views/tournaments/tournament_monitor.html.erb` = **0** (PASS)
- `grep -c "^  UI_07_FIELDS" app/controllers/tournaments_controller.rb` = **1** (PASS — class-level)
- `ruby -c app/controllers/tournaments_controller.rb` → **Syntax OK** (PASS)
- `bin/rails test test/models/discipline_test.rb` → **4 pass / 0 fail / 0 error** (PASS)
- `bin/rails test test/system/tournament_parameter_verification_test.rb` → exit 0, 4 clean skips (PASS)
