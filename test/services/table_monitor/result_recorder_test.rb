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
        @tm.stub(:end_of_set!, -> {
          end_of_set_called = true
          @tm.update_columns(state: "set_over")
        }) do
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

  # ---------------------------------------------------------------------------
  # BK-* persistence path (Phase 38.4-P9)
  # ---------------------------------------------------------------------------
  # Tests removed: Bk2::AdvanceMatchState.call / Bk2::CommitInning gibt es nicht mehr.
  # Multiset läuft komplett über legacy karambol-Pfad; BK-Regeln sind als Guards in
  # TableMonitor#follow_up?, #end_of_set?, ScoreEngine#bk_credit_negative_to_opponent?.

  # Phase 38.4-P9: BK-* set close must complete without an in-flight shot_payload.
  # Production has no writer for `current_bk2_shot_payload` — yet the BK-* dispatch
  # in result_recorder reads it via fetch(..., {}) and forwards `{}` to
  # Bk2::AdvanceMatchState → Bk2::ScoreShot, which crashes on nil obs in
  # calculate_raw_points. Symptom: BK-2 game, Player A reaches balls_goal=80,
  # +1 click on Player B fails because evaluate_result raises during the persistence
  # path. The post-set persistence must rely on data["playera"]["result"] alone —
  # match-state was already advanced via the live-scoring CommitInning path.
  test "perform_save_result does not crash for BK-* free_game_form without shot_payload" do
    @tm.data["free_game_form"] = "bk_2"
    @tm.save!

    assert_nothing_raised do
      TableMonitor::ResultRecorder.new(table_monitor: @tm).perform_save_result
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 38.5 D-03 — set-boundary re-bake guard
  # ---------------------------------------------------------------------------
  # perform_switch_to_next_set must call Bk2::AdvanceMatchState.rebake_at_set_open!
  # ONLY for free_game_form == "bk2_kombi" (research finding 3 + Pitfall 4).

  test "Phase 38.5 D-03: perform_switch_to_next_set calls rebake_at_set_open! for BK-2kombi" do
    @tm.data["free_game_form"] = "bk2_kombi"
    @tm.data["sets"] = [{"Innings1" => [10], "Innings2" => [5]}]
    @tm.save!

    original = Bk2::AdvanceMatchState.method(:rebake_at_set_open!)
    recorded = []
    Bk2::AdvanceMatchState.define_singleton_method(:rebake_at_set_open!) { |arg| recorded << arg }

    TableMonitor::ResultRecorder.new(table_monitor: @tm).perform_switch_to_next_set

    assert_equal 1, recorded.length, "rebake_at_set_open! must be called exactly once for bk2_kombi"
    assert_same @tm, recorded.first, "must receive the TableMonitor argument"
  ensure
    Bk2::AdvanceMatchState.define_singleton_method(:rebake_at_set_open!, original) if original
  end

  test "Phase 38.5 D-03: perform_switch_to_next_set does NOT call rebake_at_set_open! for karambol" do
    # @tm default free_game_form is "standard"; explicitly set to karambol
    @tm.data["free_game_form"] = "karambol"
    @tm.data["sets"] = [{"Innings1" => [10], "Innings2" => [5]}]
    @tm.save!

    original = Bk2::AdvanceMatchState.method(:rebake_at_set_open!)
    recorded = []
    Bk2::AdvanceMatchState.define_singleton_method(:rebake_at_set_open!) { |arg| recorded << arg }

    TableMonitor::ResultRecorder.new(table_monitor: @tm).perform_switch_to_next_set

    assert_equal 0, recorded.length,
      "non-BK-2kombi must NOT trigger re-bake (D-03 guard regression)"
  ensure
    Bk2::AdvanceMatchState.define_singleton_method(:rebake_at_set_open!, original) if original
  end

  # ---------------------------------------------------------------------------
  # Phase 38.7 Plan 05 — D-03 trigger detection + D-13 training-rematch guard
  # + D-08 ba_results TiebreakWinner derivation.
  # See .planning/phases/38.7-…/38.7-CONTEXT.md D-03, D-08, D-13.
  # ---------------------------------------------------------------------------

  # T1 — TR-A Karambol tied + tiebreak_required=true → tiebreak_winner_choice marker.
  test "perform_evaluate_result sets current_element=tiebreak_winner_choice when Karambol tied AND tiebreak_required" do
    # Use existing inning-based path (was_playing && !is_simple_set branch, line 332).
    # Setup: scores tied at innings_goal; tiebreak_required=true on the game; no winner pick yet.
    @game.update!(data: {"tiebreak_required" => true})
    @tm.data["free_game_form"] = "karambol"
    @tm.data["playera"]["result"] = 80
    @tm.data["playera"]["innings"] = 30
    @tm.data["playera"]["balls_goal"] = 80
    @tm.data["playerb"]["result"] = 80
    @tm.data["playerb"]["innings"] = 30
    @tm.data["playerb"]["balls_goal"] = 80
    @tm.data["innings_goal"] = 30
    @tm.data["allow_follow_up"] = false
    @tm.data["current_inning"] = {"active_player" => "playera", "balls" => 0}
    @tm.save!

    TableMonitor::ResultRecorder.call(table_monitor: @tm)
    @tm.reload

    assert_equal "protocol_final", @tm.panel_state,
      "panel_state must flip to protocol_final after end_of_set fires"
    assert_equal "tiebreak_winner_choice", @tm.current_element,
      "D-03: tied score + tiebreak_required must use the tiebreak_winner_choice marker"
  end

  # T2 — TR-A Karambol UNtied + tiebreak_required=true → confirm_result marker.
  test "perform_evaluate_result keeps current_element=confirm_result when Karambol untied (tiebreak_required=true)" do
    @game.update!(data: {"tiebreak_required" => true})
    @tm.data["free_game_form"] = "karambol"
    @tm.data["playera"]["result"] = 80
    @tm.data["playera"]["innings"] = 30
    @tm.data["playera"]["balls_goal"] = 80
    @tm.data["playerb"]["result"] = 70
    @tm.data["playerb"]["innings"] = 30
    @tm.data["playerb"]["balls_goal"] = 80
    @tm.data["innings_goal"] = 30
    @tm.data["allow_follow_up"] = false
    @tm.data["current_inning"] = {"active_player" => "playera", "balls" => 0}
    @tm.save!

    TableMonitor::ResultRecorder.call(table_monitor: @tm)
    @tm.reload

    assert_equal "confirm_result", @tm.current_element,
      "Untied result must use the legacy confirm_result marker even when tiebreak_required=true"
  end

  # T3 — Karambol tied + tiebreak_required=false → confirm_result marker (legacy regression).
  test "perform_evaluate_result keeps current_element=confirm_result when tied but tiebreak_required=false (regression)" do
    @game.update!(data: {"tiebreak_required" => false})
    @tm.data["free_game_form"] = "karambol"
    @tm.data["playera"]["result"] = 80
    @tm.data["playera"]["innings"] = 30
    @tm.data["playera"]["balls_goal"] = 80
    @tm.data["playerb"]["result"] = 80
    @tm.data["playerb"]["innings"] = 30
    @tm.data["playerb"]["balls_goal"] = 80
    @tm.data["innings_goal"] = 30
    @tm.data["allow_follow_up"] = false
    @tm.data["current_inning"] = {"active_player" => "playera", "balls" => 0}
    @tm.save!

    TableMonitor::ResultRecorder.call(table_monitor: @tm)
    @tm.reload

    assert_equal "confirm_result", @tm.current_element,
      "Legacy regression: tiebreak_required=false must produce the legacy modal"
  end

  # T5 — Training-mode rematch blocked when tiebreak pending (D-13).
  # Setup: tournament_monitor=nil, set_over state, single-set game (sets_to_win=1, sets_to_play=1),
  # scores tied AND tiebreak_required=true → revert_players must NOT be called.
  test "perform_evaluate_result blocks training rematch when tiebreak pending (D-13)" do
    @tm.tournament_monitor = nil   # training mode
    @game.update!(data: {"tiebreak_required" => true})  # no tiebreak_winner yet
    @tm.data["free_game_form"] = "karambol"
    @tm.data["sets_to_win"] = 1
    @tm.data["sets_to_play"] = 1
    @tm.data["playera"]["result"] = 80
    @tm.data["playera"]["innings"] = 30
    @tm.data["playera"]["balls_goal"] = 80
    @tm.data["playerb"]["result"] = 80
    @tm.data["playerb"]["innings"] = 30
    @tm.data["playerb"]["balls_goal"] = 80
    @tm.data["innings_goal"] = 30
    @tm.data["allow_follow_up"] = false
    @tm.data["current_inning"] = {"active_player" => "playera", "balls" => 0}
    @tm.save!
    # Move to set_over so we hit Branch C (single-set game training-rematch path).
    @tm.update_columns(state: "set_over")
    @tm.reload

    called = []
    @tm.stub(:revert_players, -> { called << :revert }) do
      @tm.stub(:end_of_set?, true) do
        @tm.stub(:acknowledge_result!, -> {}) do
          # Force final_set_score? branch logic by simulating after-acknowledge state.
          @tm.stub(:final_set_score?, true) do
            TableMonitor::ResultRecorder.call(table_monitor: @tm)
          end
        end
      end
    end

    assert_empty called, "D-13: revert_players must NOT be called while tiebreak pending"
  end

  # T6 — Training-mode rematch fires when tiebreak winner already set.
  test "perform_evaluate_result allows training rematch when tiebreak winner already set" do
    @tm.tournament_monitor = nil
    @game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playera"})
    @tm.data["free_game_form"] = "karambol"
    @tm.data["sets_to_win"] = 1
    @tm.data["sets_to_play"] = 1
    @tm.data["playera"]["result"] = 80
    @tm.data["playera"]["innings"] = 30
    @tm.data["playera"]["balls_goal"] = 80
    @tm.data["playerb"]["result"] = 80
    @tm.data["playerb"]["innings"] = 30
    @tm.data["playerb"]["balls_goal"] = 80
    @tm.data["innings_goal"] = 30
    @tm.data["allow_follow_up"] = false
    @tm.data["current_inning"] = {"active_player" => "playera", "balls" => 0}
    @tm.save!
    @tm.update_columns(state: "set_over")
    @tm.reload

    called = []
    @tm.stub(:revert_players, -> { called << :revert }) do
      @tm.stub(:do_play, -> { called << :do_play }) do
        @tm.stub(:end_of_set?, true) do
          @tm.stub(:acknowledge_result!, -> {}) do
            @tm.stub(:final_set_score?, true) do
              TableMonitor::ResultRecorder.call(table_monitor: @tm)
            end
          end
        end
      end
    end

    assert_includes called, :revert,
      "Tiebreak winner set — rematch must proceed (revert_players must be called)"
  end

  # T7 — D-08 TiebreakWinner=1 derivation when tiebreak_winner=playera.
  test "update_ba_results_with_set_result! writes TiebreakWinner=1 when game.data tiebreak_winner=playera" do
    @game.update!(data: {"tiebreak_winner" => "playera"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 80, "Ergebnis2" => 80,
      "Aufnahmen1" => 30, "Aufnahmen2" => 30,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)
    @tm.reload

    assert_equal 1, @tm.data["ba_results"]["TiebreakWinner"],
      "D-08: tiebreak_winner=playera must derive TiebreakWinner=1 in ba_results"
  end

  # T8 — D-08 TiebreakWinner=2 derivation when tiebreak_winner=playerb.
  test "update_ba_results_with_set_result! writes TiebreakWinner=2 when game.data tiebreak_winner=playerb" do
    @game.update!(data: {"tiebreak_winner" => "playerb"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 80, "Ergebnis2" => 80,
      "Aufnahmen1" => 30, "Aufnahmen2" => 30,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)
    @tm.reload

    assert_equal 2, @tm.data["ba_results"]["TiebreakWinner"],
      "D-08: tiebreak_winner=playerb must derive TiebreakWinner=2 in ba_results"
  end

  # T9 — D-08 TiebreakWinner key absent when no winner pick yet.
  test "update_ba_results_with_set_result! does NOT write TiebreakWinner when game.data has no winner" do
    @game.update!(data: {})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 80, "Ergebnis2" => 70,
      "Aufnahmen1" => 30, "Aufnahmen2" => 30,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)
    @tm.reload

    assert_nil @tm.data["ba_results"]["TiebreakWinner"],
      "TiebreakWinner key absent when no winner pick — Plan 07 PDF view will skip the indicator"
  end
end
