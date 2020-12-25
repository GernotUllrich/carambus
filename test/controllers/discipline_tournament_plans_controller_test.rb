require 'test_helper'

class DisciplineTournamentPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @discipline_tournament_plan = discipline_tournament_plans(:one)
  end

  test "should get index" do
    get discipline_tournament_plans_url
    assert_response :success
  end

  test "should get new" do
    get new_discipline_tournament_plan_url
    assert_response :success
  end

  test "should create discipline_tournament_plan" do
    assert_difference('DisciplineTournamentPlan.count') do
      post discipline_tournament_plans_url, params: { discipline_tournament_plan: { discipline_id: @discipline_tournament_plan.discipline_id, innings: @discipline_tournament_plan.innings, player_class: @discipline_tournament_plan.player_class, players: @discipline_tournament_plan.players, points: @discipline_tournament_plan.points, tournament_plan_id: @discipline_tournament_plan.tournament_plan_id } }
    end

    assert_redirected_to discipline_tournament_plan_url(DisciplineTournamentPlan.last)
  end

  test "should show discipline_tournament_plan" do
    get discipline_tournament_plan_url(@discipline_tournament_plan)
    assert_response :success
  end

  test "should get edit" do
    get edit_discipline_tournament_plan_url(@discipline_tournament_plan)
    assert_response :success
  end

  test "should update discipline_tournament_plan" do
    patch discipline_tournament_plan_url(@discipline_tournament_plan), params: { discipline_tournament_plan: { discipline_id: @discipline_tournament_plan.discipline_id, innings: @discipline_tournament_plan.innings, player_class: @discipline_tournament_plan.player_class, players: @discipline_tournament_plan.players, points: @discipline_tournament_plan.points, tournament_plan_id: @discipline_tournament_plan.tournament_plan_id } }
    assert_redirected_to discipline_tournament_plan_url(@discipline_tournament_plan)
  end

  test "should destroy discipline_tournament_plan" do
    assert_difference('DisciplineTournamentPlan.count', -1) do
      delete discipline_tournament_plan_url(@discipline_tournament_plan)
    end

    assert_redirected_to discipline_tournament_plans_url
  end
end
