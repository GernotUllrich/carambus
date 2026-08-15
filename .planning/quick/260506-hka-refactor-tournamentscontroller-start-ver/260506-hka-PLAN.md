---
phase: quick-260506-hka
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/controllers/tournaments_controller.rb
  - app/views/tournaments/tournament_monitor.html.erb
  - test/system/tournament_parameter_verification_test.rb
autonomous: true
requirements:
  - REFACTOR-START-VER-01
user_setup: []

must_haves:
  truths:
    - "When start parameters are out of range, the server responds with HTTP 302 redirect to tournament_monitor_tournament_path (PRG pattern), not an in-place render."
    - "After the redirect, the tournament_monitor page renders with @verification_failure populated, the orange warning banner visible, and the confirmation modal auto-opening."
    - "Form parameters are NOT replayed via params/session/flash — fields read from @tournament.<attribute> (every input is StimulusReflex-wired and persisted on change), so the same values reappear naturally after redirect."
    - "flash[:verification_failure] carries the payload across the single redirect and clears automatically (Redis-backed sessions, no 4KB cookie limit)."
    - "data: { turbo: false } is removed from the start_tournament form — Turbo follows the 302 via fetch, replaces <body>, and the auto_open Stimulus controller's connect() fires on the new DOM."
    - "redirect_back_or_to in the rescue branch (line 274) is left untouched — its concern is resolved as a side-effect of PRG (URL bar now sits at a valid GET route after submit), but the explicit redirect_to from commit 23d65963 stays."
    - "test/system/tournament_parameter_verification_test.rb still passes — all 4 tests exercise the redirect+flash flow without needing changes to assertions OR with minimal updates if a test pinned render-not-redirect behavior."
  artifacts:
    - path: "app/controllers/tournaments_controller.rb"
      provides: "PRG: start writes flash[:verification_failure] + redirect_to tournament_monitor_tournament_path; tournament_monitor reads flash into @verification_failure"
      contains: "flash[:verification_failure]"
    - path: "app/views/tournaments/tournament_monitor.html.erb"
      provides: "form_tag without data: { turbo: false } — Turbo handles the 302 via fetch"
      contains: "form_tag start_tournament_path"
    - path: "test/system/tournament_parameter_verification_test.rb"
      provides: "Phase 36B-06 system test still green after refactor"
  key_links:
    - from: "TournamentsController#start (failure branch)"
      to: "TournamentsController#tournament_monitor"
      via: "flash[:verification_failure] + redirect_to tournament_monitor_tournament_path"
      pattern: "flash\\[:verification_failure\\].*redirect_to tournament_monitor_tournament_path"
    - from: "TournamentsController#tournament_monitor"
      to: "app/views/tournaments/tournament_monitor.html.erb"
      via: "@verification_failure = flash[:verification_failure]"
      pattern: "@verification_failure\\s*=\\s*flash\\[:verification_failure\\]"
    - from: "tournament_monitor.html.erb form_tag"
      to: "auto_open Stimulus controller in shared/confirmation_modal"
      via: "Turbo follows 302 → replaces <body> → connect() fires"
      pattern: "form_tag start_tournament_path\\(@tournament\\), id: \"start_tournament\", method: :post do"
---

<objective>
Refactor the TournamentsController#start verification gate from in-place render to a PRG (Post/Redirect/Get) pattern.

Currently when `verify_tournament_start_parameters` finds out-of-range values, the controller does `render :tournament_monitor` — leaving the URL bar at the POST-only `/tournaments/:id/start` route. Two prior commits worked around the symptoms:

- Commit 8a948c93 added `data: { turbo: false }` to the form so the browser does a real navigation (otherwise Turbo's morph dropped the modal element after the partial-page swap).
- Commit 23d65963 replaced `redirect_back_or_to` with `redirect_to tournament_monitor_tournament_path(@tournament)` because `redirect_back_or_to` would loop back to the POST-only URL.

The PRG refactor fixes the root cause: redirect to the GET route, carry the verification payload via `flash[:verification_failure]`, let `tournament_monitor` re-render with the banner+modal. Both workarounds become moot.

Purpose: Restore Turbo-native form submission and clean up two layers of accreted workaround.
Output: Single-task semantic change with the `data: { turbo: false }` revert and a system-test re-run as part of the same task to keep the diff coherent.
</objective>

<execution_context>
@/Users/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.agents/skills/scenario-management/SKILL.md
@.agents/skills/extend-before-build/SKILL.md
@app/controllers/tournaments_controller.rb
@app/views/tournaments/tournament_monitor.html.erb
@test/system/tournament_parameter_verification_test.rb

<scenario_management_note>
This task targets carambus_bcw/, NOT carambus_master/. Per .agents/skills/scenario-management/SKILL.md, files MUST normally be edited in carambus_master/ and pulled into carambus_bcw/. The user has not yet stated "Enter scenario debugging mode for carambus_bcw" in this brainstorm. The executor's FIRST action MUST be to confirm with the user which mode applies:

  Option A — Normal Mode (default): Run the pre-edit precondition check (SKILL section "Pre-Edit Precondition"), then ask the user to switch to carambus_master/ and re-run /gsd-quick from there. The plan transfers verbatim — same file paths exist in master.

  Option B — Debugging Mode: User explicitly says "Enter scenario debugging mode for carambus_bcw". Run the pre-edit precondition check, edit in-place, do NOT commit unless user requests. If user requests commit, follow SKILL "Debugging Mode Workflow" (commit + push from bcw + immediate `git pull` in carambus_master and every other tracked checkout).

DO NOT proceed to Task 1 until mode is confirmed.
</scenario_management_note>

<interfaces>
<!-- Verified call sites and current behavior — no codebase exploration needed -->

# TournamentsController#start (lines 303-317 today)
unless params[:parameter_verification_confirmed].to_s == "1"
  failures = verify_tournament_start_parameters(@tournament, params)
  if failures.any?
    @verification_failure = build_verification_failure_payload(failures)
    render :tournament_monitor and return        # ← REPLACE with PRG
  end
end

# TournamentsController#tournament_monitor (lines 280-284 today)
def tournament_monitor
  return unless @tournament.tournament_monitor.present?
  redirect_to tournament_monitor_path(@tournament.tournament_monitor)
end
# During the start flow @tournament.tournament_monitor is nil → falls
# through and renders app/views/tournaments/tournament_monitor.html.erb
# implicitly. EXTEND: read flash[:verification_failure] into ivar.

# tournament_monitor.html.erb form (line 72 today)
<%= form_tag start_tournament_path(@tournament), id: "start_tournament", method: :post, data: { turbo: false } do %>
#                                                                                          ^^^^^^^^^^^^^^^^^^ remove

# tournament_monitor.html.erb verification banner (lines 55-71)
<% if @verification_failure.present? %>
  <div class="mb-4 p-3 border border-orange-300 bg-orange-50 rounded">…banner…</div>
  <%= render "shared/confirmation_modal", auto_open: true, … %>
<% end %>
# Reads @verification_failure unchanged — controller-side change is invisible to the view.

# Field defaults (verified for all ~16 inputs in the form, examples):
<%= number_field_tag :balls_goal, @tournament.balls_goal || @tournament.data['extracted_balls_goal'], … %>
<%= check_box_tag :auto_upload_to_cc, "1", @tournament.auto_upload_to_cc?, … %>
<%= select_tag :sets_to_play, options_for_select([…], @tournament.sets_to_play), … %>
# Every field's default is sourced from @tournament.<attr>, NOT from params.
# Every field also has data-reflex="change->TournamentReflex#<attr>" with id: @tournament.id,
# which persists each user edit to the DB immediately. After PRG redirect the
# fresh GET re-loads @tournament with the same values — no params plumbing needed.

# Failure rescue branch (lines 272-275, UNCHANGED — see locked decision 5)
rescue StandardError => e
  flash[:alert] = e.message
  redirect_back_or_to(tournament_path(@tournament))   # ← stays as-is, NOT touched
  return
end
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Convert verification gate to PRG and revert workarounds</name>
  <files>
    app/controllers/tournaments_controller.rb,
    app/views/tournaments/tournament_monitor.html.erb
  </files>
  <action>
    Make THREE coordinated edits — all in one task because they form a single semantic change (PRG refactor) and the form-revert without the controller-redirect would break the page.

    **Edit 1 — TournamentsController#start (around line 311-316):**
    Replace the failure branch's `render :tournament_monitor and return` with a PRG redirect. Keep the verification-confirmed bypass and the `failures = verify_tournament_start_parameters(...)` call exactly as-is.

    Before:
    ```ruby
    unless params[:parameter_verification_confirmed].to_s == "1"
      failures = verify_tournament_start_parameters(@tournament, params)
      if failures.any?
        @verification_failure = build_verification_failure_payload(failures)
        render :tournament_monitor and return
      end
    end
    ```

    After:
    ```ruby
    unless params[:parameter_verification_confirmed].to_s == "1"
      failures = verify_tournament_start_parameters(@tournament, params)
      if failures.any?
        # PRG (Post/Redirect/Get): write the verification payload to the
        # flash and redirect to the GET route. Form values do NOT need to be
        # replayed — every input in tournament_monitor.html.erb reads its
        # default from @tournament.<attr> (StimulusReflex change-handlers
        # have already persisted any user edits to the DB). flash is
        # Redis-backed in this project (CLAUDE.md → redis-session-store), so
        # the 4KB cookie limit does not apply and the payload auto-clears
        # after one request.
        flash[:verification_failure] = build_verification_failure_payload(failures)
        redirect_to tournament_monitor_tournament_path(@tournament) and return
      end
    end
    ```

    **Edit 2 — TournamentsController#tournament_monitor (around lines 280-284):**
    Add a single line that promotes `flash[:verification_failure]` to `@verification_failure` so the view can render the banner+modal. Place it before the early-return guard so it works even if a tournament_monitor exists (defensive — current flow has it nil during start, but no reason to gate on that).

    Before:
    ```ruby
    def tournament_monitor
      return unless @tournament.tournament_monitor.present?

      redirect_to tournament_monitor_path(@tournament.tournament_monitor)
    end
    ```

    After:
    ```ruby
    def tournament_monitor
      # PRG-Empfänger: TournamentsController#start (Verifikations-Branch)
      # legt flash[:verification_failure] an und redirected hierher. Die
      # View prüft @verification_failure und rendert Banner + Modal.
      @verification_failure = flash[:verification_failure]
      return unless @tournament.tournament_monitor.present?

      redirect_to tournament_monitor_path(@tournament.tournament_monitor)
    end
    ```

    **Edit 3 — tournament_monitor.html.erb (line 72):**
    Remove `, data: { turbo: false }` from the form_tag. With PRG, Turbo follows the 302 via fetch, replaces `<body>`, and the modal's auto_open Stimulus controller's `connect()` fires on the fresh DOM.

    Before:
    ```erb
    <%= form_tag start_tournament_path(@tournament), id: "start_tournament", method: :post, data: { turbo: false } do %>
    ```

    After:
    ```erb
    <%= form_tag start_tournament_path(@tournament), id: "start_tournament", method: :post do %>
    ```

    DO NOT touch the rescue branch's `redirect_to(tournament_path(@tournament))` at line 274 (locked decision 5: side-effect-resolved, no edit). DO NOT touch any other field defaults, the confirmation_modal partial, the StimulusReflex wiring, or any other view (verified — no other view references @verification_failure).
  </action>
  <verify>
    <automated>
      cd /Users/gullrich/DEV/carambus/carambus_bcw &amp;&amp; \
      grep -nE "flash\[:verification_failure\]\s*=\s*build_verification_failure_payload" app/controllers/tournaments_controller.rb &amp;&amp; \
      grep -nE "redirect_to tournament_monitor_tournament_path\(@tournament\) and return" app/controllers/tournaments_controller.rb &amp;&amp; \
      grep -nE "@verification_failure\s*=\s*flash\[:verification_failure\]" app/controllers/tournaments_controller.rb &amp;&amp; \
      ! grep -nE "render :tournament_monitor and return" app/controllers/tournaments_controller.rb &amp;&amp; \
      ! grep -nE "data:\s*\{\s*turbo:\s*false\s*\}" app/views/tournaments/tournament_monitor.html.erb &amp;&amp; \
      grep -nE "form_tag start_tournament_path\(@tournament\), id: \"start_tournament\", method: :post do" app/views/tournaments/tournament_monitor.html.erb
    </automated>
  </verify>
  <done>
    All six grep checks pass:
    1. flash[:verification_failure] = build_verification_failure_payload(failures) is present in the controller.
    2. redirect_to tournament_monitor_tournament_path(@tournament) and return is present in the controller (failure branch).
    3. @verification_failure = flash[:verification_failure] is present in tournament_monitor action.
    4. The old `render :tournament_monitor and return` is gone from the controller.
    5. `data: { turbo: false }` is gone from the start_tournament form_tag.
    6. The form_tag now ends with `method: :post do` (no data hash).
  </done>
</task>

<task type="auto">
  <name>Task 2: Run system test and update if assertions pinned render-not-redirect</name>
  <files>
    test/system/tournament_parameter_verification_test.rb
  </files>
  <action>
    Run the Phase 36B-06 Capybara test that exercises the verification dialog end-to-end:

    ```bash
    cd /Users/gullrich/DEV/carambus/carambus_bcw
    bin/rails test test/system/tournament_parameter_verification_test.rb
    ```

    Expected outcome: ALL 4 tests pass without source changes. The tests use Capybara `assert_text` / `find` / `click` against rendered DOM — they do not pin HTTP status codes, do not assert `params[:parameter_verification_confirmed]` survives, and do not assert "render vs redirect". They observe browser-visible state, which is identical pre/post PRG (orange banner appears, modal opens, confirm starts the tournament, in-range path skips the modal).

    **If a test fails because of the refactor** (most likely cause: timing — Turbo's fetch+body-swap is faster than full navigation, modal might not be visible when assert_text runs), apply ONE of these minimal fixes (in this order of preference):

    1. **Add a Capybara wait** if the modal needs an extra moment after redirect: `assert_text verification_title, wait: 5` (already supported by Capybara's default DSL).

    2. **Switch the test to assert via flash visibility** if the modal renders before `assert_text` polls: no change needed — `assert_text "99999"` already polls.

    3. **If the test was actually pinning render-not-redirect** (it doesn't appear to, but verify): change `assert_text` calls to wait longer, or add `assert_current_path tournament_monitor_tournament_path(@tournament), wait: 5` after `click_start_button` to confirm the redirect landed before checking modal text.

    DO NOT rewrite the tests structurally. DO NOT add new tests in scope of this quick task. The Phase 36B-06 suite is the contract — keep it green with the smallest possible delta.

    If tests pass on first run with no edits, this task's "files" list is informational only — no actual modification occurs. That is the success case.
  </action>
  <verify>
    <automated>
      cd /Users/gullrich/DEV/carambus/carambus_bcw &amp;&amp; \
      bin/rails test test/system/tournament_parameter_verification_test.rb 2>&amp;1 | tail -20 | grep -E "^[0-9]+ runs, [0-9]+ assertions, 0 failures, 0 errors"
    </automated>
  </verify>
  <done>
    `bin/rails test test/system/tournament_parameter_verification_test.rb` reports `0 failures, 0 errors` (skips are acceptable — the test file's setup includes intentional skip guards for unrelated fixture issues per plan 36B-06 deviation 3). Either:
    (a) all 4 tests passed unmodified (preferred), OR
    (b) minimal Capybara wait/assertion adjustments were applied and now all 4 pass.
  </done>
</task>

</tasks>

<verification>
End-to-end manual sanity check (after both tasks pass):

1. Start the dev stack: `foreman start -f Procfile.dev` (per CLAUDE.md).
2. Sign in, navigate to a tournament whose discipline has parameter_ranges (use `Tournament.joins(:discipline).find { |t| t.discipline.parameter_ranges.any? }` in `bin/rails console` to find one).
3. Visit `tournament_monitor_tournament_path(@tournament)`.
4. Set `balls_goal` to an out-of-range value (e.g., 99999).
5. Click "Turnier starten".
6. Expected: Browser URL bar moves from `/tournaments/:id/start` (POST) to `/tournaments/:id/tournament_monitor` (GET, Turbo-driven 302 follow). Orange banner appears. Modal auto-opens with the confirmation prompt.
7. Cancel: Modal closes, hidden input resets, tournament stays unstarted.
8. Re-submit + Confirm: Tournament transitions to `tournament_started`.
9. Reload the page (F5): NO modal, NO orange banner — flash already consumed (Redis-backed session, single-request lifecycle confirmed).

If `foreman start` is not run during this quick task, the system test in Task 2 is the substitute — it covers steps 4-8 of the manual check.
</verification>

<success_criteria>
- [ ] `flash[:verification_failure] = build_verification_failure_payload(failures)` present in TournamentsController#start.
- [ ] `redirect_to tournament_monitor_tournament_path(@tournament) and return` present in the failure branch (replaces `render :tournament_monitor and return`).
- [ ] `@verification_failure = flash[:verification_failure]` present at the top of TournamentsController#tournament_monitor.
- [ ] `data: { turbo: false }` removed from form_tag in tournament_monitor.html.erb (single occurrence at line 72).
- [ ] `redirect_back_or_to` rescue branch at line 274 NOT touched (locked decision 5).
- [ ] No `render :tournament_monitor and return` remains in TournamentsController.
- [ ] No new view files created. No new helper/concern/service files. No new partials.
- [ ] No changes to TournamentReflex (StimulusReflex change-handlers untouched — they own per-field persistence).
- [ ] No changes to any field default in tournament_monitor.html.erb (verified that all defaults read from @tournament.<attr>).
- [ ] `bin/rails test test/system/tournament_parameter_verification_test.rb` reports `0 failures, 0 errors`.
- [ ] If executor is in carambus_bcw/ checkout, scenario-management mode (Normal vs Debugging) was confirmed with user before any edit, per .agents/skills/scenario-management/SKILL.md.
</success_criteria>

<output>
After completion, create `.planning/quick/260506-hka-refactor-tournamentscontroller-start-ver/260506-hka-SUMMARY.md` summarizing:
- Final diff stats (3 edits, 2 files for Task 1; 0 or minimal for Task 2)
- Test outcome (passes / failures / skips)
- Whether the scenario-management mode was Normal (edits transferred to carambus_master) or Debugging (edits in bcw, sync follow-up status)
- Confirmation that the two prior workaround commits (8a948c93 form turbo:false, 23d65963 redirect_back_or_to → redirect_to) are now architecturally moot — workaround #1 is reverted, workaround #2 is left intact as the more explicit choice
- Any deferred follow-ups (e.g., if the rescue branch's `redirect_back_or_to` should be revisited in a future quick task)
</output>
