# frozen_string_literal: true

require "test_helper"

# Plan 35-01: Der CC-lose Meldelisten-Fluss auf dem Region Server.
#
# Fixture-Hinweis: tournaments(:local) haengt an regions(:nbv) — NBV ist eine CC-Region
# (Region::SHORTNAMES_CC). Fuer den CC-losen Weg wird der Organizer auf regions(:bbv)
# umgehaengt; BBV steht in SHORTNAMES_CC bewusst auskommentiert (seit v0.5 NuLiga) und ist
# damit CC-los im Sinne von wizard_cc_less?.
class Tournaments::EntryListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:local)
    @tournament.update_column(:organizer_id, regions(:bbv).id)

    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test" # = lokaler Server

    @club = Club.create!(name: "Testverein 35", shortname: "TV35", region_id: regions(:bbv).id)
    @alpha = Player.create!(lastname: "ALPHA", firstname: "Anna", fl_name: "A. Alpha", dbu_nr: "111111")
    SeasonParticipation.create!(player: @alpha, club: @club, season: @tournament.season)

    sign_in users(:system_admin) # deckt manage_teilnehmerliste? (admin?-Bypass)
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # --- Anzeige (AC-1) ---------------------------------------------------------

  test "GET zeigt die Meldeliste mit beiden Meldewegen" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    get tournament_entry_list_path(@tournament)

    assert_response :success
    assert_select "h1", /Meldeliste/
    assert_select "form[action=?]", tournament_entry_list_path(@tournament)
    assert_select "input[name=?]", "dbu_nr"
    assert_match @alpha.fullname, response.body
  end

  # Live aufgefallen 2026-07-29 auf tbv: 12 namenlose Altlast-Vereine sortierten als Leerzeilen an
  # den Anfang des Pickers, wodurch er leer aussah. Regionsweit betrifft das 571 von 1841 Vereinen.
  test "der Vereinspicker zeigt keine namenlosen Vereine" do
    namenlos = Club.create!(name: "", shortname: "", region_id: regions(:bbv).id)

    get tournament_entry_list_path(@tournament)

    assert_response :success
    werte = css_select("select[name='entry_list_club_id'] option").map { |o| o["value"] }
    assert_includes werte, @club.id.to_s, "benannte Vereine muessen waehlbar bleiben"
    assert_not_includes werte, namenlos.id.to_s, "ein Verein ohne Namen ist nicht waehlbar"
  end

  test "die Seite traegt keine Modus-Findung und keine ClubCloud-Bausteine" do
    get tournament_entry_list_path(@tournament)

    assert_response :success
    refute_match(/Teilnehmerliste/i, response.body,
      "der Region Server pflegt die Meldeliste, nicht die Teilnehmerliste")
    refute_match(/ClubCloud/i, response.body)
    refute_match(/use_clubcloud_as_participants/, response.body)
    refute_match(/Gruppe/i, response.body, "Gruppenbildung gehoert auf den Location Server")
    assert_select "a[href=?]", finalize_modus_tournament_path(@tournament), false,
      "kein Weg in die Modus-Findung"
  end

  # AC-4: der Freigabe-Weg ist von hier aus erreichbar — und zeigt auf die UNVERAENDERTE
  # release_draft-Action (Propagation ist settled, 32-01 + 28/29).
  test "im Entwurf fuehrt die Seite auf die bestehende Freigabe" do
    @tournament.update_column(:data, {"draft" => true}) # `data` ist serialisiert — Hash, kein JSON-String

    get tournament_entry_list_path(@tournament)

    assert_response :success
    assert_select "form[action=?]", release_draft_tournament_path(@tournament)
  end

  test "ohne Entwurfs-Status wird keine Freigabe angeboten" do
    get tournament_entry_list_path(@tournament)

    assert_select "form[action=?]", release_draft_tournament_path(@tournament), false
  end

  # --- Melden -----------------------------------------------------------------

  test "POST meldet einen Spieler per DBU-Nummer mit state registered" do
    assert_difference -> { @tournament.seedings.count }, 1 do
      post tournament_entry_list_path(@tournament), params: {dbu_nr: "111111"}
    end

    assert_redirected_to tournament_entry_list_path(@tournament)
    seeding = @tournament.seedings.find_by(player_id: @alpha.id)
    assert_equal "registered", seeding.state
  end

  test "POST ohne Eingabe legt nichts an und meldet das zurueck" do
    assert_no_difference -> { @tournament.seedings.count } do
      post tournament_entry_list_path(@tournament), params: {dbu_nr: ""}
    end

    assert_redirected_to tournament_entry_list_path(@tournament)
    assert flash[:alert].present?
  end

  test "POST mit unaufloesbarer Nummer meldet sie als Fehler zurueck" do
    assert_no_difference -> { @tournament.seedings.count } do
      post tournament_entry_list_path(@tournament), params: {dbu_nr: "999999"}
    end

    assert_equal :alert, flash.to_hash.keys.map(&:to_sym).first
  end

  # --- Zurueckziehen ----------------------------------------------------------

  test "DELETE zieht eine lokale Meldung zurueck" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    assert_difference -> { @tournament.seedings.count }, -1 do
      delete seeding_tournament_entry_list_path(@tournament, seeding.id)
    end

    assert_redirected_to tournament_entry_list_path(@tournament)
  end

  # AC-3: nach einem Rueckzug darf eine Neumeldung keine Position doppelt vergeben.
  test "nach dem Zurueckziehen bleiben die Positionen dublettenfrei" do
    beta = Player.create!(lastname: "BETA", firstname: "Bert", fl_name: "B. Beta", dbu_nr: "222222")
    SeasonParticipation.create!(player: beta, club: @club, season: @tournament.season)

    post tournament_entry_list_path(@tournament), params: {dbu_nr: "111111, 222222"}
    first = @tournament.seedings.find_by(player_id: @alpha.id)
    delete seeding_tournament_entry_list_path(@tournament, first.id)

    gamma = Player.create!(lastname: "GAMMA", firstname: "Gerd", fl_name: "G. Gamma", dbu_nr: "333333")
    SeasonParticipation.create!(player: gamma, club: @club, season: @tournament.season)
    post tournament_entry_list_path(@tournament), params: {dbu_nr: "333333"}

    positions = @tournament.seedings.pluck(:position)
    assert_equal positions.uniq.size, positions.size, "Positionen duerfen sich nicht doppeln"
  end

  test "DELETE ruehrt ein globales Seeding nicht an" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)
    seeding.update_column(:id, 4_711) # < MIN_ID = Hoheit der Authority

    assert_no_difference -> { @tournament.seedings.count } do
      delete seeding_tournament_entry_list_path(@tournament, 4_711)
    end

    assert flash[:alert].present?
  end

  # --- Picker -----------------------------------------------------------------

  test "GET players_by_club liefert die Vereinsspieler als JSON" do
    get players_by_club_tournament_entry_list_path(@tournament, club_id: @club.id)

    assert_response :success
    rows = JSON.parse(response.body)
    assert_equal [@alpha.id], rows.map { |r| r["id"] }
  end

  test "GET players_by_club laesst bereits gemeldete Spieler weg" do
    @tournament.seedings.create!(player_id: @alpha.id, position: 1)

    get players_by_club_tournament_entry_list_path(@tournament, club_id: @club.id)

    assert_equal [], JSON.parse(response.body)
  end

  # --- Gates (AC-6) -----------------------------------------------------------

  test "auf dem API-Server ist der Fluss nicht erreichbar" do
    Carambus.config.carambus_api_url = nil

    get tournament_entry_list_path(@tournament)

    assert_redirected_to tournaments_path
  end

  test "CC-Turniere werden auf ihren gewachsenen Fluss zurueckgewiesen" do
    @tournament.update_column(:organizer_id, regions(:nbv).id) # NBV = CC-Region

    get tournament_entry_list_path(@tournament)

    assert_redirected_to tournament_path(@tournament)
  end

  test "ohne manage_teilnehmerliste-Recht ist Melden abgewiesen" do
    sign_out users(:system_admin)
    sign_in users(:one) # weder TL noch Sportwart noch Admin

    assert_no_difference -> { @tournament.seedings.count } do
      post tournament_entry_list_path(@tournament), params: {dbu_nr: "111111"}
    end

    assert_redirected_to tournament_path(@tournament)
  end

  test "ohne manage_teilnehmerliste-Recht ist Zurueckziehen abgewiesen" do
    seeding = @tournament.seedings.create!(player_id: @alpha.id, position: 1)
    sign_out users(:system_admin)
    sign_in users(:one)

    assert_no_difference -> { @tournament.seedings.count } do
      delete seeding_tournament_entry_list_path(@tournament, seeding.id)
    end

    assert_redirected_to tournament_path(@tournament)
  end
end
