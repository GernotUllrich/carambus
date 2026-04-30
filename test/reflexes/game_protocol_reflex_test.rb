# frozen_string_literal: true

require "test_helper"

# Phase 38.7 Plan 06 Task 4 (revision) — GameProtocolReflex#confirm_result
# tiebreak-validation functional tests.
#
# Pattern: same as test/reflexes/party_monitor_reflex_test.rb — reflex methods
# are not driven over the WebSocket/StimulusReflex stack. Instead we instantiate
# the reflex class via .allocate (skipping the StimulusReflex base initializer
# that expects a real WebSocket session), set the @table_monitor ivar and a
# synthesized params hash directly, invoke confirm_result, and assert on the
# persisted side-effects: game.data['tiebreak_winner'], @table_monitor state.
#
# Coverage:
#   - T1: invalid tiebreak_winner ('playerc') -> modal stays open, no game.data write
#   - T2: missing tiebreak_winner (empty params) -> modal stays open, no game.data write
#   - T3: valid tiebreak_winner='playera' -> game.data['tiebreak_winner']='playera'
#   - T4: valid tiebreak_winner='playerb' -> game.data['tiebreak_winner']='playerb'
#   - T5: confirm_result on non-tiebreak path (current_element != 'tiebreak_winner_choice')
#         -> no tiebreak_winner read, no game.data write (regression guard)
#
# T1+T2 mitigate T-38.7-06-01 (forged param). T5 is the regression guard for the
# legacy non-tiebreak path. Plan 08 E2E probe still runs as defense-in-depth.
class GameProtocolReflexTest < ActiveSupport::TestCase
  setup do
    @tm = table_monitors(:one)
    @game = Game.create!(data: {"tiebreak_required" => true}, group_no: 1, seqno: 1, table_no: 1)
    # Tied karambol scores so tiebreak_pending_block? would normally hold (defense-in-depth alignment).
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "playerb" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "innings_goal" => 30,
        "allow_follow_up" => false
      }
    )
    @tm.update_columns(
      game_id: @game.id,
      panel_state: "protocol_final",
      current_element: "tiebreak_winner_choice"
    )
    @tm.reload

    @reflex = GameProtocolReflex.allocate
    @reflex.instance_variable_set(:@table_monitor, @tm)
    # Stub the broadcast helpers to avoid touching the real ActionCable / Sidekiq.
    @reflex.define_singleton_method(:send_modal_update) { |_html| nil }
    @reflex.define_singleton_method(:morph) { |_target| nil }
    @reflex.define_singleton_method(:render_protocol_modal) { "<div>modal</div>" }
  end

  test "T1: invalid tiebreak_winner ('playerc') is rejected — game.data not written, state unchanged" do
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerc")
    }
    # evaluate_result must NOT be called when validation fails.
    @tm.define_singleton_method(:evaluate_result) {
      raise "evaluate_result must not be invoked when tiebreak_winner is invalid"
    }
    assert_nothing_raised { @reflex.confirm_result }
    @game.reload
    assert_nil @game.data["tiebreak_winner"], "Invalid tiebreak_winner must not persist"
    assert_equal "tiebreak_winner_choice", @tm.reload.current_element,
      "Modal must stay open (current_element unchanged) on rejection"
  end

  test "T2: missing tiebreak_winner is rejected — game.data not written" do
    @reflex.define_singleton_method(:params) { ActionController::Parameters.new({}) }
    @tm.define_singleton_method(:evaluate_result) {
      raise "evaluate_result must not be invoked when tiebreak_winner is missing"
    }
    assert_nothing_raised { @reflex.confirm_result }
    @game.reload
    assert_nil @game.data["tiebreak_winner"]
    assert_equal "tiebreak_winner_choice", @tm.reload.current_element
  end

  test "T3: valid tiebreak_winner='playera' is persisted to game.data" do
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playera")
    }
    # Stub evaluate_result + Job — they're tested in their own files.
    @tm.define_singleton_method(:evaluate_result) { nil }
    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { @reflex.confirm_result }
    end
    @game.reload
    assert_equal "playera", @game.data["tiebreak_winner"],
      "Valid pick must persist to game.data['tiebreak_winner']"
  end

  test "T4: valid tiebreak_winner='playerb' is persisted to game.data" do
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerb")
    }
    @tm.define_singleton_method(:evaluate_result) { nil }
    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { @reflex.confirm_result }
    end
    @game.reload
    assert_equal "playerb", @game.data["tiebreak_winner"]
  end

  test "T5: non-tiebreak confirm_result does NOT read tiebreak_winner (regression guard)" do
    # Switch the marker to the legacy 'confirm_result' value — the validation branch
    # must NOT fire, even if a forged tiebreak_winner param is present.
    @tm.update_columns(current_element: "confirm_result")
    @tm.reload
    @reflex.define_singleton_method(:params) {
      ActionController::Parameters.new(tiebreak_winner: "playerc") # forged value MUST be ignored
    }
    @tm.define_singleton_method(:evaluate_result) { nil }
    TableMonitorJob.stub :perform_later, ->(_a, _b) {} do
      assert_nothing_raised { @reflex.confirm_result }
    end
    @game.reload
    assert_nil @game.data["tiebreak_winner"],
      "Non-tiebreak path must not touch game.data['tiebreak_winner'], even with forged param"
  end
end
