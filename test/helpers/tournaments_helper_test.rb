# frozen_string_literal: true

require "test_helper"
require "ostruct"

# Plan 26-01: Vereinsauswahl für die Meldeliste eines Region-Turniers.
# Reihenfolge: Vereine mit gemeldeten Teilnehmern → Austragungsort-Verein → Rest alphabetisch.
class TournamentsHelperTest < ActionView::TestCase
  include TournamentsHelper

  setup do
    @tournament = tournaments(:local)
    @region = @tournament.organizer
    assert @region.is_a?(Region), "Fixture-Vorbedingung: Region-Turnier"
  end

  def club_in_region(name)
    Club.create!(name: name, shortname: name.gsub(/\s/, "")[0, 8], region_id: @region.id)
  end

  test "liefert die Vereine der Region alphabetisch, wenn nichts priorisiert ist" do
    zeta = club_in_region("Zeta Club")
    alpha = club_in_region("Alpha Club")

    result = entry_list_clubs_for(@tournament)
    ids = result.map(&:last)

    assert_includes ids, alpha.id
    assert_includes ids, zeta.id
    assert_operator ids.index(alpha.id), :<, ids.index(zeta.id), "alphabetisch: Alpha vor Zeta"
    assert_equal result.map(&:last).uniq, result.map(&:last), "keine Dubletten"
  end

  test "Verein mit gemeldetem Teilnehmer steht vorn" do
    _alpha = club_in_region("Alpha Club")
    zeta = club_in_region("Zeta Club")

    player = Player.create!(lastname: "MUSTER", firstname: "Max", fl_name: "M. Muster")
    SeasonParticipation.create!(player: player, club: zeta, season: @tournament.season)
    @tournament.seedings.create!(player_id: player.id, position: 1)

    ids = entry_list_clubs_for(@tournament).map(&:last)

    assert_equal zeta.id, ids.first, "Verein mit Meldung muss vor dem alphabetischen Rest stehen"
  end

  test "Austragungsort-Verein steht vor dem alphabetischen Rest" do
    _alpha = club_in_region("Alpha Club")
    host = club_in_region("Zeta Host Club")

    location = Location.create!(name: "Testhalle 26", organizer: @region)
    location.clubs << host
    @tournament.update!(location_id: location.id)

    ids = entry_list_clubs_for(@tournament).map(&:last)

    assert_equal host.id, ids.first, "Austragungsort-Verein muss vorn stehen"
  end

  test "Meldung schlaegt Austragungsort" do
    host = club_in_region("Aaa Host Club")
    seeded = club_in_region("Zzz Seeded Club")

    location = Location.create!(name: "Testhalle 26b", organizer: @region)
    location.clubs << host
    @tournament.update!(location_id: location.id)

    player = Player.create!(lastname: "MELDER", firstname: "Mia", fl_name: "M. Melder")
    SeasonParticipation.create!(player: player, club: seeded, season: @tournament.season)
    @tournament.seedings.create!(player_id: player.id, position: 1)

    ids = entry_list_clubs_for(@tournament).map(&:last)

    assert_equal seeded.id, ids.first, "Verein mit Meldung vor Austragungsort-Verein"
    assert_equal host.id, ids.second, "Austragungsort-Verein danach"
  end

  test "leeres Array, wenn keine Region bestimmbar ist" do
    club_tournament = Tournament.create!(
      title: "Club-Turnier 26", season: @tournament.season,
      organizer: clubs(:bcw), date: Time.current
    )

    assert_equal [], entry_list_clubs_for(club_tournament)
  end

  # PR #64: K.-o.-Baum aus Ergebniszeilen. Verankerte Regexes + deterministischer Tie-Break.

  test "kanonisches Scoring trifft nur die passende Rundengröße" do
    assert_equal 3, ko_round_score("Finale", 1)
    assert_equal 3, ko_round_score("F", 1)
    # Substring-Falle: 'Halbfinale' enthält 'finale', darf aber NICHT den Finale-Slot treffen
    assert_equal 1, ko_round_score("Halbfinale", 1)
    assert_equal 3, ko_round_score("Halbfinale", 2)
    # Doppel-K.-o.-Einzüge sind nicht das echte Finale
    assert_equal 1, ko_round_score("Einzug Finale GwR", 1)
    assert_equal 1, ko_round_score("Einzug Finale VerlR", 1)
  end

  test "Bruchschreibweise landet in der richtigen Rundengröße" do
    assert_equal 3, ko_round_score("1/2 Finale", 2)
    assert_equal 3, ko_round_score("1/4 Finale", 4)
    assert_equal 3, ko_round_score("1/8 Finale", 8)
    # '1/2 Finale' ist ein Halbfinale, kein Finale
    assert_equal 1, ko_round_score("1/2 Finale", 1)
  end

  test "Trostrunden werden zurueckgestuft" do
    assert_equal 0, ko_round_score("1. Verliererrunde", 4)
    assert_equal 0, ko_round_score("1. GR", 4)
    assert_equal 0, ko_round_score("Trostrunde", 2)
  end

  test "fuehrende Anfuehrungszeichen stoeren den Anker nicht" do
    assert_equal "Finale", ko_normalize("\"Finale")
    assert_equal 3, ko_round_score("\"Finale", 1)
  end

  test "Tie-Break waehlt das echte Finale, nicht die Array-Reihenfolge" do
    # Genau der T#145-Fall: das echte 'Finale' muss den Finale-Slot belegen
    candidates = ["Einzug Finale GwR", "7. Verliererrunde", "Einzug Finale VerlR", "Finale"]
    picked = candidates.min_by { |n| [-ko_round_score(n, 1), ko_normalize(n).length, n] }
    assert_equal "Finale", picked
  end

  # Doppel-K.-o.: Grand-Final-Erkennung + Kanten-Rekonstruktion aus dem Spielerfluss.

  test "dko_grand_final? erkennt nur das zusammenfuehrende Endspiel" do
    assert dko_grand_final?(OpenStruct.new(gname: "Finale"))
    assert dko_grand_final?(OpenStruct.new(gname: "F"))
    refute dko_grand_final?(OpenStruct.new(gname: "Einzug Finale GwR"))
    refute dko_grand_final?(OpenStruct.new(gname: "Einzug Finale VerlR"))
    refute dko_grand_final?(OpenStruct.new(gname: "Halbfinale"))
    refute dko_grand_final?(OpenStruct.new(gname: "3. Verliererrunde"))
  end

  test "dko_edges rekonstruiert Sieger- und Abstiegskanten aus dem Spielerfluss" do
    # g1: A schlägt B (A weiter, B faellt in die Verliererrunde)
    # A zieht nach g3 (Gewinner-Baum), B nach g2 (Verlierer-Baum)
    g1 = dko_game(1, {a: 5, b: 3})
    g2 = dko_game(2, {b: 5, c: 2})
    g3 = dko_game(3, {a: 5, d: 4})

    edges = dko_edges([g1, g2, g3])

    win = edges.find { |e| e[:from] == g1.id && e[:to] == g3.id }
    loss = edges.find { |e| e[:from] == g1.id && e[:to] == g2.id }
    assert_equal "win", win[:kind], "A gewann g1 und zog weiter → win-Kante"
    assert_equal "loss", loss[:kind], "B verlor g1 und stieg ab → loss-Kante"
  end

  private

  # Baut ein Spiel als Stub: seqno, id und zwei Teilnehmer {spieler_key => result}.
  def dko_game(seqno, results)
    parts = results.map { |player_key, result| OpenStruct.new(player_id: player_key, result: result) }
    OpenStruct.new(id: seqno * 10, seqno: seqno, game_participations: parts)
  end
end
