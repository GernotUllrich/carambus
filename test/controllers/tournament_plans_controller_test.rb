require 'test_helper'

class TournamentPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament_plan = tournament_plans(:one)
  end

  test "should get index" do
    get tournament_plans_url
    assert_response :success
  end

  test "should get new" do
    get new_tournament_plan_url
    assert_response :success
  end

  test "should create tournament_plan" do
    assert_difference('TournamentPlan.count') do
      post tournament_plans_url, params: { tournament_plan: { even_more_description: @tournament_plan.even_more_description, executor_class: @tournament_plan.executor_class, executor_params: @tournament_plan.executor_params, more_description: @tournament_plan.more_description, name: @tournament_plan.name, ngroups: @tournament_plan.ngroups, nrepeats: @tournament_plan.nrepeats, players: @tournament_plan.players, rulesystem: @tournament_plan.rulesystem, tables: @tournament_plan.tables } }
    end

    assert_redirected_to tournament_plan_url(TournamentPlan.last)
  end

  test "should show tournament_plan" do
    get tournament_plan_url(@tournament_plan)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_plan_url(@tournament_plan)
    assert_response :success
  end

  test "should update tournament_plan" do
    patch tournament_plan_url(@tournament_plan), params: { tournament_plan: { even_more_description: @tournament_plan.even_more_description, executor_class: @tournament_plan.executor_class, executor_params: @tournament_plan.executor_params, more_description: @tournament_plan.more_description, name: @tournament_plan.name, ngroups: @tournament_plan.ngroups, nrepeats: @tournament_plan.nrepeats, players: @tournament_plan.players, rulesystem: @tournament_plan.rulesystem, tables: @tournament_plan.tables } }
    assert_redirected_to tournament_plan_url(@tournament_plan)
  end

  test "should destroy tournament_plan" do
    assert_difference('TournamentPlan.count', -1) do
      delete tournament_plan_url(@tournament_plan)
    end

    assert_redirected_to tournament_plans_url
  end
end
