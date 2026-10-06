# frozen_string_literal: true

require "test_helper"

# Biathlon (DBU-Regeln Biathlon §3, billardregel.de/kegel/biathlon/03-spiel-partie/):
# erst Dreiband bis zur Teildistanz bzw. Aufnahmebegrenzung, ohne Nachstoss; beim Wechsel
# werden die Dreibandpunkte mit dem Verrechnungsfaktor (6) multipliziert; danach 5-Kegel
# bis zur Gesamtpunktzahl, ueberschuessige Punkte zaehlen nicht.
#
# Wechsel fuer die GANZE Partie, sobald ein Spieler die Teildistanz erreicht (der Gegner
# bekommt keinen Dreiband-Nachstoss) oder beide die Aufnahmebegrenzung erreicht haben.
# Der folgende Spieler beginnt die Kegel-Phase.
#
# Anzeige (Betreiber 2026-10-06): in der Dreiband-Phase rohe 3B-Punkte, ×6 erst beim Wechsel.
class TableMonitor::ScoreEngineBiathlonTest < ActiveSupport::TestCase
  def biathlon_data(overrides = {})
    player = {
      "result" => 0, "innings" => 0, "innings_list" => [],
      "innings_redo_list" => [0], "innings_foul_list" => [],
      "innings_foul_redo_list" => [0], "hs" => 0, "gd" => 0.0,
      "balls_goal" => 180, "fouls_1" => 0, "discipline" => "Biathlon"
    }
    {
      "current_inning" => {"active_player" => "playera"},
      "current_kickoff_player" => "playera",
      "balls_on_table" => 15, "balls_counter" => 0, "balls_counter_stack" => [], "extra_balls" => 0,
      "playera" => player.deep_dup, "playerb" => player.deep_dup,
      "allow_overflow" => nil, "allow_follow_up" => false, "innings_goal" => 0,
      "biathlon_phase" => "3b",
      "biathlon" => {"balls_goal_3b" => 15, "innings_goal_3b" => 30, "factor" => 6}
    }.deep_merge(overrides)
  end

  def engine(data)
    TableMonitor::ScoreEngine.new(data, discipline: "Biathlon")
  end

  # Spielt eine Aufnahme des aktiven Spielers mit n Punkten und schliesst sie ab.
  def play_inning(data, n)
    e = engine(data)
    e.add_n_balls(n) if n.positive?
    e.terminate_inning_data(nil, playing: true)
  end

  # --- Dreiband-Phase ------------------------------------------------------

  test "Dreiband: Punkte zaehlen roh gegen die Teildistanz, nicht gegen das Gesamtziel" do
    data = biathlon_data
    play_inning(data, 7)

    assert_equal 7, data["playera"]["result"]
    assert_equal "3b", data["biathlon_phase"]
  end

  test "Dreiband: Erreichen der Teildistanz beendet die Aufnahme (goal_reached)" do
    data = biathlon_data("playera" => {"innings_list" => [12], "result" => 12})

    assert_equal :goal_reached, engine(data).add_n_balls(3)
  end

  test "Dreiband: Eingabe ueber die Teildistanz hinaus wird gekappt" do
    data = biathlon_data("playera" => {"innings_list" => [12], "result" => 12})

    engine(data).add_n_balls(5)

    assert_equal 3, data["playera"]["innings_redo_list"][-1]
  end

  test "Dreiband: Korrektur nach unten geht nicht unter null" do
    data = biathlon_data
    e = engine(data)
    e.add_n_balls(1)
    e.add_n_balls(-1)
    e.add_n_balls(-1)

    assert_equal 0, data["playera"]["innings_redo_list"][-1]
  end

  test "Dreiband: set_n_balls kappt an der Teildistanz und meldet goal_reached" do
    data = biathlon_data("playera" => {"innings_list" => [10], "result" => 10})

    assert_equal :goal_reached, engine(data).set_n_balls(9)
    assert_equal 5, data["playera"]["innings_redo_list"][-1]
  end

  # --- Wechsel bei Teildistanz --------------------------------------------

  test "Teildistanz erreicht: Wechsel auf 5-Kegel, beide Staende x6, Gegner ist dran" do
    data = biathlon_data(
      "playera" => {"innings_list" => [10], "result" => 10, "innings" => 1},
      "playerb" => {"innings_list" => [4], "result" => 4, "innings" => 1}
    )
    engine(data).add_n_balls(5)
    engine(data).terminate_inning_data(nil, playing: true)

    assert_equal "5k", data["biathlon_phase"]
    assert_equal 90, data["playera"]["result"]
    assert_equal 24, data["playerb"]["result"]
    assert_equal [60, 30], data["playera"]["innings_list"]
    assert_equal 15, data["playera"]["result_3b"]
    assert_equal 4, data["playerb"]["result_3b"]
    assert_equal 2, data["playera"]["innings_3b"]
    assert_equal "playerb", data["current_inning"]["active_player"]
  end

  test "Teildistanz aus den Spielparametern (10/20/120)" do
    data = biathlon_data(
      "biathlon" => {"balls_goal_3b" => 10, "innings_goal_3b" => 20},
      "playera" => {"innings_list" => [8], "result" => 8, "balls_goal" => 120},
      "playerb" => {"balls_goal" => 120}
    )

    assert_equal :goal_reached, engine(data).add_n_balls(2)
    engine(data).terminate_inning_data(nil, playing: true)

    assert_equal "5k", data["biathlon_phase"]
    assert_equal 60, data["playera"]["result"]
  end

  # --- Wechsel bei Aufnahmebegrenzung -------------------------------------

  test "Aufnahmebegrenzung: Wechsel erst, wenn beide Spieler sie erreicht haben (A stoesst an)" do
    data = biathlon_data("biathlon" => {"balls_goal_3b" => 15, "innings_goal_3b" => 2})

    play_inning(data, 1) # A 1
    play_inning(data, 1) # B 1
    play_inning(data, 1) # A 2
    assert_equal "3b", data["biathlon_phase"], "B hat seine 2. Aufnahme noch nicht gespielt"

    play_inning(data, 2) # B 2
    assert_equal "5k", data["biathlon_phase"]
    assert_equal 12, data["playera"]["result"]
    assert_equal 18, data["playerb"]["result"]
    assert_equal "playera", data["current_inning"]["active_player"]
  end

  test "Aufnahmebegrenzung greift auch, wenn B anstoesst" do
    data = biathlon_data(
      "current_inning" => {"active_player" => "playerb"},
      "current_kickoff_player" => "playerb",
      "biathlon" => {"balls_goal_3b" => 15, "innings_goal_3b" => 2}
    )

    play_inning(data, 1) # B 1
    play_inning(data, 1) # A 1
    play_inning(data, 1) # B 2
    assert_equal "3b", data["biathlon_phase"]

    play_inning(data, 1) # A 2
    assert_equal "5k", data["biathlon_phase"]
  end

  # --- Undo ueber den Wechsel ---------------------------------------------

  test "Undo direkt nach dem Wechsel kehrt in die Dreiband-Phase zurueck, ohne Faktor" do
    data = biathlon_data(
      "playera" => {"innings_list" => [10], "result" => 10, "innings" => 1},
      "playerb" => {"innings_list" => [4], "result" => 4, "innings" => 1}
    )
    engine(data).add_n_balls(5)
    engine(data).terminate_inning_data(nil, playing: true)
    assert_equal "5k", data["biathlon_phase"], "Testvoraussetzung"

    engine(data).undo_hash

    assert_equal "3b", data["biathlon_phase"]
    assert_equal "playera", data["current_inning"]["active_player"]
    assert_equal [10], data["playera"]["innings_list"]
    assert_equal 5, data["playera"]["innings_redo_list"][-1]
    assert_equal 4, data["playerb"]["result"]
  end

  test "Undo in der Kegel-Phase nach einer Kegel-Aufnahme bleibt in der Kegel-Phase" do
    data = biathlon_data(
      "playera" => {"innings_list" => [10], "result" => 10, "innings" => 1},
      "playerb" => {"innings_list" => [4], "result" => 4, "innings" => 1}
    )
    engine(data).add_n_balls(5)
    engine(data).terminate_inning_data(nil, playing: true) # Wechsel, B ist dran
    play_inning(data, 8) # B: erste Kegel-Aufnahme

    engine(data).undo_hash

    assert_equal "5k", data["biathlon_phase"]
    assert_equal 24, data["playerb"]["result"]
  end

  # --- Kegel-Phase --------------------------------------------------------

  test "Kegel: Punkte zaehlen gegen das Gesamtziel" do
    data = biathlon_data(
      "biathlon_phase" => "5k",
      "playera" => {"innings_list" => [90], "result" => 90}
    )
    play_inning(data, 20)

    assert_equal 110, data["playera"]["result"]
  end

  test "Kegel: ueberschuessige Punkte am Partieende werden gekappt" do
    data = biathlon_data(
      "biathlon_phase" => "5k",
      "playera" => {"innings_list" => [170], "result" => 170}
    )

    assert_equal :goal_reached, engine(data).add_n_balls(14)
    assert_equal 10, data["playera"]["innings_redo_list"][-1]
  end

  test "Kegel: kein erneuter Wechsel, keine erneute Multiplikation" do
    data = biathlon_data(
      "biathlon_phase" => "5k",
      "biathlon" => {"balls_goal_3b" => 15, "innings_goal_3b" => 1},
      "playera" => {"innings_list" => [90], "result" => 90, "innings" => 5},
      "playerb" => {"innings_list" => [30], "result" => 30, "innings" => 5}
    )
    play_inning(data, 2)

    assert_equal 92, data["playera"]["result"]
    assert_equal 30, data["playerb"]["result"]
  end
end
