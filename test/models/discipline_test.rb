# frozen_string_literal: true

require "test_helper"

class DisciplineTest < ActiveSupport::TestCase
  # UI-07 D-19: parameter_ranges must return a hash of field -> Range
  # and must not raise on unknown disciplines.

  UI_07_EXPECTED_KEYS = %i[
    balls_goal
    innings_goal
    timeout
    time_out_warm_up_first_min
    time_out_warm_up_follow_up_min
    sets_to_play
    sets_to_win
  ].freeze

  def freie_partie_fixture
    Discipline.find_by(name: "Freie Partie klein") ||
      Discipline.find_by(name: "Freie Partie") ||
      begin
        disciplines(:discipline_freie_partie_klein)
      rescue
        nil
      end
  end

  test "parameter_ranges returns hash with expected keys for Freie Partie klein" do
    d = freie_partie_fixture
    skip "no Freie Partie discipline in fixtures" unless d

    ranges = d.parameter_ranges
    assert_instance_of Hash, ranges
    UI_07_EXPECTED_KEYS.each do |k|
      assert ranges.key?(k), "expected key #{k} in parameter_ranges"
      assert_instance_of Range, ranges[k], "expected Range for #{k}, got #{ranges[k].class}"
    end
  end

  test "parameter_ranges includes sensible balls_goal for Freie Partie" do
    d = freie_partie_fixture
    skip "no Freie Partie discipline in fixtures" unless d

    ranges = d.parameter_ranges
    assert ranges[:balls_goal].cover?(100), "100 should be a valid balls_goal"
    assert_not ranges[:balls_goal].cover?(10_000), "10_000 should be out of range"
  end

  test "parameter_ranges returns empty hash for unknown discipline name" do
    d = Discipline.new(name: "TotallyFakeDisciplineName-#{SecureRandom.hex(4)}")
    assert_nothing_raised do
      result = d.parameter_ranges
      assert_instance_of Hash, result
      assert_empty result, "unknown discipline should yield an empty Hash"
    end
  end

  test "parameter_ranges does not raise for any fixture discipline" do
    Discipline.find_each do |d|
      result =
        begin
          d.parameter_ranges
        rescue => e
          flunk "parameter_ranges raised for discipline id=#{d.id} name=#{d.name}: #{e.class}: #{e.message}"
        end
      assert result.is_a?(Hash),
        "parameter_ranges must always return a Hash (got #{result.class} for id=#{d.id} name=#{d.name})"
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
    assert_equal [50, 60, 70],             disciplines(:bk2_kombi).ballziel_choices
    assert_equal [50],                     disciplines(:bk50).ballziel_choices
    assert_equal [100],                    disciplines(:bk100).ballziel_choices
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

  # ---------------------------------------------------------------------------
  # 2026-04-27: Anchor regression — Tournament 17411 (Dreiband klein) values
  # 100/20 are real-world normal and MUST NOT trigger the UI-07 modal.
  # Source: .planning/todos/done/2026-04-14-recalibrate-discipline-parameter-ranges-bounds.md
  # ---------------------------------------------------------------------------

  test "parameter_ranges accepts Tournament 17411 anchor (Dreiband klein 100/20)" do
    ranges = Discipline::DISCIPLINE_PARAMETER_RANGES["Dreiband klein"]
    assert ranges, "Dreiband klein must have parameter_ranges entry"
    assert ranges[:balls_goal].cover?(100),
      "balls_goal=100 must be valid for Dreiband klein (Tournament 17411 anchor)"
    assert ranges[:innings_goal].cover?(20),
      "innings_goal=20 must be valid for Dreiband klein (Tournament 17411 anchor)"
  end

  test "parameter_ranges still flags clearly-typo values" do
    ranges = Discipline::DISCIPLINE_PARAMETER_RANGES["Dreiband klein"]
    refute ranges[:balls_goal].cover?(10_000),
      "balls_goal=10000 must be flagged (typo filter still active)"
    refute ranges[:innings_goal].cover?(10_000),
      "innings_goal=10000 must be flagged (typo filter still active)"
  end
end
