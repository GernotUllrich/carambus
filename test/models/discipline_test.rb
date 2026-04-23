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

  test "BK2_DISCIPLINE_MAP contains 'BK2-Kombi' as the sole canonical entry" do
    assert defined?(Discipline::BK2_DISCIPLINE_MAP),
      "Discipline::BK2_DISCIPLINE_MAP must be defined (38.1-06 Task 1)"
    assert_instance_of Array, Discipline::BK2_DISCIPLINE_MAP
    assert_equal ["BK2-Kombi"], Discipline::BK2_DISCIPLINE_MAP,
      "BK2_DISCIPLINE_MAP must be exactly ['BK2-Kombi']"
    assert Discipline::BK2_DISCIPLINE_MAP.frozen?,
      "BK2_DISCIPLINE_MAP must be frozen"
    assert_includes Discipline::BK2_DISCIPLINE_MAP, "BK2-Kombi"
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
    refute_includes Discipline::KARAMBOL_DISCIPLINE_MAP, "BK2-Kombi",
      "BK2-Kombi must NOT be in KARAMBOL_DISCIPLINE_MAP"
  end
end
