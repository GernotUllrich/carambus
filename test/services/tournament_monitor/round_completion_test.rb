# frozen_string_literal: true

require "test_helper"

# Plan 06-01 (2026-09-03): Rundenabschluss-Erkennung.
#
# `all_table_monitors_finished?` entscheidet, ob die Runde weiterschaltet. Bis Phase 6
# prueft es dafuer den Zustand der TISCHE — die fachliche Frage gilt aber den SPIELEN.
# Drei belegte Blindstellen, auf denen Tische "fertig" aussehen, obwohl Spiele offen sind:
#
#   1. `finalize_round` setzt nach `close_match!` `game_id: nil`, laesst den State stehen.
#      Das `joins(:game)` (INNER JOIN) blendet solche Tische aus. Genau das stand nach dem
#      Vorfall vom 2026-09-03 in der DB: drei Tische in state="playing" ohne Spiel.
#   2. `do_placement` bricht bei Tischmangel mit einer blossen Error-Logzeile ab — das
#      Spiel der Runde ist unbeendet, liegt aber auf keinem Tisch.
#   3. Im continuous_placements-Pfad wird ein laufendes Spiel vom Tisch verdraengt und in
#      `tmp_results` geparkt; auch dieses Spiel ist offen, der Tisch sieht frei aus.
#
# ⚠️ Sicherheitsanforderung (Datenlage 2026-09-03): von 2497 lokalen Live-Games tragen nur
# 55 ein `round_no`. Findet die Spiel-Pruefung fuer die aktuelle Runde KEINE Spiele, darf
# sie NICHT "fertig" melden — eine leere Menge wuerde `all?` trivial erfuellen und die
# Runde bedingungslos weiterschalten. Dann gilt weiterhin die Tisch-Pruefung.
class TournamentMonitor::RoundCompletionTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  BASE_ID = 61_000_000

  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(4, {balls_goal: 30, innings_goal: 25})
    @tournament = @test_data[:tournament]
    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
    @tm.current_round!(3)

    # Der KO-Helper erzeugt in dieser Umgebung keine lokalen Spiele (verifiziert waehrend
    # Plan 05-01). Alles, was diese Tests brauchen, wird deshalb selbst angelegt — ueber
    # die Assoziation, damit `tournament_type` gesetzt ist. `Game.create!(tournament: ...)`
    # waere still wirkungslos, weil Game#belongs_to :tournament nicht polymorph deklariert
    # ist, Tournament#has_many :games aber schon (Lehre aus Plan 03-02).
    @tournament.games.where("games.id >= #{Game::MIN_ID}").destroy_all
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # Explizite ID >= MIN_ID: `live_games` filtert auf `games.id >= Game::MIN_ID`, die
  # Test-Sequenz vergibt aber vierstellige IDs. Ohne die feste ID waere `live_games` leer
  # und jeder Test liefe unbemerkt in den Tisch-Fallback statt in die Spiel-Pruefung
  # (gleiches Muster wie in tournament_archive_survives_reset_test.rb).
  def round_game!(gname, round_no:, ended: false)
    @next_game_id = (@next_game_id || BASE_ID) + 1
    @tournament.games.create!(
      id: @next_game_id, gname: gname, round_no: round_no, group_no: 1, data: {},
      ended_at: ended ? Time.current : nil
    )
  end

  # `table_name`: TableMonitor#name kommt vom zugeordneten Table (has_one :table), nicht aus
  # der eigenen Spalte — fuer den Tischnamen im Rundenstatus braucht es deshalb einen Table.
  def table_monitor!(state:, game: nil, table_name: nil)
    tabmon = TableMonitor.create!(tournament_monitor: @tm, game: game, state: state, data: {})
    if table_name
      @next_table_id = (@next_table_id || BASE_ID) + 1
      Table.create!(id: @next_table_id, name: table_name, location: locations(:one),
        table_kind: table_kinds(:one), table_monitor: tabmon)
    end
    tabmon
  end

  # ── AC-1 ───────────────────────────────────────────────────────────────────
  # Ein offenes Spiel der laufenden Runde, das auf KEINEM Tisch liegt (nicht platziert
  # oder verdraengt). Die Tisch-Pruefung sieht nur den geschlossenen Tisch und meldet
  # "fertig" — die Runde schaltet weiter, obwohl ein Spiel aussteht.
  test "AC-1: offenes Spiel der Runde ohne Tisch verhindert den Rundenwechsel" do
    finished = round_game!("hf1", round_no: 3, ended: true)
    round_game!("hf2", round_no: 3, ended: false) # offen, liegt auf keinem Tisch
    table_monitor!(state: "ready_for_new_match", game: finished)

    refute @tm.all_table_monitors_finished?,
      "Solange ein Spiel der Runde offen ist, darf die Runde nicht als fertig gelten — " \
      "auch wenn es auf keinem Tisch liegt"
  end

  # ── AC-2 ───────────────────────────────────────────────────────────────────
  # Die Karteileiche aus dem Vorfall: Tisch in aktivem Zustand, aber ohne Spiel. Er darf
  # den Rundenwechsel NICHT blockieren, denn auf ihm laeuft faktisch nichts.
  test "AC-2: verwaister Tisch in aktivem Zustand blockiert den Rundenwechsel nicht" do
    finished = round_game!("hf1", round_no: 3, ended: true)
    table_monitor!(state: "ready_for_new_match", game: finished)
    table_monitor!(state: "playing", game: nil) # Karteileiche wie am 2026-09-03

    assert @tm.all_table_monitors_finished?,
      "Alle Spiele der Runde sind beendet — ein verwaister Tischzustand darf die Runde " \
      "nicht dauerhaft blockieren"
  end

  # ── AC-3 ───────────────────────────────────────────────────────────────────
  # Ohne round_no-gefuehrte Spiele fehlt der Spiel-Pruefung die Grundlage. Dann muss das
  # bisherige Tisch-Verhalten gelten — NICHT bedingungslos "fertig".
  test "AC-3: ohne Spiele mit round_no gilt weiterhin die Tisch-Pruefung" do
    spielend = round_game!("hf1", round_no: nil, ended: false)
    table_monitor!(state: "playing", game: spielend)

    refute @tm.all_table_monitors_finished?,
      "Ohne round_no-Datengrundlage entscheidet der Tischzustand — ein spielender Tisch " \
      "haelt die Runde offen"
  end

  test "AC-3b: ohne Spiele mit round_no und ohne aktiven Tisch bleibt es bei 'fertig'" do
    beendet = round_game!("hf1", round_no: nil, ended: true)
    table_monitor!(state: "ready_for_new_match", game: beendet)

    assert @tm.all_table_monitors_finished?,
      "Fallback-Verhalten unveraendert: kein aktiver Tisch heisst fertig"
  end

  # ── AC-4 ───────────────────────────────────────────────────────────────────
  test "AC-4: regulaeres Rundenende meldet weiterhin fertig" do
    a = round_game!("hf1", round_no: 3, ended: true)
    b = round_game!("hf2", round_no: 3, ended: true)
    table_monitor!(state: "ready_for_new_match", game: a)
    table_monitor!(state: "ready_for_new_match", game: b)

    assert @tm.all_table_monitors_finished?,
      "Alle Spiele der Runde beendet, alle Tische geschlossen — die Runde ist fertig"
  end

  test "AC-4b: laufendes Spiel der Runde haelt die Runde offen" do
    round_game!("hf1", round_no: 3, ended: true)
    laufend = round_game!("hf2", round_no: 3, ended: false)
    table_monitor!(state: "playing", game: laufend)

    refute @tm.all_table_monitors_finished?,
      "Ein laufendes Spiel haelt die Runde offen — wie bisher"
  end

  # ── finalize_round: beendete Spiele muessen vom Tisch (Checkpoint-Befund 06-01) ──
  # `data` wird nur als Nebeneffekt gefuellt (tmp_results beim Verdraengen,
  # tiebreak_required beim Tiebreak). Das letzte Spiel auf einem Tisch hat deshalb oft
  # leeres `data` — es blieb am Tisch haengen, und die Ergebnistabelle zeigte dafuer
  # weiterhin Eingabefelder (editable_game = game.table_monitor.present?).
  test "finalize_round nimmt auch beendete Spiele OHNE data vom Tisch" do
    ohne_data = round_game!("p<3-4>", round_no: 3, ended: true)
    assert_empty ohne_data.data, "Vorbedingung: das Spiel traegt kein data"
    tabmon = table_monitor!(state: "final_match_score", game: ohne_data)

    @tm.finalize_round

    assert_nil tabmon.reload.game_id,
      "Ein beendetes Spiel muss vom Tisch genommen werden, auch wenn es kein data traegt — " \
      "sonst zeigt die Ergebnistabelle dafuer dauerhaft Eingabefelder"
  end

  test "finalize_round laesst unbespielte Spiele ohne data und ohne ended_at am Tisch" do
    offen = round_game!("p<5-6>", round_no: 3, ended: false)
    tabmon = table_monitor!(state: "playing", game: offen)

    @tm.finalize_round

    assert_equal offen.id, tabmon.reload.game_id,
      "Ein unbespieltes Spiel darf nicht abgeraeumt werden — das war der Zweck der " \
      "urspruenglichen data-Pruefung und bleibt erhalten"
  end

  # Spiele frueherer Runden duerfen die aktuelle Runde nicht blockieren.
  test "offene Spiele FRUEHERER Runden blockieren die aktuelle Runde nicht" do
    round_game!("group1:1", round_no: 1, ended: false) # Altlast aus Runde 1
    round_game!("hf1", round_no: 3, ended: true)

    assert @tm.all_table_monitors_finished?,
      "Nur die Spiele der aktuellen Runde entscheiden ueber deren Abschluss"
  end

  # ── Plan 17-01: round_status — warum die Runde wartet ──────────────────────
  # Liest dieselbe Spielmenge wie das Gate oben; "offen" heisst allein ended_at: nil.
  test "17-01 AC-1: round_status nennt Fortschritt und das offene Spiel mit Tisch" do
    %w[hf1 hf2 p<3-4>].each { |gname| round_game!(gname, round_no: 3, ended: true) }
    offen = round_game!("p<5-6>", round_no: 3, ended: false)
    table_monitor!(state: "playing", game: offen, table_name: "Tisch 2")

    status = I18n.with_locale(:de) { @tm.round_status }

    assert_equal 3, status[:round]
    assert_equal 4, status[:total]
    assert_equal 3, status[:finished]
    assert_equal [{name: "Spiel um Platz 5 und 6", table: "Tisch 2"}], status[:open]
  end

  test "17-01 AC-2: offenes Spiel ohne Tisch wird trotzdem genannt" do
    round_game!("hf1", round_no: 3, ended: true)
    round_game!("hf2", round_no: 3, ended: false) # nicht platziert / verdraengt

    status = @tm.round_status

    assert_equal 1, status[:finished]
    assert_equal 1, status[:open].size
    assert_nil status[:open].first[:table], "Ein Spiel ohne Tisch darf nicht verschwinden"
  end

  test "17-01 AC-3: im Tisch-Fallback (keine Spiele mit round_no) gibt es keinen Rundenstatus" do
    spielend = round_game!("hf1", round_no: nil, ended: false)
    table_monitor!(state: "playing", game: spielend, table_name: "Tisch 1")

    assert_nil @tm.round_status, "Ohne round_no-Spiele waere jede Zahl eine Scheinaussage"
    refute @tm.all_table_monitors_finished?, "Das Gate entscheidet unveraendert ueber den Tisch"
  end

  test "17-01: sind alle Spiele der Runde beendet, ist nichts offen" do
    round_game!("hf1", round_no: 3, ended: true)
    round_game!("hf2", round_no: 3, ended: true)

    status = @tm.round_status

    assert_equal 2, status[:finished]
    assert_empty status[:open]
  end

  test "17-01: Partial zeigt Fortschritt, offene Spiele mit Tisch und 'ohne Tisch'" do
    %w[hf1 hf2].each { |gname| round_game!(gname, round_no: 3, ended: true) }
    auf_tisch = round_game!("p<5-6>", round_no: 3, ended: false)
    round_game!("p<7-8>", round_no: 3, ended: false)
    table_monitor!(state: "playing", game: auf_tisch, table_name: "Tisch 2")

    html = I18n.with_locale(:de) do
      ApplicationController.render(partial: "tournament_monitors/round_status", locals: {tournament_monitor: @tm})
    end

    assert_includes html, "Runde 3: 2 von 4 Spielen beendet"
    assert_includes html, "Spiel um Platz 5 und 6 (Tisch 2)"
    assert_includes html, "Spiel um Platz 7 und 8 (ohne Tisch)"
  end
end
