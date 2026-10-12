# frozen_string_literal: true

require "test_helper"

# Plan 17-04 T2: Lässt sich ein Turnier für die Turnier-App (Plan-Modus, „attachen“) ohne
# Rails-Konsole anlegen? Das BCW-Runbook legte es per Konsole an (mit region_id) und löschte
# danach die Plan-Spiele (`t.games.destroy_all`). Diese Tests gehen den Web-Weg eines
# Vereins-Admins und halten den IST-Zustand fest (gemessen 2026-09-13):
#
#   1. Das Formular setzt keine region_id — die Bridge findet das Turnier nicht
#      (seeding: 422 „Region mismatch“, lock_table: 422 „Tournament not found“).
#   2. Einen TournamentMonitor legt im Web erst „Start“ an — und der erzeugt trotz
#      manual_assignment die Plan-Spiele (T04: 10), mit denen die App kollidiert.
#   3. Mit gesetzter region_id liefert die Bridge Plan und Setzliste, lock_table bindet den Tisch.
#
# Der Web-Weg ist damit NICHT attach-fähig; die Doku (managers/tournament-app) führt das
# Konsolen-Rezept für Admins. Wer den Web-Weg baut, dreht diese Tests um.
class AppTournamentWebPathTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test" # lokaler Server
    @nbv = regions(:nbv)
    @plan = tournament_plans(:t04_5) # T04, 5 Spieler, jeder gegen jeden = 10 Partien
    @table = tables(:one)
    @service_user = User.create!(email: "test-app-web-path-bridge@carambus.de", password: "password123",
      confirmed_at: Time.zone.now)
    @players = (1..5).map do |i|
      Player.create!(id: 50_017_040 + i, firstname: "Web#{i}", lastname: "Pfad", ba_id: 1_704_000 + i)
    end
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # Frische Sitzung: im Admin-Browser angemeldet, liefert /login kein Token für das Dienstkonto.
  def login_jwt
    reset!
    post "/login", params: {user: {email: @service_user.email, password: "password123"}}.to_json,
      headers: {"Content-Type" => "application/json", "Accept" => "application/json"}
    raise "Login failed: #{response.code}" unless response.successful?
    jwt = response.headers["Authorization"].to_s.sub(/\ABearer\s+/, "")
    reset!
    jwt
  end

  # Ein Login je Phase: jeder neue Login ersetzt den vorherigen Token (jti).
  def api_headers
    @api_headers ||= {"Accept" => "application/json", "Content-Type" => "application/json",
                      "Authorization" => "Bearer #{login_jwt}"}
  end

  # Web-Weg bis zur Modusauswahl: Formular (mit manual_assignment + Enddatum), Setzliste, Modus-Schritt.
  def create_via_web
    sign_in users(:club_admin)
    post tournaments_url, params: {tournament: {
      title: "App-Turnier Web-Weg", shortname: "APPWEB", date: 1.week.from_now, end_date: 3.weeks.from_now,
      season_id: seasons(:current).id, organizer_id: @nbv.id, organizer_type: "Region",
      discipline_id: disciplines(:carom_3band).id, location_id: @table.location_id,
      balls_goal: 15, innings_goal: 15, manual_assignment: "1"
    }}
    tournament = Tournament.order(:id).last
    assert_redirected_to tournament_path(tournament)
    # Die Setzliste selbst ist nicht Gegenstand — sie entsteht im Web über die Teilnehmerliste.
    @players.each_with_index { |p, i| tournament.seedings.create!(player: p, position: i + 1) }
    post finish_seeding_tournament_url(tournament)
    get finalize_modus_tournament_url(tournament)
    post select_modus_tournament_url(tournament), params: {tournament_plan_id: @plan.id}
    tournament.reload
  end

  def start_via_web(tournament)
    @api_headers = nil
    sign_in users(:club_admin)
    post start_tournament_url(tournament),
      params: {balls_goal: 15, innings_goal: 15, table_id: [@table.id], parameter_verification_confirmed: "1"}
    tournament.reload
  end

  def seeding_via_bridge(tournament)
    get "/api/external_tournament/seeding", params: {tournament_id: tournament.id, region: "NBV"}, headers: api_headers
    response
  end

  def lock_table_via_bridge(tournament)
    post "/api/external_tournament/lock_table",
      params: {region: {shortname: "NBV"}, tournament_id: tournament.id, table: {id: @table.id}}.to_json,
      headers: api_headers
    response
  end

  test "17-04: das Web-Formular speichert manual_assignment, Enddatum und Plan, aber keine region_id" do
    t = create_via_web

    assert t.manual_assignment
    assert t.end_date.future?
    assert_equal @plan.id, t.tournament_plan_id
    assert_equal "tournament_mode_defined", t.state
    assert_nil t.region_id, "IST: das Formular hat kein Regionsfeld"
    assert_nil t.tournament_monitor, "IST: vor „Start“ gibt es keinen TournamentMonitor"
    assert_equal 0, t.games.count
  end

  test "17-04: ohne region_id findet die Bridge das web-angelegte Turnier nicht" do
    t = create_via_web

    r = seeding_via_bridge(t)
    assert_equal 422, r.status
    assert_equal "Region mismatch", JSON.parse(r.body)["error"]

    r = lock_table_via_bridge(t)
    assert_equal 422, r.status
    assert_equal "Tournament not found", JSON.parse(r.body)["error"]
  end

  test "17-04: „Start“ legt trotz manual_assignment die Plan-Spiele an" do
    t = start_via_web(create_via_web)

    assert t.tournament_monitor.present?
    assert_equal 10, t.games.count, "IST: T04 mit 5 Spielern — die App legt ihre Partien selbst an"
    assert_nil @table.table_monitor.reload.tournament_monitor_id, "manual_assignment: kein Tisch vorbelegt"
  end

  test "17-04: mit gesetzter region_id und Monitor wäre das Turnier attach-fähig" do
    t = start_via_web(create_via_web)
    t.update_column(:region_id, @nbv.id) # der fehlende Schritt (Konsole) — im Web nicht möglich

    r = seeding_via_bridge(t)
    assert_equal 200, r.status
    assert_equal @plan.name, JSON.parse(r.body).dig("tournament", "tournament_plan", "name")

    r = lock_table_via_bridge(t)
    assert_equal 200, r.status
    assert JSON.parse(r.body)["in_tournament"]
  end
end
