# frozen_string_literal: true

require "test_helper"

class GamePlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game_plan = game_plans(:one)
  end

  test "should get index" do
    get game_plans_url
    assert_response :success
  end

  test "should get new" do
    get new_game_plan_url
    assert_response :success
  end

  test "should create game_plan" do
    assert_difference("GamePlan.count") do
      post game_plans_url,
        params: {game_plan: {data: @game_plan.data, footprint: @game_plan.footprint, name: @game_plan.name}}
    end

    assert_redirected_to game_plan_url(GamePlan.last)
  end

  test "should show game_plan" do
    get game_plan_url(@game_plan)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_plan_url(@game_plan)
    assert_response :success
  end

  test "should update game_plan" do
    patch game_plan_url(@game_plan),
      params: {game_plan: {data: @game_plan.data, footprint: @game_plan.footprint, name: @game_plan.name}}
    assert_redirected_to game_plan_url(@game_plan)
  end

  test "should destroy game_plan" do
    assert_difference("GamePlan.count", -1) do
      delete game_plan_url(@game_plan)
    end

    assert_redirected_to game_plans_url
  end
end
