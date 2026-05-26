# frozen_string_literal: true

require "test_helper"

# Plan 21-01 T2: PlayerClassCalculator-Tests.
# Decisions: D-21-01-A..F (Saisonfenster, btg+Backfill, Pool/Snooker-Skip,
# Echtzeit-Hochspielen ignoriert, Persistenz auf juengerer Vorsaison).
class PlayerClassCalculatorTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @current = seasons(:current)        # name "2025/2026"
    @prev = seasons(:previous)          # name "2024/2025" → juengere Vorsaison
    @prev_prev = seasons(:season_2024)  # name "2023/2024" → aeltere Vorsaison
    @dreiband_klein = Discipline.find_or_create_by!(name: "Dreiband klein")
    @pool = Discipline.find_or_create_by!(name: "8-Ball") # nicht in DISCIPLINE_CLASS_LIMITS
    # Season#current_season ist class-level gecacht — Cache leeren, damit Tests
    # verlaesslich die "current"-Fixture (2025/2026) treffen, statt eines Werts
    # aus einem frueheren Test-Run.
    Season.instance_variable_set(:@current_season, nil)
    Season.instance_variable_set(:@year, nil)
  end

  teardown do
    Season.instance_variable_set(:@current_season, nil)
    Season.instance_variable_set(:@year, nil)
  end

  # Hilfs-Konstruktor: erzeugt einen Player + zugehoerige PlayerRanking-Records.
  # btg_by_season: {season => btg, ...}; balls_by_season optional.
  def make_player_with_rankings(name:, discipline:, btg_by_season:, balls_by_season: {})
    player = Player.create!(firstname: "T2101", lastname: name, region: @region)
    btg_by_season.each do |season, btg|
      PlayerRanking.create!(
        player: player,
        discipline: discipline,
        region: @region,
        season: season,
        btg: btg,
        balls: balls_by_season[season].to_i,
        innings: 100
      )
    end
    player
  end

  test "T-21-01-B1: berechnet Klasse aus max(btg) und persistiert auf juengerer Vorsaison" do
    # Max ueber prev (1.5) und prev_prev (0.9) = 1.5 → Dreiband klein Klasse "1" (>=0.8).
    player = make_player_with_rankings(
      name: "Alpha", discipline: @dreiband_klein,
      btg_by_season: {@prev => 1.5, @prev_prev => 0.9}
    )

    stats = PlayerClassCalculator.call(region: @region, discipline: @dreiband_klein)

    assert_equal 1, stats[:players], "ein Spieler verarbeitet"
    assert_equal 1, stats[:persisted], "ein PlayerRanking persistiert"
    pc = PlayerClass.find_by(discipline: @dreiband_klein, shortname: "1")
    assert_not_nil pc, "PlayerClass 'Dreiband klein/1' angelegt"

    juengere = PlayerRanking.find_by(player: player, season: @prev)
    aeltere = PlayerRanking.find_by(player: player, season: @prev_prev)
    assert_equal pc.id, juengere.player_class_id,
      "player_class_id auf juengerer Vorsaison gesetzt (D-21-01-F)"
    assert_nil aeltere.player_class_id,
      "aeltere Vorsaison bleibt unangetastet"
  end

  test "T-21-01-B2: Pool/Snooker (ohne LIMITS-Eintrag) werden nicht klassifiziert" do
    player = make_player_with_rankings(
      name: "Pool", discipline: @pool,
      btg_by_season: {@prev => 5.0, @prev_prev => 4.0}
    )

    stats = PlayerClassCalculator.call(region: @region, discipline: @pool)

    assert_equal 0, stats[:disciplines], "8-Ball ist nicht in DISCIPLINE_CLASS_LIMITS, wird uebersprungen"
    assert_equal 0, stats[:players]
    pr = PlayerRanking.find_by(player: player, season: @prev)
    assert_nil pr.player_class_id, "Pool-Spieler bleibt unklassifiziert (D-21-01-C)"
  end

  test "T-21-01-B3: dry_run persistiert nicht und legt keine PlayerClass-Records an" do
    make_player_with_rankings(
      name: "Dry", discipline: @dreiband_klein,
      btg_by_season: {@prev => 1.5}
    )
    pc_count_before = PlayerClass.where(discipline: @dreiband_klein).count

    stats = PlayerClassCalculator.call(region: @region, discipline: @dreiband_klein, dry_run: true)

    assert_equal 1, stats[:persisted], "stats reportiert virtuelle Persistierung"
    assert_equal pc_count_before, PlayerClass.where(discipline: @dreiband_klein).count,
      "im dry_run wird KEIN PlayerClass-Record angelegt"
    pr = PlayerRanking.find_by(player: Player.find_by(lastname: "Dry"), season: @prev)
    assert_nil pr.player_class_id, "im dry_run wird player_class_id NICHT geschrieben"
  end

  test "T-21-01-B4: ist idempotent — zweiter Aufruf erzeugt keine doppelten PlayerClass-Records" do
    make_player_with_rankings(
      name: "Idem", discipline: @dreiband_klein,
      btg_by_season: {@prev => 1.5, @prev_prev => 1.2}
    )

    PlayerClassCalculator.call(region: @region, discipline: @dreiband_klein)
    pc_id = PlayerClass.find_by(discipline: @dreiband_klein, shortname: "1").id
    pc_count = PlayerClass.where(discipline: @dreiband_klein, shortname: "1").count

    PlayerClassCalculator.call(region: @region, discipline: @dreiband_klein)

    assert_equal pc_count,
      PlayerClass.where(discipline: @dreiband_klein, shortname: "1").count,
      "Idempotenz: PlayerClass-Count unveraendert"
    pr = PlayerRanking.find_by(player: Player.find_by(lastname: "Idem"), season: @prev)
    assert_equal pc_id, pr.player_class_id, "selbe PlayerClass-Referenz nach zweitem Aufruf"
  end

  test "T-21-01-B5: Dreiband gross Klasse I → II Degrade bei zu wenig Baellen (STO §1.4.3)" do
    dreiband_gross = Discipline.find_or_create_by!(name: "Dreiband groß")
    # btg=0.8 (>=0.7 → "1") aber balls=50 (<65) → STO-Regel: degrade auf Klasse "2" (balls_min=45, 50>=45 OK).
    player = make_player_with_rankings(
      name: "MinBalls", discipline: dreiband_gross,
      btg_by_season: {@prev => 0.8, @prev_prev => 0.75},
      balls_by_season: {@prev => 50, @prev_prev => 30}
    )

    PlayerClassCalculator.call(region: @region, discipline: dreiband_gross)

    pc = PlayerClass.find_by(discipline: dreiband_gross, shortname: "2")
    assert_not_nil pc, "Degraded Klasse '2' angelegt (Mindestballzahl 65 nicht erreicht)"
    pr = PlayerRanking.find_by(player: player, season: @prev)
    assert_equal pc.id, pr.player_class_id, "player_class_id auf '2' (statt '1') gesetzt"
    refute PlayerClass.exists?(discipline: dreiband_gross, shortname: "1"),
      "Klasse '1' wurde NICHT angelegt (Spieler erreichte sie nicht)"
  end

  test "T-21-01-B6: Backfill aus GameParticipation greift wenn btg-Werte unter Schwelle" do
    # btg ueberall 0.5 (<= BTG_BACKFILL_THRESHOLD 1.0) → Backfill greift.
    # GameParticipations liefern echte GDs → max → Klasse.
    player = make_player_with_rankings(
      name: "Backfill", discipline: @dreiband_klein,
      btg_by_season: {@prev => 0.5, @prev_prev => 0.5}
    )
    # Tournament + Game + GP fuer prev-Saison mit GD=1.2 (Klasse "1").
    tournament = Tournament.create!(
      title: "Backfill-Test prev",
      season: @prev,
      organizer_type: "Region", organizer_id: @region.id,
      discipline: @dreiband_klein,
      date: 6.months.ago
    )
    game = Game.create!(tournament: tournament, started_at: 6.months.ago)
    # GameParticipation hat keine balls-Spalte; nur gd/innings/hs/points/sets/result.
    GameParticipation.create!(game: game, player: player, gd: 1.2, innings: 42, points: 50)

    stats = PlayerClassCalculator.call(region: @region, discipline: @dreiband_klein)

    assert stats[:backfilled_pairs] > 0, "Backfill-Heuristik wurde getriggert (max btg ≤ Schwelle)"
    assert_equal 1, stats[:persisted], "Spieler aus GP-GD klassifiziert (Backfill greift)"
    pc = PlayerClass.find_by(discipline: @dreiband_klein, shortname: "1")
    assert_not_nil pc, "Klasse aus GP-Max-GD 1.2 abgeleitet (>=0.8 → '1')"
    pr = PlayerRanking.find_by(player: player, season: @prev)
    assert_equal pc.id, pr.player_class_id
  end

  test "T-21-01-B7: Backfill ohne GP-Daten → Spieler bleibt unklassifiziert (statt faelschlich in '2' zu fallen)" do
    # btg=0 → Backfill greift → keine GP angelegt → max=0 mit use_backfill=true → skip.
    player = make_player_with_rankings(
      name: "NoGP", discipline: @dreiband_klein,
      btg_by_season: {@prev => 0.0, @prev_prev => 0.0}
    )

    stats = PlayerClassCalculator.call(region: @region, discipline: @dreiband_klein)

    assert_equal 1, stats[:skipped], "ohne GP-Daten kein Backfill-Ergebnis → skip"
    assert_equal 0, stats[:persisted]
    pr = PlayerRanking.find_by(player: player, season: @prev)
    assert_nil pr.player_class_id, "player_class_id bleibt nil (kein faelschlicher Default)"
  end
end
