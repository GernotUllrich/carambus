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
    assert_equal Game.last.id, @tm.game_id,
      "game_id muss dem zuletzt angelegten Game entsprechen"
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
  # Test 6: suppress_broadcast wird vor Saves gesetzt
  # ---------------------------------------------------------------------------

  test "call sets suppress_broadcast=true before saves, resets after" do
    callbacks_during = []
    original_save = @tm.method(:save!)

    # Wir pruefen: wenn save! aufgerufen wird, ist suppress_broadcast true
    @tm.stub(:save!, -> {
      callbacks_during << @tm.suppress_broadcast
      original_save.call
    }) do
      call_setup
    end

    assert callbacks_during.any? { |v| v == true },
      "suppress_broadcast muss waehrend save! true sein"
    # Nach dem Call muss es false sein
    assert_equal false, @tm.suppress_broadcast
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

  test "call resets suppress_broadcast=false in ensure block even on exception" do
    # initialize_game wird explodieren lassen
    @tm.stub(:initialize_game, -> { raise StandardError, "Test-Fehler" }) do
      assert_raises(StandardError) do
        TableMonitorJob.stub(:perform_later, ->(*) {}) do
          TableMonitor::GameSetup.call(table_monitor: @tm, options: @options)
        end
      end
    end

    assert_equal false, @tm.suppress_broadcast,
      "suppress_broadcast muss false sein, auch nach Ausnahme"
  end

  # ---------------------------------------------------------------------------
  # BK2-Kombi derivation tests (Phase 38.1 Plan 02)
  # ---------------------------------------------------------------------------

  # Baut einen Mock-TournamentMonitor, der einen Mock-Tournament mit der
  # angegebenen Discipline zurueckgibt. Vermeidet komplexe DB-Aufbauten
  # (Season, Region/Organizer) fuer reine Derivations-Unit-Tests.
  def build_mock_tournament_monitor(discipline_name:, discipline_data_json: nil)
    mock_discipline = OpenStruct.new(
      id: 107,
      name: discipline_name,
      data: discipline_data_json
    )
    mock_tournament = OpenStruct.new(
      discipline: mock_discipline,
      is_a?: ->(klass) { klass == Tournament }
    )
    mock_tournament.define_singleton_method(:is_a?) { |klass| klass == Tournament }
    mock_tm_monitor = OpenStruct.new(
      tournament: mock_tournament,
      innings_goal: nil,
      sets_to_win: nil,
      sets_to_play: nil,
      team_size: nil,
      timeouts: nil,
      timeout: nil,
      balls_goal: nil,
      allow_overflow: nil,
      allow_follow_up: nil,
      kickoff_switches_with: nil,
      allow_change_tables: nil,
      is_a?: ->(klass) { false }
    )
    mock_tm_monitor.define_singleton_method(:is_a?) { |klass| false }
    mock_tm_monitor
  end

  # Stub-Hilfsmethode: fuehrt GameSetup.call mit einem mock tournament_monitor aus
  def call_setup_with_mock_tm_monitor(mock_tm_monitor, extra_options: {})
    @tm.define_singleton_method(:tournament_monitor) { mock_tm_monitor }
    warnings = []
    Rails.logger.stub(:warn, ->(msg) { warnings << msg }) do
      TableMonitorJob.stub(:perform_later, ->(*) {}) do
        TableMonitor::GameSetup.call(table_monitor: @tm, options: @options.merge(extra_options))
      end
    end
    @tm.reload
    warnings
  end

  test "GameSetup derives free_game_form=bk2_kombi when discipline.data contains it" do
    data_json = JSON.generate({"free_game_form" => "bk2_kombi"})
    mock_tm_monitor = build_mock_tournament_monitor(
      discipline_name: "BK2-Kombi",
      discipline_data_json: data_json
    )

    warnings = call_setup_with_mock_tm_monitor(mock_tm_monitor, extra_options: {"free_game_form" => nil})

    assert_equal "bk2_kombi", @tm.data["free_game_form"],
      "free_game_form muss bk2_kombi sein wenn discipline.data es enthaelt"
    # Kein Warning bei authoritative path
    refute warnings.any? { |msg| msg.to_s.match?(/reconcil/i) },
      "Kein Reconciliation-Warning bei authoritative discipline.data"
  end

  test "GameSetup falls back to name match when discipline.data is nil; logs reconciliation warning" do
    mock_tm_monitor = build_mock_tournament_monitor(
      discipline_name: "BK2-Kombi",
      discipline_data_json: nil
    )

    warnings = call_setup_with_mock_tm_monitor(mock_tm_monitor, extra_options: {"free_game_form" => nil})

    assert_equal "bk2_kombi", @tm.data["free_game_form"],
      "free_game_form muss bk2_kombi sein beim Name-Fallback"
    assert warnings.any? { |msg| msg.to_s.match?(/reconcil|BK2.*discipline\.data/i) },
      "Reconciliation-Warnung muss geloggt werden (gefunden: #{warnings.inspect})"
  end

  test "GameSetup does NOT set free_game_form=bk2_kombi for unrelated disciplines" do
    mock_tm_monitor = build_mock_tournament_monitor(
      discipline_name: "Freie Partie",
      discipline_data_json: nil
    )

    call_setup_with_mock_tm_monitor(mock_tm_monitor, extra_options: {"free_game_form" => nil})

    refute_equal "bk2_kombi", @tm.data["free_game_form"],
      "free_game_form darf nicht bk2_kombi sein fuer nicht-BK2-Disziplinen"
  end

  test "GameSetup preserves existing pool/snooker derivation logic" do
    # Wenn discipline.data free_game_form=snooker enthaelt, muss snooker erhalten bleiben
    data_json = JSON.generate({"free_game_form" => "snooker"})
    mock_tm_monitor = build_mock_tournament_monitor(
      discipline_name: "Snooker",
      discipline_data_json: data_json
    )

    call_setup_with_mock_tm_monitor(mock_tm_monitor, extra_options: {
      "free_game_form" => "snooker",
      "balls_on_table" => 15,
      "initial_red_balls" => 15
    })

    assert_equal "snooker", @tm.data["free_game_form"],
      "free_game_form muss snooker bleiben (kein Regression fuer bestehende Pfade)"
  end

  # ---------------------------------------------------------------------------
  # Phase 38.7 Plan 04 — start_game tiebreak_required bake integration tests.
  #
  # Verifiziert dass perform_start_game game.data['tiebreak_required'] aus dem
  # Game.derive_tiebreak_required Resolver schreibt (3 Levels — Discipline-Level
  # entfernt 2026-04-30 per User-Feedback; Trainings-Sources kommen in einer
  # Folge-Phase):
  #   - Training (any discipline): false (no tournament/plan → default false)
  #   - Idempotent across re-runs
  #   - TournamentPlan group override path lands in game.data
  # ---------------------------------------------------------------------------

  # Builds an OpenStruct mock for tournament_monitor.tournament.tournament_plan
  # so we can exercise the Plan-level override path without DB fixture chains.
  def build_mock_tm_with_plan(tournament_data:, plan_executor_params:, group_no: nil)
    mock_plan = OpenStruct.new(executor_params: plan_executor_params)
    mock_tournament = OpenStruct.new(
      data: tournament_data,
      tournament_plan: mock_plan
    )
    mock_tournament.define_singleton_method(:is_a?) { |klass| klass == Tournament }
    mock_tm_monitor = OpenStruct.new(
      tournament: mock_tournament,
      innings_goal: nil,
      sets_to_win: nil,
      sets_to_play: nil,
      team_size: nil,
      timeouts: nil,
      timeout: nil,
      balls_goal: nil,
      allow_overflow: nil,
      allow_follow_up: nil,
      kickoff_switches_with: nil,
      allow_change_tables: nil
    )
    mock_tm_monitor.define_singleton_method(:is_a?) { |_klass| false }
    [mock_tm_monitor, group_no]
  end

  test "start_game writes game.data['tiebreak_required']=false for training BK-2 match (no tournament)" do
    # Training mode: no tournament_monitor → resolver returns false (no Level-3
    # Discipline source any more). A follow-up gap-closure plan adds training
    # sources (carambus.yml preset, detail-form toggle, BK-2kombi auto-detect).
    options = @options.merge("discipline_a" => "BK-2", "discipline_b" => "BK-2", "free_game_form" => "bk_2")
    call_setup(options: options)
    @tm.reload
    assert_equal false, @tm.game.data["tiebreak_required"],
      "Training BK-2 must currently default to false — training sources land in a follow-up plan"
  end

  test "start_game writes game.data['tiebreak_required']=false for training Karambol match" do
    # Training mode + Karambol discipline → no tournament/plan source → default false.
    options = @options.merge("discipline_a" => "Dreiband", "discipline_b" => "Dreiband", "free_game_form" => nil)
    call_setup(options: options)
    @tm.reload
    assert_equal false, @tm.game.data["tiebreak_required"],
      "Karambol training match must default to false"
  end

  test "start_game tiebreak_required bake is idempotent across re-runs" do
    options = @options.merge("discipline_a" => "BK-2", "discipline_b" => "BK-2", "free_game_form" => "bk_2")

    call_setup(options: options)
    first_value = @tm.game.reload.data["tiebreak_required"]

    call_setup(options: options)
    second_value = @tm.game.reload.data["tiebreak_required"]

    assert_equal first_value, second_value, "Bake must be deterministic"
    assert_equal false, second_value
  end

  test "derive_tiebreak_required returns true when only TournamentPlan group says so" do
    # Tournament.data has no key → resolver falls through to Plan level → true.
    mock_tm_monitor, _ = build_mock_tm_with_plan(
      tournament_data: {},  # no tiebreak_on_draw key
      plan_executor_params: {"g1" => {"tiebreak_on_draw" => true, "balls" => 100}}.to_json
    )

    plan_value = Game.derive_tiebreak_required(
      tournament: mock_tm_monitor.tournament,
      tournament_plan: mock_tm_monitor.tournament.tournament_plan,
      group_no: "1"
    )
    assert_equal true, plan_value,
      "TournamentPlan group-level override must propagate via derive_tiebreak_required"
  end

  # ----------------------------------------------------------------
  # Phase 38.7 Plan 09 — Gap-01: carambus.yml quick_game_presets
  # tiebreak_on_draw source.
  # The resolver baked at start_game (Plan 04) returns false in training mode
  # (no Tournament). The preset value, if truthy, MUST override the resolver's
  # default-false via deep_merge_data! AFTER the resolver bake. Sparse-override
  # consistent with Phase 38.5 D-06.
  #
  # G1 is the load-bearing RED test. G2 + G3 are regression characterization
  # tests that should already pass against the current resolver-only path;
  # they exist to lock the sparse-absence and explicit-false contracts.
  # ----------------------------------------------------------------

  test "G1 (Gap-01): preset tiebreak_on_draw=true bakes tiebreak_required=true on game.data" do
    @tm.assign_attributes(tournament_monitor_id: nil)
    @tm.save!(validate: false)

    TableMonitor::GameSetup.call(
      table_monitor: @tm,
      options: {
        "player_a_id" => @player_a.id, "player_b_id" => @player_b.id,
        "discipline_a" => "BK-2", "discipline_b" => "BK-2",
        "free_game_form" => "bk_2", "quick_game_form" => "bk_family",
        "balls_goal" => 50, "balls_goal_a" => 50, "balls_goal_b" => 50,
        "innings_goal" => 0, "sets_to_win" => 1, "sets_to_play" => 1,
        "kickoff_switches_with" => "set", "first_break_choice" => 0,
        "tiebreak_on_draw" => true
      }
    )

    @tm.reload
    assert_equal true, @tm.game.data["tiebreak_required"],
      "Gap-01: BK-2 preset with tiebreak_on_draw=true must bake tiebreak_required=true"
  end

  test "G2 (Gap-01): preset without tiebreak_on_draw key bakes tiebreak_required=false (regression)" do
    @tm.assign_attributes(tournament_monitor_id: nil)
    @tm.save!(validate: false)

    TableMonitor::GameSetup.call(
      table_monitor: @tm,
      options: {
        "player_a_id" => @player_a.id, "player_b_id" => @player_b.id,
        "discipline_a" => "Dreiband klein", "discipline_b" => "Dreiband klein",
        "free_game_form" => "karambol", "quick_game_form" => "karambol",
        "balls_goal_a" => 30, "balls_goal_b" => 30,
        "innings_goal" => 25, "sets_to_win" => 0, "sets_to_play" => 1,
        "kickoff_switches_with" => "set", "first_break_choice" => 0,
        "allow_follow_up" => true
        # NOTE: no "tiebreak_on_draw" key
      }
    )

    @tm.reload
    assert_equal false, @tm.game.data["tiebreak_required"],
      "Gap-01: Karambol preset without tiebreak_on_draw must default to tiebreak_required=false"
  end

  test "G3 (Gap-01): explicit preset tiebreak_on_draw=false bakes tiebreak_required=false (sparse override)" do
    @tm.assign_attributes(tournament_monitor_id: nil)
    @tm.save!(validate: false)

    TableMonitor::GameSetup.call(
      table_monitor: @tm,
      options: {
        "player_a_id" => @player_a.id, "player_b_id" => @player_b.id,
        "discipline_a" => "BK-2", "discipline_b" => "BK-2",
        "free_game_form" => "bk_2", "quick_game_form" => "bk_family",
        "balls_goal" => 50, "balls_goal_a" => 50, "balls_goal_b" => 50,
        "innings_goal" => 0, "sets_to_win" => 1, "sets_to_play" => 1,
        "kickoff_switches_with" => "set", "first_break_choice" => 0,
        "tiebreak_on_draw" => false
      }
    )

    @tm.reload
    assert_equal false, @tm.game.data["tiebreak_required"],
      "Gap-01: explicit preset tiebreak_on_draw=false must bake tiebreak_required=false (sparse override)"
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
