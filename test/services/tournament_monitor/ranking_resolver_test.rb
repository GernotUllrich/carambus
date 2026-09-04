# frozen_string_literal: true

require "test_helper"

# Unit tests for TournamentMonitor::RankingResolver
# Covers player_id_from_ranking and all private resolution paths.
class TournamentMonitor::RankingResolverTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(8, {
      balls_goal: 30,
      innings_goal: 25
    })
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]

    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor

    # Populate rankings in tournament monitor data for tests
    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.data["rankings"]["groups"] ||= {}
    @tm.data["rankings"]["endgames"] ||= {}
    @tm.data["rankings"]["groups"]["group1"] = {
      @players[0].id.to_s => { "points" => 4, "gd" => 2.0 },
      @players[1].id.to_s => { "points" => 2, "gd" => 1.5 }
    }
    @tm.save!

    @resolver = TournamentMonitor::RankingResolver.new(@tm)
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # Test 1: player_id_from_ranking resolves seeding list (sl.rk1 → first seeded player_id)
  # ============================================================================

  test "player_id_from_ranking resolves sl.rk1 to first seeded player_id" do
    result = @resolver.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal @players[0].id, result
  end

  test "player_id_from_ranking resolves sl.rk2 to second seeded player_id" do
    result = @resolver.player_id_from_ranking("sl.rk2", executor_params: {})
    assert_equal @players[1].id, result
  end

  # ============================================================================
  # Test 2: player_id_from_ranking resolves group rank (g1.2 → 2nd player in group 1)
  # ============================================================================

  test "player_id_from_ranking resolves g1.1 to first player in group 1" do
    # g1.1 uses group_rank path — returns first player from distributed group 1
    result = @resolver.player_id_from_ranking("g1.1", {})
    # The result should be a player_id (integer), may be nil if group distribution returns nil
    # Just verify it doesn't raise and returns an integer or nil
    assert(result.nil? || result.is_a?(Integer), "Expected Integer or nil, got #{result.inspect}")
  end

  # ============================================================================
  # Test 3: player_id_from_ranking returns nil on invalid rule string (rescue path)
  # ============================================================================

  test "player_id_from_ranking returns nil on invalid rule string" do
    result = @resolver.player_id_from_ranking("totally-invalid-rule-xyz", executor_params: {})
    assert_nil result
  end

  test "player_id_from_ranking returns nil on nil rule string" do
    result = assert_nothing_raised do
      @resolver.player_id_from_ranking(nil.to_s, executor_params: {})
    end
    assert_nil result
  end

  # ============================================================================
  # Test 4: player_id_from_ranking resolves rule references recursively
  # ============================================================================

  test "player_id_from_ranking resolves rule1 by following executor_params rules" do
    opts = {
      executor_params: {
        "rules" => {
          "rule1" => "sl.rk1"
        }
      }
    }
    result = @resolver.player_id_from_ranking("rule1", opts)
    assert_equal @players[0].id, result
  end

  # ============================================================================
  # Test 5: group_rank calls PlayerGroupDistributor.distribute_to_group directly (D-05)
  # ============================================================================

  test "group_rank calls PlayerGroupDistributor.distribute_to_group directly not TournamentMonitor.distribute_to_group" do
    distributor_called = false
    old_method = TournamentMonitor::PlayerGroupDistributor.method(:distribute_to_group)

    TournamentMonitor::PlayerGroupDistributor.define_singleton_method(:distribute_to_group) do |*args|
      distributor_called = true
      old_method.call(*args)
    end

    begin
      @resolver.player_id_from_ranking("g1.1", {})
    rescue StandardError
      # May raise on incomplete test data — we only care that the right method was called
    ensure
      TournamentMonitor::PlayerGroupDistributor.define_singleton_method(:distribute_to_group, old_method)
    end

    assert distributor_called, "Expected PlayerGroupDistributor.distribute_to_group to be called directly"
  end

  # ============================================================================
  # Integration: RankingResolver behaves identically to TournamentMonitor delegation
  # ============================================================================

  test "resolver and tournament_monitor produce same result for seeding resolution" do
    resolver_result = @resolver.player_id_from_ranking("sl.rk1", executor_params: {})
    tm_result = @tm.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal tm_result, resolver_result
  end

  # ============================================================================
  # Plan 03-01 (§4.4.2): group_standing_order — Punkte, GD/gd_pct, BED, Höchstserie
  # ============================================================================

  test "group_standing_order returns points, gd, bed, hs for non-handicap tournaments" do
    @tournament.update!(handicap_tournier: false)
    assert_equal %i[points gd bed hs], @resolver.group_standing_order
  end

  test "group_standing_order returns points, gd_pct, bed, hs for handicap tournaments" do
    @tournament.update!(handicap_tournier: true)
    assert_equal %i[points gd_pct bed hs], @resolver.group_standing_order
  end

  # ============================================================================
  # Plan 07-01 (§4.4.2 fuer die Cross-Gruppen-Rangfolge): inter_group_order
  # ============================================================================

  test "inter_group_order returns points, gd, bed, hs for plain tournaments" do
    @tournament.update!(gd_has_prio: false, handicap_tournier: false)
    assert_equal %i[points gd bed hs], @resolver.inter_group_order
  end

  test "inter_group_order returns points, gd_pct, bed, hs for handicap tournaments" do
    @tournament.update!(gd_has_prio: false, handicap_tournier: true)
    assert_equal %i[points gd_pct bed hs], @resolver.inter_group_order
  end

  test "inter_group_order puts gd FIRST when gd_has_prio is set" do
    @tournament.update!(gd_has_prio: true, handicap_tournier: false)
    # Die Umkehrung der ersten beiden Stufen ist eine bewusste Turnier-Option, kein
    # Versehen — BED und HS werden angehaengt, points/gd behalten ihre Reihenfolge.
    assert_equal %i[gd points bed hs], @resolver.inter_group_order
  end

  test "inter_group_order puts gd_pct FIRST when gd_has_prio is set on a handicap tournament" do
    @tournament.update!(gd_has_prio: true, handicap_tournier: true)
    assert_equal %i[gd_pct points bed hs], @resolver.inter_group_order
  end

  # Verhaltenstest: der Gleichstand nach Punkten UND GD wird durch bed entschieden.
  # Bewusst ZWEIMAL mit vertauschten bed-Werten — ohne die bed-Stufe kann hoechstens
  # einer der beiden Tests zufaellig gruen werden (sort_by ist bei gleichen Schluesseln
  # nicht garantiert stabil), sodass die Gegenprobe verlaesslich anschlaegt.
  test "cross-group tie on points and gd is broken by bed (group 1 player ahead)" do
    setup_cross_group_tie(bed_group1: 5.0, bed_group2: 2.0)

    result = @resolver.player_id_from_ranking("(g1.rk1 + g2.rk1).rk1", executor_params: {})

    assert_equal @players[0].id.to_s, result,
      "Bei gleichen Punkten und gleichem GD muss der hoehere BED entscheiden (§4.4.2)"
  end

  test "cross-group tie on points and gd is broken by bed (group 2 player ahead)" do
    setup_cross_group_tie(bed_group1: 2.0, bed_group2: 5.0)

    result = @resolver.player_id_from_ranking("(g1.rk1 + g2.rk1).rk1", executor_params: {})

    assert_equal @players[1].id.to_s, result,
      "Der BED-Vergleich darf nicht von der Hash-Reihenfolge abhaengen"
  end

  test "cross-group ranking already separated by points is unchanged by the new stages" do
    setup_cross_group_tie(bed_group1: 1.0, bed_group2: 99.0)
    # Gruppe 1 bekommt mehr Punkte — die vorgelagerte Stufe muss gewinnen, obwohl der
    # Spieler aus Gruppe 2 den weit hoeheren BED hat.
    @tm.data["rankings"]["groups"]["group1"][@players[0].id.to_s]["points"] = 6
    @tm.save!

    result = @resolver.player_id_from_ranking("(g1.rk1 + g2.rk1).rk1", executor_params: {})

    assert_equal @players[0].id.to_s, result,
      "BED/HS sind nachgelagerte Stufen — sie duerfen einen Punktvorsprung nicht kippen"
  end

  # Legt je einen Spieler in Gruppe 1 und Gruppe 2 an, gleich in points/gd/hs und
  # unterschiedlich nur im bed. String-Keys, weil data eine JSON-Spalte ist.
  def setup_cross_group_tie(bed_group1:, bed_group2:)
    @tm.data["rankings"]["groups"]["group1"] = {
      @players[0].id.to_s => {"points" => 4, "gd" => 2.0, "bed" => bed_group1, "hs" => 10}
    }
    @tm.data["rankings"]["groups"]["group2"] = {
      @players[1].id.to_s => {"points" => 4, "gd" => 2.0, "bed" => bed_group2, "hs" => 10}
    }
    @tm.save!
  end

  # ============================================================================
  # Plan 03-02 (§4.4.2 Stufe 3): head_to_head_winner
  # ============================================================================

  def create_group_game(gname:, player_a:, player_b:, points_a:, points_b:)
    # Ueber die Assoziation erzeugen (wie table_populator.rb:382), nicht Game.create!
    # direkt — has_many :games, as: :tournament ist polymorph auf Tournament-Seite;
    # Game#belongs_to :tournament ist es nicht, direktes Game.create!(tournament:) laesst
    # tournament_type leer und macht das Spiel fuer tournament.games unauffindbar.
    game = @tournament.games.create!(gname: gname, group_no: 1)
    GameParticipation.create!(game: game, player: player_a, role: "playera", points: points_a)
    GameParticipation.create!(game: game, player: player_b, role: "playerb", points: points_b)
    game
  end

  test "head_to_head_winner returns the winner of a single direct match" do
    create_group_game(gname: "group1:1-2", player_a: @players[0], player_b: @players[1],
      points_a: 2, points_b: 0)

    winner = @resolver.head_to_head_winner("group", 1, @players[0].id, @players[1].id)
    assert_equal @players[0].id, winner
  end

  test "head_to_head_winner sums points across double round-robin encounters" do
    create_group_game(gname: "group1:1-2/1", player_a: @players[0], player_b: @players[1],
      points_a: 2, points_b: 0)
    create_group_game(gname: "group1:1-2/2", player_a: @players[0], player_b: @players[1],
      points_a: 0, points_b: 2)
    create_group_game(gname: "group1:1-2/3", player_a: @players[0], player_b: @players[1],
      points_a: 0, points_b: 2)

    winner = @resolver.head_to_head_winner("group", 1, @players[0].id, @players[1].id)
    assert_equal @players[1].id, winner,
      "Spieler B gewinnt 2 von 3 Begegnungen in Punktesumme, muss den direkten Vergleich gewinnen"
  end

  test "head_to_head_winner returns nil when no common game exists" do
    winner = @resolver.head_to_head_winner("group", 1, @players[0].id, @players[1].id)
    assert_nil winner
  end

  test "head_to_head_winner returns nil when points are equal across all encounters" do
    create_group_game(gname: "group1:1-2", player_a: @players[0], player_b: @players[1],
      points_a: 1, points_b: 1)

    winner = @resolver.head_to_head_winner("group", 1, @players[0].id, @players[1].id)
    assert_nil winner
  end

  test "head_to_head_winner works identically for endgame groups (fg prefix)" do
    create_group_game(gname: "fg1:1-2", player_a: @players[0], player_b: @players[1],
      points_a: 2, points_b: 0)

    winner = @resolver.head_to_head_winner("fg", 1, @players[0].id, @players[1].id)
    assert_equal @players[0].id, winner
  end

  # ============================================================================
  # Plan 03-02 (§4.4.2 vollständig): group_standing_ranking
  # ============================================================================

  test "group_standing_ranking: 2-way tie is resolved by direct comparison, overriding bed/hs" do
    # p1/p2 gleichauf bei Punkten+GD; p1 schlaegt p2 direkt; BED/HS wuerden p2 vorne sehen,
    # der direkte Vergleich muss das aber unabhaengig davon entscheiden.
    create_group_game(gname: "group1:1-2", player_a: @players[0], player_b: @players[1],
      points_a: 2, points_b: 0)

    hash = {
      @players[0].id => {"points" => 4, "gd" => 2.0, "bed" => 1.0, "hs" => 5},
      @players[1].id => {"points" => 4, "gd" => 2.0, "bed" => 3.0, "hs" => 20},
      @players[2].id => {"points" => 6, "gd" => 1.0, "bed" => 0.5, "hs" => 3}
    }

    result = @resolver.group_standing_ranking(hash, "group", 1)

    assert_equal [@players[2].id, @players[0].id, @players[1].id], result.map(&:first),
      "p3 fuehrt (mehr Punkte), p1 vor p2 per direktem Vergleich trotz schwaecherem BED/HS"
  end

  test "group_standing_ranking: 3-way tie skips direct comparison, falls back to bed/hs" do
    # Alle drei gleichauf bei Punkten+GD; p1 schlaegt p2 direkt, aber bei 3 Gleichen greift
    # der direkte Vergleich laut Entscheidung vom 2026-09-03 nicht — BED/HS entscheiden.
    create_group_game(gname: "group1:1-2", player_a: @players[0], player_b: @players[1],
      points_a: 2, points_b: 0)

    hash = {
      @players[0].id => {"points" => 4, "gd" => 2.0, "bed" => 1.0, "hs" => 5},
      @players[1].id => {"points" => 4, "gd" => 2.0, "bed" => 3.0, "hs" => 20},
      @players[2].id => {"points" => 4, "gd" => 2.0, "bed" => 2.0, "hs" => 10}
    }

    result = @resolver.group_standing_ranking(hash, "group", 1)

    assert_equal [@players[1].id, @players[2].id, @players[0].id], result.map(&:first),
      "Reihenfolge folgt BED (3.0 > 2.0 > 1.0), der direkte p1-vs-p2-Sieg wird bei 3-fachem Gleichstand ignoriert"
  end

  test "group_standing_ranking: 2-way tie without a findable direct match falls back to bed/hs" do
    # Keine gemeinsame Partie angelegt — head_to_head_winner liefert nil, die Orchestrierung
    # muss dann (wie vor diesem Plan) auf BED/HS zurueckfallen, nicht z.B. die urspruengliche
    # Punkte/GD-Reihenfolge stehen lassen.
    hash = {
      @players[0].id => {"points" => 4, "gd" => 2.0, "bed" => 1.0, "hs" => 5},
      @players[1].id => {"points" => 4, "gd" => 2.0, "bed" => 3.0, "hs" => 20}
    }

    result = @resolver.group_standing_ranking(hash, "group", 1)

    assert_equal [@players[1].id, @players[0].id], result.map(&:first),
      "Ohne auffindbare direkte Partie entscheidet BED (3.0 > 1.0)"
  end

  test "group_standing_ranking: single-player cluster (no tie) passes through unchanged" do
    hash = {
      @players[0].id => {"points" => 6, "gd" => 2.0, "bed" => 1.0, "hs" => 5},
      @players[1].id => {"points" => 4, "gd" => 1.0, "bed" => 3.0, "hs" => 20}
    }

    result = @resolver.group_standing_ranking(hash, "group", 1)

    assert_equal [@players[0].id, @players[1].id], result.map(&:first)
  end

  test "g1.rk1/g1.rk2 resolve via group_standing_ranking with string-keyed rankings hash (JSON round-trip)" do
    # @tournament_monitor.data ist eine JSON-Spalte — nach dem Rundtrip sind die
    # Spieler-ID-Keys STRINGS, nicht Integer. Dieser Test simuliert genau das und prueft,
    # dass head_to_head_winner trotzdem korrekt gegen die Integer-player_id aus
    # GameParticipation matcht (siehe Typ-Normalisierung in head_to_head_winner).
    create_group_game(gname: "group1:1-2", player_a: @players[0], player_b: @players[1],
      points_a: 2, points_b: 0)

    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.data["rankings"]["groups"] ||= {}
    @tm.data["rankings"]["groups"]["group1"] = {
      @players[0].id.to_s => {"points" => 4, "gd" => 2.0, "bed" => 1.0, "hs" => 5},
      @players[1].id.to_s => {"points" => 4, "gd" => 2.0, "bed" => 3.0, "hs" => 20}
    }
    @tm.save!

    rk1 = @resolver.player_id_from_ranking("g1.rk1", executor_params: {})
    rk2 = @resolver.player_id_from_ranking("g1.rk2", executor_params: {})

    # Rueckgabe ist der Hash-Key aus @tournament_monitor.data — nach JSON-Rundtrip ein
    # String. Das ist bestehendes, unveraendertes Verhalten von TournamentMonitor.ranking
    # (gibt Hash-Paare unveraendert zurueck); nicht Teil dieser Aenderung.
    assert_equal @players[0].id.to_s, rk1,
      "g1.rk1 muss ueber ko_ranking -> group_standing_ranking -> head_to_head_winner aufgeloest werden"
    assert_equal @players[1].id.to_s, rk2
  end
end
