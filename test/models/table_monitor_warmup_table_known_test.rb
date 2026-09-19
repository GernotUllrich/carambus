# frozen_string_literal: true

require "test_helper"

# Einspielzeit: kennt ein Spieler den Tisch schon (beendete Partie im selben Turnier an
# derselben Tischnummer), gilt time_out_warm_up_follow_up_min statt _first_min.
# Vorher lieferten player_a/b_on_table_before immer false.
class TableMonitorWarmupTableKnownTest < ActiveSupport::TestCase
  fixtures :players, :tournaments

  PLAYER_A = 50_001_010
  PLAYER_B = 50_001_011
  PLAYER_C = 50_001_012

  setup do
    @tournament = Tournament.first
    @next_id = Game::MIN_ID + 950
  end

  def create_game(table_no:, a:, b:, ended: false, tournament_id: @tournament.id)
    game = Game.create!(id: @next_id += 1, data: {}, gname: "wu_#{SecureRandom.hex(4)}",
      tournament_id: tournament_id, tournament_type: "Tournament", table_no: table_no,
      started_at: 2.hours.ago, ended_at: (ended ? 3.hours.ago : nil))
    GameParticipation.create!(game_id: game.id, player_id: a, role: "playera")
    GameParticipation.create!(game_id: game.id, player_id: b, role: "playerb")
    game
  end

  def tm_for(game)
    TableMonitor.create!(id: @next_id += 1, game: game, state: "warmup", data: {})
  end

  test "Spieler, der an diesem Tisch schon gespielt hat, kennt den Tisch" do
    create_game(table_no: 1, a: PLAYER_A, b: PLAYER_C, ended: true)
    tm = tm_for(create_game(table_no: 1, a: PLAYER_B, b: PLAYER_A))

    assert_not tm.player_a_on_table_before
    assert tm.player_b_on_table_before
  end

  test "Partie an einem anderen Tisch zählt nicht" do
    create_game(table_no: 2, a: PLAYER_A, b: PLAYER_C, ended: true)
    tm = tm_for(create_game(table_no: 1, a: PLAYER_A, b: PLAYER_B))

    assert_not tm.player_a_on_table_before
  end

  test "Partie in einem anderen Turnier zählt nicht" do
    other = Tournament.where.not(id: @tournament.id).first
    create_game(table_no: 1, a: PLAYER_A, b: PLAYER_C, ended: true, tournament_id: other.id)
    tm = tm_for(create_game(table_no: 1, a: PLAYER_A, b: PLAYER_B))

    assert_not tm.player_a_on_table_before
  end

  test "noch nicht beendete Partie zählt nicht" do
    create_game(table_no: 1, a: PLAYER_A, b: PLAYER_C, ended: false)
    tm = tm_for(create_game(table_no: 1, a: PLAYER_A, b: PLAYER_B))

    assert_not tm.player_a_on_table_before
  end

  test "erst nach dem Start der aktuellen Partie beendete Partie zählt nicht" do
    current = create_game(table_no: 1, a: PLAYER_A, b: PLAYER_B)
    create_game(table_no: 1, a: PLAYER_A, b: PLAYER_C, ended: true)
    current.update!(started_at: 4.hours.ago)
    tm = tm_for(current)

    assert_not tm.player_a_on_table_before
  end

  test "ohne Turnier oder Tischnummer: erste Einspielzeit" do
    tm = tm_for(create_game(table_no: nil, a: PLAYER_A, b: PLAYER_B))

    assert_not tm.player_a_on_table_before
  end
end
