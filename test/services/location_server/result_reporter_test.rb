# frozen_string_literal: true

require "test_helper"

# Plan 29-03: Meldung des Turnier-Abschlusses vom Location Server an den Region Server.
#
# Der Kern: das Ziel wird aus der `source_url` des globalen Turniers abgeleitet — dieselbe
# Provenienz-Konvention wie in Plan 28-01, nur rueckwaerts gelesen.
class LocationServer::ResultReporterTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @tournament = Tournament.create!(
      title: "LM Dreiband", shortname: "LM3B294",
      season: seasons(:current), organizer: @region, region_id: @region.id,
      date: Time.zone.local(2026, 10, 10, 10, 0),
      source_url: "https://nbv.carambus.de/tournaments/50002001"
    )
    @player = Player.create!(lastname: "SIEGER", firstname: "Sina", fl_name: "S. Sieger", dbu_nr: 616_161)
    @seeding = @tournament.seedings.create!(player_id: @player.id, position: 1)
    write_own_ranking(@seeding)
  end

  def write_own_ranking(seeding)
    seeding.update!(data: {
      "result" => {"Gesamtrangliste" => {"Rang" => 1, "Bälle" => 120, "Punkte" => 4}},
      "result_source" => "carambus"
    })
  end

  def reporter(armed: false, tournament: @tournament)
    LocationServer::ResultReporter.new(tournament: tournament, armed: armed)
  end

  # Carambus.config ist ein OpenStruct — fuer den Test wird der Zugang gesetzt und danach
  # zurueckgenommen, damit andere Tests die Leer-Konfiguration sehen.
  def with_region_credentials
    config = Carambus.config
    before = [config.region_server_user, config.region_server_password]
    config.region_server_user = "carambus-app-nbv-bridge@carambus.de"
    config.region_server_password = "geheim"
    yield
  ensure
    config.region_server_user, config.region_server_password = before
  end

  test "leitet Ziel und lokale ID aus der source_url ab" do
    result = reporter.call

    assert_equal 1, result.reported
    assert_equal 0, result.skipped_no_source_url
  end

  test "dry-run meldet nichts" do
    # Kein WebMock-Stub gesetzt: wuerde hier ein HTTP-Request rausgehen, schluege der Test fehl.
    result = reporter.call

    assert_equal 1, result.reported
    assert_nil result.response
  end

  def stub_login
    stub_request(:post, "https://nbv.carambus.de/login")
      .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"}, body: "{}")
  end

  test "ARMED sendet an den Region Server, mit lokaler ID und dbu_nr" do
    stub_login
    stub = stub_request(:post, "https://nbv.carambus.de/api/tournament_results")
      .with(headers: {"Authorization" => "Bearer test-jwt"})
      .with do |request|
        body = JSON.parse(request.body)
        assert_equal 50_002_001, body["source_tournament_id"], "die LOKALE ID des Region Servers"
        assert_equal 616_161, body["entries"].first["dbu_nr"].to_i
        assert_equal 1, body["entries"].first.dig("Gesamtrangliste", "Rang")
        true
      end
      .to_return(status: 200, body: {accepted: 1, unresolved: [], skipped_foreign: 0}.to_json)

    result = with_region_credentials { reporter(armed: true).call }

    assert_requested stub
    assert_equal 1, result.reported
    assert_equal 1, result.response["accepted"]
  end

  test "Turnier ohne source_url wird uebersprungen" do
    @tournament.update!(source_url: nil)

    result = reporter.call

    assert_equal 0, result.reported
    assert_equal 1, result.skipped_no_source_url
  end

  # Gescrapte Ranglisten gehoeren der ClubCloud — sie zurueckzuspielen waere eine Ueberschreibung
  # fremder Daten.
  test "meldet nur selbst erzeugte Ranglisten" do
    @seeding.update!(data: {"result" => {"Gesamtrangliste" => {"Rang" => 3}}})

    result = reporter.call

    assert_equal 0, result.reported
    assert_equal 1, result.skipped_no_own_ranking
  end

  test "Spieler ohne dbu_nr wird nicht gemeldet" do
    @player.update!(dbu_nr: nil)

    result = reporter.call

    assert_equal 0, result.reported
  end

  # Die Zusage, die den automatischen Aufruf am Turnier-Abschluss vertretbar macht.
  test "unerreichbarer Region Server bricht den Turnier-Abschluss nicht ab" do
    # `TournamentMonitor.new` statt `create!`: der initiale AASM-State ruft
    # `do_reset_tournament_monitor`, das Tische initialisiert und Spiele loescht
    # (table_populator.rb:521 ff.). Fuer diesen Test wird nur ein Empfaenger fuer den
    # ResultProcessor gebraucht — die volle Turnier-Maschinerie waere unnoetig und langsam.
    monitor = TournamentMonitor.new(tournament: @tournament)
    processor = TournamentMonitor::ResultProcessor.new(monitor)

    LocationServer::ResultReporter.stub(:new, ->(*) { raise "Connection refused" }) do
      assert_nothing_raised { processor.report_final_ranking }
    end
  end

  # ---- Zugang (Betreiber-Entscheidung: ein Service-Account je Region) --------------------------

  test "meldet verstaendlich, wenn kein Zugang konfiguriert ist" do
    error = assert_raises(RuntimeError) { reporter(armed: true).call }

    assert_match(/region_server_user/, error.message)
    assert_match(/create_carambus_app/, error.message,
      "die Fehlermeldung muss sagen, WIE man den Zugang anlegt")
  end

  test "holt das JWT beim Region Server und nutzt es" do
    login = stub_login
    post = stub_request(:post, "https://nbv.carambus.de/api/tournament_results")
      .with(headers: {"Authorization" => "Bearer test-jwt"})
      .to_return(status: 200, body: {accepted: 1}.to_json)

    with_region_credentials { reporter(armed: true).call }

    assert_requested login
    assert_requested post
  end

  test "gescheiterte Anmeldung bricht verstaendlich ab" do
    stub_request(:post, "https://nbv.carambus.de/login").to_return(status: 401, body: "")

    error = assert_raises(RuntimeError) { with_region_credentials { reporter(armed: true).call } }

    assert_match(/Anmeldung am Region Server fehlgeschlagen/, error.message)
  end

  # Plan 29-05: Die verschluesselten Rails-Credentials sind der generierte, kanonische Ort;
  # carambus.yml bleibt Fallback. Steht beides, gewinnt der Credential-Eintrag.
  test "Credentials haben Vorrang vor carambus.yml" do
    login = stub_request(:post, "https://nbv.carambus.de/login")
      .with { |request| JSON.parse(request.body).dig("user", "email") == "aus-credentials@carambus.de" }
      .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"}, body: "{}")
    stub_request(:post, "https://nbv.carambus.de/api/tournament_results")
      .to_return(status: 200, body: {accepted: 1}.to_json)

    credentials = {region_server: {nbv: {username: "aus-credentials@carambus.de", password: "geheim"}}}
    Rails.application.credentials.stub(:region_server, credentials[:region_server]) do
      with_region_credentials { reporter(armed: true).call }
    end

    assert_requested login
  end
end
