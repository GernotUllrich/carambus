# frozen_string_literal: true

require "test_helper"

# Plan 29-03: Empfang des Turnier-Abschlusses auf dem Region Server.
# Der Location Server meldet hierher; von hier traegt der Ingest (28-01) auf die Authority.
class Api::TournamentResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @user = users(:one)

    @tournament = Tournament.create!(
      title: "Landesmeisterschaft Dreiband", shortname: "LM3B293",
      season: @season, organizer: @region, region_id: @region.id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    @player = Player.create!(lastname: "SIEGER", firstname: "Sina", fl_name: "S. Sieger", dbu_nr: 515_151)
    @seeding = @tournament.seedings.create!(player_id: @player.id, position: 1)
  end

  def ranking(rang: 1)
    {"Rang" => rang, "Name" => "Sieger, Sina", "Bälle" => 120, "Aufn" => 106,
     "GD" => 1.132, "HS" => 5, "BED" => 1.29, "Punkte" => 4}
  end

  def post_result(source_tournament_id: @tournament.id, entries: [{"dbu_nr" => 515_151, "Gesamtrangliste" => ranking}])
    post api_tournament_results_url,
      params: {source_tournament_id: source_tournament_id, entries: entries},
      as: :json
  end

  def gesamtrangliste
    @seeding.reload.data.dig("result", "Gesamtrangliste")
  end

  test "ohne Authentifizierung kein Zugriff" do
    post_result
    refute_equal 200, response.status, "unauthentifiziert darf kein Ergebnis angenommen werden"
    assert_nil gesamtrangliste
  end

  test "uebernimmt die Gesamtrangliste auf das Seeding" do
    sign_in @user
    post_result

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["accepted"]

    entry = gesamtrangliste
    assert_equal 1, entry["Rang"]
    assert_equal 120, entry["Bälle"]
    assert_equal 4, entry["Punkte"], "Partiepunkte muessen von den Baellen unterscheidbar bleiben"
    assert_equal "carambus", @seeding.reload.data["result_source"], "Provenienz-Marke muss gesetzt sein"
  end

  test "unbekanntes Turnier liefert 404 statt etwas anzulegen" do
    sign_in @user
    assert_no_difference("Tournament.count") do
      post_result(source_tournament_id: 999_999_999)
    end
    assert_response :not_found
  end

  test "unbekannte dbu_nr wird berichtet, nicht angelegt" do
    sign_in @user
    assert_no_difference(["Player.count", "Seeding.count"]) do
      post_result(entries: [{"dbu_nr" => 999_999, "Gesamtrangliste" => ranking}])
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 0, body["accepted"]
    assert_equal 1, body["unresolved"].size
    assert_includes body["unresolved"].first, "999999"
  end

  # Schutzlinie: eine aus der ClubCloud gescrapte Rangliste gehoert der CC.
  test "gescrapte Gesamtrangliste wird nicht ueberschrieben" do
    scraped = {"Rang" => 9, "Punkte" => "99", "Name" => "Aus der CC"}
    @seeding.update!(data: {"result" => {"Gesamtrangliste" => scraped}})

    sign_in @user
    post_result

    assert_response :success
    assert_equal scraped, gesamtrangliste
    assert_equal 1, JSON.parse(response.body)["skipped_foreign"]
  end

  test "zweiter Aufruf aendert nichts" do
    sign_in @user
    post_result
    first = gesamtrangliste

    post_result
    assert_equal first, gesamtrangliste
    assert_equal 1, @seeding.reload.data["result"].keys.size
  end

  test "Eintrag ohne Gesamtrangliste wird uebergangen" do
    sign_in @user
    post_result(entries: [{"dbu_nr" => 515_151}])

    assert_response :success
    assert_equal 0, JSON.parse(response.body)["accepted"]
    assert_nil gesamtrangliste
  end

  test "fehlende entries-Liste wird abgewiesen" do
    sign_in @user
    post api_tournament_results_url, params: {source_tournament_id: @tournament.id}, as: :json

    assert_response :unprocessable_entity
  end
end
