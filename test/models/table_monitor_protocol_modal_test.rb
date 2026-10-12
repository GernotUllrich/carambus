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

  # ==========================================================================
  # Plan 08-01 (§4.4.3): tiebreak_extension_goal — die Ballzahl, die der Operator
  # im Stechen ansagt. 10 % des Ziels, AUFGERUNDET.
  # ==========================================================================

  test "tiebreak_extension_goal: 10 Prozent des Ziels, glatt aufgehende Faelle" do
    {250 => 25, 200 => 20, 50 => 5}.each do |goal, expected|
      @tm.update!(data: {"playera" => {"balls_goal" => goal}})
      assert_equal expected, @tm.tiebreak_extension_goal("playera"),
        "Ziel #{goal} muss #{expected} ergeben (§4.4.3: 10 %)"
    end
  end

  test "tiebreak_extension_goal: krumme Faelle werden AUFGERUNDET, nicht gerundet" do
    # Der Kern der Regel. Mit `round` statt `ceil` lieferten diese Faelle 4, 2 und 0 —
    # §4.4.3 sagt ausdruecklich "auf eine ganze Zahl aufzurunden".
    {42 => 5, 21 => 3, 1 => 1}.each do |goal, expected|
      @tm.update!(data: {"playera" => {"balls_goal" => goal}})
      assert_equal expected, @tm.tiebreak_extension_goal("playera"),
        "Ziel #{goal} muss auf #{expected} AUFGERUNDET werden, nicht abgerundet"
    end
  end

  test "tiebreak_extension_goal: ohne Ballziel gibt es keine Zahl" do
    # Aufnahmenbegrenzung statt Ballziel — das Modal zeigt dort "∞". Eine 0 waere
    # schlimmer als nichts, weil sie wie eine gueltige Ansage aussieht.
    @tm.update!(data: {"playera" => {"balls_goal" => 0}})
    assert_nil @tm.tiebreak_extension_goal("playera"), "balls_goal 0 darf keine Zahl liefern"

    @tm.update!(data: {"playera" => {}})
    assert_nil @tm.tiebreak_extension_goal("playera"), "fehlendes balls_goal darf keine Zahl liefern"

    @tm.update!(data: {})
    assert_nil @tm.tiebreak_extension_goal("playera"), "fehlende Rolle darf keine Zahl liefern"
  end

  test "tiebreak_extension_goal: bei Vorgabe rechnet jeder Spieler auf seinem EIGENEN Ziel" do
    # Betreiber-Entscheidung 2026-09-04 zum Wortlaut "der vorher zu erreichenden Ballzahl":
    # die Vorgabe bleibt im Stechen erhalten.
    @tm.update!(data: {
      "playera" => {"balls_goal" => 250},
      "playerb" => {"balls_goal" => 42}
    })
    assert_equal 25, @tm.tiebreak_extension_goal("playera")
    assert_equal 5, @tm.tiebreak_extension_goal("playerb"),
      "playerb muss aus SEINEM Ziel 42 rechnen, nicht aus playeras 250"
  end
end
