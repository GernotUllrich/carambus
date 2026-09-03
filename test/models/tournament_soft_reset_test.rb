# frozen_string_literal: true

require "test_helper"

# Sanfter Ruecksetzer (2026-09-03): der haeufigste Betriebsfall ist "Turnier klemmt,
# gleicher Modus, gleiche Meldeliste, nochmal von vorn". Beide vorhandenen Reset-Wege
# koennen das nicht:
#
#   reset_tmt_monitor! / forced_reset_tournament_monitor!
#     -> beide nach `new_tournament`
#     -> after_enter: reset_tournament
#     -> loescht bei `organizer != Club` die lokalen Seedings UND nullt tournament_plan_id
#
# Gefunden beim Aufraeumen von Turnier 18931 ("1. Vorgabepokal", organizer = Region 1):
# ein Reset ueber die State Machine haette die 10 lokal ergaenzten Meldungen mitgenommen.
#
# Diese Tests halten beide Seiten fest: was der sanfte Weg erhaelt, UND dass der harte
# Weg tatsaechlich loescht (sonst waere der sanfte Weg ueberfluessig und wuerde beim
# naechsten Refactoring stillschweigend wegfallen).
class TournamentSoftResetTest < ActiveSupport::TestCase
  BASE_ID = 59_000_000

  setup do
    @tournament = tournaments(:local)
    assert_not @tournament.organizer.is_a?(Club),
      "Vorbedingung: organizer darf kein Club sein — sonst greift der Seeding-Loeschzweig gar nicht"
  end

  def live_game!(seqno)
    @tournament.games.create!(id: BASE_ID + 100 + seqno, gname: "live#{seqno}", seqno: seqno, data: {})
  end

  def archived_game!(seqno)
    ArchivedGame.create!(id: BASE_ID + 200 + seqno, tournament_id: @tournament.id,
      tournament_type: "Tournament", gname: "R1.#{seqno}", seqno: seqno,
      ended_at: Time.current, data: {"Partie" => seqno.to_s, "Ergebnis" => "15:11"})
  end

  def local_seeding!(position)
    Seeding.create!(id: BASE_ID + 300 + position, tournament: @tournament,
      player: players(:nbv_ullrich), position: position)
  end

  def live_ids
    Game.where(tournament_id: @tournament.id)
      .where("games.type IS NULL OR games.type != 'ArchivedGame'").pluck(:id).sort
  end

  test "soft reset behaelt Meldeliste und Turniermodus, raeumt aber Monitor und Spiele ab" do
    local_seeding!(1)
    local_seeding!(2)
    live_game!(1)
    live_game!(2)
    monitor = TournamentMonitor.create!(id: BASE_ID + 1, tournament: @tournament)
    plan_id_before = @tournament.tournament_plan_id
    seeding_ids_before = @tournament.seedings.pluck(:id).sort

    assert_predicate seeding_ids_before, :any?, "Vorbedingung: Turnier muss Meldungen haben"
    assert_not_nil plan_id_before, "Vorbedingung: Turniermodus muss gesetzt sein"

    @tournament.soft_reset_tournament_monitor
    @tournament.reload

    assert_equal seeding_ids_before, @tournament.seedings.pluck(:id).sort,
      "Der sanfte Reset darf die Meldeliste NICHT anfassen — das ist sein ganzer Zweck"
    assert_equal plan_id_before, @tournament.tournament_plan_id,
      "Der gewaehlte Turniermodus muss erhalten bleiben"
    assert_equal "tournament_mode_defined", @tournament.state,
      "Das Turnier muss startbereit sein, ohne erneute Modus-Auswahl"
    assert_nil TournamentMonitor.find_by(id: monitor.id),
      "Der TournamentMonitor (und mit ihm current_round) muss weg sein"
    assert_empty live_ids, "Die lokalen Live-Spiele muessen abgeraeumt sein"
  end

  test "soft reset laesst das Ergebnisarchiv stehen" do
    live_game!(3)
    archived_game!(3)
    expected_archive = ArchivedGame.where(tournament_id: @tournament.id).pluck(:id).sort
    assert_equal 1, expected_archive.size

    @tournament.soft_reset_tournament_monitor

    assert_equal expected_archive, ArchivedGame.where(tournament_id: @tournament.id).pluck(:id).sort,
      "Wie initialize_tournament_monitor: der Neustart raeumt LIVE-Spiele ab, nicht das Archiv"
    assert_empty live_ids
  end

  test "soft reset funktioniert auch ohne TournamentMonitor" do
    live_game!(4)

    assert_nothing_raised do
      @tournament.soft_reset_tournament_monitor
    end
    assert_equal "tournament_mode_defined", @tournament.reload.state
  end

  test "soft reset behaelt die Meldeliste auch bei einem GLOBALEN Turnier (der eigentliche Problemfall)" do
    global = tournaments(:imported)
    assert_operator global.id, :<, Seeding::MIN_ID,
      "Vorbedingung: Turnier muss global sein (id < MIN_ID) — nur dort loescht reset_tournament"
    global.update_columns(tournament_plan_id: tournament_plans(:t04_5).id)
    Seeding.create!(id: BASE_ID + 400, tournament: global, player: players(:nbv_ullrich), position: 1)

    global.soft_reset_tournament_monitor
    global.reload

    assert_predicate global.seedings.where("seedings.id >= #{Seeding::MIN_ID}"), :any?,
      "Genau hier liegt der Unterschied: bei einem globalen Turnier muss die lokale Meldung ueberleben"
    assert_equal tournament_plans(:t04_5).id, global.tournament_plan_id
    assert_equal "tournament_mode_defined", global.state
  end

  # Kontrast: belegt, warum es den sanften Weg ueberhaupt braucht. Faellt dieser Test
  # eines Tages um, weil reset_tournament die Seedings nicht mehr loescht, kann der
  # sanfte Weg neu bewertet werden — dann ist er womoeglich redundant.
  #
  # Wichtig: der Loeschzweig greift NUR bei globalen Turnieren. `unless (organizer.is_a? Club)
  # || (id > Seeding::MIN_ID)` — ein lokales Turnier (id >= MIN_ID) faellt heraus und behaelt
  # seine Seedings auch beim harten Reset. Turnier 18931 war global, deshalb der Vorfall.
  test "reset_tournament loescht bei einem GLOBALEN Turnier Meldeliste und Turniermodus (Begruendung fuer den sanften Weg)" do
    global = tournaments(:imported)
    global.update_columns(tournament_plan_id: tournament_plans(:t04_5).id)
    Seeding.create!(id: BASE_ID + 401, tournament: global, player: players(:nbv_ullrich), position: 1)
    assert_predicate global.seedings.where("seedings.id >= #{Seeding::MIN_ID}"), :any?

    global.reset_tournament
    global.reload

    assert_empty global.seedings.where("seedings.id >= #{Seeding::MIN_ID}"),
      "Kontrast-Annahme: der harte Reset nimmt bei einem globalen Turnier die lokalen Meldungen mit"
    assert_nil global.tournament_plan_id,
      "Kontrast-Annahme: der harte Reset nullt den Turniermodus"
  end
end
