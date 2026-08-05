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

  # --- KETTENTEST Location Server → Region Server -----------------------------
  #
  # WARUM DIESER TEST EXISTIERT (Plan 36-04): Sender und Empfaenger waren einzeln getestet und
  # beide gruen — der Fehler sass in ihrer VERBINDUNG. `finalize_game_result` meldete an den
  # Region Server, BEVOR `update_game_participations_for_game` die Ergebnisspalten schrieb; jedes
  # Spiel reiste mit leerem Ergebnis. Kein Test konnte das sehen: der Ausloeser-Test benutzt einen
  # Spy (sieht die Nutzlast nie), der Nutzlast-Test baut die Teilnehmer von Hand MIT Ergebnissen.
  #
  # Deshalb laeuft hier der ECHTE `finalize_game_result`, die ECHTE Nutzlast des
  # `GameResultReporter` wird abgefangen und durch den ECHTEN Endpunkt geschickt — dasselbe
  # Vorgehen wie im Kettentest von Plan 36-03 (api/public/game_results_controller_test.rb:150).

  # TableMonitor-Ersatz wie in LocationServer::GameResultReporterTest: ein echter
  # TournamentMonitor loescht im initialen AASM-State genau die Spiele, die der Test braucht.
  FakeTableMonitor = Struct.new(:id, :game, :state, :data)

  # Das globale Gegenstueck am Spielort: per Sync eingetroffen, traegt `source_url` auf das lokale
  # Arbeitsexemplar des Region Servers (Plan 28-01).
  def location_side
    tournament = Tournament.create!(
      title: "Landesmeisterschaft Dreiband", shortname: "LM3B458",
      season: @season, organizer: @region, region_id: @region.id,
      tournament_plan_id: @plan.id,
      source_url: "https://nbv.carambus.de/tournaments/#{@tournament.id}",
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )

    # SO legt die Tischbelegung ein Spiel an: nur gname/seqno und die beiden Rollen — die
    # Ergebnisspalten sind noch leer (table_populator.rb:736-748). Genau darauf kam es an.
    game = tournament.games.create!(gname: "group1:2-3", seqno: 7,
      ended_at: Time.zone.local(2026, 10, 10, 14, 12))
    game.game_participations.create!(player: Player.find_by(dbu_nr: 111_111), role: "playera")
    game.game_participations.create!(player: Player.find_by(dbu_nr: 222_222), role: "playerb")

    [tournament, game]
  end

  # Was der TableMonitor am Spielende mitbringt (Einzelsatz-Fall, sets_to_play == 1).
  def table_monitor_data
    {
      "playera" => {"result" => 100, "innings" => 24, "balls_goal" => 100, "hs" => 16},
      "playerb" => {"result" => 85, "innings" => 24, "balls_goal" => 100, "hs" => 9}
    }
  end

  # Carambus.config ist ein OpenStruct — Zugang setzen und zuruecknehmen (aus ReporterTest).
  def with_region_credentials
    config = Carambus.config
    before = [config.region_server_user, config.region_server_password]
    config.region_server_user = "carambus-app-nbv-bridge@carambus.de"
    config.region_server_password = "geheim"
    yield
  ensure
    config.region_server_user, config.region_server_password = before
  end

  test "ein am Spielort abgeschlossenes Spiel kommt MIT Ergebnis auf dem Region Server an" do
    tournament, game = location_side

    stub_request(:post, "https://nbv.carambus.de/login")
      .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"}, body: "{}")
    payload = nil
    stub_request(:post, "https://nbv.carambus.de/api/game_results")
      .with { |request| payload = JSON.parse(request.body) }
      .to_return(status: 200, body: {accepted: 1, updated: 0, unresolved: []}.to_json)

    monitor = FakeTableMonitor.new(1, game, "final_match_score", table_monitor_data)
    with_region_credentials do
      TournamentMonitor::ResultProcessor
        .new(TournamentMonitor.new(tournament: tournament))
        .send(:finalize_game_result, monitor)
    end

    assert_equal 100, game.game_participations.find_by(role: "playera").result,
      "Vorbedingung: der Spielabschluss muss die Ergebnisse lokal geschrieben haben"
    assert_not_nil payload, "der Spielabschluss muss an den Region Server gemeldet haben"

    # DER KERN: hier stand vor Plan 36-04 ueberall nil.
    reported = payload["games"].sole["participations"].index_by { |p| p["role"] }
    assert_equal 100, reported["playera"]["result"], "das Ergebnis muss mitreisen, nicht nil"
    assert_equal 85, reported["playerb"]["result"]
    assert_equal 24, reported["playera"]["innings"]
    assert_equal 16, reported["playera"]["hs"]

    # ... und dieselbe Nutzlast durch den echten Endpunkt in den echten Ingest.
    sign_in @user
    post api_game_results_url, params: payload, as: :json

    assert_response :success
    assert_equal 1, JSON.parse(response.body)["accepted"]

    received = @tournament.games.sole
    assert_equal "Gruppe A", received.gname, "der Name muss vereinfacht ankommen"
    assert_equal "100:85", received.data["Punkte"], "leere Ergebnisse stuenden hier als ':'"
    assert_equal 100, received.game_participations.find_by(role: "playera").result
    assert_equal 85, received.game_participations.find_by(role: "playerb").result
  end
end
