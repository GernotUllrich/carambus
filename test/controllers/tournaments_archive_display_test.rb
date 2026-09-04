# frozen_string_literal: true

require "test_helper"

# Plan 41-02: die Turnierseite muss den archivierten Endstand vollstaendig zeigen und darf
# Archiv- nicht mit Live-Zeilen mischen.
class TournamentsArchiveDisplayTest < ActionDispatch::IntegrationTest
  BASE_ID = 58_000_000

  setup do
    @tournament = tournaments(:local)
    @player = players(:jaspers)
  end

  def seeding!(offset, rank, player: nil, name: "Test, Person")
    s = Seeding.new(id: BASE_ID + offset, tournament_id: @tournament.id,
      tournament_type: "Tournament", player: player, rank: rank, state: "participated",
      data: {"result" => {"Endstand" => {"Rang" => rank.to_s, "Name" => name, "Rank" => rank}}})
    s.save!(validate: false) # local_seeding? greift erst nach dem Insert (id ist gesetzt)
    s
  end

  def game!(offset, klass, gname, data)
    klass.create!(id: BASE_ID + offset, tournament_id: @tournament.id,
      tournament_type: "Tournament", gname: gname, seqno: offset, data: data)
  end

  # DER Fall, um den es geht: ein internationales Feld, in dem KEINE Spielerin aufloesbar war.
  # Vor 41-02 sammelte die Listen-Zeile per INNER JOIN nichts ein und die Tabelle blieb leer.
  test "Endstand erscheint auch, wenn KEIN Seeding einen Player hat" do
    seeding!(1, 1, player: nil, name: "Gastspielerin, Erste")
    seeding!(2, 2, player: nil, name: "Gastspielerin, Zweite")

    get tournament_path(@tournament)
    assert_response :success
    assert_match "Endstand", response.body, "Der Listenname muss gesammelt werden"
    assert_match "Gastspielerin, Erste", response.body
    assert_match "Gastspielerin, Zweite", response.body
  end

  test "gemischt: Zeilen mit und ohne Player erscheinen gemeinsam" do
    seeding!(3, 1, player: @player, name: "#{@player.lastname}, #{@player.firstname}")
    seeding!(4, 2, player: nil, name: "Gastspielerin, Ohne")

    get tournament_path(@tournament)
    assert_response :success
    assert_match @player.lastname, response.body
    assert_match "Gastspielerin, Ohne", response.body
  end

  # Die Spaltenkoepfe stammen aus data.keys des ERSTEN Records — deshalb darf nicht gemischt
  # werden: Live-Games tragen dort TableMonitor-State, Archiv-Zeilen die Fachspalten der App.
  test "sobald ein Archiv existiert, zeigt die Spieletabelle NUR die Archiv-Zeilen" do
    seeding!(5, 1, player: @player)
    game!(101, Game, "live1", {"playera" => "Monitor-State", "innings_list" => []})
    game!(201, ArchivedGame, "R1.1", {"Partie" => "1", "Ergebnis" => "15:11"})

    get tournament_path(@tournament)
    assert_response :success
    assert_match "15:11", response.body, "Die Archiv-Zeile muss erscheinen"
    refute_match "innings_list", response.body,
      "Der Monitor-State eines Live-Games darf nicht als Spaltenkopf auftauchen"
  end

  test "ohne Archiv bleibt die bisherige Anzeige unveraendert" do
    seeding!(6, 1, player: @player)
    game!(102, Game, "live1", {"Partie" => "1", "Ergebnis" => "20:5"})

    get tournament_path(@tournament)
    assert_response :success
    assert_match "20:5", response.body, "Ohne Archiv zeigt die Seite weiterhin die lokalen Games"
  end

  # Live am 2026-09-05: ein einziger Spieler ohne Rang legte die komplette Turnierseite
  # lahm — "comparison of NilClass with 4 failed" aus dem sort_by der Ergebnistabelle.
  # Ursache war ein RK-Defekt im Turnierplan, der einem Spieler keinen Rang zuwies; die
  # View hatte im if/elsif kein else und lieferte fuer ihn nil als Sortierschluessel.
  # Ein fehlender Rang ist ein Datenbefund, kein Grund, die Seite zu verlieren.
  def rankless_seeding!(offset, name)
    s = Seeding.new(id: BASE_ID + offset, tournament_id: @tournament.id,
      tournament_type: "Tournament", player: nil, rank: nil, state: "participated",
      data: {"result" => {"Endstand" => {"Name" => name}}}) # weder "Rank" noch "Rang"
    s.save!(validate: false)
    s
  end

  test "ein Spieler OHNE Rang wirft die Ergebnistabelle nicht um" do
    seeding!(10, 1, name: "Erster, Mit Rang")
    seeding!(11, 2, name: "Zweiter, Mit Rang")
    rankless_seeding!(12, "Ohnerang, Peter")

    get tournament_path(@tournament)

    assert_response :success
    assert_match "Erster, Mit Rang", response.body
    assert_match "Ohnerang, Peter", response.body,
      "Der ranglose Spieler muss trotzdem in der Tabelle stehen"
  end

  test "der ranglose Spieler sortiert ans ENDE, nicht nach vorn" do
    seeding!(13, 1, name: "Erster, Mit Rang")
    rankless_seeding!(14, "Ohnerang, Peter")
    seeding!(15, 2, name: "Zweiter, Mit Rang")

    get tournament_path(@tournament)

    assert_response :success
    body = response.body
    assert body.index("Ohnerang, Peter") > body.index("Zweiter, Mit Rang"),
      "Ohne Rang gehoert ans Ende der Rangliste, nicht dazwischen oder davor"
  end
end
