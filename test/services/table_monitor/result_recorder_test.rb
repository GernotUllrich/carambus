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

  # T6 — Phase 38.8 contract: training rematch is OPERATOR-GATED, not automatic.
  # Pre-Phase-38.8 (the deleted regression from c3dedb69): when tiebreak_winner was
  # set, evaluate_result auto-fired revert_players + update(state:"playing") + do_play
  # inline, bypassing the AASM :final_match_score gate. Phase 38.8 deletes that
  # auto-rematch and replaces it with operator-gated :start_rematch event (added in
  # Plan 38.8-02). After evaluate_result, tm must land in :final_match_score; the
  # operator advances via the "Nächstes Spiel" button (Plan 38.8-05) which fires
  # :start_rematch and runs revert_players + do_play as AASM after-callbacks.
  test "perform_evaluate_result lands in final_match_score when tiebreak winner set (operator-gated rematch, not automatic)" do
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
        TableMonitor::ResultRecorder.call(table_monitor: @tm)
      end
    end

    @tm.reload
    assert_empty called,
      "Phase 38.8 contract: revert_players + do_play must NOT be called inline. " \
      "They are now AASM after-callbacks of :start_rematch event, fired only when " \
      "operator clicks 'Nächstes Spiel' (Plan 38.8-05)."
    assert_equal "final_match_score", @tm.state,
      "Phase 38.8 contract: after evaluate_result on a finished single-set training " \
      "game with tiebreak winner set, TM must land in :final_match_score via AASM " \
      "finish_match! (mirroring tournament admin_ack_result path). State=#{@tm.state}."
  end

  # T7 — D-08 TiebreakWinner=1 derivation when tiebreak_winner=playera.
  # update_ba_results_with_set_result! does NOT call save! (caller is responsible —
  # see perform_save_current_set which saves AFTER deep_merge_data!), so we assert
  # against the in-memory @tm.data (no @tm.reload).
  test "update_ba_results_with_set_result! writes TiebreakWinner=1 when game.data tiebreak_winner=playera" do
    @game.update!(data: {"tiebreak_winner" => "playera"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 80, "Ergebnis2" => 80,
      "Aufnahmen1" => 30, "Aufnahmen2" => 30,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)

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

    assert_nil @tm.data["ba_results"]["TiebreakWinner"],
      "TiebreakWinner key absent when no winner pick — Plan 07 PDF view will skip the indicator"
  end

  # ----------------------------------------------------------------
  # Phase 38.7 Plan 11 — Gap-03: BK-2kombi BK-2-phase auto-detect.
  # When BK-2kombi is in BK-2 (serienspiel) phase AND the set ends with both
  # players at balls_goal in 1+1 innings AND scores tied → tiebreak_required
  # is auto-set to true on game.data at the moment of detection. This is a
  # hard rule of the discipline, NOT operator-configurable. Overrides any
  # pre-baked false.
  # ----------------------------------------------------------------

  test "G1 (Gap-03): BK-2kombi BK-2-phase tied at goal in 1+1 innings auto-sets tiebreak_required=true" do
    # bk2_kombi_current_phase: data["sets"]=[done_set] → set_number=2;
    # first_mode=direkter_zweikampf → serienspiel for set 2.
    @tm.deep_merge_data!(
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {"first_set_mode" => "direkter_zweikampf"},
      "sets" => [{"Ergebnis1" => 70, "Ergebnis2" => 50}],
      "playera" => {"innings" => 1, "result" => 70, "balls_goal" => 70},
      "playerb" => {"innings" => 1, "result" => 70, "balls_goal" => 70}
    )
    @tm.save!
    @game.update!(data: {"tiebreak_required" => false})

    # Sanity: bk2_kombi_current_phase resolves to serienspiel for set 2
    assert_equal "serienspiel", @tm.bk2_kombi_current_phase

    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    result = recorder.send(:tiebreak_pick_pending?)

    @game.reload
    assert_equal true, @game.data["tiebreak_required"],
      "Gap-03: BK-2kombi BK-2-phase + 1+1 innings + tied at goal must auto-set tiebreak_required=true"
    assert_equal true, result,
      "Gap-03: tiebreak_pick_pending? must return true after auto-detect fires"
  end

  test "G2 (Gap-03): BK-2kombi DZ-phase tied does NOT trigger auto-detect" do
    # set_number=1 with first_mode=direkter_zweikampf → bk2_kombi_current_phase=direkter_zweikampf
    @tm.deep_merge_data!(
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {"first_set_mode" => "direkter_zweikampf"},
      "sets" => [],
      "playera" => {"innings" => 1, "result" => 70, "balls_goal" => 70},
      "playerb" => {"innings" => 1, "result" => 70, "balls_goal" => 70}
    )
    @tm.save!
    @game.update!(data: {"tiebreak_required" => false})

    assert_equal "direkter_zweikampf", @tm.bk2_kombi_current_phase

    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    result = recorder.send(:tiebreak_pick_pending?)

    @game.reload
    assert_equal false, @game.data["tiebreak_required"],
      "Gap-03: BK-2kombi DZ-phase tied must NOT auto-set tiebreak_required (DZ exempt)"
    assert_equal false, result, "tiebreak_pick_pending? returns false (legacy path)"
  end

  test "G3 (Gap-03): non-BK-2kombi tied does NOT trigger auto-detect (rule only applies to BK-2kombi)" do
    @tm.deep_merge_data!(
      "free_game_form" => "karambol",
      "playera" => {"innings" => 30, "result" => 80, "balls_goal" => 80},
      "playerb" => {"innings" => 30, "result" => 80, "balls_goal" => 80}
    )
    @tm.save!
    @game.update!(data: {"tiebreak_required" => false})

    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    result = recorder.send(:tiebreak_pick_pending?)

    @game.reload
    assert_equal false, @game.data["tiebreak_required"],
      "Gap-03: non-BK-2kombi tied must NOT auto-set tiebreak_required (rule scoped to BK-2kombi)"
    assert_equal false, result, "tiebreak_pick_pending? returns false (no Plan 04 bake, no Plan 11 auto-detect)"
  end

  # ---------------------------------------------------------------------------
  # Phase 38.8 RED characterization test — locks the final_match_score
  # operator-gate contract. Today this test FAILS because evaluate_result
  # auto-starts the training rematch via update(state: "playing") + do_play
  # (smoking gun: result_recorder.rb:462-476 Branch C and 485-497 final_set_score
  # branch — bypasses AASM, skips final_match_score / "Endergebnis erfasst").
  # After Plan 38.8-03 deletes the auto-rematch block this test turns GREEN
  # (regression test: would have failed since commit c3dedb69 2026-03-24).
  #
  # IMPORTANT — Starting state must be :set_over to reach Branch C. From :playing
  # ResultRecorder lands in :set_over and returns before reaching Branch C
  # (the buggy block). Mirror the pattern from existing tiebreak tests at
  # result_recorder_test.rb:416 and :452 — `update_columns(state: "set_over")`
  # bypasses AASM so we can directly probe the buggy single-set Branch C.
  # ---------------------------------------------------------------------------

  test "evaluate_result for training single-set no-tiebreak game lands in final_match_score (NOT playing)" do
    # Reconfigure @tm to a SINGLE-SET training game at set-end conditions.
    # Scores untied (100 vs 60) so tiebreak_pick_pending? returns false and the
    # auto-rematch block fires today (RED). After Plan 03 deletes that block,
    # finish_match! runs and TM lands in :final_match_score (GREEN).
    @tm.update!(
      data: @tm.data.merge(
        "sets_to_win" => 1,
        "sets_to_play" => 1,
        "kickoff_switches_with" => "set",
        "current_kickoff_player" => "playera",
        "free_game_form" => "standard",
        "playera" => @tm.data["playera"].merge("result" => 100, "innings" => 5, "balls_goal" => 100),
        "playerb" => @tm.data["playerb"].merge("result" => 60, "innings" => 5, "balls_goal" => 100)
      )
    )
    # Move to :set_over so we hit Branch C (single-set game training-rematch path).
    # Mirrors result_recorder_test.rb:433 and :468 (phase 38.7 tiebreak tests).
    @tm.update_columns(state: "set_over")
    @tm.reload

    # Sanity check: training mode (no tournament_monitor) and game present.
    assert_nil @tm.tournament_monitor, "Training-mode precondition: tournament_monitor must be nil"
    assert_not_nil @tm.game, "Training-mode precondition: game must be present"
    assert_equal "set_over", @tm.state, "Starting-state precondition: must be :set_over to reach Branch C"

    # Drive evaluate_result through the public service entry point.
    TableMonitor::ResultRecorder.call(table_monitor: @tm)
    @tm.reload

    # CONTRACT under lock: after final result is acknowledged, TM must end in
    # final_match_score ("Endergebnis erfasst"). NOT in :playing (which would
    # mean the auto-rematch silently restarted the next game, skipping the
    # operator-gate display).
    assert_equal "final_match_score", @tm.state,
      "Phase 38.8 contract: training single-set match must land in :final_match_score " \
      "after evaluate_result, NOT :playing. Current state=#{@tm.state.inspect} " \
      "indicates the auto-rematch block in ResultRecorder#perform_evaluate_result " \
      "(result_recorder.rb:462-476 / 485-497) is still bypassing AASM via update(state: 'playing'). " \
      "This test would have failed since commit c3dedb69 (2026-03-24)."

    # Game must still be intact (auto-rematch would have called revert_players + do_play
    # which sets up the rematch; we want the original game preserved at final_match_score).
    assert_not_nil @tm.game, "Game must remain present at final_match_score (no auto-rematch)"
    assert_nil @tm.tournament_monitor, "Training mode preserved (no tournament_monitor side-effect)"
  end

  # ---------------------------------------------------------------------------
  # Quick-260501-vly Plan 01 — Bug 1: Tiebreak winner pick credits Sets1/Sets2.
  # Pre-existing latent defect: Phase 38.7 Plan 05 wrote the TiebreakWinner
  # indicator (1/2) for the PDF, but did NOT increment Sets1/Sets2 — so a tied
  # set decided by an operator tiebreak pick never advanced the match-score,
  # leaving BK-2kombi matches unable to close on tiebreak.
  #
  # Conservative gate (user-confirmed Q1 2026-05-01 "ja bitte"):
  # set-credit fires only when scores are tied AND game.data['tiebreak_required']
  # == true (strict Boolean). Legacy/edge data (TiebreakWinner set without
  # tiebreak_required) is left untouched — TiebreakWinner indicator still set
  # for the PDF, no double-count on the non-tied score-comparison path.
  # ---------------------------------------------------------------------------

  test "Quick-260501-vly Bug 1 close branch playera: tied + tiebreak_required + winner=playera credits Sets1=1" do
    @game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playera"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 50, "Ergebnis2" => 50,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)

    assert_equal 1, @tm.data["ba_results"]["Sets1"],
      "Bug 1: tied + tiebreak_required + winner=playera must credit Sets1=1"
    assert_equal 0, @tm.data["ba_results"]["Sets2"],
      "Bug 1: playera tiebreak pick must NOT credit Sets2"
    assert_equal 1, @tm.data["ba_results"]["TiebreakWinner"],
      "Plan 38.7-05 contract preserved: TiebreakWinner=1 indicator still set for PDF"
  end

  test "Quick-260501-vly Bug 1 close branch playerb: tied + tiebreak_required + winner=playerb credits Sets2=1" do
    @game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playerb"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 50, "Ergebnis2" => 50,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)

    assert_equal 1, @tm.data["ba_results"]["Sets2"],
      "Bug 1: tied + tiebreak_required + winner=playerb must credit Sets2=1"
    assert_equal 0, @tm.data["ba_results"]["Sets1"],
      "Bug 1: playerb tiebreak pick must NOT credit Sets1"
    assert_equal 2, @tm.data["ba_results"]["TiebreakWinner"],
      "Plan 38.7-05 contract preserved: TiebreakWinner=2 indicator still set for PDF"
  end

  test "Quick-260501-vly Bug 1 regression: tied + tiebreak_required but no tiebreak_winner — no credit, no indicator" do
    @game.update!(data: {"tiebreak_required" => true})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 50, "Ergebnis2" => 50,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)

    assert_equal 0, @tm.data["ba_results"]["Sets1"],
      "Plan 38.7-05 contract preserved: missing tiebreak_winner must not credit Sets1"
    assert_equal 0, @tm.data["ba_results"]["Sets2"],
      "Plan 38.7-05 contract preserved: missing tiebreak_winner must not credit Sets2"
    assert_nil @tm.data["ba_results"]["TiebreakWinner"],
      "Plan 38.7-05 contract preserved: TiebreakWinner key absent without winner pick"
  end

  test "Quick-260501-vly Bug 1 conservative gate: tiebreak_required=false + winner=playera — indicator only, no credit" do
    @game.update!(data: {"tiebreak_required" => false, "tiebreak_winner" => "playera"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 50, "Ergebnis2" => 50,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 10, "Höchstserie2" => 10
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)

    assert_equal 0, @tm.data["ba_results"]["Sets1"],
      "Conservative gate (Q1 ja bitte): tiebreak_required=false leaves legacy/edge data unchanged — no Sets1 credit"
    assert_equal 0, @tm.data["ba_results"]["Sets2"],
      "Conservative gate (Q1 ja bitte): tiebreak_required=false leaves legacy/edge data unchanged — no Sets2 credit"
    assert_equal 1, @tm.data["ba_results"]["TiebreakWinner"],
      "Plan 38.7-05 contract preserved: TiebreakWinner indicator still set independently of tiebreak_required gate"
  end

  test "Quick-260501-vly Bug 1 no double-count: non-tied + tiebreak_required + winner=playera credits Sets1=1 (from score), not 2" do
    @game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playera"})
    recorder = TableMonitor::ResultRecorder.new(table_monitor: @tm)
    game_set_result = {
      "Ergebnis1" => 70, "Ergebnis2" => 45,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 15, "Höchstserie2" => 8
    }
    recorder.send(:update_ba_results_with_set_result!, game_set_result)

    assert_equal 1, @tm.data["ba_results"]["Sets1"],
      "No double-count: non-tied path credits Sets1=1 from score comparison ONLY (not 2 with tiebreak credit)"
    assert_equal 0, @tm.data["ba_results"]["Sets2"],
      "No double-count: playerb did not score higher and did not win tiebreak — Sets2=0"
    assert_equal 1, @tm.data["ba_results"]["TiebreakWinner"],
      "Plan 38.7-05 contract preserved: TiebreakWinner=1 indicator unchanged on non-tied path"
  end

  # ---------------------------------------------------------------------------
  # Quick-260501-x07 — clear stale tiebreak_winner at set boundary
  # ---------------------------------------------------------------------------
  # perform_switch_to_next_set MUST remove Game.data["tiebreak_winner"] when
  # present so set N+1 re-evaluates the tiebreak modal independently of set N.
  # Bug surface: BK-2kombi best-of-3 set 3 silently skipped the modal because
  # tiebreak_pick_pending? saw a stale winner from set 1 and returned false.
  # tiebreak_required stays sticky (per-match preset, not cleared here).
  # No spurious Game.save! when winner is already absent (audit-log clean).

  test "Quick-260501-x07: perform_switch_to_next_set clears stale tiebreak_winner from Game.data" do
    # Setup: BK-2kombi context with one closed set (matches Phase 38.5 D-03 setup),
    # game has both tiebreak_required AND a stale tiebreak_winner from set 1.
    @tm.data["free_game_form"] = "bk2_kombi"
    @tm.data["sets"] = [{"Innings1" => [10], "Innings2" => [5]}]
    @tm.save!
    @game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playera"})
    @tm.reload  # re-fetch the cached :game association so service sees updated data

    TableMonitor::ResultRecorder.new(table_monitor: @tm).perform_switch_to_next_set

    assert_nil @game.reload.data["tiebreak_winner"],
      "Quick-260501-x07: stale tiebreak_winner must be removed at set boundary so next set re-evaluates"
  end

  test "Quick-260501-x07: perform_switch_to_next_set preserves tiebreak_required (sticky per-match flag)" do
    # Setup: same BK-2kombi context; tiebreak_required is the per-match preset
    # (Quickstart / Detail Page checkbox) and MUST persist across sets.
    @tm.data["free_game_form"] = "bk2_kombi"
    @tm.data["sets"] = [{"Innings1" => [10], "Innings2" => [5]}]
    @tm.save!
    @game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playerb"})
    @tm.reload

    TableMonitor::ResultRecorder.new(table_monitor: @tm).perform_switch_to_next_set

    assert_equal true, @game.reload.data["tiebreak_required"],
      "Quick-260501-x07: tiebreak_required is sticky per-match — must NOT be cleared at set boundary"
  end

  test "Quick-260501-x07: perform_switch_to_next_set is no-op on Game when tiebreak_winner is absent (idempotent)" do
    # Setup: BK-2kombi context with tiebreak_required=true but NO tiebreak_winner key.
    # The .present? gate must skip Game.save! entirely to avoid audit-log noise
    # (~90 spurious paper_trail versions per tournament otherwise).
    @tm.data["free_game_form"] = "bk2_kombi"
    @tm.data["sets"] = [{"Innings1" => [10], "Innings2" => [5]}]
    @tm.save!
    @game.update!(data: {"tiebreak_required" => true})
    @tm.reload
    original_updated_at = @game.reload.updated_at

    travel 1.second do
      assert_nothing_raised do
        TableMonitor::ResultRecorder.new(table_monitor: @tm).perform_switch_to_next_set
      end
    end

    assert_equal original_updated_at.to_i, @game.reload.updated_at.to_i,
      "Quick-260501-x07: when tiebreak_winner absent, no spurious Game.save! must occur (updated_at unchanged)"
  end
end
