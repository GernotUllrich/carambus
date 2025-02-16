require "test_helper"

class DisciplinePhasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @discipline_phase = discipline_phases(:one)
  end

  test "should get index" do
    get discipline_phases_url
    assert_response :success
  end

  test "should get new" do
    get new_discipline_phase_url
    assert_response :success
  end

  test "should create discipline_phase" do
    assert_difference("DisciplinePhase.count") do
      post discipline_phases_url, params: {discipline_phase: {data: @discipline_phase.data, discipline_id: @discipline_phase.discipline_id, name: @discipline_phase.name, parent_discipline_id: @discipline_phase.parent_discipline_id, position: @discipline_phase.position}}
    end

    assert_redirected_to discipline_phase_url(DisciplinePhase.last)
  end

  test "should show discipline_phase" do
    get discipline_phase_url(@discipline_phase)
    assert_response :success
  end

  test "should get edit" do
    get edit_discipline_phase_url(@discipline_phase)
    assert_response :success
  end

  test "should update discipline_phase" do
    patch discipline_phase_url(@discipline_phase), params: {discipline_phase: {data: @discipline_phase.data, discipline_id: @discipline_phase.discipline_id, name: @discipline_phase.name, parent_discipline_id: @discipline_phase.parent_discipline_id, position: @discipline_phase.position}}
    assert_redirected_to discipline_phase_url(@discipline_phase)
  end

  test "should destroy discipline_phase" do
    assert_difference("DisciplinePhase.count", -1) do
      delete discipline_phase_url(@discipline_phase)
    end

    assert_redirected_to discipline_phases_url
  end
end
