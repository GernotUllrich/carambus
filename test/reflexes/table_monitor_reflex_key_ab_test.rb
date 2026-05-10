# frozen_string_literal: true

require "test_helper"

# Regressions-Tests fuer Bug 260510: TableMonitorReflex#key_a / #key_b
# ueberschreiben "protocol_final" panel_state nicht mehr mit "pointer_mode".
#
# PROBLEM (vor Fix):
#   In key_a und key_b wurde nach terminate_current_inning unconditionally
#     assign_attributes(panel_state: "pointer_mode", current_element: "pointer_mode")
#     save
#   ausgefuehrt — auch wenn evaluate_result (via terminate_current_inning) den
#   AASM-Uebergang zu set_over vollzogen und panel_state="protocol_final" gesetzt
#   hatte. Das Ergebnis-Modal wurde nie angezeigt, finish_match! nie ausgeloest,
#   CC-Upload nie ausgefuehrt.
#
# FIX:
#   Guard: `unless @table_monitor.set_over? || @table_monitor.final_set_score? || @table_monitor.final_match_score?`
#   vor dem assign_attributes-Block in beiden Branches (key_a + key_b).
#
# TESTMETHODIK:
#   TableMonitorReflex ist eine StimulusReflex-Action (WebSocket). Wir instanziieren
#   sie per .allocate (wie GameProtocolReflexTest), stubben element + morph, und
#   stubben terminate_current_inning so, dass es end_of_set! aufruft (simuliert
#   den echten Produktions-Pfad: letzter Ball → evaluate_result → end_of_set! →
#   set_game_over → panel_state="protocol_final").
#
#   Die Tests sind TRUE RED/GREEN:
#   - MIT Fix (guard vorhanden): panel_state bleibt "protocol_final" → GRUEN
#   - OHNE Fix (guard entfernt): save ueberschreibt mit "pointer_mode" → ROT
#     (expected panel_state to be "protocol_final", got "pointer_mode")
class TableMonitorReflexKeyAbTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Hilfsmethoden
  # ---------------------------------------------------------------------------

  # Minimale data-Struktur, damit key_a den terminate_current_inning-Pfad erreicht:
  #   - kein "pool"-Formular (kein add_n_balls-Ast)
  #   - current_inning.active_player == "playera" → when "playera" Branch
  #   - current_left_player == "playerb" → Bedingung fuer terminate_current_inning
  def minimal_karambol_data
    {
      "free_game_form" => "karambol",
      "current_inning" => {"active_player" => "playera"},
      "current_left_player" => "playerb",
      "playera" => {
        "result" => 0, "innings" => 1, "balls_goal" => "1",
        "fouls_1" => 0, "discipline" => "Freie Partie",
        "innings_redo_list" => [0], "innings_list" => []
      },
      "playerb" => {
        "result" => 0, "innings" => 1, "balls_goal" => "1",
        "fouls_1" => 0, "discipline" => "Freie Partie",
        "innings_redo_list" => [0], "innings_list" => []
      }
    }
  end

  # key_b-Variante: active_player == "playerb", current_left_player == "playera"
  def minimal_karambol_data_playerb
    minimal_karambol_data.merge(
      "current_inning" => {"active_player" => "playerb"},
      "current_left_player" => "playera"
    )
  end

  # Erzeuge einen frischen TableMonitorReflex via allocate (kein WebSocket-Kontext
  # noetig, exakt wie GameProtocolReflexTest / Kommentar dazu dort).
  def build_reflex(tm)
    reflex = TableMonitorReflex.allocate

    # element.andand.dataset[:id] → liefert die TM-ID
    fake_dataset = {id: tm.id}
    fake_element = Object.new
    fake_element.define_singleton_method(:dataset) { fake_dataset }
    fake_element.define_singleton_method(:andand) { fake_element }

    reflex.define_singleton_method(:element) { fake_element }
    reflex.define_singleton_method(:morph) { |_target| nil }

    reflex
  end

  # ---------------------------------------------------------------------------
  # K1 — key_a / playera-Pfad: panel_state "protocol_final" bleibt erhalten
  #
  # Simuliert: TM ist playing, key_a wird aufgerufen, terminate_current_inning
  # loest end_of_set! aus (set_over → panel_state="protocol_final"), der Fix-Guard
  # verhindert den unconditional pointer_mode-Overwrite.
  # ---------------------------------------------------------------------------
  test "K1 (key_a / playera): panel_state 'protocol_final' wird nach end_of_set! NICHT ueberschrieben" do
    tm = TableMonitor.create!(
      state: "playing",
      data: minimal_karambol_data,
      panel_state: "pointer_mode",
      current_element: "pointer_mode"
    )
    tm.reload

    reflex = build_reflex(tm)

    # Stub terminate_current_inning: loest end_of_set! aus (= exakter Produktionspfad
    # wenn letzter Ball gespielt wird). end_of_set! → set_game_over → panel_state="protocol_final".
    # Danach ist tm.set_over? == true.
    tm.define_singleton_method(:terminate_current_inning) do |_player = nil|
      end_of_set!
    end

    # Stub reset_timer! — benoetigt echten Job-Context
    tm.define_singleton_method(:reset_timer!) { nil }

    # Stub do_play — benoetigt tournament_monitor (hat keinen in diesem Test)
    tm.define_singleton_method(:do_play) { nil }

    # Stub suppress_broadcast= (cattr_accessor wirft keinen Fehler, aber sicher ist sicher)
    tm.define_singleton_method(:suppress_broadcast=) { |_v| nil }

    # Reflex neu-fetcht @table_monitor via find — stub find so, dass unser gestubbtes
    # Objekt zurueckgegeben wird (inklusive der definierten singleton-Methoden).
    TableMonitor.stub(:find, tm) do
      assert_nothing_raised { reflex.key_a }
    end

    tm.reload
    assert_equal "protocol_final", tm.panel_state,
      "FIX-REGRESSION: key_a darf panel_state='protocol_final' nicht mit 'pointer_mode' " \
      "ueberschreiben (Bug 260510). Ohne Guard erhaelt man 'pointer_mode'."
    assert_equal "confirm_result", tm.current_element,
      "current_element muss 'confirm_result' bleiben"
    assert tm.set_over?,
      "TM muss nach dem Klick im set_over-Zustand sein"
  end

  # ---------------------------------------------------------------------------
  # K2 — key_b / playerb-Pfad: panel_state "protocol_final" bleibt erhalten
  #
  # Analog K1, aber fuer key_b (playerb-Branch). Prueft dass der identische
  # Guard in key_b ebenfalls wirkt.
  # ---------------------------------------------------------------------------
  test "K2 (key_b / playerb): panel_state 'protocol_final' wird nach end_of_set! NICHT ueberschrieben" do
    tm = TableMonitor.create!(
      state: "playing",
      data: minimal_karambol_data_playerb,
      panel_state: "pointer_mode",
      current_element: "pointer_mode"
    )
    tm.reload

    reflex = build_reflex(tm)

    tm.define_singleton_method(:terminate_current_inning) do |_player = nil|
      end_of_set!
    end
    tm.define_singleton_method(:reset_timer!) { nil }
    tm.define_singleton_method(:do_play) { nil }
    tm.define_singleton_method(:suppress_broadcast=) { |_v| nil }

    TableMonitor.stub(:find, tm) do
      assert_nothing_raised { reflex.key_b }
    end

    tm.reload
    assert_equal "protocol_final", tm.panel_state,
      "FIX-REGRESSION: key_b darf panel_state='protocol_final' nicht mit 'pointer_mode' " \
      "ueberschreiben (Bug 260510). Ohne Guard erhaelt man 'pointer_mode'."
    assert_equal "confirm_result", tm.current_element
    assert tm.set_over?
  end

  # ---------------------------------------------------------------------------
  # K3 — key_a / final_set_score-Zustand: Guard greift auch fuer final_set_score?
  #
  # Seltener Pfad: TM landet nach acknowledge_result! in final_set_score statt
  # set_over. Guard prueft auch final_set_score? und final_match_score?.
  # ---------------------------------------------------------------------------
  test "K3 (key_a / final_set_score): Guard verhindert Overwrite auch im final_set_score-Zustand" do
    tm = TableMonitor.create!(
      state: "playing",
      data: minimal_karambol_data,
      panel_state: "pointer_mode",
      current_element: "pointer_mode"
    )
    tm.reload

    reflex = build_reflex(tm)

    # Stub: terminate_current_inning springt direkt in final_set_score (statt set_over)
    tm.define_singleton_method(:terminate_current_inning) do |_player = nil|
      # Direkt in final_set_score schreiben (update_columns umgeht AASM-Validierung)
      update_columns(state: "final_set_score", panel_state: "protocol_final", current_element: "confirm_result")
      reload
    end
    tm.define_singleton_method(:reset_timer!) { nil }
    tm.define_singleton_method(:do_play) { nil }
    tm.define_singleton_method(:suppress_broadcast=) { |_v| nil }

    TableMonitor.stub(:find, tm) do
      assert_nothing_raised { reflex.key_a }
    end

    tm.reload
    assert_equal "protocol_final", tm.panel_state,
      "FIX-REGRESSION: Guard fuer final_set_score? muss panel_state='protocol_final' schuetzen"
    assert tm.final_set_score?
  end
end
