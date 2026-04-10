# frozen_string_literal: true

require "test_helper"

# Unit tests fuer TableMonitor::GameSetup.
# Verifiziert: Game-Erstellung, GameParticipation-Erstellung, Result-Hash-Aufbau,
# suppress_broadcast-Cleanup im ensure-Block, genau ein TableMonitorJob am Ende,
# Shootout-Behandlung und assign_game-Zweig.
#
# Alle Tests verwenden einen in der Datenbank gespeicherten TableMonitor.
# TableMonitorJob wird gestubbt um externe Seiteneffekte zu vermeiden.
class TableMonitor::GameSetupTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    # cattr_accessor-Lecks vermeiden
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil

    # Minimale Spieler anlegen (LocalProtector ist in Tests deaktiviert)
    @player_a = Player.create!(
      id: 50_000_001,
      firstname: "Spieler",
      lastname: "A",
      dbu_nr: 10001
    )
    @player_b = Player.create!(
      id: 50_000_002,
      firstname: "Spieler",
      lastname: "B",
      dbu_nr: 10002
    )

    # Minimaler TableMonitor im Zustand :ready
    @tm = TableMonitor.create!(state: "ready", data: {})

    # Standard-Optionen fuer start_game
    @options = {
      "player_a_id" => @player_a.id,
      "player_b_id" => @player_b.id,
      "discipline_a" => "Freie Partie",
      "discipline_b" => "Freie Partie",
      "balls_goal_a" => 100,
      "balls_goal_b" => 100,
      "sets_to_play" => 1,
      "sets_to_win" => 1,
      "timeouts" => 0,
      "timeout" => 0,
      "warntime" => 0,
      "gametime" => 0,
      "innings_goal" => 0
    }
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

  # Ruft GameSetup.call auf und stubbt TableMonitorJob.perform_later
  def call_setup(tm: @tm, options: @options)
    job_calls = []
    TableMonitorJob.stub(:perform_later, ->(id, action) { job_calls << [id, action] }) do
      TableMonitor::GameSetup.call(table_monitor: tm, options: options)
    end
    job_calls
  end

  # ---------------------------------------------------------------------------
  # Test 1: neues Game wird angelegt und mit dem TableMonitor verknuepft
  # ---------------------------------------------------------------------------

  test "call creates a new Game linked to the TableMonitor when no existing party game" do
    assert_nil @tm.game_id, "Vorbedingung: kein bestehendes Game"

    assert_difference "Game.count", 1 do
      call_setup
    end

    @tm.reload
    assert_not_nil @tm.game_id, "game_id muss nach GameSetup gesetzt sein"
    # Game hat has_one :table_monitor (Fremdschluessel game_id liegt auf table_monitors)
    assert_equal @tm.id, Game.find(@tm.game_id).table_monitor&.id
  end

  # ---------------------------------------------------------------------------
  # Test 2: GameParticipation-Datensaetze fuer playera und playerb werden angelegt
  # ---------------------------------------------------------------------------

  test "call creates GameParticipation records for playera and playerb" do
    assert_difference "GameParticipation.count", 2 do
      call_setup
    end

    @tm.reload
    game = Game.find(@tm.game_id)
    roles = game.game_participations.pluck(:role)
    assert_includes roles, "playera"
    assert_includes roles, "playerb"
  end

  # ---------------------------------------------------------------------------
  # Test 3: bestehendes Party-/Turnierspiel bleibt erhalten (tournament_type present)
  # ---------------------------------------------------------------------------

  test "call preserves existing party/tournament game when game.tournament_type present" do
    # Bestehendes Spiel mit tournament_type anlegen und dem TM zuweisen
    existing_game = Game.create!(data: {}, tournament_type: "PartyMonitor")
    @tm.update_columns(game_id: existing_game.id)
    @tm.reload

    original_game_id = existing_game.id

    assert_no_difference "Game.count" do
      call_setup
    end

    @tm.reload
    assert_equal original_game_id, @tm.game_id,
      "game_id muss unveraendert bleiben wenn tournament_type present"
  end

  # ---------------------------------------------------------------------------
  # Test 4: vorheriges Spiel (ohne tournament_type) wird entkoppelt vor neuem
  # ---------------------------------------------------------------------------

  test "call unlinks previous game before creating new one when no tournament_type" do
    old_game = Game.create!(data: {})
    @tm.update_columns(game_id: old_game.id)
    @tm.reload

    call_setup

    old_game.reload
    # Nach Entkopplung darf kein TableMonitor mehr auf das alte Game zeigen
    assert_nil old_game.table_monitor,
      "altes Game muss von TM entkoppelt werden"

    @tm.reload
    assert_not_equal old_game.id, @tm.game_id,
      "TM muss ein neues Game erhalten"
  end

  # ---------------------------------------------------------------------------
  # Test 5: Result-Hash enthaelt korrekte Spieler-Daten
  # ---------------------------------------------------------------------------

  test "call builds correct result hash with player balls_goal and discipline" do
    call_setup(options: @options.merge(
      "balls_goal_a" => 75,
      "balls_goal_b" => 80,
      "discipline_a" => "Dreiband",
      "discipline_b" => "Dreiband",
      "sets_to_win" => 3
    ))

    @tm.reload
    assert_equal "Dreiband", @tm.data.dig("playera", "discipline"),
      "discipline_a muss in playera-Daten stehen"
    assert_equal "Dreiband", @tm.data.dig("playerb", "discipline"),
      "discipline_b muss in playerb-Daten stehen"
    # sets_to_win landet in data via deep_merge_data!
    assert_equal 3, @tm.data["sets_to_win"].to_i
  end

  # ---------------------------------------------------------------------------
  # Test 6: suppress_broadcast (skip_update_callbacks) wird vor Saves gesetzt
  # ---------------------------------------------------------------------------

  test "call sets skip_update_callbacks=true before saves, resets after" do
    callbacks_during = []
    original_save = @tm.method(:save!)

    # Wir pruefen: wenn save! aufgerufen wird, ist skip_update_callbacks true
    @tm.stub(:save!, -> {
      callbacks_during << @tm.skip_update_callbacks
      original_save.call
    }) do
      call_setup
    end

    assert callbacks_during.any? { |v| v == true },
      "skip_update_callbacks muss waehrend save! true sein"
    # Nach dem Call muss es false sein
    assert_equal false, @tm.skip_update_callbacks
  end

  # ---------------------------------------------------------------------------
  # Test 7: genau ein TableMonitorJob mit (id, "table_scores") wird eingereiht
  # ---------------------------------------------------------------------------

  test "call enqueues exactly 1 TableMonitorJob with (id, table_scores) at the end" do
    job_calls = call_setup

    assert_equal 1, job_calls.size,
      "Genau ein TableMonitorJob soll eingereiht werden, tatsaechlich: #{job_calls.size}"
    assert_equal [@tm.id, "table_scores"], job_calls.first
  end

  # ---------------------------------------------------------------------------
  # Test 8: finish_warmup! wird aufgerufen bei Shootout-Disziplin
  # ---------------------------------------------------------------------------

  test "call triggers finish_warmup! when discipline matches /shootout/i" do
    finish_warmup_called = false
    options = @options.merge("discipline_a" => "Shootout", "discipline_b" => "Shootout")

    # TM in warmup-Zustand bringen damit may_finish_warmup? true ist
    @tm.update_columns(state: "warmup")
    @tm.reload

    @tm.stub(:finish_warmup!, -> { finish_warmup_called = true }) do
      call_setup(options: options)
    end

    assert finish_warmup_called,
      "finish_warmup! muss aufgerufen werden wenn discipline /shootout/i"
  end

  # ---------------------------------------------------------------------------
  # Test 9: suppress_broadcast wird in ensure zurueckgesetzt, auch bei Ausnahme
  # ---------------------------------------------------------------------------

  test "call resets skip_update_callbacks=false in ensure block even on exception" do
    # initialize_game wird explodieren lassen
    @tm.stub(:initialize_game, -> { raise StandardError, "Test-Fehler" }) do
      assert_raises(StandardError) do
        TableMonitorJob.stub(:perform_later, ->(*) {}) do
          TableMonitor::GameSetup.call(table_monitor: @tm, options: @options)
        end
      end
    end

    assert_equal false, @tm.skip_update_callbacks,
      "skip_update_callbacks muss false sein, auch nach Ausnahme"
  end

  # ---------------------------------------------------------------------------
  # Test 10: assign-Zweig — weist game_id zu, ruft initialize_game und
  #           start_new_match! auf (ready-Zweig ohne tmp_results)
  # ---------------------------------------------------------------------------

  test "assign assigns game_id to model, calls initialize_game and start_new_match!" do
    # assign_game empfaengt ein Game-Objekt (als "game_p" = party game parameter),
    # das deep_delete! unterstuetzt. Wir verwenden ein echtes Game-Objekt.
    game = Game.create!(data: {})
    initialize_game_called = false
    start_new_match_called = false

    # Im ready-Zweig (kein tmp_results) ruft GameSetup: initialize_game und start_new_match! auf
    @tm.stub(:initialize_game, -> { initialize_game_called = true }) do
      @tm.stub(:start_new_match!, -> { start_new_match_called = true }) do
        TableMonitor::GameSetup.assign(table_monitor: @tm, game_participation: game)
      end
    end

    assert initialize_game_called, "initialize_game muss aufgerufen werden"
    assert start_new_match_called, "start_new_match! muss aufgerufen werden"

    @tm.reload
    assert_equal game.id, @tm.game_id,
      "game_id muss nach assign gesetzt sein"
  end
end
