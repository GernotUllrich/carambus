# frozen_string_literal: true

require "application_system_test_case"

# Phase 38.7 Plan 08 — End-to-end tiebreak flow tests (D-15.3).
#
# Verifies the full tiebreak chain end-to-end:
#   Discipline.data['tiebreak_on_draw']  (Plan 01 seed/fixture)
#   → Game.derive_tiebreak_required + bake at start_game (Plan 04)
#   → ResultRecorder.tiebreak_pick_pending? + marker switch (Plan 05)
#   → AASM :acknowledge_result guard (Plan 05 D-08, defense-in-depth)
#   → modal radio fieldset render (Plan 06 D-07)
#   → reflex confirm_result allowlist + persistence (Plan 06 D-08, T-38.7-06-01)
#   → ba_results['TiebreakWinner'] derivation (Plan 05 D-08)
#   → PartiesHelper#tiebreak_indicator suffix (Plan 07 D-12; unit-tested elsewhere)
#
# Convention: same as test/system/bk2_scoreboard_test.rb (38.4-07 / 38.5-06):
# direct data setup over `tm.update!(data: ...)` + service-level dispatch over
# `evaluate_result` rather than full `start_game` invocation. This avoids the
# Tournament + TournamentMonitor + TournamentPlan fixture chain (which would
# pull in a large, brittle fixture graph) and exercises the same code paths
# that the production runtime uses.
#
# Reflex coverage: Plan 06 ships 5 functional unit tests in
# test/reflexes/game_protocol_reflex_test.rb. Here we drive the reflex via
# the same .allocate + define_singleton_method stub strategy when we need
# to exercise the confirm_result code path inside a system test (the
# StimulusReflex WebSocket roundtrip is async-only, so DOM-clicking submit
# in headless Capybara/Selenium would not produce a deterministic result).
#
# Coverage matrix:
#   TR-A   — Karambol-Liga tied + tiebreak_required → modal opens + radio fieldset
#            renders + valid pick persists + game.data['tiebreak_winner'] set
#   TR-B   — BK-2 Nachstoss-Ballziel-Parität → Plan 02 D-02 fix fires (set closes
#            even though both at goal with innings asymmetry) + modal opens + pick
#            persists + ba_results['TiebreakWinner'] derived
#   TR-Ctl — Karambol match WITHOUT tiebreak_required: legacy modal shows confirm_result
#            marker (NOT tiebreak_winner_choice) → no radio fieldset visible
#   TR-Sec — Forged-submit probe (T-38.7-06-01): bypassing the radio (invalid value)
#            does NOT advance state, modal stays open, server-side guard verified
#
# Trigger-class coverage from CONTEXT.md D-01:
#   TR-A (innings parity Karambol)         → tests #1 + #3 (control)
#   TR-B (BK-2 Nachstoss-parity)           → test #2
#   TR-C (generic ball parity)             → exercised implicitly via test #1 path
#   TR-D (Snooker/Pool simple-set parity)  → unit-tested in Plan 05 (T1-T9 in
#                                            result_recorder_test.rb cover the
#                                            simple-set branch); out of system-test
#                                            scope here.

class TiebreakTest < ApplicationSystemTestCase
  setup do
    @tm = table_monitors(:one)
    @game_created_by_test = false
  end

  teardown do
    if @game_created_by_test && @game&.persisted?
      @tm.update_columns(game_id: nil, state: "new", panel_state: "pointer_mode",
        current_element: "pointer_mode")
      @tm.update!(data: {})
      @game.destroy
    end
  end

  # ---------------------------------------------------------------------------
  # TR-A — Karambol-Liga tied result triggers tiebreak modal end-to-end.
  # ---------------------------------------------------------------------------

  test "TR-A Karambol-Liga: tied result + tiebreak_required → modal opens with radio fieldset and persists operator pick" do
    # Set up a Game with tiebreak_required baked (Plan 04 contract).
    @game = Game.create!(data: {"tiebreak_required" => true},
      group_no: 1, seqno: 1, table_no: 1)
    @game_created_by_test = true

    # Tied karambol match: both at result=80 in 30 innings, balls_goal=80,
    # innings_goal=30, allow_follow_up=false → end_of_set? returns true.
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "playerb" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "innings_goal" => 30,
        "allow_follow_up" => false,
        "current_kickoff_player" => "playera",
        "current_inning" => {"active_player" => "playera"}
      }
    )
    @tm.update_columns(game_id: @game.id, state: "playing")
    @tm.reload

    # Sanity: tied + tiebreak_required (Plan 05 D-08 predicate).
    assert @tm.tiebreak_pending_block?,
      "TR-A precondition: tiebreak_pending_block? must hold (tiebreak_required + tied + no winner pick)"

    # Drive the marker switch via evaluate_result (Plan 05 D-03).
    @tm.evaluate_result
    @tm.reload

    assert_equal "protocol_final", @tm.panel_state,
      "TR-A: evaluate_result must transition panel_state to protocol_final"
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "TR-A (Plan 05 D-03): tiebreak_pick_pending? must switch marker to tiebreak_winner_choice"

    # Visit the table_monitor page; assert the radio fieldset renders.
    visit table_monitor_path(@tm)

    assert_selector "form#tiebreak-form-#{@tm.id}", wait: 5, text: /Stechen|Tiebreak/i
    assert_selector "input[type=radio][name='tiebreak_winner'][value='playera']", visible: :all
    assert_selector "input[type=radio][name='tiebreak_winner'][value='playerb']", visible: :all
    assert_selector "button[type=submit][form='tiebreak-form-#{@tm.id}']", text: /bestätigen|Confirm/i

    # Drive the reflex to persist the operator pick (StimulusReflex WebSocket
    # roundtrip is non-deterministic in headless Selenium; the unit tests in
    # game_protocol_reflex_test.rb T1-T5 cover the reflex contract). Here we
    # invoke the same code path the click-submit would invoke server-side.
    reflex = GameProtocolReflex.allocate
    reflex.instance_variable_set(:@table_monitor, @tm)
    reflex.define_singleton_method(:send_modal_update) { |_html| nil }
    reflex.define_singleton_method(:morph) { |_target| nil }
    reflex.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
    reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playera")
    }
    @tm.define_singleton_method(:evaluate_result) { nil }

    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { reflex.confirm_result }
    end

    @game.reload
    assert_equal "playera", @game.data["tiebreak_winner"],
      "TR-A: valid pick must persist to game.data['tiebreak_winner']"
  end

  # ---------------------------------------------------------------------------
  # TR-B — BK-2 Nachstoss-Ballziel-Parität triggers Plan 02 D-02 fix + tiebreak.
  # ---------------------------------------------------------------------------

  test "TR-B BK-2: Nachstoss reaches balls_goal in his Nachstoss-Aufnahme triggers D-02 close + tiebreak modal" do
    # BK-2 with tiebreak_required (Plan 04 baked from Plan 01 Discipline default).
    @game = Game.create!(data: {"tiebreak_required" => true},
      group_no: 1, seqno: 1, table_no: 1)
    @game_created_by_test = true

    # Anstoss=playera reached balls_goal=70 in inning 5; Nachstoss=playerb reached
    # balls_goal=70 in his single Nachstoss-Aufnahme (inning 6). This is the exact
    # scenario Plan 02 D-02 fixes: anstoss_at_goal && nachstoss_finished_followup
    # (innings asymmetry of exactly +1 with anstoss at goal).
    @tm.update!(
      data: {
        "free_game_form" => "bk_2",
        "playera" => {"discipline" => "BK-2", "result" => 70, "innings" => 5,
                      "balls_goal" => 70, "innings_redo_list" => [0]},
        "playerb" => {"discipline" => "BK-2", "result" => 70, "innings" => 6,
                      "balls_goal" => 70, "innings_redo_list" => [0]},
        "current_kickoff_player" => "playera",
        "allow_follow_up" => true,
        "current_inning" => {"active_player" => "playerb"}
      }
    )
    @tm.update_columns(game_id: @game.id, state: "playing")
    @tm.reload

    # Sanity: end_of_set? must fire via Plan 02 D-02 fix branch (not the legacy
    # branch — innings 5 vs 6 is NOT parity, so legacy branch is silent).
    assert @tm.end_of_set?,
      "TR-B (Plan 02 D-02): end_of_set? must fire for Anstoss-at-goal + Nachstoss-finished-followup case"
    assert @tm.tiebreak_pending_block?,
      "TR-B precondition: tiebreak_pending_block? must hold (tied scores + tiebreak_required)"

    # Drive evaluate_result → marker switch.
    @tm.evaluate_result
    @tm.reload

    assert_equal "protocol_final", @tm.panel_state,
      "TR-B: evaluate_result must transition panel_state to protocol_final"
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "TR-B (Plan 05 D-03): marker must switch to tiebreak_winner_choice"

    visit table_monitor_path(@tm)

    assert_selector "form#tiebreak-form-#{@tm.id}", wait: 5
    assert_selector "input[type=radio][name='tiebreak_winner'][value='playerb']", visible: :all

    # Drive the reflex with playerb pick.
    reflex = GameProtocolReflex.allocate
    reflex.instance_variable_set(:@table_monitor, @tm)
    reflex.define_singleton_method(:send_modal_update) { |_html| nil }
    reflex.define_singleton_method(:morph) { |_target| nil }
    reflex.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
    reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerb")
    }
    @tm.define_singleton_method(:evaluate_result) { nil }

    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { reflex.confirm_result }
    end

    @game.reload
    assert_equal "playerb", @game.data["tiebreak_winner"],
      "TR-B: valid playerb pick must persist to game.data['tiebreak_winner']"
  end

  # ---------------------------------------------------------------------------
  # TR-Ctl — Control: Karambol WITHOUT tiebreak_required → legacy modal.
  # Regression guard: legacy non-tiebreak path must continue to use the
  # confirm_result marker (NOT tiebreak_winner_choice) and the modal must NOT
  # show the radio fieldset.
  # ---------------------------------------------------------------------------

  test "TR-Ctl Karambol without tiebreak_required: legacy modal renders WITHOUT radio fieldset (regression guard)" do
    # Game with tiebreak_required absent / false (no Plan 01 seed, no Tournament
    # override) → tiebreak_required key is absent / false in game.data.
    @game = Game.create!(data: {"tiebreak_required" => false},
      group_no: 1, seqno: 1, table_no: 1)
    @game_created_by_test = true

    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "playerb" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "innings_goal" => 30,
        "allow_follow_up" => false,
        "current_kickoff_player" => "playera",
        "current_inning" => {"active_player" => "playera"}
      }
    )
    @tm.update_columns(game_id: @game.id, state: "playing")
    @tm.reload

    refute @tm.tiebreak_pending_block?,
      "TR-Ctl precondition: pending-block predicate must be false when tiebreak_required is false"

    @tm.evaluate_result
    @tm.reload

    assert_equal "protocol_final", @tm.panel_state,
      "TR-Ctl: evaluate_result still transitions to protocol_final on tied result (legacy)"
    assert_equal "confirm_result", @tm.current_element,
      "TR-Ctl regression: tiebreak_required=false → legacy confirm_result marker (NOT tiebreak_winner_choice)"

    visit table_monitor_path(@tm)

    # Modal must render but WITHOUT the tiebreak fieldset.
    assert_selector "#game-protocol-modal", wait: 5
    # TR-Ctl: legacy modal must NOT render the tiebreak form/fieldset.
    assert_no_selector "form#tiebreak-form-#{@tm.id}"
    # TR-Ctl: legacy modal must NOT render any tiebreak_winner radio inputs.
    assert_no_selector "input[type=radio][name='tiebreak_winner']"
    # The legacy confirm-result button must still be present (text 'Ergebnis bestätigen').
    assert_selector "button", text: /Ergebnis bestätigen/i
  end

  # ---------------------------------------------------------------------------
  # TR-Sec — Security probe (T-38.7-06-01): forged submit without valid pick.
  # The form's HTML5 `required` attribute is the UX layer; the reflex's
  # allowlist guard is the actual security boundary. We exercise the BYPASS
  # case (an invalid `tiebreak_winner` value, simulating a forged form submit
  # that bypasses HTML5 validation) and verify state did NOT advance.
  # ---------------------------------------------------------------------------

  test "TR-Sec forged-submit (T-38.7-06-01): invalid tiebreak_winner value is rejected server-side, modal stays open" do
    @game = Game.create!(data: {"tiebreak_required" => true},
      group_no: 1, seqno: 1, table_no: 1)
    @game_created_by_test = true

    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "playerb" => {"discipline" => "Dreiband", "result" => 80, "innings" => 30,
                      "balls_goal" => 80, "innings_redo_list" => [0]},
        "innings_goal" => 30,
        "allow_follow_up" => false,
        "current_kickoff_player" => "playera",
        "current_inning" => {"active_player" => "playera"}
      }
    )
    @tm.update_columns(game_id: @game.id, state: "playing")
    @tm.reload

    @tm.evaluate_result
    @tm.reload
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "TR-Sec precondition: marker must be tiebreak_winner_choice"

    # Visit the page so the modal renders (browser side proves the radios are
    # `required`; we check the attribute as the UX-layer artifact).
    visit table_monitor_path(@tm)
    # TR-Sec: HTML5 `required` attribute must be present on both radios (UX layer).
    assert_selector "input[type=radio][name='tiebreak_winner'][required]", visible: :all

    # Now simulate a forged submit: the StimulusReflex roundtrip with an invalid
    # `tiebreak_winner` value (NOT in %w[playera playerb]) must be rejected by
    # the reflex's allowlist guard (T-38.7-06-01 mitigation).
    reflex = GameProtocolReflex.allocate
    reflex.instance_variable_set(:@table_monitor, @tm)
    reflex.define_singleton_method(:send_modal_update) { |_html| nil }
    reflex.define_singleton_method(:morph) { |_target| nil }
    reflex.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
    reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerc") # FORGED — not in allowlist
    }
    # If the reflex incorrectly advances state, evaluate_result would fire and
    # raise here. We assert that path is NOT taken.
    @tm.define_singleton_method(:evaluate_result) {
      raise "TR-Sec FAILURE: evaluate_result must NOT be invoked when tiebreak_winner is forged"
    }
    assert_nothing_raised { reflex.confirm_result }

    # Verify state did NOT advance: game.data has no winner; current_element
    # still points at tiebreak_winner_choice; modal is still open.
    @game.reload
    @tm.reload
    assert_nil @game.data["tiebreak_winner"],
      "TR-Sec (T-38.7-06-01): forged tiebreak_winner='playerc' must NOT persist to game.data"
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "TR-Sec: state must NOT advance after forged submit; marker still tiebreak_winner_choice"
    assert_equal "protocol_final", @tm.panel_state,
      "TR-Sec: panel_state must remain protocol_final (modal still open)"

    # Also assert the EMPTY-pick variant is rejected (alternative bypass path).
    reflex2 = GameProtocolReflex.allocate
    reflex2.instance_variable_set(:@table_monitor, @tm)
    reflex2.define_singleton_method(:send_modal_update) { |_html| nil }
    reflex2.define_singleton_method(:morph) { |_target| nil }
    reflex2.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
    reflex2.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    @tm.define_singleton_method(:evaluate_result) {
      raise "TR-Sec FAILURE: evaluate_result must NOT be invoked when tiebreak_winner is missing"
    }
    assert_nothing_raised { reflex2.confirm_result }

    @game.reload
    assert_nil @game.data["tiebreak_winner"],
      "TR-Sec (T-38.7-06-01): empty tiebreak_winner submit must NOT persist to game.data"
  end
end
