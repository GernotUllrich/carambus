# frozen_string_literal: true

require "test_helper"

# Plan 23-01 (2026-09-22): Der Rundenwechsel gehoert dem Turnierleiter, nicht dem Tisch.
#
# ANLASS: NDM Freie Partie Klasse 7 am 2026-09-20. Beim Stand 32:31 ging ein Nachstoss daneben;
# ein Klick zu viel machte daraus 32:32, Spiel beendet, Protokoll bestaetigt. Die Korrektur war
# nur per direktem DB-Eingriff moeglich — weil das Korrekturfenster bereits zu war.
#
# URSACHE: Am Scoreboard steht "Naechstes Spiel" (_scoreboard.html.erb:213). Fuer den Spieler
# heisst das *mein Tisch ist frei*. War er zufaellig der Letzte seiner Runde, heisst es zugleich
# *Runde zu, naechste besetzt* — denn `close_match` traegt den AASM-after-Callback
# `advance_tournament_round_if_present` (table_monitor.rb:434). Der Drueckende kann das nicht
# sehen, weil er nicht weiss, ob an anderen Tischen noch gespielt wird.
#
# ⚠️ DER SCHNITT VERLAEUFT INNERHALB DER KASKADE, NICHT AN IHREM AUFRUF.
# `advance_round_after_match_close` (result_processor.rb:129) macht ZWEI Dinge:
#   1. `accumulate_results` + Status-Broadcast — laufen nach JEDEM Spiel
#   2. `finalize_round` / `incr_current_round!` / `populate_tables` — nur bei kompletter Runde
# Ein pauschales Loesen des Callbacks wuerde auch (1) abschalten und die Rangliste waehrend der
# laufenden Runde einfrieren. Test 2 sichert genau das ab.
class TournamentMonitor::RoundAdvanceGateTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  BASE_ID = 62_000_000

  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(4, {balls_goal: 30, innings_goal: 25})
    @tournament = @test_data[:tournament]
    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
    @tm.current_round!(3)

    # Wie in round_completion_test.rb: der KO-Helper erzeugt hier keine lokalen Spiele.
    @tournament.games.where("games.id >= #{Game::MIN_ID}").destroy_all
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # Explizite ID >= MIN_ID: `live_games` filtert darauf; ohne feste ID liefe jeder Test
  # unbemerkt in den Tisch-Fallback statt in die Spiel-Pruefung (Lehre aus 06-01).
  def round_game!(gname, round_no:, ended: false)
    @next_game_id = (@next_game_id || BASE_ID) + 1
    @tournament.games.create!(
      id: @next_game_id, gname: gname, round_no: round_no, group_no: 1, data: {},
      ended_at: ended ? Time.current : nil
    )
  end

  def table_monitor!(state:, game: nil)
    TableMonitor.create!(tournament_monitor: @tm, game: game, state: state, data: {})
  end

  # ── Test 1: das Gate ───────────────────────────────────────────────────────
  # Belegt am alten Code (2026-09-22): dieser Test war VOR dem Umbau in der Form
  # `assert_operator current_round, :>, vorher` gruen — der gruene Knopf am Tisch schaltete
  # die Runde weiter. Nach dem Umbau kippte er ("Expected 3 to be > 3") und steht jetzt hier
  # in der umgekehrten Richtung.
  test "GATE: close_match am letzten Spiel gibt den Tisch frei, schaltet die Runde aber NICHT" do
    a = round_game!("hf1", round_no: 3, ended: true)
    b = round_game!("hf2", round_no: 3, ended: true)
    table_monitor!(state: "ready_for_new_match", game: a)
    tabmon = table_monitor!(state: "final_match_score", game: b)

    assert @tm.all_table_monitors_finished?,
      "Vorbedingung: alle Spiele der Runde sind beendet"

    vorher = @tm.current_round
    tabmon.close_match!

    assert_equal vorher, @tm.reload.current_round,
      "Der gruene Knopf am Tisch darf die Runde nicht mehr schliessen — das Korrekturfenster " \
      "bleibt offen, bis der Turnierleiter schaltet (NDM-Vorfall 2026-09-20)"
    assert_equal "ready_for_new_match", tabmon.reload.state,
      "Der Tisch wird trotzdem frei — fuer den Spieler aendert sich nichts"
  end

  # ── Test 4: der Turnierleiter schaltet ─────────────────────────────────────
  test "TURNIERLEITER: advance_round_by_operator schaltet die Runde weiter" do
    a = round_game!("hf1", round_no: 3, ended: true)
    b = round_game!("hf2", round_no: 3, ended: true)
    table_monitor!(state: "ready_for_new_match", game: a)
    table_monitor!(state: "ready_for_new_match", game: b)

    vorher = @tm.current_round
    assert @tm.advance_round_by_operator, "Der Aufruf meldet, dass er geschaltet hat"

    assert_operator @tm.reload.current_round, :>, vorher,
      "Genau die Kaskade, die vorher am Tisch hing, laeuft jetzt auf Klick des Turnierleiters"
  end

  # ── Test 5: Doppelbetaetigung ──────────────────────────────────────────────
  # Der Schutz kommt aus dem Rundenabschluss-Gate selbst: nach dem ersten Schalten hat
  # populate_tables die Spiele der neuen Runde angelegt, `all_table_monitors_finished?` ist
  # damit false und der zweite Aufruf faellt in den elsif-Zweig (nur Broadcast).
  test "SCHUTZ: zweimal betaetigt erhoeht current_round um genau 1" do
    a = round_game!("hf1", round_no: 3, ended: true)
    b = round_game!("hf2", round_no: 3, ended: true)
    table_monitor!(state: "ready_for_new_match", game: a)
    table_monitor!(state: "ready_for_new_match", game: b)

    vorher = @tm.current_round
    @tm.advance_round_by_operator
    nach_erstem = @tm.reload.current_round
    @tm.advance_round_by_operator

    assert_equal nach_erstem, @tm.reload.current_round,
      "Ein zweiter Klick darf die Runde nicht erneut hochzaehlen"
    assert_equal vorher + 1, nach_erstem,
      "Und der erste Klick schaltet um genau eine Runde"
  end

  # ── Test 6: die Ausnahmen ──────────────────────────────────────────────────
  # `continuous_placements` ruecken Spiele nach, sobald ein Tisch frei wird — ein
  # Turnierleiter-Gate wuerde dort den laufenden Betrieb anhalten.
  test "AUSNAHME: continuous_placements bleibt ungegatet" do
    round_game!("hf1", round_no: 3, ended: true)

    assert @tm.operator_gated_round_advance?,
      "Vorbedingung: ein regulaeres Turnier mit gefuehrter Runde wartet auf den Turnierleiter"

    @tournament.update!(continuous_placements: true)

    refute @tm.reload.operator_gated_round_advance?,
      "Bei continuous_placements schaltet es wie bisher automatisch weiter — Spiele ruecken " \
      "nach, sobald ein Tisch frei wird"
  end

  test "AUSNAHME: manual_assignment bleibt ungegatet" do
    round_game!("hf1", round_no: 3, ended: true)
    @tournament.update!(manual_assignment: true)

    refute @tm.reload.operator_gated_round_advance?,
      "App-gesteuerte Turniere besitzen ihren Plan selbst (Phase 17-04)"
  end

  # ── Test 7: kein Gate ohne gefuehrte Runde ─────────────────────────────────
  # Gemessen am 2026-09-22 (Entwicklungs-DB = Prod-Kopie): 613 lokale Turnierspiele, davon nur
  # 59 mit `round_no` — pro Turnier aber alles-oder-nichts. Ohne round_no gaebe es keinen
  # Rundenstatus und damit keinen Knopf; ein Gate wuerde solche Turniere stranden lassen.
  test "AUSNAHME: ohne round_no-gefuehrte Runde wird nicht gegatet" do
    round_game!("hf1", round_no: nil, ended: true)

    refute @tm.round_tracked?,
      "Vorbedingung: die Runde ist nicht round_no-gefuehrt (Tisch-Fallback aus Phase 6)"
    refute @tm.operator_gated_round_advance?,
      "Ohne sichtbaren Knopf darf nicht gegatet werden — sonst stuende das Turnier fuer immer"
  end

  # ── Test 2: was der Umbau NICHT abschalten darf ────────────────────────────
  # `accumulate_results` laeuft in der Kaskade VOR dem Rundenabschluss-Gate und haelt die
  # Rangliste waehrend der Runde aktuell. Wird der Callback pauschal geloest, friert sie ein.
  test "SCHUTZ: accumulate_results laeuft auch ohne Rundenabschluss" do
    a = round_game!("hf1", round_no: 3, ended: true)
    offen = round_game!("hf2", round_no: 3, ended: false)
    tabmon = table_monitor!(state: "final_match_score", game: a)
    table_monitor!(state: "playing", game: offen)

    refute @tm.all_table_monitors_finished?,
      "Vorbedingung: ein Spiel der Runde ist noch offen"

    vorher = @tm.current_round
    tabmon.close_match!
    @tm.reload

    assert_equal vorher, @tm.current_round,
      "Bei offener Runde darf nicht weitergeschaltet werden — heute wie nach dem Umbau"
    assert @tm.data["rankings"].present?,
      "accumulate_results muss nach JEDEM Spiel laufen, sonst friert die Rangliste " \
      "waehrend der Runde ein"
  end

  # ── Test 3: der Trainingsmodus bleibt unberuehrt ───────────────────────────
  # Ohne tournament_monitor feuert der gruene Knopf `start_rematch`, nicht `close_match`
  # (_scoreboard.html.erb:213). Der Guard `return if tournament_monitor.blank?`
  # (table_monitor.rb:2052) schuetzt den Fall zusaetzlich.
  test "SCHUTZ: close_match ohne tournament_monitor loest keine Kaskade aus" do
    tabmon = TableMonitor.create!(tournament_monitor: nil, game: nil,
      state: "final_match_score", data: {})

    assert_nothing_raised do
      tabmon.close_match!
    end

    assert_equal "ready_for_new_match", tabmon.reload.state,
      "Der Tisch wird frei — ohne Turnierkontext passiert sonst nichts"
  end
end
