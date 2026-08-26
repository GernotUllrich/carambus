# frozen_string_literal: true

require "test_helper"

# Plan 41-02: Archiv-Zeilen duerfen den Turnierfortschritt nicht verfaelschen.
#
# carambus_app pusht den Endstand nach JEDER Runde — waehrend der Monitor noch zaehlt. Ohne
# den Ausschluss wuerde `finals_finished?` bei gesetztem `GK` nie mehr wahr: der Sollwert
# steht fest, waehrend Archiv-Games mit `ended_at` nur den Ist-Zaehler erhoehen.
class TournamentMonitorArchiveGamesTest < ActiveSupport::TestCase
  BASE_ID = 57_000_000

  setup do
    @tournament = tournaments(:local)
    @monitor = TournamentMonitor.create!(id: BASE_ID + 1, tournament: @tournament)
  end

  # IDs explizit >= MIN_ID: die Fortschrittslogik zaehlt nur lokale Spiele, und auf der
  # Authority (dieses Repo) vergibt die Sequence kleine IDs. Auf einem lokalen Server — wo
  # der Monitor tatsaechlich laeuft — waeren sie ohnehin gross.
  # `tournament_type` muss explizit gesetzt werden: `Game belongs_to :tournament` ist NICHT
  # polymorph (game.rb:29-30, die polymorphe Zeile ist auskommentiert), `Tournament has_many
  # :games, as: :tournament` dagegen schon. Ohne den Typ findet die Assoziation die Spiele
  # nicht — der Archiver setzt ihn aus demselben Grund.
  def live_game!(gname, seqno, ended: false)
    Game.create!(id: BASE_ID + 100 + seqno, tournament_id: @tournament.id,
      tournament_type: "Tournament", gname: gname, seqno: seqno,
      ended_at: ended ? Time.current : nil, data: {})
  end

  def archived_game!(gname, seqno)
    ArchivedGame.create!(id: BASE_ID + 200 + seqno, tournament_id: @tournament.id,
      tournament_type: "Tournament", gname: gname, seqno: seqno,
      ended_at: Time.current, data: {"Ergebnis" => "15:11"})
  end

  # `GK` = fester Sollwert. Das ist der Fall, in dem der Fehler zuschlaegt.
  def with_gk(value)
    plan = TournamentPlan.new(executor_params: {"GK" => value}.to_json)
    @monitor.stub(:tournament, @tournament) do
      @tournament.stub(:tournament_plan, plan) { yield }
    end
  end

  test "finals_finished? ignoriert Archiv-Zeilen bei gesetztem GK" do
    live_game!("f1", 1, ended: true)
    live_game!("f2", 2, ended: false)
    archived_game!("R1.1", 101)
    archived_game!("R1.2", 102)

    with_gk(2) do
      refute @monitor.finals_finished?,
        "Ein Live-Spiel laeuft noch — die zwei Archiv-Zeilen duerfen es nicht 'fertig' machen"
    end
  end

  test "finals_finished? wird wahr, sobald die Live-Spiele fertig sind" do
    live_game!("f1", 1, ended: true)
    live_game!("f2", 2, ended: true)
    archived_game!("R1.1", 101)

    with_gk(2) do
      assert @monitor.finals_finished?,
        "Zwei fertige Live-Spiele bei GK=2 — das Archiv darf den Abschluss nicht verhindern"
    end
  end

  # Der NULL-Fallstrick: bei STI ist `type` fuer gewoehnliche Games NULL. Ein naives
  # `where.not(type: "ArchivedGame")` wuerde sie mit ausschliessen — beide Zaehler waeren 0
  # und `finals_finished?` faelschlich wahr.
  test "gewoehnliche Games mit type NULL zaehlen weiterhin mit" do
    g = live_game!("f1", 1, ended: false)
    assert_nil g.type, "Vorbedingung: ein gewoehnliches Game hat type NULL"

    with_gk(1) do
      refute @monitor.finals_finished?,
        "Das nicht beendete Live-Spiel MUSS zaehlen — sonst schliesst das Turnier zu frueh ab"
    end
  end

  test "group_phase_finished? ignoriert Archiv-Zeilen ebenfalls" do
    live_game!("group1:1-2", 1, ended: true)
    live_game!("group1:3-4", 2, ended: false)
    archived_game!("group1:9-9", 103)

    refute @monitor.group_phase_finished?
  end
end
