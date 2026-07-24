# frozen_string_literal: true

require "test_helper"

# Plan 32-08: Ergebniszeilen -> lokale Games am lokalen Turnier des Region Servers.
#
# Der Schluessel ist (gname, seqno), NICHT gname allein — die Vereinfachung der Spielnamen ist
# viele-zu-eins ("hf1" und "hf2" werden beide zu "Halbfinale"). AC-2b haelt genau das fest.
class RegionServer::GameResultIngestTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    # T06: Gruppen g1/g2 + hf1/hf2 + fin + p<3-4> + p<5-6>
    # -> erlaubt: Gruppe A, Gruppe B, Halbfinale, Finale, Spiel um Platz 3, Spiel um Platz 5
    @plan = tournament_plans(:t06_6)

    # Explizite lokale ID: der Ingest ist auf das lokale Arbeitsexemplar beschraenkt, und die
    # Test-Sequenz vergaebe sonst eine ID unterhalb MIN_ID.
    @tournament = Tournament.create!(
      id: 50_000_900,
      title: "Landesmeisterschaft Dreiband", shortname: "LM3B908",
      season: @season, organizer: @region, region_id: @region.id,
      tournament_plan_id: @plan.id,
      date: Time.zone.local(2026, 10, 10, 10, 0)
    )

    @anna = Player.create!(lastname: "ANNA", firstname: "Anna", fl_name: "A. Anna", dbu_nr: 111_111)
    @bodo = Player.create!(lastname: "BODO", firstname: "Bodo", fl_name: "B. Bodo", dbu_nr: 222_222)
  end

  def row(group: "Gruppe A", seqno: 7, result_a: 100, result_b: 85)
    {
      "group" => group, "seqno" => seqno, "ended_at" => "2026-10-10T14:12:00+02:00",
      "participations" => [
        {"dbu_nr" => "111111", "role" => "playera", "result" => result_a, "innings" => 24, "hs" => 16, "gd" => 4.17},
        {"dbu_nr" => "222222", "role" => "playerb", "result" => result_b, "innings" => 24, "hs" => 9, "gd" => 3.54}
      ]
    }
  end

  def ingest(games, tournament_plan_id: nil)
    RegionServer::GameResultIngest.new(
      tournament: @tournament, games: games, tournament_plan_id: tournament_plan_id
    ).call
  end

  # AC-1
  test "Ergebniszeile wird zu lokalem Spiel mit zwei Teilnehmern" do
    result = ingest([row])

    assert_equal 1, result.accepted
    assert_empty result.unresolved

    game = @tournament.games.sole
    assert_equal "Gruppe A", game.gname
    assert_equal 7, game.seqno
    assert_equal "Tournament", game.tournament_type, "die has_many :as-Assoziation muss den Typ setzen"
    assert_equal @region.id, game.region_id

    playera = game.game_participations.find_by(role: "playera")
    assert_equal @anna.id, playera.player_id
    assert_equal 100, playera.result
    assert_equal 24, playera.innings
    assert_equal 16, playera.hs
    assert_in_delta 4.17, playera.gd, 0.001
    assert_equal 85, game.game_participations.find_by(role: "playerb").result
  end

  # AC-2
  test "wiederholter Push aktualisiert dasselbe Spiel statt zu duplizieren" do
    ingest([row])
    result = ingest([row(result_a: 100, result_b: 87)])

    assert_equal 0, result.accepted
    assert_equal 1, result.updated
    assert_equal 1, @tournament.games.count, "Korrektur darf kein zweites Spiel anlegen"
    assert_equal 2, Game.find_by(gname: "Gruppe A").game_participations.count,
      "keine verwaisten GameParticipations"
    assert_equal 87, @tournament.games.sole.game_participations.find_by(role: "playerb").result
  end

  # AC-2b — der Kern des (gname, seqno)-Schluessels
  test "gleicher Name mit anderer Partie ist ein anderes Spiel" do
    ingest([row(group: "Halbfinale", seqno: 12)])
    ingest([row(group: "Halbfinale", seqno: 13)])

    assert_equal 2, @tournament.games.where(gname: "Halbfinale").count,
      "hf1 und hf2 heissen beide 'Halbfinale' — seqno unterscheidet sie"
    assert_equal [12, 13], @tournament.games.order(:seqno).pluck(:seqno)
  end

  # AC-2c
  test "Spielname ausserhalb des Turnierplans wird abgewiesen" do
    result = nil
    assert_no_difference("Game.count") do
      result = ingest([row(group: "Gruppe Q")])
    end

    assert_equal 0, result.accepted
    assert_equal 1, result.unresolved.size
    assert_includes result.unresolved.first, "Gruppe Q"
  end

  test "alle Namen des Turnierplans werden akzeptiert" do
    %w[Halbfinale Finale].each_with_index do |group, ix|
      result = ingest([row(group: group, seqno: 20 + ix)])
      assert_equal 1, result.accepted, "#{group} muss aus dem Plan ableitbar sein"
    end
    assert_equal 1, ingest([row(group: "Spiel um Platz 3", seqno: 30)]).accepted
  end

  # AC-3
  test "unbekannte dbu_nr wird gemeldet, kein Spieler und kein Spiel angelegt" do
    result = nil
    assert_no_difference(["Player.count", "Game.count", "GameParticipation.count"]) do
      result = ingest([{"group" => "Gruppe A", "seqno" => 7, "participations" => [
        {"dbu_nr" => "111111", "role" => "playera", "result" => 100},
        {"dbu_nr" => "999999", "role" => "playerb", "result" => 85}
      ]}])
    end

    assert_equal 0, result.accepted
    assert_equal 1, result.unresolved.size
    assert_includes result.unresolved.first, "999999"
  end

  test "andere Zeilen desselben Pushes werden trotz einer Luecke verarbeitet" do
    broken = {"group" => "Gruppe A", "seqno" => 8, "participations" => [
      {"dbu_nr" => "999999", "role" => "playera", "result" => 100},
      {"dbu_nr" => "222222", "role" => "playerb", "result" => 85}
    ]}
    result = ingest([row(seqno: 7), broken])

    assert_equal 1, result.accepted
    assert_equal 1, result.unresolved.size
    assert_equal 1, @tournament.games.count
  end

  test "Zeile ohne group oder seqno wird gemeldet" do
    result = ingest([row.except("seqno")])

    assert_equal 0, result.accepted
    assert_equal 1, result.unresolved.size
    assert_equal 0, @tournament.games.count
  end

  test "setzt den Turnierplan, wenn er lokal noch fehlt" do
    @tournament.update_column(:tournament_plan_id, nil)
    result = ingest([row], tournament_plan_id: @plan.id)

    assert_nil result.error
    assert_equal @plan.id, @tournament.reload.tournament_plan_id
  end

  test "abweichender Turnierplan wird gemeldet statt uebernommen" do
    result = ingest([row], tournament_plan_id: tournament_plans(:t04_5).id)

    assert_not_nil result.error
    assert_equal @plan.id, @tournament.reload.tournament_plan_id, "lokaler Plan darf nicht kippen"
    assert_equal 0, @tournament.games.count, "bei Planabweichung wird nichts eingelesen"
  end

  # Fail-open: die Namenspruefung ist eine Absicherung gegen Tippfehler, kein Zugangsschutz.
  # Ein Turnier ohne ableitbaren Plan darf keine gueltigen Ergebnisse verlieren.
  test "ohne Turnierplan wird der Name nicht geprueft" do
    @tournament.update_column(:tournament_plan_id, nil)
    result = ingest([row(group: "Irgendein Name")])

    assert_equal 1, result.accepted
    assert_equal "Irgendein Name", @tournament.games.sole.gname
  end
end
