# frozen_string_literal: true

require "test_helper"

# Charakterisierungstests fuer den TRAININGS-Finalisierungspfad (v0.3 Phase 1, Plan 01-01).
#
# Abgrenzung zu table_monitor_char_test.rb: dort wird die AASM als solche fixiert
# (alle Transitions, set_game_over, Broadcast-Verhalten). HIER geht es ausschliesslich
# um das freie Trainingsspiel — ein TableMonitor OHNE tournament_monitor — und darum,
# was beim Uebergang nach :final_match_score mit Game und GameParticipation passiert.
#
# Warum das noetig ist: TableMonitor::ResultRecorder#perform_evaluate_result feuert im
# Training zwar explizit finish_match! (result_recorder.rb:510-517), ruft die
# Ergebnisverbuchung aber ueber `@tm.tournament_monitor&.report_result(@tm)` auf —
# im Training ist tournament_monitor nil, die Safe-Navigation macht daraus einen No-op.
# Die Statistikfelder auf GameParticipation bleiben deshalb heute leer.
#
# Die Anlage selbst (GameSetup#create_new_game erzeugt Game + beide GameParticipations,
# und loest beim Folgespiel nur die Verknuepfung) ist bereits in
# test/services/table_monitor/game_setup_test.rb fixiert und wird hier nicht dupliziert;
# dieser Test setzt auf dem Ergebnis dieser Anlage auf.
#
# Hinweis zu IDs: in der Test-DB startet die games-Sequence bei 1, in Dev/Produktion
# dagegen oberhalb von MIN_ID (dort haben ALLE lokalen Spiele id >= 50_000_000).
# Trainings-Games werden hier daher mit expliziter id angelegt, damit sie der
# Produktionsrealitaet — und dem Game.training-Scope — entsprechen.
class TableMonitorTrainingFinalizeCharTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :players

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

  # Lokales Trainings-Game (id >= MIN_ID, keine Turnierbindung) inkl. beider
  # GameParticipations. Spiegelt, was GameSetup#create_new_game im Betrieb anlegt.
  def create_training_game(player_a: players(:jaspers), player_b: players(:cho))
    game = Game.create!(
      id: next_training_game_id,
      data: {},
      gname: "training_char_#{SecureRandom.hex(4)}"
    )
    GameParticipation.create!(game_id: game.id, player: player_a, role: "playera")
    GameParticipation.create!(game_id: game.id, player: player_b, role: "playerb")
    game.reload
  end

  def next_training_game_id
    @next_training_game_id = (@next_training_game_id || Game::MIN_ID) + 1
  end

  # TableMonitor im Zustand :final_set_score mit gespielten Werten — der Zustand,
  # aus dem heraus finish_match! nach :final_match_score fuehrt.
  def tm_ready_to_finish(game)
    tm = TableMonitor.create!(
      state: "final_set_score",
      data: {
        "playera" => {"result" => 30, "innings" => 20, "hs" => 6, "balls_goal" => 30},
        "playerb" => {"result" => 24, "innings" => 20, "hs" => 4, "balls_goal" => 30},
        "current_inning" => {"active_player" => "playera", "balls" => 0}
      }
    )
    tm.update_columns(game_id: game.id)
    tm.reload
  end

  def participation(game, role)
    game.game_participations.find_by(role: role)
  end

  # ===========================================================================
  # A. Was im Training bereits existiert
  # ===========================================================================

  test "freies Trainingsspiel hat Game und beide GameParticipations" do
    game = create_training_game

    assert_not_nil game.id
    assert_nil game.tournament_id, "Trainingsspiel darf keine Turnierbindung haben"
    assert_nil game.tournament_type
    assert_equal 2, game.game_participations.count
    assert_equal players(:jaspers).id, participation(game, "playera").player_id
    assert_equal players(:cho).id, participation(game, "playerb").player_id
  end

  test "TableMonitor ohne tournament_monitor ist der Trainingsfall" do
    tm = tm_ready_to_finish(create_training_game)

    assert_nil tm.tournament_monitor, "Trainingsmodus = kein tournament_monitor"
    assert_equal "final_set_score", tm.state
  end

  # ===========================================================================
  # B. Finalisierung: was heute passiert
  # ===========================================================================

  test "finish_match! bringt Trainingsspiel nach final_match_score" do
    tm = tm_ready_to_finish(create_training_game)

    tm.finish_match!

    assert tm.final_match_score?
    assert_equal "final_match_score", tm.state
  end

  test "finish_match! setzt game.ended_at (set_end_time-Callback)" do
    game = create_training_game
    tm = tm_ready_to_finish(game)
    assert_nil game.ended_at

    tm.finish_match!

    assert_not_nil game.reload.ended_at, "set_end_time muss ended_at setzen"
  end

  # VORHER/NACHHER: Bis Plan 01-01 Task 3 blieben hier ALLE Statistikfelder NULL —
  # das war die dokumentierte Luecke (tournament_monitor&.report_result ist im Training
  # ein No-op). Task 3 haengt TrainingResultRecorder als zweiten after-Callback an das
  # finish_match-Event; seitdem sind die Felder gefuellt. Die Erwartung ist bewusst
  # umgedreht worden.
  test "finish_match! verbucht die Statistikfelder beider GameParticipations" do
    game = create_training_game
    tm = tm_ready_to_finish(game)

    tm.finish_match!

    game.reload
    a = participation(game, "playera")
    b = participation(game, "playerb")

    assert_equal 30, a.result
    assert_equal 20, a.innings
    assert_equal 6, a.hs
    assert_in_delta 1.5, a.gd, 0.001
    assert_equal 1, a.sets
    assert_equal 2, a.points, "playera hat 30:24 gewonnen"

    assert_equal 24, b.result
    assert_equal 20, b.innings
    assert_equal 4, b.hs
    assert_in_delta 1.2, b.gd, 0.001
    assert_equal 1, b.sets
    assert_equal 0, b.points
  end

  # ===========================================================================
  # C. Historie ueberlebt — der Rematch loescht nichts
  # ===========================================================================

  test "Loesen der Verknuepfung laesst die Game-Zeile bestehen" do
    game = create_training_game
    tm = tm_ready_to_finish(game)
    game_id = game.id

    # Was create_new_game beim naechsten Spiel tut (game_setup.rb:411-412)
    game.update(table_monitor: nil)
    tm.update(game_id: nil)

    assert Game.exists?(game_id), "Game-Zeile muss das Loesen der Verknuepfung ueberleben"
    assert_equal 2, Game.find(game_id).game_participations.count,
      "GameParticipations muessen ebenfalls bestehen bleiben"
  end

  test "mehrere aufeinanderfolgende Trainingsspiele erzeugen mehrere Game-Zeilen" do
    first = create_training_game
    first.update(table_monitor: nil)
    second = create_training_game

    assert_not_equal first.id, second.id
    assert Game.exists?(first.id)
    assert Game.exists?(second.id)
  end
end
