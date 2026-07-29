# frozen_string_literal: true

require "test_helper"

# Plan 35-03: Die gemeinsame Schreibschicht fuer Ergebnisse auf dem Region Server.
#
# Der wichtigste Test ist "data traegt die Anzeigeform" — genau daran scheiterte der Ingest-Weg
# bisher stillschweigend (tournaments/show.html.erb:146 filtert auf "Ergebnis"/"Punkte").
class RegionServer::GameResultWriterTest < ActiveSupport::TestCase
  setup do
    @tournament = tournaments(:local)
    # Explizit gesetzt: ohne region_id pruefen die Regions-Assertions unten nil gegen nil.
    @tournament.update_column(:region_id, regions(:nbv).id)
    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 111_111)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 222_222)
  end

  def write(gname: "Gruppe A", seqno: 1, a: {}, b: {})
    RegionServer::GameResultWriter.new(
      tournament: @tournament,
      gname: gname,
      seqno: seqno,
      ended_at: Time.zone.local(2026, 10, 10, 12, 0),
      participations: [
        {player: @anna, result: 100, innings: 24, hs: 16}.merge(a),
        {player: @bodo, result: 85, innings: 24, hs: 9}.merge(b)
      ]
    ).call
  end

  # --- Sichtbarkeit (AC-1/AC-2) -----------------------------------------------

  test "data traegt die Anzeigeform, die die Turnierseite braucht" do
    game = write.game

    assert_equal "Gruppe A", game.data["Gruppe"]
    assert_equal 1, game.data["Partie"]
    assert_equal "100:85", game.data["Punkte"]
    assert_equal "24/24", game.data["Aufn."]
    assert_equal "16/9", game.data["HS"]
    assert_equal @anna.fullname, game.data["Heim"]
    assert_equal @bodo.fullname, game.data["Gast"]
  end

  test "das Spiel passiert den Filter der Turnierseite" do
    game = write.game

    # show.html.erb:146 — ohne "Ergebnis" ODER "Punkte" wird die Zeile uebersprungen.
    assert game.data["Ergebnis"].present? || game.data["Punkte"].present?
  end

  test "der Schluesselsatz ist konstant, auch wenn Werte fehlen" do
    voll = write(seqno: 1).game
    ohne_hs = write(seqno: 2, a: {hs: nil}, b: {hs: nil}).game

    # show.html.erb:136 baut den Kopf aus dem ERSTEN Spiel, die Zellen je Zeile aus data.each —
    # ein fehlender Schluessel verschoebe die Spalten. Deshalb bewusst kein `compact`.
    assert_equal voll.data.keys, ohne_hs.data.keys
  end

  # --- Rollen (AC-2) ----------------------------------------------------------

  test "die Rollen heissen playera und playerb" do
    game = write.game

    assert_equal %w[playera playerb], game.game_participations.order(:role).pluck(:role)
    assert_equal @anna.id, game.game_participations.find_by(role: "playera").player_id
    assert_equal @bodo.id, game.game_participations.find_by(role: "playerb").player_id
  end

  test "die Ergebniswerte landen in den GameParticipations" do
    gp = write.game.game_participations.find_by(role: "playera")

    assert_equal 100, gp.result
    assert_equal 24, gp.innings
    assert_equal 16, gp.hs
    assert_equal "Gruppe A", gp.data["results"]["Gr."]
  end

  # --- Generaldurchschnitt ----------------------------------------------------

  test "der Generaldurchschnitt wird aus Baellen und Aufnahmen berechnet" do
    gp = write.game.game_participations.find_by(role: "playera")

    assert_in_delta 4.17, gp.gd, 0.01
  end

  test "ein mitgelieferter Generaldurchschnitt wird nicht ueberschrieben" do
    gp = write(a: {gd: 3.99}).game.game_participations.find_by(role: "playera")

    assert_in_delta 3.99, gp.gd, 0.01
  end

  test "null Aufnahmen fuehren nicht zu Infinity" do
    gp = write(a: {innings: 0}).game.game_participations.find_by(role: "playera")

    assert_nil gp.gd
  end

  # --- Upsert (AC-5) ----------------------------------------------------------

  test "dasselbe Spiel wird aktualisiert statt dupliziert" do
    first = write(gname: "Gruppe A", seqno: 3)
    assert first.created

    assert_no_difference -> { @tournament.games.count } do
      second = write(gname: "Gruppe A", seqno: 3, a: {result: 120})
      refute second.created
      assert_equal first.game.id, second.game.id
    end

    assert_equal 120, @tournament.games.find_by(gname: "Gruppe A", seqno: 3)
      .game_participations.find_by(role: "playera").result
  end

  test "verschiedene Partien desselben Spielnamens bleiben getrennt" do
    write(gname: "Halbfinale", seqno: 10)
    write(gname: "Halbfinale", seqno: 11)

    assert_equal 2, @tournament.games.where(gname: "Halbfinale").count
  end

  # Die Lokalitaet (id >= MIN_ID) stellt die DB-Sequenz her, nicht der Writer — in der
  # Testumgebung vergibt sie kleine IDs (derselbe Umstand, den game_result_ingest_test.rb mit einer
  # expliziten ID umgeht). Geprueft wird deshalb, was der Writer tatsaechlich setzt.
  test "das Spiel traegt die Region des Turniers" do
    assert_equal @tournament.region_id, write.game.region_id
  end

  test "die Participations tragen die Region des Turniers" do
    assert_equal [@tournament.region_id] * 2,
      write.game.game_participations.pluck(:region_id)
  end
end
