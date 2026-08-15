# frozen_string_literal: true

require "test_helper"

# Plan 32-10: Die OEFFENTLICHE Lese-Sicht auf die Ergebniszeilen des Region Servers.
#
# Betreiber-Entscheidung D9: Lesen ist oeffentlich (wie das public CC), Schreiben bleibt
# authentifiziert. Der SCOPE (region+season) ist der Schutz, nicht ein Token.
class Api::Public::GameResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @plan = tournament_plans(:t06_6)

    @tournament = Tournament.create!(
      id: 50_000_920,
      title: "Landesmeisterschaft Dreiband", shortname: "LM3B920",
      season: @season, organizer: @region, region_id: @region.id,
      tournament_plan_id: @plan.id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 515_151)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 616_161)
    build_game(@tournament)
  end

  # Explizite lokale IDs (>= MIN_ID): die Test-Sequenz vergaebe sonst globale. Deterministisch
  # hochgezaehlt statt zufaellig — ein Test, der je nach Lauf andere IDs bekommt, ist schwerer
  # zu reproduzieren, wenn er einmal faellt.
  def build_game(tournament, gname: "Gruppe A", seqno: 7)
    @next_game_id = (@next_game_id || 50_000_500) + 1
    game = tournament.games.create!(id: @next_game_id,
      gname: gname, seqno: seqno, ended_at: Time.zone.local(2026, 10, 10, 14, 12))
    game.game_participations.create!(player: @anna, role: "playera", result: 100, innings: 24, hs: 16, gd: 4.17)
    game.game_participations.create!(player: @bodo, role: "playerb", result: 85, innings: 24, hs: 9, gd: 3.54)
    game
  end

  def get_results(region: @region.shortname, season: @season.name)
    params = {}
    params[:region] = region if region
    params[:season] = season if season
    get api_public_game_results_url, params: params
  end

  def body = JSON.parse(response.body)

  # AC-6 — der Kern der Entscheidung D9
  test "liefert ohne Authorization-Header aus" do
    get_results

    assert_response :success
    assert_equal "carambus.game_result/v1", body["schema"]
    assert_equal @region.shortname, body.dig("region", "shortname")

    # Nicht mehr `.sole`: das Dokument fuehrt seit dem Pruning-Fix auch Turniere ohne Spiele,
    # also die uebrigen Fixture-Turniere der Region/Saison. Geprueft wird das eigene.
    payload = body["tournaments"].find { |t| t["source_tournament_id"] == @tournament.id }
    assert payload, "das bespielte Turnier muss enthalten sein"
    assert_equal @plan.id, payload["tournament_plan_id"]

    row = payload["games"].sole
    assert_equal "Gruppe A", row["group"]
    assert_equal 7, row["seqno"]
    assert_equal %w[515151 616161], row["participations"].map { |p| p["dbu_nr"] }
    assert_equal 100, row["participations"].first["result"]
  end

  # AC-6 — der Scope ist der Schutz
  test "ohne region antwortet 400" do
    get_results(region: nil)
    assert_response :bad_request
  end

  test "ohne season antwortet 400" do
    get_results(season: nil)
    assert_response :bad_request
  end

  test "unbekannte Region antwortet 404" do
    get_results(region: "GIBTSNICHT")
    assert_response :not_found
  end

  test "Region wird case-insensitive aufgeloest" do
    get_results(region: @region.shortname.downcase)
    assert_response :success
  end

  # Die folgenden drei Tests pruefen je einen FILTER. Sie stuetzten sich frueher darauf, dass die
  # Liste genau ein Element hat — seit Turniere ohne Spiele mit ausgeliefert werden (fuer das
  # Pruning, siehe unten), enthaelt sie auch die uebrigen Fixture-Turniere der Region/Saison.
  # Die Zusicherung ist dieselbe geblieben, nur zielgerichtet auf das jeweilige Turnier formuliert.
  def delivered_ids = body["tournaments"].map { |t| t["source_tournament_id"] }

  test "Turniere anderer Saisons sind nicht enthalten" do
    other = Season.where.not(id: @season.id).first
    skip "keine zweite Saison in den Fixtures" if other.nil?

    get_results(season: other.name)

    assert_response :success
    assert_not_includes delivered_ids, @tournament.id
  end

  # AC-4 — was aus der ClubCloud stammt, gehoert der ClubCloud
  test "CC-Turniere werden nicht ausgeliefert" do
    TournamentCc.create!(tournament: @tournament, cc_id: 4711)

    get_results

    assert_response :success
    assert_not_includes delivered_ids, @tournament.id
  end

  test "globale Turniere werden nicht ausgeliefert" do
    global = Tournament.create!(
      id: 23_456, title: "Globales Turnier", shortname: "GLOB456",
      season: @season, organizer: @region, region_id: @region.id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    build_game(global, gname: "Finale", seqno: 99)

    get_results

    assert_not_includes delivered_ids, global.id, "id < MIN_ID gehört der Authority"
    assert_includes delivered_ids, @tournament.id
  end

  # UMGESCHRIEBEN 2026-08-05. Der Test hielt zuvor fest, dass Turniere ohne Spiele NICHT erscheinen
  # ("wäre nur Ballast"). Das galt, solange der Importer ausschliesslich Upserts machte. Seit er
  # geloeschte Spiele entfernt (GameResultImporter#prune_removed_games), ist die leere Liste die
  # EINZIGE Moeglichkeit auszudruecken, dass alle Spiele zurueckgezogen wurden — fehlt das Turnier,
  # laeuft das Pruning fuer es nie.
  #
  # LIVE AUFGEFALLEN: nach dem Loeschen aller Spiele auf tbv lieferte der Endpunkt
  # `"tournaments":[]`; der Ingest lief folgenlos durch, die globalen Spiele blieben stehen.
  test "Turniere ohne Spiele erscheinen mit leerer Spieleliste" do
    @tournament.games.destroy_all

    get_results

    assert_response :success
    payload = body["tournaments"].find { |t| t["source_tournament_id"] == @tournament.id }

    assert payload, "das Turnier muss enthalten bleiben, sonst kann die Authority nicht aufräumen"
    assert_empty payload["games"]
  end

  # --- KETTENTEST Sender → Empfänger -----------------------------------------
  #
  # WARUM DIESER TEST EXISTIERT: Sender und Empfänger waren einzeln getestet und beide grün —
  # der Fehler saß in ihrer VERBINDUNG. Der Endpunkt lieferte Turniere ohne Spiele gar nicht aus
  # ("wäre nur Ballast"), das Pruning des Importers lief für sie deshalb nie, und gelöschte Spiele
  # blieben global stehen. Live aufgefallen 2026-08-05.
  #
  # Genau diese Klasse von Fehlern — Mechanik intakt, Verbindung ungeprüft — ist heute mehrfach
  # aufgetreten. Der Test füttert deshalb die ECHTE Endpunkt-Antwort in den ECHTEN Importer,
  # statt beide Seiten gegen ein handgeschriebenes Dokument zu prüfen.
  test "eine Löschung auf der Quelle räumt über den echten Endpunkt auch global auf" do
    # Das globale Gegenstück auf der Authority, wie es ein früherer Ingest angelegt hätte.
    global = Tournament.create!(
      id: 23_457, title: "Landesmeisterschaft Dreiband", shortname: "LM3B457",
      season: @season, organizer: @region, region_id: @region.id,
      source_url: "https://nbv.carambus.de/tournaments/#{@tournament.id}",
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )
    global.games.create!(gname: "Gruppe A", seqno: 7, region_id: @region.id)
    assert_equal 1, global.games.count

    # Der Sportwart löscht das Spiel auf dem Region Server.
    @tournament.games.destroy_all

    get_results
    assert_response :success

    result = RegionServer::GameResultImporter.new(
      region: @region, season: @season, base_url: "https://nbv.carambus.de",
      armed: true, document: body
    ).call

    assert_equal 1, result.games_removed, "der Importer muss die Löschung erkennen"
    assert_equal 0, global.games.reload.count, "das globale Spiel muss verschwunden sein"
  end

  test "ein CC-Turnier bleibt auch ohne Spiele draussen" do
    @tournament.games.destroy_all
    TournamentCc.create!(tournament: @tournament, cc_id: 987_654)

    get_results

    assert_response :success
    assert_not_includes delivered_ids, @tournament.id,
      "CC-Turniere gehören der ClubCloud — auch leer nicht ausliefern"
  end
end
