# frozen_string_literal: true

require "test_helper"

# Regression: Im AASM-Zustand set_over MUSS panel_state "protocol_final" sein, damit das
# Scoreboard DIREKT den ProtokollEditor (final-mode) zeigt statt des seltenen "...OK?"/alten
# innings_list-Umwegs. Diverse Pfade hinterlassen beim Set-Ende einen abweichenden panel_state
# ("inputs" aus dem Karambol-Eingabe-Modus, "pointer_mode" aus key_a/key_b, App-/Bridge-Spiele).
# Die before_save-Invariante enforce_protocol_final_panel_at_set_over fixiert das zentral.
# Live beobachtet: TM #50000002 state=set_over, panel_state="inputs" -> altes Panel + "Fertig"-Falle.
class TableMonitorProtocolModalTest < ActiveSupport::TestCase
  setup do
    @tm = TableMonitor.create!(state: "new", data: {})
  end

  test "set_over + panel_state 'inputs' wird beim save auf 'protocol_final' fixiert (der Live-Bug)" do
    @tm.update!(state: "set_over", panel_state: "inputs", current_element: "add_10")
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state,
      "Im set_over muss panel_state protocol_final sein (ProtokollEditor final-mode, kein altes Panel)"
    assert @tm.protocol_modal_should_be_open?, "ProtokollEditor muss offen sein"
  end

  test "set_over + 'pointer_mode' (key_a/key_b-Pfad) wird ebenfalls fixiert" do
    @tm.update!(state: "set_over", panel_state: "pointer_mode")
    assert_equal "protocol_final", @tm.reload.panel_state
  end

  test "Tiebreak: current_element bleibt erhalten (nur panel_state wird fixiert)" do
    @tm.update!(state: "set_over", panel_state: "inputs", current_element: "tiebreak_winner_choice")
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "current_element darf NICHT ueberschrieben werden (Tiebreak-Auswahl)"
  end

  test "NICHT set_over: panel_state bleibt unveraendert (Normalfluss)" do
    @tm.update!(state: "playing", panel_state: "inputs")
    @tm.reload
    assert_equal "inputs", @tm.panel_state, "Im laufenden Spiel keine Fixierung"
    refute @tm.protocol_modal_should_be_open?, "Im laufenden Spiel ist das Protokoll-Modal zu"
  end

  test "set_over + bereits protocol_final bleibt unveraendert" do
    @tm.update!(state: "set_over", panel_state: "protocol_final", current_element: "confirm_result")
    @tm.reload
    assert_equal "protocol_final", @tm.panel_state
    assert_equal "confirm_result", @tm.current_element
  end
end
