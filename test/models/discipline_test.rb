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
end
