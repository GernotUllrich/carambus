# frozen_string_literal: true

require "test_helper"

class DisciplineTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------
  # Phase 39 D-16: parameter_ranges(tournament:) DTP-backed lookup
  # ---------------------------------------------------------------------

  # D-16(a): exact DTP hit normal case.
  # Fixture fpk_t04_5_class1: discipline=Freie Partie klein, plan=t04_5, players=5, class=1, points=250, innings=15.
  # Range = ((250*0.75).floor..250) = (187..250); ((15*0.75).floor..15) = (11..15).
  test "parameter_ranges returns reduced..canonical Range on exact DTP hit (D-16a)" do
    tournament = tournaments(:local_fpk_class1)
    discipline = disciplines(:discipline_freie_partie_klein)
    ranges = discipline.parameter_ranges(tournament: tournament)
    assert_equal(187..250, ranges[:balls_goal],
      "D-16(a): balls_goal Range must be (250*0.75).floor..250 = 187..250")
    assert_equal(11..15, ranges[:innings_goal],
      "D-16(a): innings_goal Range must be (15*0.75).floor..15 = 11..15")
  end

  # Gap-01 regression (quick 260507-24p): parameter_ranges must filter seedings
  # by Seeding::MIN_ID before counting, otherwise local tournaments with synced
  # global seedings (id < MIN_ID) report an inflated count that misses every
  # DTP row. Without the smart-fallback in lookup_dtp_with_class_walk, this
  # test is RED — base_scope.where(players: 8) yields no DTP row.
  test "parameter_ranges still resolves correct DTP row when local + global seedings are mixed (Gap-01)" do
    tournament = tournaments(:local_fpk_class1)
    # Lock fixture shape — 5 local + 3 global = 8 total.
    assert_equal 8, tournament.seedings.count,
      "Fixture precondition: local_fpk_class1 must have 5 local + 3 global seedings"
    assert_equal 5, tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).count,
      "Fixture precondition: 5 local seedings (id >= MIN_ID) expected"
    assert_equal 3, tournament.seedings.where("seedings.id < ?", Seeding::MIN_ID).count,
      "Fixture precondition: 3 global seedings (id < MIN_ID) expected"

    discipline = disciplines(:discipline_freie_partie_klein)
    ranges = discipline.parameter_ranges(tournament: tournament)
    assert_equal(187..250, ranges[:balls_goal],
      "Gap-01: balls_goal Range must match DTP players=5 (local count), not players=8 (raw count)")
    assert_equal(11..15, ranges[:innings_goal],
      "Gap-01: innings_goal Range must match DTP players=5 (local count), not players=8 (raw count)")
  end

  # Gap-01 defense-in-depth (quick 260507-24p): symmetric test — when a
  # tournament has ONLY global seedings (id < MIN_ID, the central-API-server
  # case), the smart fallback in effective_player_count must fall back to
  # counting the global seedings. Without the else-branch, this test is RED.
  #
  # Mirrors the canonical fallback pattern from tournament_cc.rb:286.
  test "parameter_ranges falls back to global seedings when no local seedings present (central API server case)" do
    # Build a transient tournament + 5 global seedings entirely in test scope.
    # LocalProtector is disabled in tests (LocalProtectorTestOverride in test_helper.rb).
    central_api_tournament = Tournament.create!(
      id: 9_500_001,                            # explicitly < Seeding::MIN_ID
      title: "Central API FPK class 1 (Gap-01 fallback test)",
      season_id: 50_000_001,
      organizer_id: 50_000_001,
      organizer_type: "Region",
      discipline_id: 50_000_004,                # Freie Partie klein
      tournament_plan_id: 50_000_100,           # t04_5 (5 players)
      player_class: "1",
      state: "tournament_mode_defined",
      date: 2.weeks.from_now,
      handicap_tournier: false
    )

    5.times do |i|
      Seeding.create!(
        id: 9_500_100 + i,                      # all < Seeding::MIN_ID
        player_id: [50_001_001, 50_001_002].sample,
        tournament_id: central_api_tournament.id,
        tournament_type: "Tournament",
        state: "seeded",
        position: i + 1
      )
    end

    # Fixture-shape lock: 0 local + 5 global = 5 total.
    assert_equal 5, central_api_tournament.seedings.count
    assert_equal 0, central_api_tournament.seedings.where("seedings.id >= ?", Seeding::MIN_ID).count,
      "Central API fixture: NO local seedings expected"
    assert_equal 5, central_api_tournament.seedings.where("seedings.id < ?", Seeding::MIN_ID).count,
      "Central API fixture: 5 global seedings expected"

    discipline = disciplines(:discipline_freie_partie_klein)
    ranges = discipline.parameter_ranges(tournament: central_api_tournament)
    assert_equal(187..250, ranges[:balls_goal],
      "Gap-01 fallback: balls_goal Range must match DTP players=5 via global-count fallback")
    assert_equal(11..15, ranges[:innings_goal],
      "Gap-01 fallback: innings_goal Range must match DTP players=5 via global-count fallback")
  end

  # D-16(b): class-walk fallback. tournament.player_class="5" → no exact match,
  # walks "5"→"4"→"3" → hits class "3" row (points=200, innings=12).
  test "parameter_ranges walks PLAYER_CLASS_ORDER on class miss (D-16b)" do
    tournament = tournaments(:local_fpk_class5_walks_to_3)
    discipline = disciplines(:discipline_freie_partie_klein)
    ranges = discipline.parameter_ranges(tournament: tournament)
    assert_equal(150..200, ranges[:balls_goal],
      "D-16(b): walk to class 3 must yield (200*0.75).floor..200 = 150..200")
    assert_equal(9..12, ranges[:innings_goal],
      "D-16(b): walk to class 3 must yield (12*0.75).floor..12 = 9..12")
  end

  # D-16(c): walk-miss. carom_3band has only class "1" DTP for plan t04_5.
  # tournament.player_class="III" → walk goes off end of PLAYER_CLASS_ORDER → {}.
  test "parameter_ranges returns empty hash when walk exhausts PLAYER_CLASS_ORDER (D-16c)" do
    tournament = tournaments(:local_carom_classIII_walk_miss)
    discipline = disciplines(:carom_3band)
    assert_equal({}, discipline.parameter_ranges(tournament: tournament),
      "D-16(c): walk past end of PLAYER_CLASS_ORDER must yield {}")
  end

  # D-16(d): Non-DTP discipline. BK-2kombi has no DTP rows → {}.
  test "parameter_ranges returns empty hash for non-DTP discipline (D-16d)" do
    tournament = tournaments(:local_bk2kombi_non_dtp)
    discipline = disciplines(:bk2_kombi)
    assert_equal({}, discipline.parameter_ranges(tournament: tournament),
      "D-16(d): discipline without any DTP rows must yield {}")
  end

  # D-16(e): handicap_tournier=true short-circuits regardless of discipline/plan/class.
  test "parameter_ranges returns empty hash for handicap_tournier=true (D-16e)" do
    tournament = tournaments(:local_handicap)
    discipline = disciplines(:discipline_freie_partie_klein)
    assert_equal({}, discipline.parameter_ranges(tournament: tournament),
      "D-16(e): handicap_tournier=true must yield {} (per-Seeding balls_goal, no innings limit)")
  end

  # D-16(f): tournament_plan_id=nil → defensive {}.
  test "parameter_ranges returns empty hash when tournament has no plan (D-16f)" do
    tournament = tournaments(:local_no_plan)
    discipline = disciplines(:discipline_freie_partie_klein)
    assert_equal({}, discipline.parameter_ranges(tournament: tournament),
      "D-16(f): tournament_plan_id=nil must yield {} (defensive)")
  end

  # RQ-01: zero-canonical DTP row (points=0 AND innings=0) → {}.
  # Cup-series semantics — Score-Target lives per-Discipline in individual Cup tournaments.
  test "parameter_ranges returns empty hash on zero-canonical DTP row (RQ-01)" do
    tournament = tournaments(:local_fpk_zero_canonical)
    discipline = disciplines(:discipline_freie_partie_klein)
    assert_equal({}, discipline.parameter_ranges(tournament: tournament),
      "RQ-01: DTP points=0 AND innings=0 (Cup-series) must yield {}")
  end

  # RQ-03: blank player_class → {} immediately, no walk attempt.
  test "parameter_ranges returns empty hash for blank player_class (RQ-03)" do
    tournament = tournaments(:local_fpk_blank_class)
    discipline = disciplines(:discipline_freie_partie_klein)
    assert_equal({}, discipline.parameter_ranges(tournament: tournament),
      "RQ-03: blank/empty player_class must yield {} (defensive symmetry with D-10/D-11)")
  end

  # Defensive regression: parameter_ranges must always return a Hash, never raise.
  test "parameter_ranges returns Hash for every discipline + every relevant tournament fixture" do
    tournament_fixture_keys = %i[
      local_fpk_class1 local_fpk_class5_walks_to_3 local_carom_classIII_walk_miss
      local_handicap local_no_plan local_fpk_zero_canonical local_fpk_blank_class
      local_bk2kombi_non_dtp
    ]
    tournament_fixture_keys.each do |t_key|
      Discipline.find_each do |d|
        result = nil
        assert_nothing_raised do
          result = d.parameter_ranges(tournament: tournaments(t_key))
        end
        assert_kind_of Hash, result,
          "discipline=#{d.name} tournament=#{t_key} must return Hash (got #{result.class})"
      end
    end
  end

  # ---------------------------------------------------------------------
  # 38.1-06: BK2-Kombi discipline map (Task 1)
  # BK2-Kombi is a distinct Kegel-family discipline served by a dedicated
  # scoreboard partial. It is intentionally kept OUT of KARAMBOL_DISCIPLINE_MAP
  # to avoid shifting the index basis consumed by the karambol free-game
  # detail view's radio-selects.
  # ---------------------------------------------------------------------

  # Snapshot of KARAMBOL_DISCIPLINE_MAP as it exists at plan 38.1-06 time.
  # If this list changes without an intentional refactor, the karambol
  # detail view's radio-select indices will silently drift (see
  # scoreboard_free_game_karambol_new.html.erb uses indices 0..5).
  KARAMBOL_DISCIPLINE_MAP_SNAPSHOT_38_1_06 = [
    "Dreiband klein",
    "Freie Partie klein",
    "Einband klein",
    "Cadre 52/2",
    "Cadre 35/2",
    "Eurokegel",
    "Dreiband groß",
    "Freie Partie groß",
    "Einband groß",
    "Cadre 71/2",
    "Cadre 47/2",
    "Cadre 47/1",
    "5-Pin Billards",
    "Biathlon"
  ].freeze

  # Phase 38.4-04: BK2_DISCIPLINE_MAP extended from 1 to 5 entries (D-04).
  test "BK2_DISCIPLINE_MAP contains all 5 BK-* names" do
    assert defined?(Discipline::BK2_DISCIPLINE_MAP),
      "Discipline::BK2_DISCIPLINE_MAP must be defined"
    assert_instance_of Array, Discipline::BK2_DISCIPLINE_MAP
    assert_equal %w[BK-2kombi BK50 BK100 BK-2 BK-2plus], Discipline::BK2_DISCIPLINE_MAP,
      "BK2_DISCIPLINE_MAP must contain all 5 BK-* discipline names (Phase 38.4-04)"
    assert Discipline::BK2_DISCIPLINE_MAP.frozen?,
      "BK2_DISCIPLINE_MAP must be frozen"
    assert_includes Discipline::BK2_DISCIPLINE_MAP, "BK-2kombi"
  end

  # ---------------------------------------------------------------------
  # Phase 38.4-04: BK-family predicate + ballziel_choices (Task 1)
  # ---------------------------------------------------------------------

  test "bk_family? returns true for all 5 BK-* fixtures" do
    %i[bk2_kombi bk50 bk100 bk_2 bk_2plus].each do |fixture_name|
      d = disciplines(fixture_name)
      assert d.bk_family?,
        "Discipline '#{fixture_name}' should be BK-family (data.free_game_form=#{d.data_free_game_form.inspect})"
    end
  end

  test "bk_family? returns false for non-BK disciplines" do
    %i[carom_3band pool_8ball].each do |fixture_name|
      d = disciplines(fixture_name)
      assert_not d.bk_family?, "Discipline '#{fixture_name}' should NOT be BK-family"
    end
  end

  test "ballziel_choices returns correct array from data" do
    assert_equal [50, 60, 70], disciplines(:bk2_kombi).ballziel_choices
    assert_equal [50], disciplines(:bk50).ballziel_choices
    assert_equal [100], disciplines(:bk100).ballziel_choices
    assert_equal [50, 60, 70, 80, 90, 100], disciplines(:bk_2).ballziel_choices
    assert_equal [50, 60, 70, 80, 90, 100], disciplines(:bk_2plus).ballziel_choices
  end

  test "ballziel_choices returns empty array for non-BK disciplines" do
    assert_equal [], disciplines(:carom_3band).ballziel_choices
  end

  test "BK2_FREE_GAME_FORMS contains 5 free_game_form values" do
    assert_equal %w[bk2_kombi bk50 bk100 bk_2 bk_2plus], Discipline::BK2_FREE_GAME_FORMS
    assert Discipline::BK2_FREE_GAME_FORMS.frozen?
  end

  test "KARAMBOL_DISCIPLINE_MAP is UNCHANGED by 38.1-06 (regression snapshot)" do
    # Widening KARAMBOL_DISCIPLINE_MAP would shift the indices that
    # scoreboard_free_game_karambol_new.html.erb relies on for its
    # small-billard radio-select (indices 0..5). BK2-Kombi must live in its
    # OWN constant (BK2_DISCIPLINE_MAP).
    assert_equal KARAMBOL_DISCIPLINE_MAP_SNAPSHOT_38_1_06,
      Discipline::KARAMBOL_DISCIPLINE_MAP,
      "KARAMBOL_DISCIPLINE_MAP must not be widened — BK2-Kombi goes in BK2_DISCIPLINE_MAP"
    assert_equal 14, Discipline::KARAMBOL_DISCIPLINE_MAP.size
    refute_includes Discipline::KARAMBOL_DISCIPLINE_MAP, "BK-2kombi",
      "BK-2kombi must NOT be in KARAMBOL_DISCIPLINE_MAP"
  end

  # ---------------------------------------------------------------------------
  # Phase 38.4-11 O2: Discipline#nachstoss_allowed? helper
  # ---------------------------------------------------------------------------

  test "T-O2-nachstoss-allowed-true 38.4-11: discipline with nachstoss_allowed:true returns true" do
    d = Discipline.new(name: "BK50-test", data: {"nachstoss_allowed" => true, "free_game_form" => "bk50"}.to_json)
    assert_equal true, d.nachstoss_allowed?
  end

  test "T-O2-nachstoss-allowed-default-false 38.4-11: discipline without nachstoss_allowed key returns false" do
    d = Discipline.new(name: "Karambol-test", data: {"free_game_form" => "karambol"}.to_json)
    assert_equal false, d.nachstoss_allowed?
  end

  test "T-O2-nachstoss-allowed-malformed-json 38.4-11: discipline with malformed data JSON returns false" do
    d = Discipline.new(name: "Broken-test", data: "{not valid json}")
    assert_equal false, d.nachstoss_allowed?
  end

  test "T-O2-nachstoss-allowed-nil-data 38.4-11: discipline with nil data returns false" do
    d = Discipline.new(name: "Empty-test", data: nil)
    assert_equal false, d.nachstoss_allowed?
  end

  # Phase 38.4-16 P5: Plan 11's seed-applied test asserted ALL 5 disciplines carried
  # nachstoss_allowed: true. Plan 16 narrows the flag to BK-2kombi only — only
  # BK-2kombi expects true; BK50/BK100/BK-2/BK-2plus expect false (key absent → false
  # per the existing helper contract verified by T-O2-nachstoss-allowed-default-false).
  test "T-P5-seed-only-bk2kombi-has-flag 38.4-16: Only BK-2kombi has nachstoss_allowed: true after seed replay; the 4 others have it absent" do
    # Programmatic replay of the POST-Plan-16 seed_bk2_disciplines.rb logic.
    # The 4 non-BK-2kombi entries OMIT the nachstoss_allowed key (matches the new
    # discs array literal in script/seed_bk2_disciplines.rb after Task 2).
    # Only BK-2kombi keeps the flag (matches the find(107) backfill block).
    # Idempotent: safe to run repeatedly in test DB.
    seed_data = {
      "BK50" => {"free_game_form" => "bk50", "ballziel_choices" => [50]},
      "BK100" => {"free_game_form" => "bk100", "ballziel_choices" => [100]},
      "BK-2" => {"free_game_form" => "bk_2", "ballziel_choices" => [50, 60, 70, 80, 90, 100]},
      "BK-2plus" => {"free_game_form" => "bk_2plus", "ballziel_choices" => [50, 60, 70, 80, 90, 100]},
      "BK2-Kombi" => {"free_game_form" => "bk2_kombi", "ballziel_choices" => [50, 60, 70], "nachstoss_allowed" => true}
    }
    expected_flag = {
      "BK50" => false,
      "BK100" => false,
      "BK-2" => false,
      "BK-2plus" => false,
      "BK2-Kombi" => true
    }
    seed_data.each do |name, expected_data|
      rec = Discipline.find_or_initialize_by(name: name)
      rec.data = expected_data.to_json
      rec.save!(validate: false)
      rec.reload
      assert_equal expected_flag[name], rec.nachstoss_allowed?,
        "T-P5-seed: #{name} must have nachstoss_allowed=#{expected_flag[name]} after Plan 16 narrowing (BK-2kombi keeps flag; the other 4 lose it)"
    end
  end

  # Phase 38.4-16 P5: regression guard — explicit assertion that BK2-Kombi (the SOLE
  # post-Plan-16 keeper of nachstoss_allowed) does NOT lose the flag in a future
  # refactor. Exercises the seed's BK2-Kombi backfill logic (find_or_initialize_by
  # name='BK2-Kombi' + write data including nachstoss_allowed: true).
  # If a future refactor accidentally drops the flag from BK2-Kombi or removes the
  # backfill block, this test surfaces the regression in CI.
  test "T-P5-bk2kombi-keeps-nachstoss 38.4-16: BK-2kombi MUST keep nachstoss_allowed: true after seed replay (regression guard for D-01 / D-13 / D-14)" do
    # Replay the seed's BK2-Kombi backfill block programmatically.
    # Mirrors script/seed_bk2_disciplines.rb lines 51-63 (the find(107) block) but
    # uses find_or_initialize_by(name:) so it works in test DB without depending
    # on the production id 107.
    bk2 = Discipline.find_or_initialize_by(name: "BK2-Kombi")
    current = bk2.data.present? ? JSON.parse(bk2.data) : {}
    current["free_game_form"] = "bk2_kombi"
    current["ballziel_choices"] = [50, 60, 70]
    current["nachstoss_allowed"] = true
    bk2.data = current.to_json
    bk2.save!(validate: false)
    bk2.reload

    assert_equal true, bk2.nachstoss_allowed?,
      "T-P5-bk2kombi: BK-2kombi MUST keep nachstoss_allowed=true (regression guard — protects against accidental drop in future refactor)"
    parsed = JSON.parse(bk2.data)
    assert_equal "bk2_kombi", parsed["free_game_form"],
      "T-P5-bk2kombi: free_game_form must remain bk2_kombi"
    assert_equal [50, 60, 70], parsed["ballziel_choices"],
      "T-P5-bk2kombi: ballziel_choices must remain [50, 60, 70] (D-13 contract)"
  end

  # ---------------------------------------------------------------------
  # Plan 21-01: STO-BTK §1.4.1 Klasseneinteilung + class_from_val Edge-Case
  # ---------------------------------------------------------------------
  # Kanonische STO-Tabelle (Stand 06/2019, Norddeutscher Billard Verband e.V.).
  # Quelle der Wahrheit für DISCIPLINE_CLASS_LIMITS. Falls die STO sich aendert
  # ODER neue Disziplinen aufgenommen werden, diese Tabelle UND die Konstante
  # synchron halten.
  #
  # BEKANNTE CODE↔STO-DIVERGENZ (T1-Defer, separater Plan): Die MB-Disziplinen
  # Cadre 47/2, Cadre 71/2, Einband groß, Dreiband groß tragen im Code arabische
  # Klassen-Namen ("1"/"2"/"3") statt der STO §1.4.1-konformen roemischen
  # ("I"/"II"/"III"). Eine Umstellung braucht einen koordinierten Fix mit dem
  # Bestand (DTP-Eintraege, Tournament.player_class-Werte) und ist daher NICHT
  # Teil von Plan 21-01 T1. Diese Tabelle spiegelt deshalb fuer diese 4
  # Disziplinen den aktuellen CODE-Stand, nicht die reine STO. "Freie Partie groß"
  # wurde in T1 explizit angeglichen (STO-konform I/II/III).
  STO_BTK_141 = {
    "Freie Partie klein" => {"1" => 25.0, "2" => 16.0, "3" => 10.0, "4" => 7.0, "5" => 4.0, "6" => 2.0, "7" => 0.0},
    "Freie Partie groß" => {"I" => 10.0, "II" => 5.0, "III" => 0.0},
    "Cadre 35/2" => {"1" => 6.0, "2" => 0.0},
    "Cadre 52/2" => {"1" => 5.0, "2" => 0.0},
    "Cadre 47/2" => {"1" => 7.0, "2" => 0.0},
    "Cadre 71/2" => {"1" => 5.0, "2" => 0.0},
    "Einband klein" => {"1" => 2.5, "2" => 0.0},
    "Einband groß" => {"1" => 3.0, "2" => 0.0},
    "Dreiband klein" => {"1" => 0.8, "2" => 0.0},
    "Dreiband groß" => {"1" => 0.7, "2" => 0.5, "3" => 0.0}  # +Mindestballzahl §1.4.3 (65/45) im Calculator separat
  }.freeze

  test "T-21-01-A1: DISCIPLINE_CLASS_LIMITS deckt jede STO-Disziplin mit korrekten GD-Werten je Klasse ab" do
    STO_BTK_141.each do |disc_name, classes|
      limits = Discipline::DISCIPLINE_CLASS_LIMITS[disc_name]
      assert_not_nil limits, "DISCIPLINE_CLASS_LIMITS fehlt fuer #{disc_name}"
      classes.each do |cls, expected_gd|
        actual = limits[cls]
        actual_gd = Array(actual)[0]
        assert_equal expected_gd, actual_gd,
          "#{disc_name} Klasse #{cls}: Code=#{actual_gd.inspect}, STO=#{expected_gd} (§1.4.1)"
      end
    end
  end

  test "T-21-01-A2: Dreiband gross Klasse I/II tragen Mindestballzahlen 65/45 (STO §1.4.3; vorher 66)" do
    limits = Discipline::DISCIPLINE_CLASS_LIMITS["Dreiband groß"]
    assert_equal [0.7, 65], limits["1"], "Dreiband gross Klasse I = [GD-Min 0.7, Ball-Min 65]"
    assert_equal [0.5, 45], limits["2"], "Dreiband gross Klasse II = [GD-Min 0.5, Ball-Min 45]"
  end

  test "T-21-01-A3: Freie Partie gross hat MB-Klassen I/II/III (vorher faelschlich TB-Werte 1..7)" do
    limits = Discipline::DISCIPLINE_CLASS_LIMITS["Freie Partie groß"]
    assert_equal({"I" => 10.0, "II" => 5.0, "III" => 0.0}, limits,
      "Freie Partie gross MUSS MB I/II/III enthalten, NICHT TB 1..7")
    assert_nil limits["1"], "TB-Klasse '1' darf bei Freie Partie gross NICHT existieren"
  end

  test "T-21-01-A4: class_from_val ist inklusiv an Klassengrenzen (>=, nicht >)" do
    # Dreiband klein: { "1" => 0.8, "2" => 0.0 } — Walk in Insertion-Order, erste passende Klasse.
    d = Discipline.new(name: "Dreiband klein")
    assert_equal "1", d.class_from_val(0.8), "GD exakt 0.8 => Klasse 1 (Grenze inklusiv)"
    assert_equal "1", d.class_from_val(1.0), "GD 1.0 ueber 0.8 => Klasse 1"
    assert_equal "2", d.class_from_val(0.799), "GD knapp unter 0.8 => Klasse 2"
    assert_equal "2", d.class_from_val(0.0), "GD 0.0 => Klasse 2 (UNTERSTE Klasse mit Grenze 0; vorher faelschlich '')"
    assert_equal "", d.class_from_val(-0.1), "Negativer GD => leer (Fallback)"
  end

  test "T-21-01-A5: class_from_val liefert fuer jede STO-Disziplin an jeder Grenze die zugehoerige Klasse" do
    STO_BTK_141.each do |disc_name, classes|
      d = Discipline.new(name: disc_name)
      classes.each do |cls, gd_min|
        actual = d.class_from_val(gd_min)
        assert_equal cls, actual,
          "#{disc_name}: GD exakt #{gd_min} sollte Klasse #{cls} liefern, war: #{actual.inspect}"
      end
    end
  end

  test "T-21-01-A6: class_from_val fuer Disziplin ohne LIMITS-Eintrag (Pool, Snooker) liefert leer" do
    %w[8-Ball 9-Ball 10-Ball Pool Snooker].each do |name|
      d = Discipline.new(name: name)
      assert_equal "", d.class_from_val(5.0),
        "#{name} ist nicht in DISCIPLINE_CLASS_LIMITS => leer (STO-BTK ist Karambol-only)"
    end
  end

  # ---------------------------------------------------------------------
  # Plan 23-01 T4: root_chain für transitiven Permission-Check
  # ---------------------------------------------------------------------

  test "root_chain liefert self bei root-Discipline (kein super_discipline)" do
    root = Discipline.create!(name: "T4-Root")
    chain = root.root_chain
    assert_equal [root.id], chain.map(&:id)
  end

  test "root_chain liefert [self, super, ..., root] für 3-stufige Hierarchie" do
    root = Discipline.create!(name: "T4-Karambol")
    mid = Discipline.create!(name: "T4-Dreiband", super_discipline: root)
    leaf = Discipline.create!(name: "T4-Dreiband-groß", super_discipline: mid)

    chain = leaf.root_chain
    assert_equal [leaf.id, mid.id, root.id], chain.map(&:id),
      "root_chain muss leaf-first, root-last sein"
  end

  test "root_chain ist zyklen-defensive (kein Hang bei Self-Reference)" do
    d = Discipline.create!(name: "T4-Cycle-A")
    # Forciere zyklische Beziehung: d.super_discipline = d
    d.update_column(:super_discipline_id, d.id)
    chain = d.root_chain
    assert_equal [d.id], chain.map(&:id), "Self-Cycle wird nach erstem Element abgebrochen"
  end
end
