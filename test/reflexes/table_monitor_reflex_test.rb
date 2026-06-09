# frozen_string_literal: true

require "test_helper"

# Regression: Lost-update auf panel_state in key_a/key_b/foul_*/balls_left.
#
# Bug: Wird der letzte Ball/das Set-Ende per A/B-Taste (oder Foul/balls_left) erreicht,
# transitioniert terminate_current_inning via AASM nach :set_over -> after_enter
# :set_game_over setzt panel_state="protocol_final". Direkt danach setzte der Reflex
# UNBEDINGT panel_state="pointer_mode" -> beim folgenden save wurde protocol_final
# ueberschrieben. Render-Folge (_player_score_panel.html.erb): state==set_over UND
# panel_state != protocol_final -> else-Zweig -> altes render_innings_list-Panel statt
# ProtokollEditor. Fix: das "pointer_mode" wird mit `unless set_over?` geguardet.
#
# Test-Pattern wie game_protocol_reflex_test.rb: Reflex via .allocate (ohne
# StimulusReflex-Websocket-Stack), @table_monitor/element/morph gestubbt,
# TableMonitor.find auf die Test-Instanz gestubbt, set-beendender Pfad via
# terminate_current_inning/foul_one-Stub simuliert.
class TableMonitorReflexTest < ActiveSupport::TestCase
  setup do
    @tm = table_monitors(:one)
    @tm.update!(data: {
      "free_game_form" => "karambol",
      "current_inning" => {"active_player" => "playera"},
      "current_left_player" => "playerb",
      "playera" => {"fouls_1" => 0, "result" => 0, "innings" => 0},
      "playerb" => {"fouls_1" => 0, "result" => 0, "innings" => 0}
    })
    @tm.update_columns(state: "playing", panel_state: "pointer_mode", current_element: "pointer_mode")
    @tm.reload

    # Umgebungs-Praedikate deterministisch halten (keine Warmup/Shootout-Modals, nicht gesperrt).
    @tm.define_singleton_method(:warmup_modal_should_be_open?) { false }
    @tm.define_singleton_method(:shootout_modal_should_be_open?) { false }
    @tm.define_singleton_method(:locked_scoreboard) { false }
    @tm.define_singleton_method(:reset_timer!) { nil }
    @tm.define_singleton_method(:do_play) { nil }

    @reflex = TableMonitorReflex.allocate
    @reflex.define_singleton_method(:morph) { |_target| nil }
    @reflex.define_singleton_method(:element) { OpenStruct.new(dataset: {id: 1}) }
  end

  # Simuliert end_of_set!: AASM nach :set_over + set_game_over (panel_state protocol_final).
  def stub_set_ending!(method_name)
    @tm.define_singleton_method(method_name) do |*_args|
      write_attribute(:state, "set_over")
      assign_attributes(panel_state: "protocol_final", current_element: "confirm_result")
    end
  end

  # Simuliert einen Tastendruck, der das Set NICHT beendet (state bleibt playing).
  def stub_non_ending!(method_name)
    @tm.define_singleton_method(method_name) { |*_args| nil }
  end

  test "key_a am Set-Ende behaelt protocol_final (kein Lost-update auf pointer_mode)" do
    stub_set_ending!(:terminate_current_inning)
    TableMonitor.stub(:find, @tm) { @reflex.key_a }
    @tm.reload
    assert @tm.set_over?, "Voraussetzung: state ist set_over"
    assert_equal "protocol_final", @tm.panel_state,
      "panel_state darf am Set-Ende NICHT auf pointer_mode ueberschrieben werden"
  end

  test "key_b am Set-Ende behaelt protocol_final" do
    # key_b terminiert (Set-Ende) nur, wenn current_left_player != "playera" -> "playerb".
    @tm.update!(data: @tm.data.merge("current_inning" => {"active_player" => "playerb"}, "current_left_player" => "playerb"))
    stub_set_ending!(:terminate_current_inning)
    TableMonitor.stub(:find, @tm) { @reflex.key_b }
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state
  end

  test "key_a OHNE Set-Ende setzt weiterhin pointer_mode (Normalfluss unveraendert)" do
    stub_non_ending!(:terminate_current_inning)
    TableMonitor.stub(:find, @tm) { @reflex.key_a }
    @tm.reload
    refute @tm.set_over?, "Voraussetzung: Set ist NICHT vorbei"
    assert_equal "pointer_mode", @tm.panel_state,
      "Im Normalfluss bleibt das pointer_mode-Verhalten erhalten"
  end

  test "foul_one am Set-Ende behaelt protocol_final" do
    stub_set_ending!(:foul_one)
    TableMonitor.stub(:find, @tm) { @reflex.foul_one }
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state
  end
end
