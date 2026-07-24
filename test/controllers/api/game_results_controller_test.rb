# frozen_string_literal: true

require "test_helper"

# Plan 32-08: Empfang einzelner Spielergebnisse auf dem Region Server.
#
# Abgrenzung zu Api::TournamentResultsControllerTest (29-03): dort die Gesamtrangliste beim
# Turnier-Abschluss, hier einzelne Spiele waehrend des Turniers.
#
# Dieser Weg ist ein SCHREIB-Weg und bleibt authentifiziert (Betreiber-Entscheidung D9) — die
# oeffentliche Lese-Sicht entsteht in Plan 32-10 daneben.
class Api::GameResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @user = users(:one)
    @plan = tournament_plans(:t06_6)

    @tournament = Tournament.create!(
      id: 50_000_910,
      title: "Landesmeisterschaft Dreiband", shortname: "LM3B910",
      season: @season, organizer: @region, region_id: @region.id,
      tournament_plan_id: @plan.id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )

    Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 111_111)
    Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 222_222)
  end

  def game_row(group: "Gruppe A", seqno: 7)
    {
      "group" => group, "seqno" => seqno, "ended_at" => "2026-10-10T14:12:00+02:00",
      "participations" => [
        {"dbu_nr" => "111111", "role" => "playera", "result" => 100, "innings" => 24, "hs" => 16, "gd" => 4.17},
        {"dbu_nr" => "222222", "role" => "playerb", "result" => 85, "innings" => 24, "hs" => 9, "gd" => 3.54}
      ]
    }
  end

  def post_games(source_tournament_id: @tournament.id, games: [game_row], **extra)
    post api_game_results_url,
      params: {schema: "carambus.game_result/v1", target_type: "Tournament",
               source_tournament_id: source_tournament_id, games: games}.merge(extra),
      as: :json
  end

  # AC-5
  test "ohne Authentifizierung kein Zugriff" do
    assert_no_difference("Game.count") { post_games }
    refute_equal 200, response.status, "unauthentifiziert darf kein Ergebnis angenommen werden"
  end

  # AC-1 durch den Endpunkt
  test "nimmt eine Ergebniszeile an und legt das lokale Spiel an" do
    sign_in @user
    post_games

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["accepted"]
    assert_equal 0, body["updated"]
    assert_empty body["unresolved"]
    assert_equal "Gruppe A", @tournament.games.sole.gname
  end

  test "zweiter Push derselben Partie meldet updated statt accepted" do
    sign_in @user
    post_games
    post_games

    assert_response :success
    assert_equal 1, JSON.parse(response.body)["updated"]
    assert_equal 1, @tournament.games.count
  end

  test "unbekanntes Turnier liefert 404 statt etwas anzulegen" do
    sign_in @user
    assert_no_difference(["Tournament.count", "Game.count"]) do
      post_games(source_tournament_id: 999_999_999)
    end
    assert_response :not_found
  end

  # AC-4
  test "globales Turnier wird abgewiesen" do
    global = Tournament.create!(
      id: 12_345, title: "Globales Turnier", shortname: "GLOB345",
      season: @season, organizer: @region, region_id: @region.id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )

    sign_in @user
    assert_no_difference("Game.count") { post_games(source_tournament_id: global.id) }
    assert_response :unprocessable_entity
  end

  test "fehlende games-Liste wird abgewiesen" do
    sign_in @user
    post api_game_results_url,
      params: {source_tournament_id: @tournament.id}, as: :json

    assert_response :unprocessable_entity
  end

  # Das Schemafeld haelt den Kanal fuer CC-lose Ligen offen — heute wird nur "Tournament" bedient.
  test "unbekanntes target_type wird abgewiesen" do
    sign_in @user
    assert_no_difference("Game.count") { post_games(target_type: "Party") }

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["error"], "Party"
  end

  test "abweichender Turnierplan liefert 422" do
    sign_in @user
    assert_no_difference("Game.count") do
      post_games(tournament_plan_id: tournament_plans(:t04_5).id)
    end

    assert_response :unprocessable_entity
  end

  test "unbekannte dbu_nr wird berichtet, nicht angelegt" do
    sign_in @user
    broken = game_row.merge("participations" => [
      {"dbu_nr" => "999999", "role" => "playera", "result" => 100},
      {"dbu_nr" => "222222", "role" => "playerb", "result" => 85}
    ])

    assert_no_difference(["Player.count", "Game.count"]) { post_games(games: [broken]) }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 0, body["accepted"]
    assert_includes body["unresolved"].first, "999999"
  end
end
