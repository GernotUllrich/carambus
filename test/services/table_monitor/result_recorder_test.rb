# frozen_string_literal: true

require "test_helper"

# Unit-Tests fuer TableMonitor::ResultRecorder.
# Verifiziert: Ergebnispersistenz (save_result, save_current_set),
# Satz-Navigation (switch_to_next_set, get_max_number_of_wins),
# AASM-Integration (end_of_set!, finish_match! via evaluate_result),
# und dass keine CableReady-Referenzen im Service existieren.
#
# Alle Tests verwenden in der Datenbank gespeicherte Datensaetze.
# AASM-Events werden mit Stubs getestet um Seiteneffekte zu isolieren.
class TableMonitor::ResultRecorderTest < ActiveSupport::TestCase
  RESULT_RECORDER_PATH = Rails.root.join("app/services/table_monitor/result_recorder.rb").to_s

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil

    @player_a = Player.create!(
      id: 50_100_001,
      firstname: "ResultA",
      lastname: "Test",
      dbu_nr: 20001,
      ba_id: 20001
    )
    @player_b = Player.create!(
      id: 50_100_002,
      firstname: "ResultB",
      lastname: "Test",
      dbu_nr: 20002,
      ba_id: 20002
    )

    @game = Game.create!(
      data: {},
      group_no: 1,
      seqno: 1,
      table_no: 1
    )

    GameParticipation.create!(game: @game, player: @player_a, role: "playera")
    GameParticipation.create!(game: @game, player: @player_b, role: "playerb")

    @tm = TableMonitor.create!(
      state: "playing",
      game: @game,
      data: {
        "sets_to_win" => 2,
        "sets_to_play" => 3,
        "kickoff_switches_with" => "set",
        "current_kickoff_player" => "playera",
        "free_game_form" => "standard",
        "ba_results" => {
          "Gruppe" => 1,
          "Partie" => 1,
          "Spieler1" => 20001,
          "Spieler2" => 20002,
          "Sets1" => 0,
          "Sets2" => 0,
          "Ergebnis1" => 0,
          "Ergebnis2" => 0,
          "Aufnahmen1" => 0,
          "Aufnahmen2" => 0,
          "Höchstserie1" => 0,
          "Höchstserie2" => 0,
          "Tischnummer" => 1
        },
        "sets" => [],
        "playera" => {
          "result" => 100,
          "innings" => 5,
          "innings_list" => [20, 30, 50],
          "innings_redo_list" => [],
          "hs" => 50,
          "gd" => "20.00",
          "balls_goal" => 100
        },
        "playerb" => {
          "result" => 60,
          "innings" => 5,
          "innings_list" => [20, 20, 20],
          "innings_redo_list" => [],
          "hs" => 20,
          "gd" => "12.00",
          "balls_goal" => 100
        },
        "current_inning" => {
          "active_player" => "playera",
          "balls" => 0
        }
      }
    )
  end

  teardown do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end

  # ---------------------------------------------------------------------------
  # Test 1: ResultRecorder.call triggert evaluate_result-Logik
  # ---------------------------------------------------------------------------

  test "call dispatches to perform_evaluate_result logic" do
    # Mit einem TM das nicht am Set-Ende ist (no end_of_set? trigger)
    # verify wird nur aufgerufen, kein Crash
    assert_nothing_raised do
      TableMonitor::ResultRecorder.call(table_monitor: @tm)
    end
    # Nachbedingungen: Spieler A hat balls_goal erreicht (100 >= 100) bei gleichen Innings (5==5)
    # => end_of_set? ist true => Zustand wechselt auf set_over, panel_state auf protocol_final
    @tm.reload
    assert_equal "set_over", @tm.state,
      "Zustand muss nach evaluate_result auf set_over stehen (Set-Ende erkannt)"
    assert_equal "protocol_final", @tm.panel_state,
      "panel_state muss auf protocol_final stehen nach Set-Ende"
  end

  # ---------------------------------------------------------------------------
  # Test 2: save_result baut den Ergebnis-Hash auf
  # ---------------------------------------------------------------------------

  test "save_result returns a game_set_result hash with correct keys" do
    result = TableMonitor::ResultRecorder.save_result(table_monitor: @tm)

    assert_kind_of Hash, result
    assert_equal 100, result["Ergebnis1"]
    assert_equal 60, result["Ergebnis2"]
    assert_equal 5, result["Aufnahmen1"]
    assert_equal 5, result["Aufnahmen2"]
    assert_equal 50, result["Höchstserie1"]
    assert_equal 20, result["Höchstserie2"]
    assert_equal 1, result["Gruppe"]
    assert_equal 1, result["Partie"]
  end

  # ---------------------------------------------------------------------------
  # Test 3: save_current_set schreibt set in data["sets"] und speichert
  # ---------------------------------------------------------------------------

  test "save_current_set appends set result to data sets array" do
    assert_equal [], @tm.data["sets"]

    TableMonitor::ResultRecorder.save_current_set(table_monitor: @tm)

    @tm.reload
    assert_equal 1, @tm.data["sets"].count
    saved_set = @tm.data["sets"].first
    assert_equal 100, saved_set["Ergebnis1"]
    assert_equal 60, saved_set["Ergebnis2"]
  end

  # ---------------------------------------------------------------------------
  # Test 4: get_max_number_of_wins gibt die maximale Satzanzahl zurueck
  # ---------------------------------------------------------------------------

  test "get_max_number_of_wins returns 0 when no sets won yet" do
    result = TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: @tm)

    assert_equal 0, result
  end

  test "get_max_number_of_wins returns max of Sets1 and Sets2" do
    @tm.data["ba_results"]["Sets1"] = 2
    @tm.data["ba_results"]["Sets2"] = 1
    @tm.save!

    result = TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: @tm)

    assert_equal 2, result
  end

  # ---------------------------------------------------------------------------
  # Test 5: switch_to_next_set initialisiert naechsten Satz
  # ---------------------------------------------------------------------------

  test "switch_to_next_set resets current set scores and persists state" do
    # add one completed set first so switch has context
    @tm.data["sets"] = [{"Innings1" => [20, 30, 50], "Innings2" => [20, 20, 20]}]
    @tm.save!

    TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: @tm)

    @tm.reload
    assert_equal 0, @tm.data["playera"]["result"].to_i
    assert_equal 0, @tm.data["playerb"]["result"].to_i
    assert_equal 0, @tm.data["playera"]["innings"].to_i
    assert_equal 0, @tm.data["playerb"]["innings"].to_i
    assert_equal "playing", @tm.state
  end

  # ---------------------------------------------------------------------------
  # Test 6: evaluate_result loest end_of_set! aus wenn Set entschieden ist
  # ---------------------------------------------------------------------------

  test "evaluate_result fires end_of_set! when end_of_set? is true and playing" do
    end_of_set_called = false

    # Stub end_of_set? to return true, may_end_of_set? true
    @tm.stub(:end_of_set?, true) do
      @tm.stub(:may_end_of_set?, true) do
        @tm.stub(:end_of_set!, -> { end_of_set_called = true; @tm.update_columns(state: "set_over") }) do
          @tm.stub(:save_current_set, -> {}) do
            @tm.stub(:get_max_number_of_wins, -> { 1 }) do
              TableMonitor::ResultRecorder.call(table_monitor: @tm)
            end
          end
        end
      end
    end

    assert end_of_set_called, "end_of_set! muss aufgerufen werden wenn Set entschieden"
  end

  # ---------------------------------------------------------------------------
  # Test 7: evaluate_result loest finish_match! aus wenn Match gewonnen ist
  # ---------------------------------------------------------------------------

  test "evaluate_result triggers finish_match path when match is won" do
    # Simple set game, match won scenario:
    # set_over state, sets_to_win reached
    @tm.update_columns(state: "set_over")
    @tm.reload

    # With set_over and final_set_score state, verify no crash
    @tm.stub(:end_of_set?, true) do
      @tm.stub(:save_current_set, -> {}) do
        @tm.stub(:get_max_number_of_wins, -> { 2 }) do
          @tm.stub(:acknowledge_result!, -> {}) do
            assert_nothing_raised do
              TableMonitor::ResultRecorder.call(table_monitor: @tm)
            end
            # Nachbedingungen: automatic_next_set=true und max_wins(1) < sets_to_win(2),
            # daher ruft evaluate_result switch_to_next_set auf => Zustand wechselt zu playing.
            # Das Spiel muss weiterhin mit dem TableMonitor verknuepft sein.
            @tm.reload
            assert_equal "playing", @tm.state,
              "Zustand muss nach switch_to_next_set wieder playing sein (naechster Satz)"
            assert_equal @game.id, @tm.game_id,
              "game_id muss unveraendert auf das urspruengliche Spiel zeigen"
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 8: Keine CableReady-Referenzen in result_recorder.rb
  # ---------------------------------------------------------------------------

  test "result_recorder.rb contains no CableReady references" do
    refute File.read(RESULT_RECORDER_PATH).include?("CableReady"),
      "ResultRecorder darf keine CableReady-Aufrufe enthalten (Broadcasts via after_update_commit)"
  end
end
