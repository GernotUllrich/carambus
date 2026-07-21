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
end
