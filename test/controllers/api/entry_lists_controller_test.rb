# frozen_string_literal: true

require "test_helper"

# Plan 28-01: Ausliefer-Endpunkt der Meldeliste (laeuft auf dem Region Server).
class Api::EntryListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @user = users(:one)

    @tournament = Tournament.create!(
      title: "Landesmeisterschaft Einband", shortname: "LME",
      season: @season, organizer: @region, region_id: @region.id,
      date: Time.zone.local(2026, 10, 10, 10, 0), player_class: "I", balls_goal: 100
    )
    @club = Club.create!(name: "Meldeverein", shortname: "MV", region_id: @region.id)
    @player = Player.create!(lastname: "MELDER", firstname: "Mia", fl_name: "M. Melder", dbu_nr: 424_242)
    SeasonParticipation.create!(player: @player, club: @club, season: @season)
    @tournament.seedings.create!(player_id: @player.id, position: 1)
  end

  def get_entry_lists(region: @region.shortname, season: @season.name)
    get api_entry_lists_url(region: region, season: season)
  end

  test "ohne Authentifizierung kein Zugriff" do
    get_entry_lists
    refute_equal 200, response.status, "unauthentifiziert darf die Meldeliste nicht ausgeliefert werden"
  end

  test "liefert Turnier mit gemeldeten Spielern" do
    sign_in @user
    get_entry_lists

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "carambus.entry_list/v1", body["schema"]
    assert_equal @region.shortname, body.dig("region", "shortname")

    tournament = body["tournaments"].find { |t| t["source_tournament_id"] == @tournament.id }
    assert tournament, "Turnier muss enthalten sein"
    assert_equal "Landesmeisterschaft Einband", tournament["title"]
    assert_equal 100, tournament["balls_goal"]

    entry = tournament["entries"].first
    assert_equal 424_242, entry["dbu_nr"]
    assert_equal "MELDER", entry["lastname"]
    assert_equal "Meldeverein", entry["club"], "Verein reist als Gegenprobe mit"
  end

  test "Turnier ohne Meldungen erscheint mit leerer Liste" do
    sign_in @user
    leer = Tournament.create!(title: "Noch keine Meldungen", season: @season,
      organizer: @region, date: Time.zone.local(2026, 11, 1, 10, 0))

    get_entry_lists

    tournament = JSON.parse(response.body)["tournaments"].find { |t| t["source_tournament_id"] == leer.id }
    assert tournament, "Turnier ohne Meldungen darf nicht fehlen"
    assert_equal [], tournament["entries"]
  end

  test "Entwuerfe aus der Saison-Kopie werden NICHT ausgeliefert" do
    sign_in @user
    draft = Tournament.create!(title: "Entwurf aus Kopie", season: @season, organizer: @region,
      date: Time.zone.local(2026, 12, 1, 10, 0), data: {"draft" => true})

    get_entry_lists

    ids = JSON.parse(response.body)["tournaments"].map { |t| t["source_tournament_id"] }
    refute_includes ids, draft.id, "nicht freigegebene Entwuerfe duerfen nicht global werden"
  end

  test "unbekannte Region und Saison werden abgewiesen" do
    sign_in @user

    get_entry_lists(region: "GIBTESNICHT")
    assert_response :not_found

    get_entry_lists(season: "1999/2000")
    assert_response :not_found
  end
end
