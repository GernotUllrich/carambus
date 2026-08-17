# frozen_string_literal: true

require "test_helper"

# Plan 32-10: Ergebniszeilen des Region Servers -> GLOBALE Game/GameParticipation auf der Authority.
#
# Zwei Dinge stehen im Mittelpunkt:
#   1. Die Record-Form muss der des CC-Scrapes gleichen (Heim/Gast, data.results) — nur dann
#      verrechnet das turnieruebergreifende Ranking sie wie gescrapte Spiele.
#   2. Upsert statt Delete-and-Rebuild: ein unveraenderter Quellstand darf KEINE Versionen erzeugen.
class RegionServer::GameResultImporterTest < ActiveSupport::TestCase
  BASE = "https://nbv.carambus.de"
  SOURCE_ID = 50_000_021

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)

    # Das GLOBALE Turnier auf der Authority — verknuepft ueber source_url, nicht ueber die ID.
    @tournament = Tournament.create!(
      id: 34_567, title: "Landesmeisterschaft Dreiband", shortname: "LM3B567",
      season: @season, organizer: @region, region_id: @region.id,
      date: Time.zone.local(2026, 10, 10, 10, 0),
      source_url: "#{BASE}/tournaments/#{SOURCE_ID}"
    )
    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 717_171)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 818_181)
  end

  def game_row(group: "Gruppe A", seqno: 7, result_a: 100, result_b: 85, dbu_b: "818181")
    {
      "group" => group, "seqno" => seqno, "ended_at" => "2026-10-10T14:12:00+02:00",
      "participations" => [
        {"dbu_nr" => "717171", "role" => "playera", "result" => result_a, "innings" => 24, "hs" => 16, "gd" => 4.17},
        {"dbu_nr" => dbu_b, "role" => "playerb", "result" => result_b, "innings" => 24, "hs" => 9, "gd" => 3.54}
      ]
    }
  end

  def document(games: [game_row], source_tournament_id: SOURCE_ID)
    {
      "schema" => "carambus.game_result/v1",
      "tournaments" => [
        {"source_tournament_id" => source_tournament_id, "tournament_plan_id" => 42, "games" => games}
      ]
    }
  end

  def import(doc = document, armed: true)
    RegionServer::GameResultImporter.new(
      region: @region, season: @season, base_url: BASE, armed: armed, document: doc
    ).call
  end

  # AC-1 — die kanonische Form
  test "erzeugt globale Spiele in CC-Scrape-Form" do
    result = import

    assert_equal 1, result.tournaments_matched
    assert_equal 1, result.games_created

    game = @tournament.games.sole
    assert_operator game.id, :<, ApplicationRecord::MIN_ID, "auf der Authority entstehen globale IDs"
    assert_equal "Tournament", game.tournament_type
    assert_equal "Gruppe A", game.gname
    assert_equal 7, game.seqno
    assert_equal @region.id, game.region_id

    assert_equal %w[Heim Gast], game.game_participations.map(&:role),
      "global tragen die Rollen Heim/Gast wie beim CC-Scrape, nicht playera/playerb"

    heim = game.game_participations.find_by(role: "Heim")
    assert_equal @anna.id, heim.player_id
    assert_equal 100, heim.result
    assert_equal "Gruppe A", heim.data.dig("results", "Gr.")
    assert_equal 16, heim.data.dig("results", "HS")
  end

  # Ohne diese Felder ueberspringt tournaments/show.html.erb:137 das Spiel — es waere unsichtbar.
  test "game.data traegt die Felder, die die Turnierseite anzeigt" do
    import

    data = @tournament.games.sole.data
    assert_equal "100:85", data["Punkte"], "die Turnierseite filtert auf Ergebnis ODER Punkte"
    assert_equal 7, data["Partie"], "danach sortiert die Turnierseite"
    assert_equal "Gruppe A", data["Gruppe"]
    assert_equal "24/24", data["Aufn."]
    assert_equal "16/9", data["HS"]
    assert_equal @anna.fullname, data["Heim"]
    assert_equal @bodo.fullname, data["Gast"]
  end

  # AC-2
  test "Korrektur aktualisiert dasselbe Spiel ohne Dublette" do
    import
    result = import(document(games: [game_row(result_b: 87)]))

    assert_equal 1, @tournament.games.count
    assert_equal 1, result.games_updated
    assert_equal 87, @tournament.games.sole.game_participations.find_by(role: "Gast").result
    assert_equal "100:87", @tournament.games.sole.data["Punkte"]
  end

  # AC-2, zweiter Teil — der Grund fuer Upsert statt Delete-and-Rebuild
  test "unveraenderter Quellstand erzeugt keine neue Version" do
    import
    game = @tournament.games.sole
    versions_before = game.versions.count

    result = import

    assert_equal 1, result.games_unchanged
    assert_equal 0, result.games_created
    assert_equal versions_before, game.reload.versions.count,
      "ein zweiter Pull ohne Quelländerung darf den Sync nicht fluten"
  end

  test "gleicher Name mit anderer Partie bleibt ein eigenes Spiel" do
    import(document(games: [game_row(group: "Halbfinale", seqno: 12),
      game_row(group: "Halbfinale", seqno: 13)]))

    assert_equal 2, @tournament.games.where(gname: "Halbfinale").count
  end

  # AC-3
  test "unbekannte dbu_nr wird berichtet, kein Spieler und kein Spiel angelegt" do
    result = nil
    assert_no_difference(["Player.count", "Game.count"]) do
      result = import(document(games: [game_row(dbu_b: "999999")]))
    end

    assert_equal 1, result.players_unresolved.size
    assert_includes result.players_unresolved.first, "999999"
  end

  # AC-4 — was aus der ClubCloud stammt, gehoert der ClubCloud
  #
  # SEIT PLAN 34-02 entscheidet das die PROVENIENZ (`cc_sourced?`), nicht mehr die blosse Existenz
  # eines `tournament_cc`. Der Unterschied ist nicht kosmetisch: 376 Turniere im Bestand tragen einen
  # CC-Zwilling aus der BillardArea-Migration, obwohl die ClubCloud sie nie gefuehrt hat (gemessen auf
  # Produktion 2026-08-16). Die gehoeren der CC nicht — `tournament_cc.present?` behauptete es trotzdem.
  test "CC-Turniere werden nicht angefasst" do
    @tournament.update!(source_kind: :club_cloud)
    TournamentCc.create!(tournament: @tournament, cc_id: 4711)

    result = nil
    assert_no_difference("Game.count") { result = import }

    assert_equal 1, result.tournaments_skipped_cc
    assert_equal 0, result.tournaments_matched
  end

  # Die Kehrseite derselben Umstellung, bewusst festgehalten: ein CC-ZWILLING ALLEIN reicht nicht
  # mehr. Ein Turnier, das der Region Server angelegt hat (`source_kind :carambus`), wird importiert,
  # auch wenn irgendwo ein `tournament_cc` daran haengt.
  #
  # Im Bestand existiert diese Kombination NICHT — kein einziges der Turniere mit `tournament_cc`
  # traegt `:carambus` (Produktion 2026-08-16: 5 121x `club_cloud`, 376x `ba`, 0x `carambus`). Und
  # entstehen kann sie kaum: sobald ein Turnier wirklich aus der CC gescrapt wird, traegt es eine
  # CC-`source_url` und damit `:club_cloud`.
  test "ein CC-Zwilling allein macht ein Region-Server-Turnier nicht zum CC-Turnier" do
    TournamentCc.create!(tournament: @tournament, cc_id: 4712)

    assert_equal "carambus", @tournament.reload.source_kind, "Testvoraussetzung: Region-Server-Herkunft"

    result = nil
    assert_difference("Game.count", 1) { result = import }

    assert_equal 0, result.tournaments_skipped_cc
    assert_equal 1, result.tournaments_matched
  end

  test "unbekanntes Turnier wird berichtet, nicht angelegt" do
    result = nil
    assert_no_difference(["Tournament.count", "Game.count"]) do
      result = import(document(source_tournament_id: 50_009_999))
    end

    assert_equal 1, result.tournaments_unmatched.size
    assert_includes result.tournaments_unmatched.first, "50009999"
  end

  # AC-5 — der Probelauf muss gefahrlos sein
  test "dry-run zaehlt, schreibt aber nichts" do
    result = nil
    assert_no_difference(["Game.count", "GameParticipation.count"]) do
      result = import(armed: false)
    end

    assert_equal 1, result.games_created, "der Probelauf muss zeigen, was entstehen würde"
  end

  test "Antwort ohne tournaments-Liste bricht verstaendlich ab" do
    error = assert_raises(ArgumentError) { import({"schema" => "x"}) }

    assert_match(/tournaments/, error.message)
  end

  # --- Loeschung (live aufgefallen 2026-07-29) --------------------------------
  #
  # Der Importer machte ausschliesslich Upserts. Ein auf dem Region Server geloeschtes Spiel blieb
  # global stehen — und floss weiter ins Ranking ein. Das Muster ist von
  # EntryListImporter#prune_removed_entries uebernommen; Schluessel wie beim Upsert: (gname, seqno).

  test "ein auf der Quelle geloeschtes Spiel verschwindet global" do
    import(document(games: [game_row(seqno: 1), game_row(seqno: 2)]))
    assert_equal 2, @tournament.games.count

    result = import(document(games: [game_row(seqno: 1)]))

    assert_equal 1, result.games_removed
    assert_equal [1], @tournament.games.reload.pluck(:seqno)
  end

  test "eine leere Spieleliste raeumt das Turnier vollstaendig" do
    import
    result = import(document(games: []))

    assert_equal 1, result.games_removed
    assert_equal 0, @tournament.games.reload.count
  end

  test "unveraenderter Quellstand loescht nichts" do
    import
    result = import

    assert_equal 0, result.games_removed
    assert_equal 1, @tournament.games.reload.count
  end

  test "dry-run loescht nicht, meldet die Loeschung aber" do
    import
    result = nil

    assert_no_difference -> { @tournament.games.count } do
      result = import(document(games: []), armed: false)
    end
    assert_equal 1, result.games_removed
  end

  # Ein Spiel, dessen Spieler nicht aufloesbar ist, EXISTIERT auf der Quelle — es zu loeschen waere
  # die falsche Schlussfolgerung aus einem Stammdaten-Problem.
  test "ein Spiel mit unaufloesbarem Spieler wird nicht geloescht" do
    import
    result = import(document(games: [game_row(dbu_b: "999999")]))

    assert_equal 1, result.players_unresolved.size
    assert_equal 0, result.games_removed
    assert_equal 1, @tournament.games.reload.count
  end
end
