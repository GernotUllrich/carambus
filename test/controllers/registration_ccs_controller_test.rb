require "test_helper"

class RegistrationCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @registration_cc = registration_ccs(:one)
  end

  test "should get index" do
    get registration_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_registration_cc_url
    assert_response :success
  end

  test "should create registration_cc" do
    assert_difference('RegistrationCc.count') do
      post registration_ccs_url, params: { registration_cc: { player_id: @registration_cc.player_id, registration_list_cc_id: @registration_cc.registration_list_cc_id, status: @registration_cc.status } }
    end

    assert_redirected_to registration_cc_url(RegistrationCc.last)
  end

  test "should show registration_cc" do
    get registration_cc_url(@registration_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_registration_cc_url(@registration_cc)
    assert_response :success
  end

  test "should update registration_cc" do
    patch registration_cc_url(@registration_cc), params: { registration_cc: { player_id: @registration_cc.player_id, registration_list_cc_id: @registration_cc.registration_list_cc_id, status: @registration_cc.status } }
    assert_redirected_to registration_cc_url(@registration_cc)
  end

  test "should destroy registration_cc" do
    assert_difference('RegistrationCc.count', -1) do
      delete registration_cc_url(@registration_cc)
    end

    assert_redirected_to registration_ccs_url
  end
end
