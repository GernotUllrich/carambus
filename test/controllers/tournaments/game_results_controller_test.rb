# frozen_string_literal: true

require "test_helper"

# Plan 35-03: Manuelle Ergebniserfassung auf dem Region Server.
#
# Fixture-Hinweis wie beim Meldelisten-Test: tournaments(:local) haengt an regions(:nbv) — einer
# CC-Region. Fuer den CC-losen Weg wird der Organizer auf regions(:bbv) umgehaengt (BBV steht in
# Region::SHORTNAMES_CC bewusst auskommentiert, seit v0.5 NuLiga).
# SEIT 34-03 ist die Region fuer diese Frage ohne Belang — `source_kind` allein entscheidet; die
# Umhaengung bleibt trotzdem stehen, weil sie das Szenario realistisch haelt.
class Tournaments::GameResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:local)
    @tournament.update_columns(organizer_id: regions(:bbv).id, region_id: regions(:bbv).id)

    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"

    # Plan 36-03: test_helper.rb:139 zwingt Integration-Tests auf den :inline-Adapter (fuer die
    # Mailer-Charakterisierung). GameResultSyncJob liefe damit SYNCHRON im Request — samt echtem
    # HTTP-Call an die Authority, den WebMock zu Recht blockt (500 statt Redirect). In Produktion
    # laeuft der Job im Hintergrund; hier also :test, damit dieser Test den CONTROLLER misst.
    # Dass der Anstoss ueberhaupt erfolgt, sichert game_result_writer_test.rb.
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 111_111)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 222_222)
    [@anna, @bodo].each_with_index do |player, ix|
      @tournament.seedings.create!(player_id: player.id, position: ix + 1)
    end

    sign_in users(:system_admin)
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  def record(overrides = {})
    post tournament_game_results_path(@tournament), params: {
      gname: "Gruppe A", seqno: 1,
      player_a_id: @anna.id, result_a: 100, innings_a: 24, hs_a: 16,
      player_b_id: @bodo.id, result_b: 85, innings_b: 24, hs_b: 9
    }.merge(overrides)
  end

  # --- Anzeige (AC-2) ---------------------------------------------------------

  test "GET zeigt die Ergebnisliste mit Erfassungsformular" do
    get tournament_game_results_path(@tournament)

    assert_response :success
    assert_select "form[action=?]", tournament_game_results_path(@tournament)
    assert_select "select[name=?]", "gname"
    assert_select "select[name=?]", "player_a_id"
  end

  # Gegen Wege pruefen, nicht gegen Woerter: "Scoreboard" steht als data-Attribut im Layout und
  # sagt nichts ueber diese Seite aus.
  test "die Seite fuehrt nicht ins Turniermanagement" do
    get tournament_game_results_path(@tournament)

    assert_response :success
    assert_select "a[href=?]", finalize_modus_tournament_path(@tournament), false,
      "kein Weg in die Modus-Findung"
    assert_select "a[href=?]", tournament_monitor_tournament_path(@tournament), false,
      "kein Weg in den TableMonitor"
    refute_match(/use_clubcloud_as_participants/, response.body)
  end

  # --- Erfassen (AC-2) --------------------------------------------------------

  test "POST erfasst ein Spiel mit beiden Spielern" do
    assert_difference -> { @tournament.games.count }, 1 do
      record
    end

    game = @tournament.games.find_by(gname: "Gruppe A", seqno: 1)
    assert_equal %w[playera playerb], game.game_participations.order(:role).pluck(:role)
    assert_equal 100, game.game_participations.find_by(role: "playera").result
  end

  test "ein erfasstes Spiel ist auf der Turnierseite sichtbar" do
    record
    game = @tournament.games.find_by(gname: "Gruppe A", seqno: 1)

    # show.html.erb:146 filtert auf "Ergebnis" ODER "Punkte".
    assert game.data["Ergebnis"].present? || game.data["Punkte"].present?
    assert_equal "100:85", game.data["Punkte"]
  end

  test "der Generaldurchschnitt wird berechnet" do
    record
    gp = @tournament.games.find_by(gname: "Gruppe A", seqno: 1).game_participations.find_by(role: "playera")

    assert_in_delta 4.17, gp.gd, 0.01
  end

  # --- Korrektur (AC-5) -------------------------------------------------------

  test "dieselbe Partie erneut erfasst korrigiert statt zu duplizieren" do
    record
    assert_no_difference -> { @tournament.games.count } do
      record(result_a: 120)
    end

    gp = @tournament.games.find_by(gname: "Gruppe A", seqno: 1).game_participations.find_by(role: "playera")
    assert_equal 120, gp.result
  end

  # --- Validierung (AC-3, AC-4) -----------------------------------------------

  test "ein nicht akzeptierter Spielname wird serverseitig abgewiesen" do
    assert_no_difference -> { @tournament.games.count } do
      record(gname: "1. Runde") # reale Schreibweise, aber nicht im Namensraum
    end

    assert flash[:alert].present?
  end

  test "derselbe Spieler auf beiden Seiten wird abgewiesen" do
    assert_no_difference -> { @tournament.games.count } do
      record(player_b_id: @anna.id)
    end

    assert flash[:alert].present?
  end

  test "ein nicht gemeldeter Spieler wird abgewiesen" do
    fremd = Player.create!(lastname: "FREMD", firstname: "Franz", fl_name: "F. Fremd", dbu_nr: 999_999)

    assert_no_difference -> { @tournament.games.count } do
      record(player_b_id: fremd.id)
    end

    assert flash[:alert].present?
  end

  test "ein Spieler ohne dbu_nr wird gar nicht erst angeboten" do
    ohne = Player.create!(lastname: "OHNE", firstname: "Otto", fl_name: "O. Ohne")
    @tournament.seedings.create!(player_id: ohne.id, position: 3)

    get tournament_game_results_path(@tournament)

    refute_match(/O\. Ohne|OHNE/, response.body,
      "ohne dbu_nr verwirft der Authority-Importer die Zeile still")
  end

  test "fehlende Partie-Nummer wird abgewiesen" do
    assert_no_difference -> { @tournament.games.count } do
      record(seqno: "")
    end

    assert flash[:alert].present?
  end

  # --- Entfernen --------------------------------------------------------------

  # Die lokale ID wird explizit gesetzt: produktiv vergibt die Sequenz des Region Servers IDs
  # oberhalb MIN_ID, die Testumgebung nicht (derselbe Umstand wie in game_result_ingest_test.rb).
  test "DELETE entfernt ein erfasstes Spiel" do
    record
    game = @tournament.games.find_by(gname: "Gruppe A", seqno: 1)
    game.update_column(:id, Game::MIN_ID + 501)

    assert_difference -> { @tournament.games.count }, -1 do
      delete game_tournament_game_results_path(@tournament, Game::MIN_ID + 501)
    end
  end

  # Live aufgefallen 2026-07-29: die Löschung erreichte die Authority nicht. Der Anstoß im
  # GameResultWriter deckt nur das Schreiben ab — der Löschpfad läuft nicht durch ihn.
  # Gegenstück auf der Authority: GameResultImporter#prune_removed_games.
  test "DELETE stoesst den Authority-Ingest an" do
    record
    game = @tournament.games.find_by(gname: "Gruppe A", seqno: 1)
    game.update_column(:id, Game::MIN_ID + 502)

    assert_enqueued_with(job: GameResultSyncJob,
      args: [{region_id: @tournament.region_id, season_id: @tournament.season_id}]) do
      delete game_tournament_game_results_path(@tournament, Game::MIN_ID + 502)
    end
  end

  test "ein abgewiesenes DELETE stoesst nichts an" do
    record
    game = @tournament.games.find_by(gname: "Gruppe A", seqno: 1)
    game.update_column(:id, 4_712) # < MIN_ID = Hoheit der Authority

    assert_no_enqueued_jobs only: GameResultSyncJob do
      delete game_tournament_game_results_path(@tournament, 4_712)
    end
  end

  test "DELETE ruehrt ein globales Spiel nicht an" do
    record
    game = @tournament.games.find_by(gname: "Gruppe A", seqno: 1)
    game.update_column(:id, 4_711) # < MIN_ID = Hoheit der Authority

    assert_no_difference -> { @tournament.games.count } do
      delete game_tournament_game_results_path(@tournament, 4_711)
    end

    assert flash[:alert].present?
  end

  # --- Gates (AC-6) -----------------------------------------------------------

  test "auf dem API-Server ist die Seite nicht erreichbar" do
    Carambus.config.carambus_api_url = nil

    get tournament_game_results_path(@tournament)

    assert_redirected_to tournaments_path
  end

  # Seit 34-03 macht die Region ein Turnier NICHT mehr zum CC-Turnier — allein `source_kind` tut das.
  test "CC-Turniere werden abgewiesen" do
    @tournament.update_columns(organizer_id: regions(:nbv).id, source_kind: "club_cloud")

    get tournament_game_results_path(@tournament)

    assert_redirected_to tournament_path(@tournament)
  end

  test "ohne manage_teilnehmerliste-Recht ist Erfassen abgewiesen" do
    sign_out users(:system_admin)
    sign_in users(:one)

    assert_no_difference -> { @tournament.games.count } do
      record
    end

    assert_redirected_to tournament_path(@tournament)
  end
end
