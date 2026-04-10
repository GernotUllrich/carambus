# frozen_string_literal: true

require "test_helper"

# Unit tests fuer Tournament::RankingCalculator.
# Verifiziert:
#   - Fruehzeitiger Return wenn kein Organizer vom Typ Region
#   - Fruehzeitiger Return wenn keine Disziplin vorhanden
#   - Fruehzeitiger Return fuer globale Records (id < MIN_ID)
#   - Korrekte Berechnung und Caching der Player-Rankings im data-Hash
#   - reorder_seedings aktualisiert Seeding-Positionen sequenziell ab 1
#
# Verwendet lokale IDs (>= 50_000_000) um Fixture-Kollisionen zu vermeiden.
class Tournament::RankingCalculatorTest < ActiveSupport::TestCase
  CALC_TEST_ID_BASE = 50_200_000

  self.use_transactional_tests = true

  setup do
    @id_counter = 0
    clear_user_context
    # Minimaler Spieler fuer Seeding-Tests (LocalProtector in Tests deaktiviert)
    @player = Player.create!(
      id: 50_200_900,
      firstname: "Test",
      lastname: "Spieler",
      dbu_nr: 20001
    )
  end

  teardown do
    clear_user_context
  end

  def clear_user_context
    User.current = nil
    PaperTrail.request.whodunnit = nil
  end

  def next_id
    @id_counter += 1
    CALC_TEST_ID_BASE + @id_counter
  end

  def build_local_tournament(attrs = {})
    t = Tournament.new(
      {
        id: next_id,
        title: "RankingCalculator Test Tournament",
        season: seasons(:current),
        organizer: regions(:nbv),
        organizer_type: "Region",
        date: 2.weeks.from_now
      }.merge(attrs)
    )
    t.save!(validate: false)
    clear_user_context
    t
  end

  # ============================================================================
  # Test 1: Fruehzeitiger Return wenn kein Organizer vom Typ Region
  # ============================================================================

  test "calculate_and_cache_rankings returns nil when organizer is not a Region" do
    tournament = build_local_tournament(organizer: clubs(:bcw), organizer_type: "Club")
    calculator = Tournament::RankingCalculator.new(tournament)

    result = calculator.calculate_and_cache_rankings

    assert_nil result
  end

  # ============================================================================
  # Test 2: Fruehzeitiger Return wenn keine Disziplin vorhanden
  # ============================================================================

  test "calculate_and_cache_rankings returns nil when tournament has no discipline" do
    tournament = build_local_tournament(discipline_id: nil)
    calculator = Tournament::RankingCalculator.new(tournament)

    result = calculator.calculate_and_cache_rankings

    assert_nil result
  end

  # ============================================================================
  # Test 3: Fruehzeitiger Return fuer globale Records (id < MIN_ID)
  # ============================================================================

  test "calculate_and_cache_rankings returns nil when id is below MIN_ID" do
    # Globaler Record mit id < 50_000_000 — muss fruehzeitig zurueckkehren
    global_tournament = Tournament.new(
      id: 1,
      title: "Global Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      date: 2.weeks.from_now
    )
    calculator = Tournament::RankingCalculator.new(global_tournament)

    result = calculator.calculate_and_cache_rankings

    assert_nil result
  end

  # ============================================================================
  # Test 4: Korrekte Berechnung und Caching der Player-Rankings
  # ============================================================================

  test "calculate_and_cache_rankings caches player_rankings in data hash for valid tournament" do
    tournament = build_local_tournament(discipline: disciplines(:carom_3band))
    calculator = Tournament::RankingCalculator.new(tournament)

    # Kein Fehler erwartet — auch ohne PlayerRanking-Eintraege muss die Methode durchlaufen
    assert_nothing_raised do
      calculator.calculate_and_cache_rankings
    end

    tournament.reload
    # data['player_rankings'] muss ein Hash sein (leer wenn keine Rankings vorhanden)
    assert_not_nil tournament.data["player_rankings"],
      "player_rankings sollte im data-Hash vorhanden sein"
    assert_kind_of Hash, tournament.data["player_rankings"]
  end

  # ============================================================================
  # Test 5: reorder_seedings aktualisiert Seeding-Positionen
  # ============================================================================

  test "reorder_seedings updates Seeding positions sequentially starting from 1" do
    tournament = build_local_tournament
    # Seedings anlegen (Spieler benoetigt durch belongs_to :player)
    @player2 = Player.create!(id: 50_200_901, firstname: "Test2", lastname: "Spieler2", dbu_nr: 20002)
    seeding_a = Seeding.create!(tournament: tournament, player: @player, position: 5)
    seeding_b = Seeding.create!(tournament: tournament, player: @player2, position: 3)

    tournament.reload
    calculator = Tournament::RankingCalculator.new(tournament)

    assert_nothing_raised do
      calculator.reorder_seedings
    end

    # Positionen muessen neu von 1 durchnummeriert sein
    positions = tournament.reload.seedings.order(:id).map(&:position)
    assert_equal [1, 2], positions
  end
end
