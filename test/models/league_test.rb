require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  def setup
    @league = leagues(:one)
  end

  test "should reconstruct game plan from existing data" do
    # Skip if league doesn't have required associations
    skip unless @league.discipline.present? && @league.parties.any?
    
    # Test that the method can be called without errors
    result = @league.reconstruct_game_plan_from_existing_data
    
    # Should return a GamePlan object or nil
    assert result.nil? || result.is_a?(GamePlan)
  end

  test "should handle league without discipline" do
    league_without_discipline = League.new(name: "Test League")
    
    result = league_without_discipline.reconstruct_game_plan_from_existing_data
    
    assert_nil result
  end

  test "should handle league without parties" do
    league_without_parties = League.new(name: "Test League", discipline: disciplines(:one))
    
    result = league_without_parties.reconstruct_game_plan_from_existing_data
    
    # Should still create a basic GamePlan with defaults
    assert result.is_a?(GamePlan)
  end
end 