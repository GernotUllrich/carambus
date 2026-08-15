---
phase: 36B
plan: 06
type: execute
wave: 3
depends_on: ["36B-02", "36B-03", "36B-05"]
files_modified:
  - app/models/discipline.rb
  - app/views/tournaments/tournament_monitor.html.erb
  - app/controllers/tournaments_controller.rb
  - test/models/discipline_test.rb
  - test/system/tournament_parameter_verification_test.rb
autonomous: true
requirements: [UI-07]
tags: [model, controller, ui, stimulus, modal, test, system-test]

must_haves:
  truths:
    - "Discipline#parameter_ranges returns a Hash like { balls_goal: 50..200, ... } keyed by the 7 UI-07 fields"
    - "Discipline#parameter_ranges handles unknown disciplines by returning either default ranges or an empty hash (never raises)"
    - "When the start form is submitted, the server detects out-of-range values before calling start_tournament!"
    - "Out-of-range values cause the page to re-render with the shared confirmation modal auto-opening via the Stimulus autoOpenValue from plan 05 — NO inline <script> block is added"
    - "In-range values go straight through to start_tournament! (no modal)"
    - "A Minitest unit test asserts Discipline#parameter_ranges for 2+ disciplines and for the nil/unknown case"
    - "A Capybara system test asserts that out-of-range submission shows the modal and in-range submission does not"
    - "UI_07_FIELDS is defined at the TournamentsController class level (NOT inside a method body — that would be a Ruby parse error)"
  artifacts:
    - path: "app/models/discipline.rb"
      provides: "Discipline#parameter_ranges method + DISCIPLINE_PARAMETER_RANGES constant"
      contains: "def parameter_ranges"
    - path: "app/views/tournaments/tournament_monitor.html.erb"
      provides: "Start form carrying the parameter_verification_confirmed hidden token + second render of shared/confirmation_modal with auto_open: true on failure"
    - path: "app/controllers/tournaments_controller.rb"
      provides: "#start action with pre-start parameter verification gate + UI_07_FIELDS class-level constant"
    - path: "test/models/discipline_test.rb"
      provides: "NEW Minitest unit tests for Discipline#parameter_ranges"
    - path: "test/system/tournament_parameter_verification_test.rb"
      provides: "Capybara system test for the pre-start verification dialog"
  key_links:
    - from: "app/controllers/tournaments_controller.rb #start"
      to: "app/models/discipline.rb #parameter_ranges"
      via: "Discipline#parameter_ranges called before start_tournament!"
      pattern: "parameter_ranges"
    - from: "tournament_monitor.html.erb (on server-side verification failure)"
      to: "plan-05 shared/confirmation_modal partial with auto_open: true"
      via: "render \"shared/confirmation_modal\", auto_open: true, hidden_override_name: \"parameter_verification_confirmed\", form_id: \"start_tournament\", ..."
      pattern: "shared/confirmation_modal"
---

<objective>
Implement UI-07 (parameter verification dialog before `start_tournament!`) as follows:

**D-17 / D-18 design:**
1. Add `Discipline#parameter_ranges` returning a hash of `field_name => range` for these 7 fields: `balls_goal`, `innings_goal`, `timeout`, `time_out_warm_up_first_min`, `time_out_warm_up_follow_up_min`, `sets_to_play`, `sets_to_win`. First pass uses hardcoded constants inside the model (future refinement may move to DB).
2. Modify `TournamentsController#start` so it runs a pre-flight range check against the submitted params. If any value is out of range, the action re-renders `tournament_monitor.html.erb` with an instance variable `@verification_failure` (a Hash with `:body_text`, `:failures`) that makes the shared confirmation modal render with `auto_open: true`. If the form was resubmitted with a hidden `parameter_verification_confirmed: "1"` param, the check is bypassed (user has explicitly confirmed via the modal Confirm button).
3. Modify `tournament_monitor.html.erb` to (a) include a hidden `parameter_verification_confirmed` input inside the start form (default `"0"`), and (b) render a second instance of `shared/confirmation_modal` at the top of the page ONLY when the controller sets `@verification_failure`, passing `auto_open: true`, `hidden_override_name: "parameter_verification_confirmed"`, and `auto_open_form_id: "start_tournament"`. This uses the plan-05 Stimulus values — there is NO inline `<script>` block (Stimulus-first policy, CLAUDE.md).
4. Add Minitest unit tests for `Discipline#parameter_ranges`.
5. Add a Capybara system test for the full flow.

**Why server-side check is authoritative (T-36b06-02):** the range check runs in the Rails controller, not only in JavaScript. Client-side override of the modal can't bypass the check because the server re-runs the comparison on every submit and requires the `parameter_verification_confirmed` hidden input to be explicitly present AND equal to `"1"`.

**Why wave 3:** this plan touches `tournament_monitor.html.erb` (conflicts with plans 02 and 03) and depends on the shared modal infrastructure from plan 05 (including its `autoOpenValue` + `hiddenOverrideNameValue` Stimulus values, which plan 05 defines from day one). It's the last plan in the phase for that reason.

**Stimulus-first policy:** the previous draft of this plan used an inline `<script>` to auto-open the modal and flip the hidden input. That violates the project's Stimulus + importmap convention (CLAUDE.md). This plan uses the plan-05 controller's `autoOpenValue` and `hiddenOverrideNameValue` — NO inline scripts anywhere.

**Ruby constant scope correction:** an earlier draft placed `UI_07_FIELDS = %i[...].freeze unless defined?(UI_07_FIELDS)` inside the `verify_tournament_start_parameters` method body. That is a parse-time error in Ruby — dynamic constant assignment inside a method is forbidden, and the `unless defined?` guard does not help. This plan places `UI_07_FIELDS` at the CLASS level, under `class TournamentsController`, before the `def start` action.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md
@.planning/REQUIREMENTS.md
@app/models/discipline.rb
@app/views/tournaments/tournament_monitor.html.erb
@app/controllers/tournaments_controller.rb
@app/javascript/controllers/confirmation_modal_controller.js
@app/views/shared/_confirmation_modal.html.erb

<interfaces>
Discipline model (from app/models/discipline.rb, line 23):
  class Discipline < ApplicationRecord
    belongs_to :super_discipline, ...
    has_many :sub_disciplines, ...
    # Common discipline `name` values used in the project include:
    #   "Freie Partie", "Freie Partie klein", "Cadre 47/1", "Cadre 47/2",
    #   "Cadre 71/2", "Einband", "Dreiband", "5-Kegel-Billard"
  end

TournamentsController#start (from app/controllers/tournaments_controller.rb:288+):
  def start
    auto_upload_enabled = params[:auto_upload_to_cc].to_i == 1
    if @tournament.tournament_cc.present? && auto_upload_enabled
      ... ClubCloud validation ...
    end

    data_ = @tournament.data
    data_["table_ids"] = params[:table_id]
    data_["balls_goal"] = params[:balls_goal].to_i
    ...
    @tournament.start_tournament!
    ...
  end

TournamentsController `private` section starts at line 949.

tournament_monitor.html.erb start form (from file, line 39):
  <%= form_tag start_tournament_path(@tournament), id: "start_tournament", method: :post do %>

tournament_monitor.html.erb submit button (from file, line 115):
  <%= submit_tag I18n.t("tournaments.start_tournament"), class: "btn btn-flat btn-primary mt-2" %>
  # → renders as <input type="submit" name="commit" value="Starte den Turnier-Monitor">

balls_goal input (from file, line 63):
  <%= number_field_tag :balls_goal, ... %>
  # → renders as <input type="number" name="balls_goal" ...>

Shared modal controller (plan 05) — Stimulus values supported:
  static values = {
    autoOpen: Boolean,
    autoOpenTitle: String,
    autoOpenBody: String,
    autoOpenConfirmLabel: String,
    autoOpenFormId: String,
    hiddenOverrideName: String,
    hiddenOverrideResetOnCancel: { type: Boolean, default: true }
  }

Shared modal partial (plan 05) — locals supported:
  auto_open:                        Boolean
  auto_open_title:                  String
  auto_open_body:                   String
  auto_open_confirm_label:          String
  auto_open_form_id:                String
  hidden_override_name:             String
  hidden_override_reset_on_cancel:  Boolean (default true)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add Discipline#parameter_ranges + Minitest unit tests (RED → GREEN)</name>
  <files>
    app/models/discipline.rb
    test/models/discipline_test.rb
  </files>
  <read_first>
    - app/models/discipline.rb (full file — understand existing constants, class method patterns)
    - test/models/tournament_test.rb (Minitest conventions — mirror its style)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-17, §D-18, §D-19
  </read_first>
  <behavior>
    Test 1: A Discipline with name "Freie Partie" or "Freie Partie klein" returns ranges with keys [:balls_goal, :innings_goal, :timeout, :time_out_warm_up_first_min, :time_out_warm_up_follow_up_min, :sets_to_play, :sets_to_win]
    Test 2: For "Freie Partie klein", `parameter_ranges[:balls_goal]` is a Range that includes 100 and excludes 10000
    Test 3: For a Discipline with an unknown/nil name, `parameter_ranges` returns an empty hash (NO exception)
    Test 4: For every discipline in the fixtures, calling `parameter_ranges` does not raise
    Test 5: Each returned range is a `Range` object (not an Array, not a Hash) with `.cover?` usable
  </behavior>
  <action>
**A — Create `test/models/discipline_test.rb` (file does not exist yet):**

    require "test_helper"

    class DisciplineTest < ActiveSupport::TestCase
      # UI-07 D-19: parameter_ranges must return a hash of field -> Range
      # and must not raise on unknown disciplines.

      test "parameter_ranges returns hash with expected keys for Freie Partie klein" do
        d = Discipline.find_by(name: "Freie Partie klein") ||
            Discipline.find_by(name: "Freie Partie") ||
            disciplines(:freie_partie) rescue nil
        skip "no Freie Partie discipline in fixtures" unless d

        ranges = d.parameter_ranges
        assert_instance_of Hash, ranges
        %i[balls_goal innings_goal timeout
           time_out_warm_up_first_min time_out_warm_up_follow_up_min
           sets_to_play sets_to_win].each do |k|
          assert ranges.key?(k), "expected key #{k} in parameter_ranges"
          assert_instance_of Range, ranges[k], "expected Range for #{k}, got #{ranges[k].class}"
        end
      end

      test "parameter_ranges includes sensible balls_goal for Freie Partie" do
        d = Discipline.find_by(name: "Freie Partie klein") ||
            Discipline.find_by(name: "Freie Partie")
        skip "no Freie Partie discipline in fixtures" unless d

        ranges = d.parameter_ranges
        assert ranges[:balls_goal].cover?(100), "100 should be a valid balls_goal"
        assert_not ranges[:balls_goal].cover?(10_000), "10_000 should be out of range"
      end

      test "parameter_ranges returns empty hash for unknown discipline name" do
        d = Discipline.new(name: "TotallyFakeDisciplineName-#{SecureRandom.hex(4)}")
        assert_nothing_raised do
          result = d.parameter_ranges
          assert_instance_of Hash, result
          assert_empty result, "unknown discipline should yield an empty Hash"
        end
      end

      test "parameter_ranges does not raise for any fixture discipline" do
        Discipline.find_each do |d|
          assert_nothing_raised(nil, "discipline id=#{d.id} name=#{d.name}") do
            result = d.parameter_ranges
            assert result.is_a?(Hash), "parameter_ranges must always return a Hash"
          end
        end
      end
    end

Run this test file — all four tests should FAIL with `NoMethodError: undefined method 'parameter_ranges'` (this is the RED step).

**B — Implement `Discipline#parameter_ranges` in `app/models/discipline.rb`:**

Add near the top of the class (after the existing constants, before the existing `has_many` associations):

    # UI-07 D-17: Parameter-Bereiche pro Disziplin für die Verifikations-
    # Abfrage vor dem Turnierstart. Key = Attributname (Symbol), Value = Range.
    # Erste Implementierung mit fest kodierten Werten — später auslagerbar.
    DISCIPLINE_PARAMETER_RANGES = {
      "Freie Partie"        => { balls_goal: 50..500,   innings_goal: 20..80,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "Freie Partie klein"  => { balls_goal: 50..500,   innings_goal: 20..80,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "Cadre 47/1"          => { balls_goal: 50..300,   innings_goal: 15..60,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "Cadre 47/2"          => { balls_goal: 50..300,   innings_goal: 15..60,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "Cadre 71/2"          => { balls_goal: 50..300,   innings_goal: 15..60,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "Einband"             => { balls_goal: 30..200,   innings_goal: 15..60,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "Dreiband"            => { balls_goal: 10..80,    innings_goal: 20..80,  timeout: 30..90,  time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 },
      "5-Kegel-Billard"     => { balls_goal: 60..300,   innings_goal: 10..60,  timeout: 30..120, time_out_warm_up_first_min: 1..10, time_out_warm_up_follow_up_min: 0..5, sets_to_play: 1..7, sets_to_win: 1..4 }
    }.freeze

And add this instance method:

    # UI-07 D-17: Liefert ein Hash mit Field -> Range für die UI-07 Pre-Start-
    # Verifikation. Unbekannte Disziplinen bekommen ein leeres Hash — der
    # Controller interpretiert das als "keine Prüfung" (keine Exception).
    def parameter_ranges
      DISCIPLINE_PARAMETER_RANGES[name.to_s] || {}
    end

Run the tests again — all four MUST pass (GREEN). The `for fixture disciplines` test may return an empty hash for disciplines whose `name` is not in the constant — that is allowed per the "unknown discipline → empty hash" contract.

**C — Do NOT** remove or modify any existing method in `app/models/discipline.rb`. `parameter_ranges` is a pure addition.
  </action>
  <verify>
    <automated>bin/rails test test/models/discipline_test.rb -x && bundle exec standardrb app/models/discipline.rb test/models/discipline_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/models/discipline_test.rb` exists
    - `grep -c "def parameter_ranges" app/models/discipline.rb` returns `1`
    - `grep -c "DISCIPLINE_PARAMETER_RANGES" app/models/discipline.rb` returns `2` (constant def + use inside method)
    - `grep -c "class DisciplineTest" test/models/discipline_test.rb` returns `1`
    - `grep -c "^  test " test/models/discipline_test.rb` returns `4`
    - `bin/rails test test/models/discipline_test.rb -x` exits 0
    - `bundle exec standardrb app/models/discipline.rb test/models/discipline_test.rb` exits 0
  </acceptance_criteria>
  <done>
    Discipline#parameter_ranges exists and is hardcoded per discipline; 4 Minitest tests cover the known-discipline, unknown-discipline, and iterate-all-fixtures cases; all tests pass.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Server-side range check in TournamentsController#start + override-token handling (class-level constant)</name>
  <files>app/controllers/tournaments_controller.rb</files>
  <read_first>
    - app/controllers/tournaments_controller.rb lines 1-50 (find class declaration; locate a spot for a class-level constant near other constants)
    - app/controllers/tournaments_controller.rb lines 288-380 (the `def start` action in full)
    - app/controllers/tournaments_controller.rb line 949 (the existing `private` section marker — the helper goes inside this section)
    - app/models/discipline.rb (after Task 1 — confirm `parameter_ranges` available)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-17, §D-18
  </read_first>
  <action>
**A — Add a class-level constant `UI_07_FIELDS` near the top of the class.** Find the class declaration (`class TournamentsController < ApplicationController`) and add the constant immediately after any existing `before_action` / constants block, BEFORE any method definitions:

    # UI-07 D-18: Felder, die vor dem Turnierstart gegen Discipline#parameter_ranges
    # geprüft werden. Reihenfolge matcht die Anzeige im Start-Formular, damit der
    # Nutzer Ausreißer in derselben Reihenfolge sieht.
    UI_07_FIELDS = %i[
      balls_goal
      innings_goal
      timeout
      time_out_warm_up_first_min
      time_out_warm_up_follow_up_min
      sets_to_play
      sets_to_win
    ].freeze

**CRITICAL — do NOT place this constant inside any method body.** Ruby forbids dynamic constant assignment inside methods. Placing it under `class TournamentsController` at the top of the class (outside any `def`) is the only valid location.

**B — Modify `TournamentsController#start` so the very first thing it does (before any data mutation or AASM transition) is run a range check:**

Replace the beginning of `def start` with:

    def start
      # UI-07 D-17/D-18: Parameter-Verifikation vor start_tournament!
      # Wenn der Nutzer noch nicht explizit die Ausreißer bestätigt hat
      # (parameter_verification_confirmed != "1"), sammeln wir alle Out-of-Range-
      # Werte und rendern das Formular mit aktivem Bestätigungs-Modal neu.
      unless params[:parameter_verification_confirmed].to_s == "1"
        failures = verify_tournament_start_parameters(@tournament, params)
        if failures.any?
          @verification_failure = build_verification_failure_payload(failures)
          render :tournament_monitor and return
        end
      end

      # ---- alles unverändert ab hier ----
      auto_upload_enabled = params[:auto_upload_to_cc].to_i == 1
      if @tournament.tournament_cc.present? && auto_upload_enabled
        ...

**C — Add the two private helpers at the bottom of the controller (inside the existing `private` section at ~line 949):**

    # UI-07: vergleicht die im Start-Formular übermittelten Parameter
    # mit Discipline#parameter_ranges und liefert eine Liste von Ausreißern.
    # Liefert [] wenn alles in Ordnung.
    #
    # Shape des Rückgabewerts:
    #   [{ field: :balls_goal, value: 9999, range: (50..500), label: "Bälle-Ziel" }, ...]
    def verify_tournament_start_parameters(tournament, raw_params)
      ranges = tournament.discipline&.parameter_ranges || {}
      return [] if ranges.empty?

      UI_07_FIELDS.each_with_object([]) do |field, failures|
        range = ranges[field]
        next unless range

        raw = raw_params[field]
        next if raw.nil? || raw.to_s.strip.empty?

        value = raw.to_i
        next if range.cover?(value)

        failures << {
          field: field,
          value: value,
          range: range,
          label: I18n.t("tournaments.monitor_form.labels.#{field}", default: field.to_s.humanize)
        }
      end
    end

    # UI-07: baut das Hash, das an shared/confirmation_modal übergeben wird,
    # inklusive des Body-Textes, der alle Ausreißer inkl. Bereich auflistet.
    def build_verification_failure_payload(failures)
      body_lines = failures.map do |f|
        "#{f[:label]} = #{f[:value]} (üblich: #{f[:range].first}-#{f[:range].last})"
      end
      body_intro = I18n.t(
        "tournaments.monitor_form.verification.body_intro",
        default: "Die folgenden Werte liegen außerhalb des üblichen Bereichs für diese Disziplin. Bitte prüfen und bestätigen, wenn sie wirklich gewollt sind:"
      )
      {
        failures: failures,
        body_text: body_intro + "\n\n" + body_lines.join("\n")
      }
    end

**Note:** `UI_07_FIELDS` is referenced from `verify_tournament_start_parameters` as a simple constant lookup — no `defined?` guard, no dynamic assignment. Ruby resolves it against the enclosing `TournamentsController` class.

**No other changes to the controller.** The existing data_ hash population, the `@tournament.save`, the `@tournament.start_tournament!` — all stay exactly as they are. If the check passes, execution falls through to the original start logic.

If `@tournament.discipline` is `nil` (edge case for tournaments without a discipline), `parameter_ranges` returns `{}` and the check returns `[]` → falls through to normal start. No change in behavior for that edge case.

**Key naming change:** the hidden input is now called `parameter_verification_confirmed` (was `verified_override` in the earlier draft) because the new name is more self-documenting and matches the Stimulus `hidden_override_name` local passed to the partial in Task 3.
  </action>
  <verify>
    <automated>bundle exec standardrb app/controllers/tournaments_controller.rb && ruby -c app/controllers/tournaments_controller.rb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "parameter_verification_confirmed" app/controllers/tournaments_controller.rb` returns `>= 1`
    - `grep -c "verify_tournament_start_parameters" app/controllers/tournaments_controller.rb` returns `2` (call site + definition)
    - `grep -c "build_verification_failure_payload" app/controllers/tournaments_controller.rb` returns `2` (call site + definition)
    - `grep -c "parameter_ranges" app/controllers/tournaments_controller.rb` returns `1`
    - `grep -c "@verification_failure" app/controllers/tournaments_controller.rb` returns `1`
    - `grep -c "^  UI_07_FIELDS" app/controllers/tournaments_controller.rb` returns `1` (constant declared at CLASS level, 2-space indent — not inside a method)
    - `grep -n "UI_07_FIELDS" app/controllers/tournaments_controller.rb | head -1 | grep -v "def "` succeeds (first occurrence is NOT inside a def line)
    - `grep -c "def start$" app/controllers/tournaments_controller.rb` returns `1` (single start action, not duplicated)
    - `grep -c "start_tournament!" app/controllers/tournaments_controller.rb` returns `>= 1` (original AASM call preserved, not removed)
    - `ruby -c app/controllers/tournaments_controller.rb` exits 0 (parses successfully — catches the dynamic-constant-assignment error that the previous draft would have produced)
    - `bundle exec standardrb app/controllers/tournaments_controller.rb` exits 0
  </acceptance_criteria>
  <done>
    `TournamentsController#start` runs a server-side range check before `start_tournament!`, two private helpers (`verify_tournament_start_parameters`, `build_verification_failure_payload`) exist, the override token bypasses the check when explicitly set, `UI_07_FIELDS` is a class-level constant (NOT defined inside a method body), the file parses without Ruby errors, and standardrb is clean.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Render verification modal via plan-05 shared partial (auto_open + hidden_override, NO inline script)</name>
  <files>app/views/tournaments/tournament_monitor.html.erb</files>
  <read_first>
    - app/views/tournaments/tournament_monitor.html.erb (post plan-02 and plan-03 state — tooltips in place, admin_controlled row removed; line 39 shows the start form with id "start_tournament")
    - app/views/shared/_confirmation_modal.html.erb (plan 05 — confirm the auto_open / hidden_override_name locals API)
    - app/javascript/controllers/confirmation_modal_controller.js (plan 05 — confirm the autoOpenValue + hiddenOverrideNameValue + setHiddenOverride behavior)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-17, §D-18
    - CLAUDE.md (Stimulus + importmap policy — NO inline `<script>` blocks)
  </read_first>
  <action>
Two changes to `tournament_monitor.html.erb`. **NEITHER change adds an inline `<script>` block** — Stimulus-first policy per CLAUDE.md.

**A — Add a hidden `parameter_verification_confirmed` input inside the start form.** The form currently opens with (line ~39):

    <%= form_tag start_tournament_path(@tournament), id: "start_tournament", method: :post do %>

Inside the form, near the top (right after the opening `do %>`), add:

    <%= hidden_field_tag :parameter_verification_confirmed, "0" %>

This is a no-op on first render. When the controller detects failures and re-renders, it still writes `"0"` here (the template always emits `"0"`). The plan-05 Stimulus controller's `confirm()` action calls `setHiddenOverride("1")` on this field before running `requestSubmit()`, so the second POST carries `parameter_verification_confirmed=1` and the server-side gate in Task 2 lets it through. Cancel calls `setHiddenOverride("0")` so a re-open-after-cancel cycle doesn't leave `"1"` stuck.

**B — Render the shared confirmation modal (auto-open mode) BEFORE the start form.** Immediately above the form opening, add:

    <% if @verification_failure.present? %>
      <div class="mb-4 p-3 border border-orange-300 bg-orange-50 rounded">
        <p class="text-sm text-orange-900 font-semibold mb-2">
          <%= I18n.t("tournaments.monitor_form.verification.banner",
                     default: "Einige Werte weichen vom üblichen Bereich für diese Disziplin ab. Bitte prüfen und bestätigen.") %>
        </p>
      </div>

      <%= render "shared/confirmation_modal",
            auto_open: true,
            auto_open_title: I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter"),
            auto_open_body: @verification_failure[:body_text],
            auto_open_confirm_label: I18n.t("tournaments.monitor_form.verification.confirm", default: "Ja, Werte übernehmen und Turnier starten"),
            auto_open_form_id: "start_tournament",
            hidden_override_name: "parameter_verification_confirmed",
            hidden_override_reset_on_cancel: true %>
    <% end %>

That's it. No `<script>` block. No JavaScript at all in the ERB.

**How this works (reading the plan-05 controller):**
1. The `<% if @verification_failure.present? %>` guard only fires on the server-rendered response after the range check found a failure.
2. Inside, we render `shared/confirmation_modal` a **second time** for this page (the layout already renders it once via `application.html.erb` for click-trigger use). The second render produces a separate `data-controller="confirmation-modal"` element with its own Stimulus controller instance. Because `auto_open: true`, that instance's `connect()` hook calls `openWithValues()` via `queueMicrotask`, populating the title/body/confirm label from the `auto_open_*_value` data attributes.
3. When the user clicks Confirm, the plan-05 controller's `confirm()` method:
   - Calls `setHiddenOverride("1")` which finds the `input[name="parameter_verification_confirmed"]` element inside the form with id `"start_tournament"` and sets its value to `"1"`.
   - Calls `requestSubmit()` on `document.getElementById("start_tournament")`.
4. The browser POSTs the form again, this time with `parameter_verification_confirmed=1`. The Task 2 controller code sees the `"1"` and skips the verification step, calling `start_tournament!` normally.
5. If the user clicks Cancel, the controller's `cancel()` method calls `setHiddenOverride("0")` (because `hiddenOverrideResetOnCancelValue` defaults to `true`), ensuring that if the user edits a field and resubmits, the verification gate runs fresh.

**C — DO NOT** add the `tournaments.monitor_form.verification.*` keys to de.yml/en.yml in this task. All `t()` calls use `default:` fallbacks. Keeping this plan out of de.yml/en.yml avoids another round of wave-serialization on the locale files.

**D — DO NOT** touch any parameter-row label or tooltip. Plans 02 and 03 own those.

**E — DO NOT** add any `<script>` tag anywhere in the file. The entire wiring goes through plan 05's `confirmation_modal_controller.js`.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournaments/tournament_monitor.html.erb && ruby -e "src = File.read('app/views/tournaments/tournament_monitor.html.erb'); raise 'inline script forbidden in tournament_monitor.html.erb' if src =~ /<script/i; puts 'no inline script — OK'"</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "parameter_verification_confirmed" app/views/tournaments/tournament_monitor.html.erb` returns **exactly `1`** (just the hidden_field_tag — no inline JS setter)
    - `grep -c "hidden_field_tag :parameter_verification_confirmed" app/views/tournaments/tournament_monitor.html.erb` returns `1`
    - `grep -c "@verification_failure" app/views/tournaments/tournament_monitor.html.erb` returns `>= 1`
    - `grep -c 'render "shared/confirmation_modal"' app/views/tournaments/tournament_monitor.html.erb` returns `1`
    - `grep -c "auto_open: true" app/views/tournaments/tournament_monitor.html.erb` returns `1`
    - `grep -c 'hidden_override_name: "parameter_verification_confirmed"' app/views/tournaments/tournament_monitor.html.erb` returns `1`
    - `grep -c 'auto_open_form_id: "start_tournament"' app/views/tournaments/tournament_monitor.html.erb` returns `1`
    - `grep -c 'id: "start_tournament"' app/views/tournaments/tournament_monitor.html.erb` returns `1` (existing form id preserved)
    - `grep -c "<script" app/views/tournaments/tournament_monitor.html.erb` returns **`0`** (Stimulus-first policy — no inline script)
    - `grep -c "tournaments.monitor_form.verification" app/views/tournaments/tournament_monitor.html.erb` returns `>= 3` (banner + title + body_intro/confirm)
    - `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` exits 0
  </acceptance_criteria>
  <done>
    Hidden override input is in the form; the conditional `render "shared/confirmation_modal"` call renders when `@verification_failure` is present; NO inline `<script>` exists; the plan-05 Stimulus controller handles auto-open + hidden-override via its declared values; erblint is clean.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 4: Capybara system test for the UI-07 verification flow (robust name-based selectors)</name>
  <files>test/system/tournament_parameter_verification_test.rb</files>
  <read_first>
    - test/system/tournament_reset_confirmation_test.rb (from plan 05 — mirror the setup + sign-in pattern)
    - app/views/tournaments/tournament_monitor.html.erb (after Task 3 — verify the start form id + balls_goal input name + submit button name)
    - app/controllers/tournaments_controller.rb (after Task 2)
    - test/test_helper.rb (fixture availability + LocalProtectorTestOverride)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-20
  </read_first>
  <behavior>
    Test 1: Submitting the start form with an out-of-range balls_goal (e.g., 9999 for Freie Partie klein) shows the parameter verification modal with the offending value listed in the body.
    Test 2: Clicking Cancel in the modal closes it, the tournament does NOT start (state unchanged), the form stays on the same page.
    Test 3: Clicking Confirm in the modal flips the parameter_verification_confirmed hidden input to "1", submits the form, the tournament starts (AASM state transitions).
    Test 4: Submitting the form with in-range values goes straight through without showing the modal. The tournament starts directly.
  </behavior>
  <action>
Create `test/system/tournament_parameter_verification_test.rb` using **robust name-based selectors** (NOT `fill_in "balls_goal"` with a label, NOT `click_button I18n.t(...)` with button text — those are fragile). The file under test uses `number_field_tag :balls_goal` and `submit_tag ...` which render as `<input name="balls_goal">` and `<input type="submit" name="commit">` respectively. We use those name attributes directly.

    require "application_system_test_case"

    class TournamentParameterVerificationTest < ApplicationSystemTestCase
      # UI-07 D-20: Capybara system test for the parameter verification dialog
      # that surfaces before start_tournament! when values are out of range.

      setup do
        @user = users(:admin) rescue User.first
        raise "sign_in helper required — include Devise::Test::IntegrationHelpers in ApplicationSystemTestCase" unless respond_to?(:sign_in)
        sign_in @user

        # Find a tournament that is in the tournament_mode_defined state
        # (ready to start) with a discipline that has parameter_ranges.
        @tournament = Tournament.joins(:discipline)
                                .where.not(state: %w[tournament_started playing_groups playing_finals finals_finished results_published closed])
                                .find { |t| t.discipline && t.discipline.parameter_ranges.any? }
        skip "no eligible tournament with discipline ranges" unless @tournament
      end

      def fill_balls_goal(value)
        # number_field_tag :balls_goal renders <input type="number" name="balls_goal">.
        # Use the name attribute directly — no reliance on labels or IDs.
        find("input[name='balls_goal']").set(value.to_s)
      end

      def click_start_button
        # submit_tag I18n.t("tournaments.start_tournament") renders
        # <input type="submit" name="commit" value="...">. Find by name="commit"
        # scoped to the start_tournament form to avoid matching other submits.
        within("#start_tournament") do
          find("input[type='submit'][name='commit']").click
        end
      end

      test "out-of-range balls_goal opens verification modal" do
        visit tournament_monitor_tournament_path(@tournament)

        fill_balls_goal(99999)
        click_start_button

        # Server re-renders with @verification_failure set; the second
        # shared/confirmation_modal render has auto_open: true, so the
        # plan-05 Stimulus controller auto-opens it on connect().
        assert_text I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter")
        assert_text "99999"

        # Tournament did NOT start
        assert_not_equal "tournament_started", @tournament.reload.state
      end

      test "clicking Cancel keeps tournament un-started" do
        visit tournament_monitor_tournament_path(@tournament)

        fill_balls_goal(99999)
        click_start_button

        assert_text I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter")
        find("button[data-action='click->confirmation-modal#cancel']", match: :first).click

        assert_not_equal "tournament_started", @tournament.reload.state
      end

      test "clicking Confirm starts the tournament with the override" do
        visit tournament_monitor_tournament_path(@tournament)

        fill_balls_goal(99999)
        click_start_button

        assert_text I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter")
        find("button[data-action='click->confirmation-modal#confirm']", match: :first).click

        # AASM transition: start_tournament! goes to tournament_started_waiting_for_monitors
        # (or tournament_started, depending on monitor-readiness).
        assert_includes %w[tournament_started tournament_started_waiting_for_monitors],
                        @tournament.reload.state
      end

      test "in-range values skip the modal and start the tournament directly" do
        visit tournament_monitor_tournament_path(@tournament)

        # Use a value that is inside any reasonable range (50..500 for Freie Partie).
        fill_balls_goal(100)
        click_start_button

        # No modal text should appear.
        assert_no_text I18n.t("tournaments.monitor_form.verification.title", default: "Ungewöhnliche Turnierparameter")
        assert_includes %w[tournament_started tournament_started_waiting_for_monitors],
                        @tournament.reload.state
      end
    end

**Design notes (W-5 fix):**
- `find("input[name='balls_goal']").set(...)` is robust against label/id changes. `number_field_tag :balls_goal` does not produce an associated `<label for="...">`, so Capybara's `fill_in "balls_goal"` would fail.
- `find("input[type='submit'][name='commit']", ...)` is robust against button-text/i18n-default drift. `submit_tag` always produces `name="commit"` unless explicitly overridden.
- `within("#start_tournament")` scopes both fills so neighboring forms on the page (e.g., the plan-05 reset form) don't interfere with the selector.
- The `match: :first` on the modal buttons handles the case where both the layout-level modal AND the auto-open modal exist on the page — both have the same `data-action` selectors, but only the auto-open one is visible. Capybara will find the first matching DOM element regardless of visibility; if the first is hidden, Capybara will skip it. In a headless browser, prefer visible matching: use `find("button[data-action='click->confirmation-modal#confirm']", match: :first, visible: true)` if the default doesn't work.
- **Loud sign_in guard:** `raise "sign_in helper required..."` instead of silently skipping — a missing Devise helper is a test-setup bug, not a fixture gap (I-3 fix).
- Skip-friendly setup: if no eligible tournament fixture exists, the test `skip`s with a clear message rather than fails.

Do NOT touch any fixture file. The test works against whatever fixture data exists; it skips if nothing matches.
  </action>
  <verify>
    <automated>bin/rails test test/system/tournament_parameter_verification_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/system/tournament_parameter_verification_test.rb` exists
    - `grep -c "class TournamentParameterVerificationTest" test/system/tournament_parameter_verification_test.rb` returns `1`
    - `grep -c "^  test " test/system/tournament_parameter_verification_test.rb` returns `4`
    - `grep -c "99999" test/system/tournament_parameter_verification_test.rb` returns `>= 3` (out-of-range value used in 3 tests)
    - `grep -c "confirmation-modal#cancel" test/system/tournament_parameter_verification_test.rb` returns `1`
    - `grep -c "confirmation-modal#confirm" test/system/tournament_parameter_verification_test.rb` returns `1`
    - `grep -c "input\\[name='balls_goal'\\]" test/system/tournament_parameter_verification_test.rb` returns `>= 1` (name-based selector for balls_goal, NOT fill_in "balls_goal")
    - `grep -c "input\\[type='submit'\\]\\[name='commit'\\]" test/system/tournament_parameter_verification_test.rb` returns `>= 1` (name-based submit selector)
    - `grep -c 'fill_in "balls_goal"' test/system/tournament_parameter_verification_test.rb` returns `0` (fragile label-based selector NOT used)
    - `grep -c 'raise "sign_in helper required' test/system/tournament_parameter_verification_test.rb` returns `1` (loud guard, not silent skip)
    - `bin/rails test test/system/tournament_parameter_verification_test.rb` exits 0 (all tests pass OR all skip with clear preconditions)
  </acceptance_criteria>
  <done>
    System test file exists with 4 tests (open / cancel / confirm / bypass-when-in-range). Uses robust name-based selectors (not label-based). Sign-in guard raises loudly on misconfiguration. Tests pass or skip cleanly.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| operator browser → TournamentsController#start | Start form POSTs tournament parameters |
| Stimulus controller → form.requestSubmit() | Modal Confirm triggers form submission |
| Rails controller → AASM transition | start_tournament! fires the state machine |

## STRIDE Threat Register (ASVS L1)

| Threat ID | Category | Component | Disposition | Mitigation |
|-----------|----------|-----------|-------------|------------|
| T-36b06-01 | Tampering (T) / DOM manipulation | User manipulates DOM to set `parameter_verification_confirmed=1` and skip the modal | mitigate | The override token is checked SERVER-SIDE in `TournamentsController#start`. If the user manipulates the DOM, the server still re-runs `verify_tournament_start_parameters` on every submit — and the check returns failures for out-of-range values regardless of what the client did. The client-side modal is UX; the server-side check is authoritative. Note: a user CAN deliberately bypass by setting the value directly via curl — but that is a DELIBERATE opt-in, which is exactly the semantic the plan intends. |
| T-36b06-02 | Elevation of privilege (E) | User bypasses the verification modal by POSTing directly with curl | mitigate | Direct POST with `parameter_verification_confirmed=1` succeeds IF the operator explicitly opts in. This is by design — the modal is a warning, not a hard ban. Setting the override is a DELIBERATE user action. The server-side check is not a security boundary; it is a confirmation UX. Existing authentication and authorization on the `#start` action (Devise + Pundit / role check) remain unchanged. |
| T-36b06-03 | Tampering (T) / XSS | Out-of-range failure messages rendered into the DOM | mitigate | The failure body string is constructed in the controller's `build_verification_failure_payload` helper using plain Ruby string concatenation, then passed to the shared partial as `auto_open_body`, which the partial inserts via `<%= %>` (HTML-escaped) into a `data-confirmation-modal-auto-open-body-value` attribute. The plan-05 Stimulus controller reads the value and writes it to the DOM via `textContent` (never `innerHTML`). `f[:label]` comes from `I18n.t(...)` with a safe `default:` fallback. `f[:value]` is cast to integer via `.to_i` before interpolation, so no HTML can sneak through. |
| T-36b06-04 | Denial of service (D) | Malformed params cause the controller to raise instead of gracefully re-rendering | mitigate | `verify_tournament_start_parameters` is wrapped in a `return [] if ranges.empty?` guard. The `raw_params[field].to_i` call tolerates nil and non-numeric input. `cover?` is called only when `range` is present. `parameter_ranges` itself returns `{}` for unknown disciplines (Task 1 test #3). No exception paths. |
| T-36b06-05 | Repudiation (R) | Operator claims they didn't set an unusual value | accept | The override token is persistent in the form submission. Future audit work (PaperTrail is already in the project) could log the override explicitly; out of scope for UI-07 first-pass. |
| T-36b06-06 | Code-execution (E) | Inline `<script>` block could be an XSS sink if future contributors interpolate params into it | mitigate | This plan explicitly does NOT add any `<script>` tag to `tournament_monitor.html.erb`. All client-side logic goes through the plan-05 Stimulus controller (`confirmation_modal_controller.js`). The `erblint` + `grep -c "<script"` acceptance criterion in Task 3 enforces this at CI time. |
</threat_model>

<verification>
1. `bin/rails test test/models/discipline_test.rb -x` exits 0.
2. `bin/rails test test/system/tournament_parameter_verification_test.rb` exits 0.
3. `bundle exec standardrb app/models/discipline.rb app/controllers/tournaments_controller.rb test/models/discipline_test.rb` exits 0.
4. `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` exits 0.
5. `ruby -c app/controllers/tournaments_controller.rb` exits 0 (parse check — catches dynamic-constant-assignment errors).
6. `grep -c "<script" app/views/tournaments/tournament_monitor.html.erb` returns `0`.
7. All acceptance criteria greps pass.
8. Manual UAT (user runs in carambus_bcw): open a tournament ready to start, change balls_goal to 99999 → click Start → verification modal shows the offending value → click Confirm → tournament starts. Retry with balls_goal=100 → no modal → tournament starts directly.
</verification>

<success_criteria>
- UI-07: ✅ `Discipline#parameter_ranges` exists with 8 pre-filled discipline mappings + nil-safe fallback; `TournamentsController#start` runs a server-side range check before `start_tournament!` using a CLASS-LEVEL `UI_07_FIELDS` constant (not a method-body constant); the shared modal from plan 05 surfaces the offending values via its `auto_open` and `hidden_override_name` Stimulus values — NO inline `<script>` added; 4 Minitest unit tests + 4 Capybara system tests (robust name-based selectors) cover the feature
</success_criteria>

<output>
After completion, create `.planning/phases/36B-ui-cleanup-kleine-features/36B-06-SUMMARY.md` listing: Discipline model changes (new constant + method), TournamentsController#start modifications (class-level constant + two private helpers), tournament_monitor.html.erb additions (hidden field + conditional second render of shared/confirmation_modal, NO inline script), 4 unit tests, 4 system tests using name-based selectors, explicit confirmation that no i18n YAML keys were touched (deferred via `default:` fallbacks), and confirmation that the file has zero `<script>` tags.
</output>
</content>
</invoke>