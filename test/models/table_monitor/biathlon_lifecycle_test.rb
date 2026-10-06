# frozen_string_literal: true

require "test_helper"

# Biathlon im Turnier (2026-10-06): Turnierpartien laufen ueber assign_game/initialize_game,
# nicht ueber GameSetup#perform_start_game — und TournamentsController#start schreibt die
# innings_goal des Turniers nachtraeglich auf alle Tische. Die Partie darf darauf nicht
# hereinfallen: Biathlon hat keine Aufnahmebegrenzung fuer die Partie (nur fuer Dreiband,
# data["biathlon"]) und keinen Nachstoss (§3.2), egal was in innings_goal/allow_follow_up steht.
class TableMonitor::BiathlonLifecycleTest < ActiveSupport::TestCase
  def monitor_data(discipline:, phase: nil, a: {}, b: {}, extra: {})
    player = {"result" => 0, "innings" => 0, "innings_list" => [], "innings_redo_list" => [0],
              "innings_foul_list" => [], "innings_foul_redo_list" => [0], "balls_goal" => 180,
              "discipline" => discipline}
    {
      "current_inning" => {"active_player" => "playera"},
      "current_kickoff_player" => "playera", "current_left_player" => "playera",
      "innings_goal" => 30, "allow_follow_up" => true,
      "balls_on_table" => 15, "balls_counter" => 0, "balls_counter_stack" => [], "extra_balls" => 0,
      "biathlon_phase" => phase,
      "playera" => player.merge(a), "playerb" => player.merge(b)
    }.merge(extra)
  end

  def monitor(**kw)
    TableMonitor.new(state: "playing", data: monitor_data(**kw))
  end

  # --- end_of_set? ---------------------------------------------------------

  test "Biathlon: Gesamtziel erreicht beendet die Partie sofort, auch wenn allow_follow_up gesetzt ist" do
    tm = monitor(discipline: "Biathlon", phase: "5k",
      a: {"result" => 180, "innings" => 12}, b: {"result" => 150, "innings" => 11})

    assert tm.end_of_set?
  end

  test "Gegenprobe Dreiband: mit Nachstoss wartet die Partie auf den Ausgleich" do
    tm = monitor(discipline: "Dreiband gross", extra: {"innings_goal" => 0},
      a: {"result" => 30, "innings" => 12, "balls_goal" => 30}, b: {"result" => 20, "innings" => 11, "balls_goal" => 30})

    assert_not tm.end_of_set?
  end

  test "Biathlon: innings_goal der Partie beendet sie nicht (die Grenze gilt nur fuer Dreiband)" do
    tm = monitor(discipline: "Biathlon", phase: "5k",
      a: {"result" => 120, "innings" => 30}, b: {"result" => 100, "innings" => 30})

    assert_not tm.end_of_set?
  end

  test "Gegenprobe Dreiband: innings_goal erreicht beendet die Partie" do
    tm = monitor(discipline: "Dreiband gross",
      a: {"result" => 12, "innings" => 30, "balls_goal" => 30}, b: {"result" => 10, "innings" => 30, "balls_goal" => 30})

    assert tm.end_of_set?
  end

  # --- follow_up? ----------------------------------------------------------

  test "Biathlon: kein Nachstoss, auch wenn allow_follow_up gesetzt ist" do
    tm = monitor(discipline: "Biathlon", phase: "5k",
      a: {"result" => 180, "innings" => 12}, b: {"result" => 150, "innings" => 11},
      extra: {"current_inning" => {"active_player" => "playerb"}})

    assert_not tm.follow_up?
  end

  test "Gegenprobe Dreiband: Nachstoss nach Erreichen des Ziels" do
    tm = monitor(discipline: "Dreiband gross", extra: {"innings_goal" => 0, "current_inning" => {"active_player" => "playerb"}},
      a: {"result" => 30, "innings" => 1, "balls_goal" => 30}, b: {"result" => 0, "innings" => 0, "balls_goal" => 30})

    assert tm.follow_up?
  end

  # --- Rueckspiel ----------------------------------------------------------

  test "Rueckspiel uebernimmt die Biathlon-Variante" do
    variant = {"balls_goal_3b" => 10, "innings_goal_3b" => 15, "factor" => 6}
    tm = TableMonitor.create!(state: "playing", game: Game.create!(data: {}),
      data: monitor_data(discipline: "Biathlon", phase: "5k", extra: {"biathlon" => variant}))
    captured = nil
    tm.define_singleton_method(:start_game) { |options| captured = options }

    tm.revert_players

    assert_equal variant, captured["biathlon"]
  end

  # --- ScoreEngine: Aufnahmezaehlung ---------------------------------------

  test "Biathlon: innings_goal der Partie sperrt weder den Spielerwechsel noch die Zaehlung" do
    data = monitor_data(discipline: "Biathlon", phase: "5k", extra: {"innings_goal" => 2},
      a: {"innings" => 2, "innings_list" => [60, 6], "result" => 66})
    engine = TableMonitor::ScoreEngine.new(data, discipline: "Biathlon")

    assert_equal :ok, engine.terminate_inning_data(nil, playing: true)
    assert_equal 3, data["playera"]["innings"]
  end
end
