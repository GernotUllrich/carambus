# frozen_string_literal: true

require "test_helper"

# Plan 41-01: Ergebnisarchiv — die Schreiblogik.
#
# `local_server?` wird gestubbt, weil der Endpoint ausschliesslich auf Location-Servern laeuft
# (dort spricht carambus_app mit Carambus) und die Seeding-Validierung genau daran haengt:
# Seedings ohne aufgeloesten Spieler sind nur lokal erlaubt (Seeding#local_seeding?). Dieses
# Repo ist die Authority — ohne den Stub misst der Test die falsche Rolle.
class TournamentResultArchiverTest < ActiveSupport::TestCase
  BASE_ID = 55_000_000

  setup do
    @region = regions(:nbv)
    @tournament = tournaments(:local)
    @tournament.update_columns(region_id: @region.id)
    @player = players(:jaspers)
  end

  def payload(standings: nil, games: nil, title: "Endstand")
    {
      title: title,
      standings: standings || [
        {player: {cc_id: nil, dbu_nr: nil, firstname: @player.firstname, lastname: @player.lastname},
         rank: 1,
         columns: {"Rang" => "1", "Name" => "#{@player.lastname}, #{@player.firstname}", "MP" => "10"}}
      ],
      games: games || [
        {gname: "R1.1", seqno: 1, round_no: 1, table_no: 1,
         columns: {"Partie" => "1", "Runde" => "1", "Ergebnis" => "15:11"}}
      ]
    }
  end

  def archive(pl = nil)
    ApplicationRecord.stub(:local_server?, true) do
      ExternalTournament::TournamentResultArchiver.new(
        tournament: @tournament, region: @region, payload: pl || payload
      ).call
    end
  end

  test "legt lokale Seedings mit result-Struktur und Rank als Integer an" do
    result = archive

    assert_equal 1, result[:seedings_written]
    seeding = @tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).first
    refute_nil seeding
    assert_equal 1, seeding.rank
    assert_equal "participated", seeding.state

    row = seeding.data["result"]["Endstand"]
    assert_equal 1, row["Rank"], "Die Anzeige sortiert auf Rank — muss Integer sein, nicht String"
    assert_equal "10", row["MP"], "Die von der App gelieferten Spalten muessen 1:1 durchkommen"
  end

  test "Spieler ohne Treffer: kein Create, Seeding entsteht trotzdem, Meldung in players_unmatched" do
    players_before = Player.count
    pl = payload(standings: [
      {player: {cc_id: nil, dbu_nr: nil, firstname: "Unbekannt", lastname: "Gastspielerin"},
       rank: 1, columns: {"Name" => "Gastspielerin, Unbekannt"}}
    ])

    result = archive(pl)

    assert_equal players_before, Player.count, "Der Vertrag verbietet das Anlegen von Spielern"
    assert_equal 1, result[:seedings_written], "Die Zeile muss trotzdem im Endstand landen"
    assert_equal 1, result[:players_unmatched].size
    assert_equal "Gastspielerin", result[:players_unmatched].first[:lastname]

    seeding = @tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).first
    assert_nil seeding.player_id
  end

  test "legt Spiele als ArchivedGame an und laesst Live-Games unberuehrt" do
    live = Game.create!(tournament: @tournament, gname: "LIVE", seqno: 99,
      data: {"playera" => "x", "innings_list" => []})

    result = archive

    assert_equal 1, result[:games_written]
    archived = ArchivedGame.where(tournament_id: @tournament.id).to_a
    assert_equal 1, archived.size
    assert_equal "ArchivedGame", archived.first.type
    assert_equal "15:11", archived.first.data["Ergebnis"]

    live.reload
    assert_nil live.type, "Ein Live-Game darf vom Archiv-Push nicht angefasst werden"
    assert_equal "x", live.data["playera"]
  end

  test "idempotent: zweiter Lauf aendert nichts" do
    first = archive
    seedings_after_first = @tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).count
    games_after_first = ArchivedGame.where(tournament_id: @tournament.id).count

    second = archive

    assert_equal first[:seedings_written], second[:seedings_written]
    assert_equal seedings_after_first,
      @tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).count,
      "Ein zweiter Push darf keine Dubletten erzeugen"
    assert_equal games_after_first, ArchivedGame.where(tournament_id: @tournament.id).count
  end

  test "markiert das Turnier als archiviert" do
    archive
    assert @tournament.reload.data["archived_at"].present?
  end
end
