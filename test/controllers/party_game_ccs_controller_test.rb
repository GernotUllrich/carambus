require "test_helper"

class PartyGameCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @party_game_cc = party_game_ccs(:one)
  end

  test "should get index" do
    get party_game_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_party_game_cc_url
    assert_response :success
  end

  test "should create party_game_cc" do
    assert_difference('PartyGameCc.count') do
      post party_game_ccs_url, params: { party_game_cc: { cc_id: @party_game_cc.cc_id, data: @party_game_cc.data, discipline_id: @party_game_cc.discipline_id, name: @party_game_cc.name, player_a_id: @party_game_cc.player_a_id, player_b_id: @party_game_cc.player_b_id, seqno: @party_game_cc.seqno } }
    end

    assert_redirected_to party_game_cc_url(PartyGameCc.last)
  end

  test "should show party_game_cc" do
    get party_game_cc_url(@party_game_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_party_game_cc_url(@party_game_cc)
    assert_response :success
  end

  test "should update party_game_cc" do
    patch party_game_cc_url(@party_game_cc), params: { party_game_cc: { cc_id: @party_game_cc.cc_id, data: @party_game_cc.data, discipline_id: @party_game_cc.discipline_id, name: @party_game_cc.name, player_a_id: @party_game_cc.player_a_id, player_b_id: @party_game_cc.player_b_id, seqno: @party_game_cc.seqno } }
    assert_redirected_to party_game_cc_url(@party_game_cc)
  end

  test "should destroy party_game_cc" do
    assert_difference('PartyGameCc.count', -1) do
      delete party_game_cc_url(@party_game_cc)
    end

    assert_redirected_to party_game_ccs_url
  end
end
