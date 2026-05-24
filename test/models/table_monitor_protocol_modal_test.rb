# frozen_string_literal: true

require "test_helper"

# Regression: protocol_modal_should_be_open? muss bei state==set_over IMMER true sein,
# unabhaengig vom panel_state. Sonst rendert _player_score_panel.html.erb am Set-Ende das
# ALTE innings_list-Panel statt des ProtokollEditors. Diverse Pfade hinterlassen beim Set-Ende
# einen abweichenden panel_state ("inputs"/"pointer_mode"/...), u.a. der Karambol-Eingabe-Modus
# und App-/Bridge-Spiele (Phase 17). Beobachtet live: TM #50000002 state=set_over, panel_state="inputs".
class TableMonitorProtocolModalTest < ActiveSupport::TestCase
  setup do
    @tm = TableMonitor.create!(state: "new", data: {})
  end

  test "set_over + panel_state 'inputs' -> Protokoll-Modal offen (der Live-Bug)" do
    @tm.update_columns(state: "set_over", panel_state: "inputs", current_element: "add_10")
    assert @tm.set_over?
    assert @tm.protocol_modal_should_be_open?,
      "Bei set_over muss der ProtokollEditor erscheinen, nicht das alte innings_list-Panel"
  end

  test "set_over + panel_state 'pointer_mode' -> Protokoll-Modal offen" do
    @tm.update_columns(state: "set_over", panel_state: "pointer_mode")
    assert @tm.protocol_modal_should_be_open?
  end

  test "protocol_final ist weiterhin offen (unveraendert)" do
    @tm.update_columns(state: "playing", panel_state: "protocol_final")
    assert @tm.protocol_modal_should_be_open?
  end

  test "NICHT set_over + panel_state 'inputs' -> Modal bleibt zu (Normalfluss unveraendert)" do
    @tm.update_columns(state: "playing", panel_state: "inputs")
    refute @tm.set_over?
    refute @tm.protocol_modal_should_be_open?,
      "Im laufenden Spiel (Eingabe-Modus) darf das Protokoll-Modal NICHT erzwungen werden"
  end
end
