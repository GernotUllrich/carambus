# frozen_string_literal: true

require "test_helper"

# Plan 32-09: Meldung EINES abgeschlossenen Spiels vom Location Server an den Region Server.
#
# Zwei Dinge stehen hier im Mittelpunkt:
#   1. Der Name wird VEREINFACHT (`group1:2-3` -> "Gruppe A"), wie im CC-Weg. Der feine
#      ExecutorParams-Name gehoert in die Ausfuehrung, nicht in die Uebermittlung.
#   2. Ein Netzfehler darf den Spielbetrieb nicht abbrechen.
class LocationServer::GameResultReporterTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @plan = tournament_plans(:t06_6)
    @tournament = Tournament.create!(
      title: "LM Dreiband", shortname: "LM3B909",
      season: seasons(:current), organizer: @region, region_id: @region.id,
      tournament_plan_id: @plan.id,
      date: Time.zone.local(2026, 10, 10, 10, 0),
      source_url: "https://nbv.carambus.de/tournaments/50002001"
    )
    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 313_131)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 414_141)
    @game = build_game(gname: "group1:2-3")
  end

  def build_game(gname:, seqno: 7)
    game = @tournament.games.create!(gname: gname, seqno: seqno,
      ended_at: Time.zone.local(2026, 10, 10, 14, 12))
    game.game_participations.create!(player: @anna, role: "playera", result: 100, innings: 24, hs: 16, gd: 4.17)
    game.game_participations.create!(player: @bodo, role: "playerb", result: 85, innings: 24, hs: 9, gd: 3.54)
    game
  end

  def reporter(armed: false, game: @game)
    LocationServer::GameResultReporter.new(game: game, armed: armed)
  end

  # Carambus.config ist ein OpenStruct — Zugang setzen und danach zuruecknehmen, damit andere
  # Tests die Leer-Konfiguration sehen. Uebernommen aus ResultReporterTest.
  def with_region_credentials
    config = Carambus.config
    before = [config.region_server_user, config.region_server_password]
    config.region_server_user = "carambus-app-nbv-bridge@carambus.de"
    config.region_server_password = "geheim"
    yield
  ensure
    config.region_server_user, config.region_server_password = before
  end

  def stub_login
    stub_request(:post, "https://nbv.carambus.de/login")
      .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"}, body: "{}")
  end

  # AC-1 / AC-1b
  test "meldet den vereinfachten Namen, nicht den feinen gname" do
    stub_login
    stub = stub_request(:post, "https://nbv.carambus.de/api/game_results")
      .with(headers: {"Authorization" => "Bearer test-jwt"})
      .with do |request|
        body = JSON.parse(request.body)
        assert_equal 50_002_001, body["source_tournament_id"], "die LOKALE ID des Region Servers"
        assert_equal @plan.id, body["tournament_plan_id"], "der Namensraum muss ableitbar sein"
        assert_equal "Tournament", body["target_type"]

        row = body["games"].sole
        assert_equal "Gruppe A", row["group"], "group1:2-3 muss vereinfacht ankommen"
        assert_equal 7, row["seqno"]
        assert_equal %w[313131 414141], row["participations"].map { |p| p["dbu_nr"] }
        assert_equal 100, row["participations"].first["result"]
        assert_equal 16, row["participations"].first["hs"]
        true
      end
      .to_return(status: 200, body: {accepted: 1, updated: 0, unresolved: []}.to_json)

    result = with_region_credentials { reporter(armed: true).call }

    assert_requested stub
    assert_equal 1, result.reported
    assert_equal 1, result.response["accepted"]
  end

  # AC-1b — die Vereinfachung ist viele-zu-eins
  test "hf2 wird zu Halbfinale" do
    game = build_game(gname: "hf2", seqno: 13)
    stub_login
    stub = stub_request(:post, "https://nbv.carambus.de/api/game_results")
      .with { |request| JSON.parse(request.body)["games"].sole["group"] == "Halbfinale" }
      .to_return(status: 200, body: {accepted: 1}.to_json)

    with_region_credentials { reporter(armed: true, game: game).call }

    assert_requested stub
  end

  test "dry-run bereitet vor, sendet aber nichts" do
    # Kein WebMock-Stub gesetzt: ginge hier ein Request raus, schluege der Test fehl.
    result = reporter.call

    assert_equal 1, result.reported
    assert_nil result.response
  end

  # AC-3
  test "Turnier ohne source_url wird uebersprungen" do
    @tournament.update!(source_url: nil)

    result = reporter.call

    assert_equal 0, result.reported
    assert_equal 1, result.skipped_no_source_url
  end

  # AC-1c
  test "nicht abbildbarer Spielname wird nicht gemeldet" do
    game = build_game(gname: "voellig-unbekannt", seqno: 99)

    result = reporter(game: game).call

    assert_equal 0, result.reported
    assert_equal 1, result.skipped_unmappable_name
  end

  test "Spiel ohne dbu_nr wird nicht gemeldet" do
    @bodo.update!(dbu_nr: nil)

    result = reporter.call

    assert_equal 0, result.reported
    assert_equal 1, result.skipped_incomplete
  end

  test "Spiel mit nur einem Teilnehmer wird nicht gemeldet" do
    game = @tournament.games.create!(gname: "fin", seqno: 42)
    game.game_participations.create!(player: @anna, role: "playera", result: 100)

    result = reporter(game: game).call

    assert_equal 0, result.reported
    assert_equal 1, result.skipped_incomplete
  end

  test "meldet verstaendlich, wenn kein Zugang konfiguriert ist" do
    error = assert_raises(RuntimeError) { reporter(armed: true).call }

    assert_match(/region_server_user/, error.message)
    assert_match(/create_carambus_app/, error.message,
      "die Fehlermeldung muss sagen, WIE man den Zugang anlegt")
  end

  # ---- Verzweigung in finalize_game_result ----------------------------------------------------
  #
  # `TournamentMonitor.new` statt `create!` und ein schlanker TableMonitor-Ersatz: der initiale
  # AASM-State ruft `do_reset_tournament_monitor`, das Tische initialisiert und Spiele LOESCHT
  # (table_populator.rb:521 ff.) — genau die Spiele, die dieser Test braucht. Dieselbe Abwaegung
  # trifft ResultReporterTest fuer den Turnier-Abschluss.
  FakeTableMonitor = Struct.new(:id, :game, :state, :data)

  def processor_for(tournament)
    TournamentMonitor::ResultProcessor.new(TournamentMonitor.new(tournament: tournament))
  end

  def finalize(tournament, game)
    # manual_assignment: der Zweig danach (update_game_participations_for_game) ist nicht Gegenstand
    # dieses Tests und wuerde die volle Turniermaschinerie ziehen.
    tournament.update_column(:manual_assignment, true)
    monitor = FakeTableMonitor.new(1, game, "final_match_score", {})
    processor_for(tournament).send(:finalize_game_result, monitor)
  end

  # AC-4 — die Zusage, die den automatischen Aufruf vertretbar macht
  test "unerreichbarer Region Server bricht den Spielabschluss nicht ab" do
    LocationServer::GameResultReporter.stub(:new, ->(*) { raise "Connection refused" }) do
      assert_nothing_raised { finalize(@tournament, @game) }
    end
  end

  # Zaehlt Aufrufe und liefert ein unauffaelliges Ergebnis, damit finalize_game_result weiterlaeuft.
  class ReporterSpy
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def call
      @calls += 1
      LocationServer::GameResultReporter::Result.new(
        reported: 1, skipped_no_source_url: 0, skipped_unmappable_name: 0, skipped_incomplete: 0
      )
    end
  end

  def with_reporter_spy
    spy = ReporterSpy.new
    LocationServer::GameResultReporter.stub(:new, ->(**) { spy }) { yield }
    spy
  end

  # AC-2 — Verhaltenserhalt des produktiven CC-Pfads
  test "CC-Turnier meldet nicht an den Region Server" do
    TournamentCc.create!(tournament: @tournament, cc_id: 4711)

    spy = with_reporter_spy do
      Setting.stub(:upload_game_to_cc, ->(*) { {success: true} }) do
        finalize(@tournament.reload, @game)
      end
    end

    assert_equal 0, spy.calls, "bei einem CC-Turnier darf ausschliesslich der ClubCloud-Upload laufen"
  end

  # Die Falle, die das blosse `elsif` nicht abfaengt: auto_upload_to_cc? abgeschaltet macht aus
  # einem CC-Turnier kein CC-loses. Seine Ergebnisse gehoeren weiterhin der ClubCloud.
  test "CC-Turnier mit abgeschaltetem Auto-Upload meldet trotzdem nicht an den Region Server" do
    TournamentCc.create!(tournament: @tournament, cc_id: 4711)
    @tournament.update_column(:auto_upload_to_cc, false)

    spy = with_reporter_spy { finalize(@tournament.reload, @game) }

    assert_equal 0, spy.calls
  end

  test "CC-loses Turnier meldet an den Region Server" do
    spy = with_reporter_spy { finalize(@tournament, @game) }

    assert_equal 1, spy.calls, "ohne tournament_cc und mit source_url muss der CC-lose Zweig greifen"
  end
end
