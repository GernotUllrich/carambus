# frozen_string_literal: true

require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Test: reconstruct_game_plan_from_existing_data
  # The method builds a GamePlan from existing party/game data. Without parties
  # it creates an empty GamePlan with default parameters.
  # ---------------------------------------------------------------------------

  test "should reconstruct game plan from existing data" do
    # Create discipline with branch name matching GAME_PARAMETER_DEFAULTS key
    discipline = Discipline.create!(id: 50_000_200, name: "Pool")
    organizer = regions(:nbv)

    league = League.create!(
      id: 50_000_200,
      name: "Test Pool League",
      discipline: discipline,
      organizer: organizer,
      organizer_type: "Region",
      season: seasons(:current),
      shortname: "TPL"
    )

    result = league.send(:reconstruct_game_plan_from_existing_data)

    # Method must return a GamePlan (not nil) when discipline is present
    assert_instance_of GamePlan, result
    assert_equal "Test Pool League - Pool - NBV", result.name

  ensure
    league&.destroy
    discipline&.destroy
  end

  test "should handle league without discipline" do
    league_without_discipline = League.new(name: "Test League")

    result = league_without_discipline.send(:reconstruct_game_plan_from_existing_data)

    assert_nil result
  end

  test "should handle league without parties returns GamePlan with defaults" do
    discipline = Discipline.create!(id: 50_000_201, name: "Karambol")
    organizer = regions(:nbv)

    league = League.create!(
      id: 50_000_201,
      name: "Test Karambol League",
      discipline: discipline,
      organizer: organizer,
      organizer_type: "Region",
      season: seasons(:current),
      shortname: "TKL"
    )

    result = league.send(:reconstruct_game_plan_from_existing_data)

    assert_instance_of GamePlan, result
    assert result.data.is_a?(Hash), "GamePlan data must be a Hash"

  ensure
    league&.destroy
    discipline&.destroy
  end
end
