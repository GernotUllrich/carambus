# frozen_string_literal: true

require "test_helper"

# Nachtrag zu Phase 41: das Archiv haelt gegen den naechtlichen GC — aber NICHT gegen einen
# Turnier-(Neu-)Start.
#
# Gemessen am 2026-08-26 auf bcw: Turnier 50000057 hatte vier erfolgreiche Pushes (alle mit
# `games` im Payload, alle 200 OK) und trotzdem NULL Partien in der Datenbank. Der Endstand
# (12 Seedings) war da. Ursache: drei Stellen loeschen bedingungslos alle lokalen Games eines
# Turniers, und keine nahm `ArchivedGame` aus:
#
#   tournament.rb (initialize_tournament_monitor) · tournament.rb (reset) · table_populator.rb
#
# Ausloeser dort war ein Turnier-Neuaufsetzen (TournamentMonitor 50000059 -> 50000060).
# Der Schaden ist still: `durable: true` wird weiter gemeldet.
#
# ⚠️ Beim Filtern gilt die STI-Falle aus 41-02: `where.not(type: "ArchivedGame")` waere FALSCH,
# weil `type` fuer gewoehnliche Games NULL ist und `NOT (type = 'x')` bei NULL nicht wahr ist —
# dann fielen die LIVE-Spiele aus der Loeschung und blieben als Leichen stehen.
class TournamentArchiveSurvivesResetTest < ActiveSupport::TestCase
  BASE_ID = 58_000_000

  setup do
    @tournament = tournaments(:local)
  end

  def live_game!(seqno)
    Game.create!(id: BASE_ID + 100 + seqno, tournament_id: @tournament.id,
      tournament_type: "Tournament", gname: "live#{seqno}", seqno: seqno, data: {})
  end

  def archived_game!(seqno)
    ArchivedGame.create!(id: BASE_ID + 200 + seqno, tournament_id: @tournament.id,
      tournament_type: "Tournament", gname: "R1.#{seqno}", seqno: seqno,
      ended_at: Time.current, data: {"Partie" => seqno.to_s, "Ergebnis" => "15:11"})
  end

  def archived_ids
    ArchivedGame.where(tournament_id: @tournament.id).pluck(:id).sort
  end

  def live_ids
    Game.where(tournament_id: @tournament.id)
      .where("games.type IS NULL OR games.type != 'ArchivedGame'").pluck(:id).sort
  end

  test "initialize_tournament_monitor raeumt die Live-Spiele ab und laesst das Archiv stehen" do
    live_game!(1)
    live_game!(2)
    archived_game!(1)
    archived_game!(2)
    expected_archive = archived_ids
    assert_equal 2, expected_archive.size

    @tournament.initialize_tournament_monitor

    assert_equal expected_archive, archived_ids,
      "Ein Turnier-Neustart darf das Ergebnisarchiv nicht mitloeschen"
    assert_empty live_ids,
      "Die Live-Spiele muessen weiterhin abgeraeumt werden — sonst bleiben Leichen stehen"
  end

  # Dritter Loeschpfad: der TablePopulator raeumt beim Aufbau der TableMonitors noch einmal ab.
  # Ohne eigenen Test bliebe er ungeprueft — `initialize_tournament_monitor` erreicht ihn nur,
  # wenn ein TournamentPlan vorliegt.
  test "do_reset_tournament_monitor laesst das Archiv stehen" do
    monitor = TournamentMonitor.create!(id: BASE_ID + 1, tournament: @tournament)
    live_game!(4)
    archived_game!(4)
    expected_archive = archived_ids

    ::TournamentMonitor::TablePopulator.new(monitor).do_reset_tournament_monitor

    assert_equal expected_archive, archived_ids,
      "Auch der Aufbau der TableMonitors darf das Ergebnisarchiv nicht mitloeschen"
    assert_empty live_ids
  end

  test "reset_tournament laesst das Archiv stehen" do
    live_game!(3)
    archived_game!(3)
    expected_archive = archived_ids

    @tournament.reset_tournament

    assert_equal expected_archive, archived_ids,
      "Auch der Reset darf das Ergebnisarchiv nicht mitloeschen"
    assert_empty live_ids
  end
end
