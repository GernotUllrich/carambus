# frozen_string_literal: true

require "test_helper"

# Tests fuer TableMonitor#finalize_if_decided (Milestone v0.3, Plan 01-02).
#
# Deckt ab:
#   A. Finalisierung aus playing / set_over / final_set_score (AC-1, AC-3)
#   B. No-op bei unentschiedenem Spiel (AC-2)
#   C. No-op im Turnier-/Ligabetrieb und ohne Game (AC-5)
#   D. Ausstehender Tiebreak wirft nicht (AC-6)
#   E. Zusammenspiel mit Plan 01-01: nach der Finalisierung steht die Statistik
#
# ⚠️ IDs: in der Test-DB startet die games-Sequence bei 1, in Dev/Produktion oberhalb
# von MIN_ID. Trainings-Games daher mit EXPLIZITER id >= Game::MIN_ID anlegen —
# sonst greift der Game.training-Scope nicht.
class TableMonitorFinalizeIfDecidedTest < ActiveSupport::TestCase
  fixtures :players, :seasons, :season_participations, :clubs, :locations, :tournaments

  PLAYER_A = 50_001_010 # nbv_ullrich
  PLAYER_B = 50_001_011 # nbv_andresen

  setup do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
    @next_id = Game::MIN_ID + 900
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

  def next_id
    @next_id += 1
  end

  def create_game(id: next_id, tournament_id: nil)
    game = Game.create!(id: id, data: {}, gname: "fid_#{SecureRandom.hex(4)}", tournament_id: tournament_id)
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_A, role: "playera")
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_B, role: "playerb")
    game.reload
  end

  # decided: playera hat sein balls_goal erreicht -> end_of_set? == true
  # undecided: beide unter dem Ziel
  def build_tm(game:, state: "playing", decided: true, extra: {})
    a_result = decided ? 30 : 12
    tm = TableMonitor.create!(
      state: state,
      data: {
        "playera" => {"result" => a_result, "innings" => 20, "hs" => 6, "balls_goal" => 30},
        "playerb" => {"result" => 18, "innings" => 20, "hs" => 4, "balls_goal" => 30},
        "innings_goal" => 0,
        "allow_follow_up" => false,
        "current_inning" => {"active_player" => "playera", "balls" => 0}
      }.merge(extra)
    )
    tm.update_columns(game_id: game.id)
    tm.reload
  end

  def gp(game, role)
    game.game_participations.find_by(role: role)
  end

  # ===========================================================================
  # A. Finalisierung aus den verschiedenen Ausgangszustaenden
  # ===========================================================================

  test "A1: entschiedenes Spiel wird aus playing finalisiert" do
    tm = build_tm(game: create_game, state: "playing")
    assert tm.end_of_set?, "Testaufbau: Spiel muss entschieden sein"

    assert tm.finalize_if_decided

    assert_equal "final_match_score", tm.reload.state
  end

  test "A2: entschiedenes Spiel wird aus set_over finalisiert" do
    tm = build_tm(game: create_game, state: "set_over")

    assert tm.finalize_if_decided

    assert_equal "final_match_score", tm.reload.state
  end

  test "A3: entschiedenes Spiel wird aus final_set_score finalisiert" do
    tm = build_tm(game: create_game, state: "final_set_score")

    assert tm.finalize_if_decided

    assert_equal "final_match_score", tm.reload.state
  end

  # ===========================================================================
  # B. Unentschiedene Spiele bleiben unangetastet (AC-2)
  # ===========================================================================

  test "B1: unentschiedenes Spiel wird nicht finalisiert" do
    tm = build_tm(game: create_game, state: "playing", decided: false)
    assert_not tm.end_of_set?, "Testaufbau: Spiel darf nicht entschieden sein"

    assert_not tm.finalize_if_decided

    assert_equal "playing", tm.reload.state
  end

  test "B2: bereits finalisiertes Spiel meldet false (keine Doppelverarbeitung)" do
    tm = build_tm(game: create_game, state: "final_set_score")
    tm.finalize_if_decided
    assert_equal "final_match_score", tm.reload.state

    assert_not tm.finalize_if_decided, "zweiter Aufruf darf nicht erneut finalisieren"
  end

  # ===========================================================================
  # C. No-op ausserhalb des Trainings (AC-5)
  # ===========================================================================

  test "C1: kein Eingriff wenn tournament_monitor gesetzt ist" do
    tm = build_tm(game: create_game, state: "playing")
    tm.define_singleton_method(:tournament_monitor) { TournamentMonitor.new }

    assert_not tm.finalize_if_decided
    assert_equal "playing", tm.reload.state
  end

  test "C2: kein Eingriff bei einem Spiel mit Turnierbindung" do
    tm = build_tm(game: create_game(tournament_id: tournaments(:local).id), state: "playing")

    assert_not tm.finalize_if_decided
    assert_equal "playing", tm.reload.state
  end

  test "C3: kein Eingriff bei globalem Spiel (id < MIN_ID)" do
    tm = build_tm(game: create_game(id: 4713), state: "playing")

    assert_not tm.finalize_if_decided
    assert_equal "playing", tm.reload.state
  end

  test "C4: kein Eingriff ohne Game" do
    tm = TableMonitor.create!(state: "playing", data: {})

    assert_not tm.finalize_if_decided
  end

  test "C5: leeres data fuehrt nicht zur Ausnahme" do
    game = create_game
    tm = TableMonitor.create!(state: "playing", data: {})
    tm.update_columns(game_id: game.id)
    tm.reload

    assert_nothing_raised { assert_not tm.finalize_if_decided }
  end

  # ===========================================================================
  # D. Tiebreak (AC-6)
  # ===========================================================================

  test "D1: ausstehender Tiebreak-Pick blockiert ohne Ausnahme" do
    game = create_game
    # tiebreak_pending_block? verlangt ALLE drei Bedingungen (table_monitor.rb:1855ff):
    # game.data["tiebreak_required"] == true, kein tiebreak_winner, UND Gleichstand.
    # Deshalb 30:30 — beide erreichen zugleich das balls_goal, end_of_set? ist true.
    tm = build_tm(game: game, state: "set_over",
      extra: {"playerb" => {"result" => 30, "innings" => 20, "hs" => 4, "balls_goal" => 30}})
    game.deep_merge_data!("tiebreak_required" => true)
    game.save!
    tm.reload

    assert tm.end_of_set?, "Testaufbau: Spiel muss entschieden sein"
    assert_not tm.may_acknowledge_result?, "Testaufbau: Tiebreak-Guard muss greifen"

    assert_nothing_raised do
      assert_not tm.finalize_if_decided
    end
    assert_equal "set_over", tm.reload.state, "TableMonitor muss in seinem Zustand bleiben"
  end

  # ===========================================================================
  # E. Zusammenspiel mit Plan 01-01
  # ===========================================================================

  test "E1: nach der Finalisierung tragen beide Teilnehmer die Statistik" do
    game = create_game
    tm = build_tm(game: game, state: "playing")

    assert tm.finalize_if_decided

    game.reload
    assert_equal 30, gp(game, "playera").result
    assert_equal 18, gp(game, "playerb").result
    assert_equal 2, gp(game, "playera").points, "playera hat 30:18 gewonnen"
    assert_in_delta 1.5, gp(game, "playera").gd, 0.001
  end
end
