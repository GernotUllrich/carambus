# frozen_string_literal: true

require "test_helper"

# Plan 28-01: Ingest der Meldeliste auf die Authority — mit ID-Uebersetzung.
# Das Dokument wird direkt injiziert (document:), damit die Tests netzfrei bleiben.
class RegionServer::EntryListImporterTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @base_url = "https://nbv.carambus.de"
    @source_id = 50_000_777 # LOKALE ID der Quelle — darf auf der Authority nirgends auftauchen

    @player = Player.create!(lastname: "GLOBAL", firstname: "Gerd", fl_name: "G. Global", dbu_nr: 777_777)
  end

  def document(entries: nil, source_tournament_id: @source_id)
    {
      "schema" => "carambus.entry_list/v1",
      "region" => {"shortname" => @region.shortname},
      "season" => {"name" => @season.name},
      "tournaments" => [{
        "source_tournament_id" => source_tournament_id,
        "title" => "Landesmeisterschaft Dreiband",
        "shortname" => "LM3B",
        "balls_goal" => 150,
        "player_class" => "I",
        "date" => "2026-10-10T10:00:00+02:00",
        "end_date" => "2026-10-11T18:00:00+02:00",
        "entries" => entries || [{
          "dbu_nr" => 777_777, "lastname" => "GLOBAL", "firstname" => "Gerd",
          "club" => "Testverein", "position" => 1, "balls_goal" => 150
        }]
      }]
    }
  end

  def importer(armed: false, doc: document)
    RegionServer::EntryListImporter.new(
      region: @region, season: @season, base_url: @base_url, armed: armed, document: doc
    )
  end

  test "dry-run schreibt nichts, meldet aber was entstehen wuerde" do
    result = nil
    assert_no_difference(["Tournament.count", "Seeding.count"]) do
      result = importer.call
    end

    assert_equal 1, result.tournaments_created
    assert_equal 1, result.seedings_created
  end

  test "ARMED legt ein Turnier mit GLOBALER id an — die lokale ID taucht nicht auf" do
    assert_difference("Tournament.count", 1) do
      importer(armed: true).call
    end

    imported = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")
    assert imported, "Turnier muss ueber source_url auffindbar sein"
    refute_equal @source_id, imported.id, "die lokale Quell-ID darf nicht uebernommen werden"
    assert_equal "Landesmeisterschaft Dreiband", imported.title
    assert_equal 150, imported.balls_goal
    assert_equal @season.id, imported.season_id
    refute imported.auto_upload_to_cc
  end

  test "gemeldete Spieler werden als Seedings verknuepft" do
    importer(armed: true).call
    imported = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")

    assert_equal 1, imported.seedings.count
    assert_equal @player.id, imported.seedings.first.player_id
  end

  test "zweiter Lauf legt keine Dubletten an" do
    importer(armed: true).call

    result = nil
    assert_no_difference(["Tournament.count", "Seeding.count"]) do
      result = importer(armed: true).call
    end
    assert_equal 1, result.tournaments_matched
    assert_equal 0, result.seedings_created
  end

  test "gewachsene Meldeliste ergaenzt nur den neuen Spieler" do
    importer(armed: true).call
    neu = Player.create!(lastname: "NACH", firstname: "Nina", fl_name: "N. Nach", dbu_nr: 888_888)

    erweitert = document(entries: [
      {"dbu_nr" => 777_777, "lastname" => "GLOBAL", "firstname" => "Gerd", "position" => 1},
      {"dbu_nr" => 888_888, "lastname" => "NACH", "firstname" => "Nina", "position" => 2}
    ])

    assert_difference("Seeding.count", 1) do
      importer(armed: true, doc: erweitert).call
    end

    imported = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")
    assert_includes imported.seedings.pluck(:player_id), neu.id
  end

  test "unaufloesbare Spieler werden berichtet und NICHT angelegt" do
    unbekannt = document(entries: [
      {"dbu_nr" => 999_999, "lastname" => "UNBEKANNT", "firstname" => "Udo", "club" => "Fremdverein"}
    ])

    result = nil
    assert_no_difference("Player.count") do
      result = importer(armed: true, doc: unbekannt).call
    end

    assert_equal 1, result.players_unresolved.size
    assert_match(/UNBEKANNT/, result.players_unresolved.first)
    assert_match(/999999|999_999/, result.players_unresolved.first.delete("_"))
  end

  test "Eintrag ohne Quell-Kennung wird uebersprungen" do
    ohne_id = document(source_tournament_id: nil)

    result = importer(armed: true, doc: ohne_id).call

    assert_equal 1, result.skipped_no_source_id
    assert_equal 0, result.tournaments_created
  end

  test "Antwort ohne tournaments-Liste wird abgelehnt" do
    assert_raises(ArgumentError) do
      importer(doc: {"schema" => "carambus.entry_list/v1"}).call
    end
  end

  # ---- Plan 29-03: Ergebnis-Transport ----------------------------------------------------------

  def ranking
    {"Rang" => 1, "Name" => "Global, Gerd", "Bälle" => 120, "Aufn" => 106,
     "GD" => 1.132, "HS" => 5, "BED" => 1.29, "Punkte" => 4}
  end

  def document_with_ranking
    doc = document
    doc["tournaments"].first["entries"].first["Gesamtrangliste"] = ranking
    doc
  end

  # REGRESSIONSPROBE Phase 28: ohne Ergebnis muss sich der Meldelisten-Weg exakt wie vorher verhalten.
  test "ohne Ergebnis bleibt der Meldelisten-Ingest unveraendert" do
    result = importer(armed: true).call

    assert_equal 1, result.tournaments_created
    assert_equal 1, result.seedings_created
    assert_equal 0, result.rankings_imported
    seeding = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}").seedings.first
    assert seeding.data.blank? || seeding.data.dig("result", "Gesamtrangliste").blank?
  end

  test "ARMED traegt die Gesamtrangliste auf das globale Seeding" do
    result = importer(armed: true, doc: document_with_ranking).call

    assert_equal 1, result.rankings_imported
    seeding = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}").seedings.first
    entry = seeding.data.dig("result", "Gesamtrangliste")
    assert_equal 1, entry["Rang"]
    assert_equal 120, entry["Bälle"]
    assert_equal 4, entry["Punkte"]
    assert_equal "carambus", seeding.data["result_source"]
  end

  test "dry-run meldet das Ergebnis, schreibt es aber nicht" do
    result = nil
    assert_no_difference("Seeding.count") do
      result = importer(doc: document_with_ranking).call
    end

    assert_equal 1, result.rankings_imported
  end

  test "zweiter Lauf mit Ergebnis erzeugt keine Dubletten" do
    importer(armed: true, doc: document_with_ranking).call
    importer(armed: true, doc: document_with_ranking).call

    tournament = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")
    assert_equal 1, tournament.seedings.count
    assert_equal 1, tournament.seedings.first.data["result"].keys.size
  end

  # Ein spaeter nachgemeldetes Ergebnis muss ein bereits bestehendes Seeding erreichen.
  test "Ergebnis erreicht ein bereits bestehendes Seeding" do
    importer(armed: true).call
    result = importer(armed: true, doc: document_with_ranking).call

    assert_equal 0, result.seedings_created, "die Meldung existiert schon"
    assert_equal 1, result.rankings_imported
    seeding = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}").seedings.first
    assert_equal 1, seeding.data.dig("result", "Gesamtrangliste", "Rang")
  end

  test "gescrapte Gesamtrangliste wird nicht ueberschrieben" do
    importer(armed: true).call
    seeding = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}").seedings.first
    scraped = {"Rang" => 9, "Name" => "Aus der CC"}
    seeding.update!(data: {"result" => {"Gesamtrangliste" => scraped}})

    result = importer(armed: true, doc: document_with_ranking).call

    assert_equal 1, result.rankings_skipped_foreign
    assert_equal 0, result.rankings_imported
    assert_equal scraped, seeding.reload.data.dig("result", "Gesamtrangliste")
  end

  # ---- Plan 29-05: Zugang -----------------------------------------------------------------------
  # Der Endpunkt steht hinter `authenticate_user!`. Ohne Token bekam der Ingest einen
  # Login-Redirect und meldete "Quelle nicht erreichbar (HTTP 302)" — die Ursache blieb verborgen.

  # Kein `document:` — dieser Zweig ist der einzige, der wirklich fetcht.
  def fetching_importer(token: nil)
    RegionServer::EntryListImporter.new(
      region: @region, season: @season, base_url: @base_url, armed: false, token: token
    )
  end

  def with_yaml_credentials
    config = Carambus.config
    before = [config.region_server_user, config.region_server_password]
    config.region_server_user = "carambus-app-nbv-bridge@carambus.de"
    config.region_server_password = "geheim"
    yield
  ensure
    config.region_server_user, config.region_server_password = before
  end

  test "der Meldelisten-Fetch traegt das Bearer-Token" do
    login = stub_request(:post, "#{@base_url}/login")
      .to_return(status: 200, headers: {"Authorization" => "Bearer test-jwt"}, body: "{}")
    fetch = stub_request(:get, "#{@base_url}/api/entry_lists")
      .with(query: {region: @region.shortname, season: @season.name},
        headers: {"Authorization" => "Bearer test-jwt"})
      .to_return(status: 200, body: document.to_json)

    result = with_yaml_credentials { fetching_importer.call }

    assert_requested login
    assert_requested fetch
    assert_equal 1, result.seedings_created, "der dry-run zaehlt die Meldungen"
  end

  test "ohne Zugang bricht der Ingest verstaendlich ab" do
    error = assert_raises(RuntimeError) { fetching_importer.call }

    assert_match(/create_carambus_app/, error.message,
      "die Meldung muss sagen, WIE der Service-Account entsteht")
    assert_match(/secrets\.yml/, error.message,
      "und ueber welchen Weg die Zugangsdaten ausgeliefert werden")
    refute_match(/HTTP 302/, error.message)
  end

  test "abgelehnte Anmeldung wird als solche gemeldet" do
    stub_request(:post, "#{@base_url}/login").to_return(status: 401, body: "")

    error = assert_raises(RuntimeError) { with_yaml_credentials { fetching_importer.call } }

    assert_match(/Anmeldung am Region Server fehlgeschlagen \(HTTP 401\)/, error.message)
  end

  # Der document:-Pfad darf keinen Zugang verlangen — die 8 Tests oben fahren darauf.
  test "injiziertes Dokument braucht keine Zugangsdaten" do
    assert_nothing_raised { importer.call }
  end

  # --- Plan 29-06: der Ingest aktualisiert und entfernt jetzt (nicht mehr nur anlegen) ---

  # Ein zweiter Spieler in der Meldeliste, damit Prune/Update etwas zu greifen haben.
  def second_player
    @second_player ||= Player.create!(lastname: "ZWEIT", firstname: "Zoe", fl_name: "Z. Zweit", dbu_nr: 888_888)
  end

  def entry_for(player, position:, balls_goal: 150)
    {"dbu_nr" => player.dbu_nr, "lastname" => player.lastname, "firstname" => player.firstname,
     "club" => "Testverein", "position" => position, "balls_goal" => balls_goal}
  end

  test "zweiter Lauf aktualisiert Titel und Datum eines bestehenden Turniers" do
    importer(armed: true).call
    t = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")

    doc = document
    doc["tournaments"][0]["title"] = "LM Dreiband (verlegt)"
    doc["tournaments"][0]["date"] = "2026-11-15T10:00:00+01:00"

    result = importer(armed: true, doc: doc).call

    assert_equal 1, result.tournaments_matched
    assert_equal 1, result.tournaments_updated
    assert_equal "LM Dreiband (verlegt)", t.reload.title
    assert_equal Date.new(2026, 11, 15), t.date.to_date
  end

  test "eine auf der Quelle geloeschte Meldung wird auf der Authority entfernt" do
    two = document(entries: [entry_for(@player, position: 1), entry_for(second_player, position: 2)])
    importer(armed: true, doc: two).call
    t = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")
    assert_equal 2, t.seedings.count

    one = document(entries: [entry_for(@player, position: 1)])
    result = importer(armed: true, doc: one).call

    assert_equal 1, result.seedings_removed
    assert_equal [@player.id], t.reload.seedings.pluck(:player_id)
  end

  test "eine bereits gespielte Meldung (mit Ergebnis) wird NIE entfernt" do
    two = document(entries: [entry_for(@player, position: 1), entry_for(second_player, position: 2)])
    importer(armed: true, doc: two).call
    t = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")
    gespielt = t.seedings.find_by(player_id: second_player.id)
    gespielt.update!(data: {"result" => {"Gesamtrangliste" => {"Rang" => 1}}})

    one = document(entries: [entry_for(@player, position: 1)])
    result = importer(armed: true, doc: one).call

    assert_equal 0, result.seedings_removed, "Ergebnis-Seeding ist geschuetzt"
    assert t.reload.seedings.exists?(player_id: second_player.id)
  end

  test "geaenderte Setzposition wird nachgezogen" do
    importer(armed: true, doc: document(entries: [entry_for(@player, position: 5)])).call
    t = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")
    assert_equal 5, t.seedings.first.position

    importer(armed: true, doc: document(entries: [entry_for(@player, position: 1)])).call

    assert_equal 1, t.reload.seedings.first.position
  end

  test "dry-run des zweiten Laufs schreibt weder Update noch Loeschung" do
    two = document(entries: [entry_for(@player, position: 1), entry_for(second_player, position: 2)])
    importer(armed: true, doc: two).call
    t = Tournament.find_by(source_url: "#{@base_url}/tournaments/#{@source_id}")

    one = document(entries: [entry_for(@player, position: 1)])
    one["tournaments"][0]["title"] = "Geaendert"

    result = nil
    assert_no_difference("Seeding.count") do
      result = importer(armed: false, doc: one).call
    end
    assert_equal 1, result.seedings_removed, "der Probelauf MELDET die Loeschung"
    assert_equal 1, result.tournaments_updated
    assert_equal 2, t.reload.seedings.count, "aber schreibt sie nicht"
    refute_equal "Geaendert", t.title
  end
end
