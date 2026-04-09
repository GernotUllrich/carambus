# frozen_string_literal: true

require "test_helper"

# Charakterisierungstests fuer TableMonitor State Machine und after_update_commit Verhalten.
# Zweck: Bestehendes Verhalten vor der Extraktion fixieren. Verhalten hier NICHT aendern.
#
# Hinweis zu PartyMonitor: PartyMonitor ist KEIN STI-Subtyp von TableMonitor.
# Es ist ein eigenstaendiges Modell (eigene Tabelle party_monitors). Ein TableMonitor
# kann jedoch einen PartyMonitor als polymorphes tournament_monitor referenzieren —
# dieser Ast in after_update_commit wird hier getestet.
#
# Rails 7.2 feuert after_commit Callbacks nativ in transaktionalen Tests (seit Rails 5.0,
# siehe rails/rails#18458). Das test_after_commit Gem wird nicht benoetigt.
class TableMonitorCharTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    # Setze alle cattr_accessor auf nil zurueck, um Zustandslecks zwischen Tests zu verhindern
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil

    # Erzeuge einen frischen TableMonitor im Zustand :ready
    @tm = TableMonitor.create!(state: "ready", data: {})
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
  # Hilfsmethoden
  # ---------------------------------------------------------------------------

  # Erzeuge einen TableMonitor in einem bestimmten Zustand ohne after_commit-Seiteneffekte
  def tm_in_state(state)
    TableMonitor.create!(state: state, data: {})
  end

  # Erzeuge ein minimales Game-Objekt (kein Tournament erforderlich)
  def create_test_game
    Game.create!(data: {}, gname: "char_test_#{SecureRandom.hex(4)}")
  end

  # ===========================================================================
  # A. AASM State Transition Tests
  # ===========================================================================

  test "ready -> start_new_match! -> warmup" do
    game = create_test_game
    @tm.update_columns(game_id: game.id)
    @tm.reload
    assert @tm.ready?
    @tm.start_new_match!
    assert @tm.warmup?, "Expected warmup state after start_new_match!, got: #{@tm.state}"
  end

  test "warmup -> finish_warmup! -> match_shootout" do
    tm = tm_in_state("warmup")
    tm.finish_warmup!
    assert tm.match_shootout?
    assert_equal "match_shootout", tm.state
  end

  test "match_shootout -> finish_shootout! -> playing" do
    tm = tm_in_state("match_shootout")
    tm.finish_shootout!
    assert tm.playing?
    assert_equal "playing", tm.state
  end

  test "playing -> end_of_set! -> set_over" do
    tm = tm_in_state("playing")
    tm.end_of_set!
    assert_equal "set_over", tm.state
  end

  test "set_over -> acknowledge_result! -> final_set_score" do
    tm = tm_in_state("set_over")
    # set_game_over (after_enter fuer set_over) setzt panel_state — kein save-Fehler erwartet
    tm.acknowledge_result!
    assert tm.final_set_score?
    assert_equal "final_set_score", tm.state
  end

  test "final_set_score -> finish_match! -> final_match_score" do
    tm = tm_in_state("final_set_score")
    game = create_test_game
    tm.update_columns(game_id: game.id)
    tm.reload
    tm.finish_match!
    assert tm.final_match_score?
    assert_equal "final_match_score", tm.state
  end

  test "ready_for_new_match -> ready! -> ready" do
    tm = tm_in_state("ready_for_new_match")
    tm.ready!
    assert tm.ready?
    assert_equal "ready", tm.state
  end

  test "force_ready! transitions to ready from playing" do
    tm = tm_in_state("playing")
    tm.force_ready!
    assert tm.ready?
    assert_equal "ready", tm.state
  end

  test "force_ready! transitions to ready from warmup" do
    tm = tm_in_state("warmup")
    tm.force_ready!
    assert_equal "ready", tm.state
  end

  test "force_ready! transitions to ready from match_shootout" do
    tm = tm_in_state("match_shootout")
    tm.force_ready!
    assert_equal "ready", tm.state
  end

  test "force_ready! transitions to ready from final_match_score" do
    tm = tm_in_state("final_match_score")
    tm.force_ready!
    assert_equal "ready", tm.state
  end

  test "invalid transition raises AASM::InvalidTransition with whiny_transitions enabled" do
    # finish_shootout! ist nur von :match_shootout erlaubt — von :ready ist es ungueltig
    tm = tm_in_state("ready")
    assert_raises(AASM::InvalidTransition) do
      tm.finish_shootout!
    end
  end

  test "invalid transition end_of_set! from warmup raises AASM::InvalidTransition" do
    tm = tm_in_state("warmup")
    assert_raises(AASM::InvalidTransition) do
      tm.end_of_set!
    end
  end

  test "warmup -> warmup_a! -> warmup_a" do
    tm = tm_in_state("warmup")
    tm.warmup_a!
    assert tm.warmup_a?
    assert_equal "warmup_a", tm.state
  end

  test "warmup_a -> warmup_b! -> warmup_b" do
    tm = tm_in_state("warmup_a")
    tm.warmup_b!
    assert tm.warmup_b?
    assert_equal "warmup_b", tm.state
  end

  test "close_match! transitions from playing to ready_for_new_match" do
    tm = tm_in_state("playing")
    tm.close_match!
    assert tm.ready_for_new_match?
    assert_equal "ready_for_new_match", tm.state
  end

  test "undo! transitions from set_over back to playing" do
    tm = tm_in_state("set_over")
    tm.undo!
    assert tm.playing?
    assert_equal "playing", tm.state
  end

  test "next_set! transitions from set_over to playing" do
    tm = tm_in_state("set_over")
    tm.next_set!
    assert tm.playing?
  end

  # ===========================================================================
  # B. after_enter Callback Tests
  # ===========================================================================

  test "entering set_over via end_of_set! triggers set_game_over and sets panel_state" do
    tm = tm_in_state("playing")
    tm.end_of_set!
    # Reload, um DB-Persistierung durch set_game_over#save zu pruefen
    tm.reload
    assert_equal "protocol_final", tm.panel_state,
      "set_game_over should set panel_state=protocol_final when entering set_over"
    assert_equal "confirm_result", tm.current_element
    assert_equal "set_over", tm.state
  end

  test "entering final_set_score does NOT set panel_state to protocol_final" do
    # set_game_over prueft state == 'set_over' — fuer final_set_score kein panel_state-Update
    tm = tm_in_state("set_over")
    tm.update_columns(panel_state: "pointer_mode")
    tm.acknowledge_result!
    tm.reload
    assert_equal "final_set_score", tm.state
    assert_equal "pointer_mode", tm.panel_state,
      "set_game_over should not change panel_state when entering final_set_score"
  end

  test "start_new_match! calls set_start_time which updates game.started_at" do
    game = create_test_game
    @tm.update_columns(game_id: game.id)
    @tm.reload
    assert_nil game.started_at, "game.started_at should be nil before start_new_match!"
    @tm.start_new_match!
    game.reload
    assert_not_nil game.started_at, "set_start_time should set game.started_at on start_new_match!"
  end

  test "finish_match! calls set_end_time which updates game.ended_at" do
    tm = tm_in_state("final_set_score")
    game = create_test_game
    tm.update_columns(game_id: game.id)
    tm.reload
    assert_nil game.ended_at
    tm.finish_match!
    game.reload
    assert_not_nil game.ended_at, "set_end_time should set game.ended_at on finish_match!"
  end

  test "set_end_time is idempotent: does not overwrite existing ended_at" do
    # IDEMPOTENCY-Guard: Wenn ended_at bereits gesetzt ist, wird es nicht ueberschrieben
    tm = tm_in_state("final_set_score")
    game = create_test_game
    existing_ended_at = 2.hours.ago.change(usec: 0)
    game.update_columns(ended_at: existing_ended_at)
    tm.update_columns(game_id: game.id)
    tm.reload
    tm.finish_match!
    game.reload
    assert_equal existing_ended_at.to_i, game.ended_at.to_i,
      "set_end_time idempotency: should not overwrite existing ended_at"
  end

  # ===========================================================================
  # C. after_update_commit Branch Tests
  # ===========================================================================

  test "skip_update_callbacks = true suppresses all TableMonitorJob enqueues" do
    ApplicationRecord.stub(:local_server?, true) do
      assert_no_enqueued_jobs only: [TableMonitorJob] do
        @tm.skip_update_callbacks = true
        @tm.update!(state: "warmup")
      end
    end
  end

  test "local_server? returns false suppresses all TableMonitorJob enqueues" do
    # Auf dem API-Server (local_server? == false) werden keine Scoreboards betrieben
    ApplicationRecord.stub(:local_server?, false) do
      assert_no_enqueued_jobs only: [TableMonitorJob] do
        @tm.update!(state: "warmup")
      end
    end
  end

  test "state change with local_server? true enqueues table_scores, teaser, and full scoreboard jobs" do
    # 'state' ist ein relevant_key (nicht in der Ausschlussliste).
    # Default-Pfad (kein ultra_fast/simple_score_update?):
    #   1. table_scores (relevant_keys vorhanden)
    #   2. teaser (relevant_keys vorhanden)
    #   3. "" (slow path: full scoreboard, kein early return durch fast paths)
    # get_options! wird gestubbt, da es table.location benoetigt (kein Table in diesem Test).
    ApplicationRecord.stub(:local_server?, true) do
      @tm.stub(:get_options!, nil) do
        assert_enqueued_jobs(3, only: [TableMonitorJob]) do
          @tm.update!(state: "warmup")
        end
      end
    end
  end

  test "PartyMonitor-tournament_monitor branch enqueues party_monitor_scores job on state change" do
    # Erzeuge TableMonitor mit PartyMonitor als tournament_monitor.
    # get_options! wird gestubbt, da es table.location benoetigt (kein Table in diesem Test).
    party_monitor = PartyMonitor.create!(state: "seeding_mode", data: {})
    tm = TableMonitor.create!(state: "ready", data: {}, tournament_monitor: party_monitor)

    ApplicationRecord.stub(:local_server?, true) do
      tm.stub(:get_options!, nil) do
        enqueued = capture_enqueued_jobs do
          tm.update!(state: "warmup")
        end
        party_monitor_jobs = enqueued.select { |j| j[:args]&.include?("party_monitor_scores") }
        assert_not_empty party_monitor_jobs,
          "Expected party_monitor_scores job when tournament_monitor is a PartyMonitor"
      end
    end
  end

  test "plain TableMonitor (no PartyMonitor) does not enqueue party_monitor_scores" do
    # @tm hat keinen tournament_monitor — kein party_monitor_scores Job erwartet.
    # get_options! wird gestubbt, da es table.location benoetigt (kein Table in diesem Test).
    ApplicationRecord.stub(:local_server?, true) do
      @tm.stub(:get_options!, nil) do
        enqueued = capture_enqueued_jobs do
          @tm.update!(state: "warmup")
        end
        party_monitor_jobs = enqueued.select { |j| j[:args]&.include?("party_monitor_scores") }
        assert_empty party_monitor_jobs,
          "party_monitor_scores should not be enqueued when tournament_monitor is not a PartyMonitor"
      end
    end
  end

  test "ultra_fast_score_update? returns false when collected_data_changes is blank" do
    # Frisches Objekt — @collected_data_changes ist nil/leer
    tm = TableMonitor.new(data: {})
    refute tm.ultra_fast_score_update?,
      "ultra_fast_score_update? should be false when @collected_data_changes is blank"
  end

  test "simple_score_update? returns false when collected_data_changes is blank" do
    tm = TableMonitor.new(data: {})
    refute tm.simple_score_update?,
      "simple_score_update? should be false when @collected_data_changes is blank"
  end

  test "ultra_fast_score_update? returns false for 14.1 endlos discipline" do
    # 14.1 endlos benoetigt immer Full-Updates
    tm = TableMonitor.new(data: {
      "playera" => { "discipline" => "14.1 endlos", "innings_redo_list" => [5] },
      "playerb" => {}
    })
    # Simuliere @collected_data_changes direkt (private-state-Simulation)
    tm.instance_variable_set(:@collected_data_changes, [{ "playera" => { "innings_redo_list" => [5] } }])
    refute tm.ultra_fast_score_update?,
      "ultra_fast_score_update? should return false for 14.1 endlos discipline"
  end

  test "ultra_fast_score_update? returns true when only innings_redo_list changed for one player" do
    tm = TableMonitor.new(data: {
      "playera" => { "discipline" => "Freie Partie", "innings_redo_list" => [5] },
      "playerb" => { "discipline" => "Freie Partie", "innings_redo_list" => [] }
    })
    tm.instance_variable_set(:@collected_data_changes, [{ "playera" => { "innings_redo_list" => [5] } }])
    tm.instance_variable_set(:@collected_changes, [])
    assert tm.ultra_fast_score_update?,
      "ultra_fast_score_update? should return true when only innings_redo_list changed for one player"
  end

  test "simple_score_update? returns true when only safe keys changed for one player" do
    tm = TableMonitor.new(data: {
      "playera" => { "discipline" => "Freie Partie", "result" => 10 },
      "playerb" => {}
    })
    tm.instance_variable_set(:@collected_data_changes, [{ "playera" => { "result" => 10 } }])
    tm.instance_variable_set(:@collected_changes, [])
    assert tm.simple_score_update?,
      "simple_score_update? should return true when only safe keys changed for one player"
  end

  test "end-to-end ultra_fast_score_update triggers score_data job via data pipeline" do
    # End-to-End-Test: Aendert NUR innings_redo_list eines Spielers ueber update!(data: ...).
    # Prueft den vollstaendigen Pfad: before_save log_state_change ->
    # @collected_data_changes -> after_update_commit ultra_fast-Ast -> score_data Job.
    #
    # Hinweis: Nach create! enthaelt @collected_data_changes noch die Initialdaten von
    # log_state_change (after_update_commit feuert nicht bei create!). Deshalb wird der
    # Record per find() neu geladen — ein frisches Objekt ohne Instanzvariablen.
    initial_data = {
      "playera" => { "discipline" => "Freie Partie", "innings_redo_list" => [5, 3], "result" => 10 },
      "playerb" => { "discipline" => "Freie Partie", "innings_redo_list" => [4], "result" => 8 }
    }
    tm = TableMonitor.find(TableMonitor.create!(state: "playing", data: initial_data).id)

    # Nur innings_redo_list von playera aendern — kein anderer Key, kein state-Wechsel
    modified_data = initial_data.deep_dup
    modified_data["playera"]["innings_redo_list"] = [5, 3, 7]

    ApplicationRecord.stub(:local_server?, true) do
      tm.stub(:get_options!, nil) do
        enqueued = capture_enqueued_jobs do
          tm.update!(data: modified_data)
        end
        score_data_jobs = enqueued.select { |j| j[:args]&.include?("score_data") }
        assert_not_empty score_data_jobs,
          "Expected score_data job for ultra_fast path, got: #{enqueued.map { |j| j[:args] }.inspect}"
        assert score_data_jobs.any? { |j| j[:args]&.any? { |a| a.is_a?(Hash) && a["player"] == "playera" } },
          "Expected score_data job with player: playera"
      end
    end
  end

  test "end-to-end simple_score_update triggers player_score_panel job via data pipeline" do
    # End-to-End-Test: Aendert result (safe key, aber nicht nur innings_redo_list) via update!(data: ...).
    # ultra_fast schlaegt fehl (result != innings_redo_list), simple greift -> player_score_panel Job.
    # Prueft den vollstaendigen Pfad: before_save log_state_change ->
    # @collected_data_changes -> after_update_commit simple-Ast -> player_score_panel Job.
    #
    # Hinweis: Record per find() neu laden, damit @collected_data_changes/@collected_changes
    # sauber nil sind (keine Residuen aus create!).
    initial_data = {
      "playera" => { "discipline" => "Freie Partie", "result" => 10, "innings_redo_list" => [5, 3] },
      "playerb" => { "discipline" => "Freie Partie", "result" => 8, "innings_redo_list" => [4] }
    }
    tm = TableMonitor.find(TableMonitor.create!(state: "playing", data: initial_data).id)

    # Nur result von playera aendern — ultra_fast schlaegt fehl, simple greift
    modified_data = initial_data.deep_dup
    modified_data["playera"]["result"] = 15

    ApplicationRecord.stub(:local_server?, true) do
      tm.stub(:get_options!, nil) do
        enqueued = capture_enqueued_jobs do
          tm.update!(data: modified_data)
        end
        panel_jobs = enqueued.select { |j| j[:args]&.include?("player_score_panel") }
        assert_not_empty panel_jobs,
          "Expected player_score_panel job for simple path, got: #{enqueued.map { |j| j[:args] }.inspect}"
        assert panel_jobs.any? { |j| j[:args]&.any? { |a| a.is_a?(Hash) && a["player"] == "playera" } },
          "Expected player_score_panel job with player: playera"
        score_data_jobs = enqueued.select { |j| j[:args]&.include?("score_data") }
        assert_empty score_data_jobs,
          "score_data job must NOT be enqueued on simple path (ultra_fast should not fire)"
      end
    end
  end

  # ===========================================================================
  # D. log_state_transition Callback Test
  # ===========================================================================

  test "log_state_transition is registered as after_all_transitions callback" do
    # Pruefe dass der Callback in der AASM-Konfiguration eingetragen ist
    global_callbacks = TableMonitor.aasm.state_machine.global_callbacks
    after_callbacks = Array(global_callbacks[:after_all_transitions])
    has_log_callback = after_callbacks.any? { |c| c.to_s.include?("log_state_transition") }
    assert has_log_callback,
      "log_state_transition should be registered as after_all_transitions callback"
  end

  test "state transition persists new state to database" do
    @tm.update_columns(state: "playing")
    @tm.reload
    @tm.end_of_set!
    @tm.reload
    assert_equal "set_over", @tm.state,
      "State change should be persisted to the database after transition"
  end

  # ===========================================================================
  # E. PartyMonitor Relationship Tests (per D-07)
  # ===========================================================================

  test "PartyMonitor is NOT an STI subclass of TableMonitor" do
    # PartyMonitor erbt direkt von ApplicationRecord, nicht von TableMonitor
    assert_equal ApplicationRecord, PartyMonitor.superclass
    assert_not_equal TableMonitor, PartyMonitor.superclass
  end

  test "PartyMonitor has its own AASM state machine with different states from TableMonitor" do
    pm_states = PartyMonitor.aasm.states.map(&:name)
    tm_states = TableMonitor.aasm.states.map(&:name)
    assert pm_states.include?(:seeding_mode), "PartyMonitor should have seeding_mode state"
    assert pm_states.include?(:playing_round), "PartyMonitor should have playing_round state"
    assert_not tm_states.include?(:seeding_mode), "TableMonitor should NOT have seeding_mode state"
    assert_not pm_states.include?(:warmup), "PartyMonitor should NOT have warmup state"
  end

  test "TableMonitor can reference PartyMonitor as polymorphic tournament_monitor" do
    party_monitor = PartyMonitor.create!(state: "seeding_mode", data: {})
    tm = TableMonitor.create!(state: "ready", data: {}, tournament_monitor: party_monitor)
    assert_equal party_monitor, tm.tournament_monitor
    assert tm.tournament_monitor.is_a?(PartyMonitor)
    assert_equal "PartyMonitor", tm.tournament_monitor_type
  end

  test "after_update_commit checks is_a?(PartyMonitor) for polymorphic tournament_monitor routing" do
    # Charakterisiert: der Ast wird anhand von .is_a?(PartyMonitor) ausgefuehrt
    party_monitor = PartyMonitor.create!(state: "seeding_mode", data: {})
    tm = TableMonitor.create!(state: "ready", data: {}, tournament_monitor: party_monitor)
    assert tm.tournament_monitor.is_a?(PartyMonitor),
      "tournament_monitor should be a PartyMonitor for polymorphic routing"
    assert_not tm.tournament_monitor.is_a?(TableMonitor),
      "PartyMonitor should not be a TableMonitor"
  end

  private

  # Hilfsmethode: Enqueued Jobs erfassen ohne Ausfuehren
  def capture_enqueued_jobs(&block)
    queue_adapter = ActiveJob::Base.queue_adapter
    before_count = queue_adapter.enqueued_jobs.size
    block.call
    queue_adapter.enqueued_jobs[before_count..]
  end
end
