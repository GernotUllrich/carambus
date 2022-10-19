require "test_helper"

class RegistrationListCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @registration_list_cc = registration_list_ccs(:one)
  end

  test "should get index" do
    get registration_list_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_registration_list_cc_url
    assert_response :success
  end

  test "should create registration_list_cc" do
    assert_difference('RegistrationListCc.count') do
      post registration_list_ccs_url, params: { registration_list_cc: { branch_cc_id: @registration_list_cc.branch_cc_id, category_cc_id: @registration_list_cc.category_cc_id, cc_id: @registration_list_cc.cc_id, context: @registration_list_cc.context, data: @registration_list_cc.data, deadline: @registration_list_cc.deadline, discipline_id: @registration_list_cc.discipline_id, name: @registration_list_cc.name, qualifying_date: @registration_list_cc.qualifying_date, season_id: @registration_list_cc.season_id, status: @registration_list_cc.status } }
    end

    assert_redirected_to registration_list_cc_url(RegistrationListCc.last)
  end

  test "should show registration_list_cc" do
    get registration_list_cc_url(@registration_list_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_registration_list_cc_url(@registration_list_cc)
    assert_response :success
  end

  test "should update registration_list_cc" do
    patch registration_list_cc_url(@registration_list_cc), params: { registration_list_cc: { branch_cc_id: @registration_list_cc.branch_cc_id, category_cc_id: @registration_list_cc.category_cc_id, cc_id: @registration_list_cc.cc_id, context: @registration_list_cc.context, data: @registration_list_cc.data, deadline: @registration_list_cc.deadline, discipline_id: @registration_list_cc.discipline_id, name: @registration_list_cc.name, qualifying_date: @registration_list_cc.qualifying_date, season_id: @registration_list_cc.season_id, status: @registration_list_cc.status } }
    assert_redirected_to registration_list_cc_url(@registration_list_cc)
  end

  test "should destroy registration_list_cc" do
    assert_difference('RegistrationListCc.count', -1) do
      delete registration_list_cc_url(@registration_list_cc)
    end

    assert_redirected_to registration_list_ccs_url
  end
end
