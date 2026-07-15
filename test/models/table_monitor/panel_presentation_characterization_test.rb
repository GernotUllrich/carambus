# frozen_string_literal: true

require "test_helper"

# Characterization (Phase 54) — pins the IST behaviour of the read-only
# presentation/view-data cluster of TableMonitor (state_display, render_*,
# the *_modal_should_be_open? predicates, get_progress_bar_status) BEFORE it is
# extracted into TableMonitor::PanelPresenter.
#
# Scope note: these methods are read-only (no save!/AASM mutation). We pin the
# model-level orchestration (state/panel_state/timer reads, delegation to
# score_engine, rescue contract, I18n key selection) — NOT the score_engine
# rendering internals (covered by score_engine_test.rb).
class TableMonitor
  class PanelPresentationCharacterizationTest < ActiveSupport::TestCase
    include TableMonitorCharacterizationHelper

    # ---- *_modal_should_be_open? : AASM-state based -----------------------

    test "characterizes: warmup_modal open in warmup/warmup_a/warmup_b, closed in playing" do
      assert build_table_monitor(state: "warmup").warmup_modal_should_be_open?
      assert build_table_monitor(state: "warmup_a").warmup_modal_should_be_open?
      assert build_table_monitor(state: "warmup_b").warmup_modal_should_be_open?
      refute build_table_monitor(state: "playing").warmup_modal_should_be_open?
    end

    test "characterizes: shootout_modal open in match_shootout, closed in playing" do
      assert build_table_monitor(state: "match_shootout").shootout_modal_should_be_open?
      refute build_table_monitor(state: "playing").shootout_modal_should_be_open?
    end

    # ---- *_modal_should_be_open? : panel_state / nnn based ----------------

    test "characterizes: numbers_modal open via panel_state numbers OR nnn present" do
      tm = build_table_monitor
      tm.panel_state = "numbers"
      assert tm.numbers_modal_should_be_open?

      tm2 = build_table_monitor
      tm2.panel_state = "pointer_mode"
      tm2.nnn = 7
      assert tm2.numbers_modal_should_be_open?

      tm3 = build_table_monitor # default panel_state "pointer_mode", nnn nil
      refute tm3.numbers_modal_should_be_open?
    end

    test "characterizes: protocol_modal open for protocol/protocol_edit/protocol_final" do
      %w[protocol protocol_edit protocol_final].each do |ps|
        tm = build_table_monitor
        tm.panel_state = ps
        assert tm.protocol_modal_should_be_open?, "expected open for panel_state=#{ps}"
      end
      tm = build_table_monitor
      tm.panel_state = "pointer_mode"
      refute tm.protocol_modal_should_be_open?
    end

    test "characterizes: foul_modal open only for panel_state foul" do
      tm = build_table_monitor
      tm.panel_state = "foul"
      assert tm.foul_modal_should_be_open?
      tm.panel_state = "pointer_mode"
      refute tm.foul_modal_should_be_open?
    end

    test "characterizes: snooker_inning_edit_modal open only for panel_state snooker_inning_edit" do
      tm = build_table_monitor
      tm.panel_state = "snooker_inning_edit"
      assert tm.snooker_inning_edit_modal_should_be_open?
      tm.panel_state = "pointer_mode"
      refute tm.snooker_inning_edit_modal_should_be_open?
    end

    test "characterizes: final_protocol_modal open only for panel_state protocol_final" do
      tm = build_table_monitor
      tm.panel_state = "protocol_final"
      assert tm.final_protocol_modal_should_be_open?
      tm.panel_state = "protocol"
      refute tm.final_protocol_modal_should_be_open?
    end

    # ---- render_innings_list / render_last_innings : delegation + rescue --
    # We pin the model orchestration (delegates to score_engine, rescue
    # re-raises outside production). The rendering output itself is score_engine's
    # concern (score_engine_test.rb). Rescue branches of the predicates above are
    # NOT triggerable without stubbing AASM/attr readers → left verbatim, untested.

    test "characterizes: render_innings_list re-raises when score_engine raises" do
      tm = build_table_monitor
      with_raising_score_engine(tm) do |t|
        assert_raises(StandardError) { t.render_innings_list("playera") }
      end
    end

    test "characterizes: render_last_innings re-raises when score_engine raises" do
      tm = build_table_monitor
      with_raising_score_engine(tm) do |t|
        assert_raises(StandardError) { t.render_last_innings(60, "playera") }
      end
    end

    # ---- state_display : I18n key selection by state ----------------------

    test "characterizes: state_display for non-set_over state uses status.<state>" do
      tm = build_table_monitor(state: "playing")
      assert_equal I18n.t("table_monitor.status.playing"), tm.state_display(:de)
    end

    test "characterizes: state_display for set_over uses set_over key with final_set_score (sets_to_play<=1)" do
      tm = build_table_monitor(state: "set_over")
      expected = I18n.t("table_monitor.status.set_over",
        game_or_set_finished: I18n.t("table_monitor.final_set_score"),
        wait_check: I18n.t("table_monitor.status.wait_check"))
      assert_equal expected, tm.state_display(:de)
    end

    test "characterizes: state_display for set_over uses set_finished when sets_to_play>1" do
      tm = build_table_monitor(state: "set_over", sets_to_play: 2)
      expected = I18n.t("table_monitor.status.set_over",
        game_or_set_finished: I18n.t("table_monitor.set_finished"),
        wait_check: I18n.t("table_monitor.status.wait_check"))
      assert_equal expected, tm.state_display(:de)
    end

    # ---- get_progress_bar_status : structure / nil-timer path -------------
    # Time.now-dependent exact values are intentionally NOT asserted.

    test "characterizes: get_progress_bar_status returns all-zero 7-tuple when no timer set" do
      tm = build_table_monitor
      assert_equal [0, 0, 0, 0, 0, 0, 0], tm.get_progress_bar_status(18)
    end

    test "characterizes: get_progress_bar_status returns a 7-element array with a running timer" do
      tm = build_table_monitor
      tm.active_timer = "10min"
      tm.timer_start_at = Time.now - 60
      tm.timer_finish_at = Time.now + 600
      result = tm.get_progress_bar_status(18)
      assert_instance_of Array, result
      assert_equal 7, result.size
    end
  end
end
