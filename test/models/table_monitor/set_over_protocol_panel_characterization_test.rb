# frozen_string_literal: true

require "test_helper"

# Characterization + bug fix: the Abschluss ("protocol_final") panel flicker.
#
# Design invariant: while AASM state == "set_over", panel_state MUST be
# "protocol_final" — the scoreboard then shows exactly ONE Abschluss-modal
# (guards against the old "two alternating protocols" bug). That half is enforced
# by the before_save hook and must NOT regress.
#
# The bug: once the result is acknowledged and the state leaves set_over
# (set_over -> final_set_score via ResultRecorder), nothing released panel_state,
# so it stayed "protocol_final". `final_protocol_modal_should_be_open?` (==
# panel_state == "protocol_final") therefore stayed true -> the modal flickered
# back and often needed a second confirm. Fix: make the invariant symmetric —
# release protocol_final on any save where state is no longer set_over.
class TableMonitor
  class SetOverProtocolPanelCharacterizationTest < ActiveSupport::TestCase
    include TableMonitorCharacterizationHelper

    test "characterizes: while in set_over, saving keeps panel_state protocol_final (invariant, KEEP)" do
      tm = build_table_monitor(state: "set_over")
      assert_equal "protocol_final", tm.panel_state, "entering set_over must show the protocol_final modal"

      tm.panel_state = "pointer_mode"
      tm.save!
      assert_equal "protocol_final", tm.panel_state, "invariant must re-assert protocol_final while set_over"
    end

    test "protocol_final is released once state leaves set_over (fixes flicker / confirm-twice)" do
      tm = build_table_monitor(state: "set_over")
      assert_equal "protocol_final", tm.panel_state

      # Acknowledge the result: state advances out of set_over (as ResultRecorder does).
      tm.state = "final_set_score"
      tm.save!
      assert_equal "pointer_mode", tm.panel_state,
        "protocol_final must not leak past set_over — otherwise the Abschluss modal flickers back"
    end

    test "the invariant leaves unrelated panel_states outside set_over untouched" do
      tm = build_table_monitor(state: "playing")
      tm.panel_state = "foul"
      tm.save!
      assert_equal "foul", tm.panel_state, "only protocol_final is synced with set_over; others are untouched"
    end
  end
end
