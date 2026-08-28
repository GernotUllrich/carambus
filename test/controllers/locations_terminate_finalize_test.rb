# frozen_string_literal: true

require "test_helper"

# Milestone v0.3 Plan 01-02 — Abbruch-Pfad des Scoreboards
# (LocationsController#show, params[:terminate_game_id]).
#
# Bisher traf JEDES freie Spiel (tournament.blank?) den destroy-Zweig
# (locations_controller.rb) — mitsamt `dependent: :destroy` auf game_participations.
# Damit vernichtete ein Abbruch die von Plan 01-01 geschriebene Statistik.
#
# Neu: Ist das Trainingsspiel ENTSCHIEDEN, wird es zuvor nach :final_match_score
# finalisiert und behalten; der Tisch wird nur freigegeben. Unentschiedene Spiele
# werden weiterhin geloescht (Betreiber-Entscheidung 2026-08-28).
#
# Testhinweise (uebernommen aus locations_terminate_external_hold_test.rb):
#   - Ein User ist angemeldet, damit set_location nicht in den Scoreboard-Bypass laeuft.
#   - TableMonitorJob.perform_later wird gestubbt: reset_table_monitor/Zustandswechsel
#     stossen Broadcasts an, deren Partial eine vollstaendige Table/Location-Kette
#     braucht, die der synthetische TableMonitor hier nicht hat.
#   - ⚠️ Games mit EXPLIZITER id >= Game::MIN_ID: in der Test-DB startet die Sequence
#     bei 1, und Game.training verlangt lokale IDs.
class LocationsTerminateFinalizeTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @location = locations(:one)
    @player_a = Player.create!(id: 50_100_411, firstname: "FinA", lastname: "Test", dbu_nr: 41_111, ba_id: 41_111)
    @player_b = Player.create!(id: 50_100_412, firstname: "FinB", lastname: "Test", dbu_nr: 41_112, ba_id: 41_112)
    @next_id = Game::MIN_ID + 1200
  end

  teardown do
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
  end

  # Freies Trainingsspiel (kein tournament_id) im Zustand :playing.
  # decided: playera erreicht sein balls_goal -> end_of_set? == true
  def build_training_game(decided:)
    @next_id += 1
    game = Game.create!(id: @next_id, tournament_id: nil, data: {}, gname: "term_fin")
    GameParticipation.create!(game: game, player: @player_a, role: "playera")
    GameParticipation.create!(game: game, player: @player_b, role: "playerb")
    TableMonitor.create!(
      state: "playing", game: game,
      data: {
        "playera" => {"result" => decided ? 30 : 12, "innings" => 20, "hs" => 6, "balls_goal" => 30},
        "playerb" => {"result" => 18, "innings" => 20, "hs" => 4, "balls_goal" => 30},
        "innings_goal" => 0,
        "allow_follow_up" => false
      }
    )
    game.reload
  end

  def terminate(game)
    TableMonitorJob.stub(:perform_later, nil) do
      get location_path(@location, sb_state: "tables", terminate_game_id: game.id)
    end
  end

  test "entschiedenes Trainingsspiel ueberlebt den Abbruch und traegt die Statistik" do
    game = build_training_game(decided: true)
    assert game.table_monitor.end_of_set?, "Vorbedingung: Spiel muss entschieden sein"

    terminate(game)

    assert Game.exists?(game.id), "entschiedenes Trainingsspiel darf NICHT geloescht werden"
    game.reload
    a = game.game_participations.find_by(role: "playera")
    b = game.game_participations.find_by(role: "playerb")
    assert_equal 30, a.result, "Statistik muss geschrieben sein (Plan 01-01)"
    assert_equal 18, b.result
    assert_equal 2, a.points
    assert_not_equal "playing", game.table_monitor&.state.to_s,
      "der Tisch darf nicht im laufenden Spiel haengenbleiben"
  end

  test "unentschiedenes Trainingsspiel wird beim Abbruch geloescht wie bisher" do
    game = build_training_game(decided: false)
    assert_not game.table_monitor.end_of_set?, "Vorbedingung: Spiel darf nicht entschieden sein"
    game_id = game.id

    terminate(game)

    assert_not Game.exists?(game_id), "unentschiedenes Spiel wird verworfen (unveraendertes Verhalten)"
  end
end
