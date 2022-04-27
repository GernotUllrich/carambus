require "test_helper"

class PartyCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @party_cc = party_ccs(:one)
  end

  test "should get index" do
    get party_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_party_cc_url
    assert_response :success
  end

  test "should create party_cc" do
    assert_difference('PartyCc.count') do
      post party_ccs_url, params: { party_cc: { cc_id: @party_cc.cc_id, data: @party_cc.data, day_seqno: @party_cc.day_seqno, integer: @party_cc.integer, league_cc_id: @party_cc.league_cc_id, league_team_a_cc_id: @party_cc.league_team_a_cc_id, league_team_b_cc_id: @party_cc.league_team_b_cc_id, league_team_host_cc_id: @party_cc.league_team_host_cc_id, party_id: @party_cc.party_id, remarks: @party_cc.remarks } }
    end

    assert_redirected_to party_cc_url(PartyCc.last)
  end

  test "should show party_cc" do
    get party_cc_url(@party_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_party_cc_url(@party_cc)
    assert_response :success
  end

  test "should update party_cc" do
    patch party_cc_url(@party_cc), params: { party_cc: { cc_id: @party_cc.cc_id, data: @party_cc.data, day_seqno: @party_cc.day_seqno, integer: @party_cc.integer, league_cc_id: @party_cc.league_cc_id, league_team_a_cc_id: @party_cc.league_team_a_cc_id, league_team_b_cc_id: @party_cc.league_team_b_cc_id, league_team_host_cc_id: @party_cc.league_team_host_cc_id, party_id: @party_cc.party_id, remarks: @party_cc.remarks } }
    assert_redirected_to party_cc_url(@party_cc)
  end

  test "should destroy party_cc" do
    assert_difference('PartyCc.count', -1) do
      delete party_cc_url(@party_cc)
    end

    assert_redirected_to party_ccs_url
  end
end
