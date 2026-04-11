# frozen_string_literal: true

require "test_helper"

# Tests for League::GamePlanReconstructor ApplicationService.
# Verifies the dispatcher pattern and basic operation contracts.
class League::GamePlanReconstructorTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 80_000

  @@counter = 0

  def next_id
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  setup do
    base = next_id
    @league = League.create!(
      id: base,
      name: "GPR Test #{base}",
      shortname: "GPR#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band)
    )
    @season = seasons(:current)
  end

  # --- operation: :reconstruct ---

  test "reconstruct returns nil when league has no parties" do
    result = League::GamePlanReconstructor.call(league: @league, operation: :reconstruct)

    assert_nil result
  end

  test "reconstruct delegates via League#reconstruct_game_plan_from_existing_data" do
    # Model delegation wrapper and direct service call must agree (both nil for empty league)
    via_model = @league.reconstruct_game_plan_from_existing_data
    via_service = League::GamePlanReconstructor.call(league: @league, operation: :reconstruct)

    assert_nil via_model, "Expected nil for league with no parties"
    assert_nil via_service, "Expected nil for league with no parties"
  end

  # --- operation: :reconstruct_for_season ---

  test "reconstruct_for_season returns hash with success, failed, errors keys" do
    result = League::GamePlanReconstructor.call(season: @season, operation: :reconstruct_for_season)

    assert result.key?(:success), "Result must have :success key"
    assert result.key?(:failed), "Result must have :failed key"
    assert result.key?(:errors), "Result must have :errors key"
  end

  test "reconstruct_for_season returns integer counts" do
    result = League::GamePlanReconstructor.call(season: @season, operation: :reconstruct_for_season)

    assert_kind_of Integer, result[:success]
    assert_kind_of Integer, result[:failed]
    assert_kind_of Array, result[:errors]
  end

  test "reconstruct_for_season delegates via League.reconstruct_game_plans_for_season" do
    via_model = League.reconstruct_game_plans_for_season(@season)
    via_service = League::GamePlanReconstructor.call(season: @season, operation: :reconstruct_for_season)

    assert_equal via_model[:success], via_service[:success]
    assert_equal via_model[:failed], via_service[:failed]
  end

  # --- operation: :delete_for_season ---

  test "delete_for_season does not raise" do
    assert_nothing_raised do
      League::GamePlanReconstructor.call(league: @league, season: @season, operation: :delete_for_season)
    end
  end

  test "delete_for_season returns an integer" do
    result = League::GamePlanReconstructor.call(season: @season, operation: :delete_for_season)

    assert_kind_of Integer, result
  end

  # --- unknown operation ---

  test "unknown operation raises ArgumentError" do
    assert_raises(ArgumentError) do
      League::GamePlanReconstructor.call(league: @league, operation: :unknown_op)
    end
  end
end
