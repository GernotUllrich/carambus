# frozen_string_literal: true

require "test_helper"

# Unit-Tests fuer TrainingPartnerRanking (Milestone v0.3, Plan 02-02).
#
# Deckt ab:
#   A. Rangfolge nach Aktualitaet (AC-1)
#   B. Fallback-Kaskade exakt -> Disziplin -> irgendein Trainingsspiel (AC-2)
#   C. Was NICHT zaehlt: Gaeste, unentschiedene Spiele, Turnier- und App-Spiele (AC-3)
#   D. Begrenzung und Robustheit
#
# ⚠️ IDs: in der Test-DB startet die games-Sequence bei 1, in Dev/Produktion oberhalb
# von MIN_ID. Trainings-Games werden hier daher mit EXPLIZITER id >= Game::MIN_ID
# angelegt — sonst greift der Game.training-Scope nicht.
#
# ⚠️ club_locations.yml wird bewusst NICHT geladen: die Datei verknuepft ueber
# Label-Verweise, die die expliziten Club-IDs verfehlen. Die Verknuepfung Location->Club
# baut das Setup daher selbst mit korrekten IDs auf (gleiche Falle wie im
# TrainingResultRecorderTest, Abschnitt C3).
class TrainingPartnerRankingTest < ActiveSupport::TestCase
  fixtures :players, :seasons, :season_participations, :clubs, :locations,
    :tables, :table_kinds, :tournaments

  PLAYER_A = 50_001_010 # nbv_ullrich
  PLAYER_B = 50_001_011 # nbv_andresen

  DISCIPLINE = "Freie Partie klein"

  setup do
    @next_id = Game::MIN_ID + 30_000
    @club = clubs(:bcw)
    @location = tables(:one).location
    ClubLocation.find_or_create_by!(club_id: @club.id, location_id: @location.id) do |cl|
      cl.status = "active"
    end
    @location.reload
    assert_equal @club.id, @location.club&.id, "Vorbedingung: Location muss ihren Club aufloesen"

    # Zwei weitere Kaderspieler, damit Rangfolgen sichtbar werden.
    @player_c = create_member(50_001_500, "Cording")
    @player_d = create_member(50_001_501, "Dohrmann")
  end

  # ---------------------------------------------------------------------------
  # Hilfsmethoden
  # ---------------------------------------------------------------------------

  def next_id
    @next_id += 1
  end

  def create_member(id, lastname)
    player = Player.create!(id: id, lastname: lastname, firstname: "Test")
    SeasonParticipation.create!(player_id: player.id, club_id: @club.id,
      season_id: Season.current_season.id, status: "active")
    player
  end

  # Legt ein gewertetes Trainingsspiel an. `created_at` steuert die Rangfolge.
  def training_game(a:, b:, discipline: DISCIPLINE, balls_goal: 40, created_at: Time.current, result: 40)
    game = Game.create!(id: next_id, data: {}, gname: "tpr_#{SecureRandom.hex(4)}")
    game.update_columns(created_at: created_at)
    [[a, "playera"], [b, "playerb"]].each do |player_id, role|
      GameParticipation.create!(
        game_id: game.id, player_id: player_id, role: role,
        result: result,
        data: {"discipline" => discipline, "balls_goal" => balls_goal}.compact
      )
    end
    game
  end

  def rank(discipline: DISCIPLINE, balls_goal: 40, limit: nil)
    args = {location: @location, discipline: discipline, balls_goal: balls_goal}
    args[:limit] = limit if limit
    TrainingPartnerRanking.call(args)
  end

  # ===========================================================================
  # A. Rangfolge nach Aktualitaet (AC-1)
  # ===========================================================================

  test "A1: das juengere Spiel steht vor dem aelteren" do
    training_game(a: PLAYER_A, b: PLAYER_B, created_at: 2.days.ago)
    training_game(a: @player_c.id, b: @player_d.id, created_at: 1.day.ago)

    result = rank

    assert_equal [@player_c.id, @player_d.id].sort, result.first(2).sort,
      "die Spieler des juengeren Spiels muessen vorn stehen"
    assert_equal [PLAYER_A, PLAYER_B].sort, result.last(2).sort
  end

  test "A2: ohne jede Trainingshistorie bleibt die Liste leer" do
    assert_empty rank
  end

  test "A3: derselbe Spieler erscheint nur einmal" do
    training_game(a: PLAYER_A, b: PLAYER_B, created_at: 2.days.ago)
    training_game(a: PLAYER_A, b: @player_c.id, created_at: 1.day.ago)

    result = rank
    assert_equal result.uniq, result
    assert_equal PLAYER_A, result.first, "der zuletzt Aktive steht vorn"
  end

  # ===========================================================================
  # B. Fallback-Kaskade (AC-2)
  # ===========================================================================

  test "B1: exakte Parameter schlagen blosse Disziplin-Uebereinstimmung" do
    # aelter, aber exakt passend
    training_game(a: PLAYER_A, b: PLAYER_B, balls_goal: 40, created_at: 3.days.ago)
    # juenger, gleiche Disziplin, andere Distanz
    training_game(a: @player_c.id, b: @player_d.id, balls_goal: 30, created_at: 1.day.ago)

    result = rank(balls_goal: 40)

    assert_equal [PLAYER_A, PLAYER_B].sort, result.first(2).sort,
      "Stufe 1 (exakt) geht Stufe 2 (nur Disziplin) vor, auch wenn sie aelter ist"
  end

  test "B2: ohne exakten Treffer greift die Disziplin-Stufe" do
    training_game(a: PLAYER_A, b: PLAYER_B, balls_goal: 30)

    result = rank(balls_goal: 40)

    assert_includes result, PLAYER_A, "gleiche Disziplin genuegt, wenn die Distanz nie gespielt wurde"
    assert_includes result, PLAYER_B
  end

  test "B3: ohne Disziplin-Treffer greift die dritte Stufe" do
    training_game(a: PLAYER_A, b: PLAYER_B, discipline: "Cadre 35/2", balls_goal: 100)

    result = rank(discipline: "Einband", balls_goal: 40)

    assert_includes result, PLAYER_A, "irgendein gewertetes Trainingsspiel zaehlt als letzte Stufe"
  end

  test "B4: Spiele ohne Kontext erscheinen ueber die dritte Stufe" do
    # Genau der Zustand der drei Altspiele aus Phase 1: gewertet, aber ohne Kontext.
    game = Game.create!(id: next_id, data: {}, gname: "tpr_kontextlos")
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_A, role: "playera", result: 40)
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_B, role: "playerb", result: 10)

    result = rank

    assert_includes result, PLAYER_A, "kontextlose Altspiele duerfen nicht verlorengehen"
  end

  # ===========================================================================
  # C. Was NICHT zaehlt (AC-3)
  # ===========================================================================

  test "C1: unentschiedene Spiele ohne Ergebnis zaehlen nicht" do
    game = Game.create!(id: next_id, data: {}, gname: "tpr_offen")
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_A, role: "playera")
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_B, role: "playerb")

    assert_empty rank, "ohne verbuchtes Ergebnis gibt es keine verwertbare Historie"
  end

  test "C2: Turnierspiele zaehlen nicht" do
    game = Game.create!(id: next_id, data: {}, gname: "tpr_turnier",
      tournament_id: tournaments(:local).id)
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_A, role: "playera", result: 40,
      data: {"discipline" => DISCIPLINE, "balls_goal" => 40})

    assert_empty rank, "Game.training schliesst Turnierspiele aus"
  end

  test "C3: App-gesteuerte Turnierspiele (external_id) zaehlen nicht" do
    game = Game.create!(id: next_id, data: {"external_id" => "abc-1"}, gname: "tpr_app")
    GameParticipation.create!(game_id: game.id, player_id: PLAYER_A, role: "playera", result: 40,
      data: {"discipline" => DISCIPLINE, "balls_goal" => 40})

    assert_empty rank, "Game.training schliesst App-Turnierspiele aus"
  end

  test "C4: Spieler ausserhalb des Kaders erscheinen nicht" do
    fremder = Player.create!(id: 50_001_600, lastname: "Fremdling", firstname: "Test")
    training_game(a: fremder.id, b: PLAYER_A)

    result = rank

    assert_not_includes result, fremder.id,
      "die Kopfgruppe darf niemanden zeigen, den die Vollliste nicht enthaelt"
    assert_includes result, PLAYER_A
  end

  test "C5: legt keine Player- oder SeasonParticipation-Datensaetze an" do
    training_game(a: PLAYER_A, b: PLAYER_B)

    assert_no_difference ["Player.count", "SeasonParticipation.count"] do
      rank
    end
  end

  # ===========================================================================
  # D. Begrenzung und Robustheit
  # ===========================================================================

  test "D1: liefert hoechstens limit Eintraege" do
    training_game(a: PLAYER_A, b: PLAYER_B, created_at: 2.days.ago)
    training_game(a: @player_c.id, b: @player_d.id, created_at: 1.day.ago)

    assert_equal 3, rank(limit: 3).size
  end

  test "D2: Default-Limit ist DEFAULT_LIMIT" do
    assert_equal 6, TrainingPartnerRanking::DEFAULT_LIMIT
  end

  test "D3: SCAN_LIMIT begrenzt die geladenen Spiele" do
    assert_equal 300, TrainingPartnerRanking::SCAN_LIMIT
    assert_operator TrainingPartnerRanking::SCAN_LIMIT, :>, TrainingPartnerRanking::DEFAULT_LIMIT
  end

  test "D4: ohne Location liefert das Ranking eine leere Liste statt zu scheitern" do
    training_game(a: PLAYER_A, b: PLAYER_B)

    assert_empty TrainingPartnerRanking.call(location: nil, discipline: DISCIPLINE, balls_goal: 40)
  end

  test "D5: ohne Parameter faellt es auf die dritte Stufe zurueck" do
    training_game(a: PLAYER_A, b: PLAYER_B)

    result = TrainingPartnerRanking.call(location: @location)

    assert_includes result, PLAYER_A, "ohne Disziplin/Distanz zaehlt die reine Aktualitaet"
  end
end
