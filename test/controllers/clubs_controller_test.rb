require 'test_helper'

class ClubsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @club = clubs(:one)
  end

  test "should get index" do
    get clubs_url
    assert_response :success
  end

  test "should get new" do
    get new_club_url
    assert_response :success
  end

  test "should create club" do
    assert_difference('Club.count') do
      post clubs_url, params: { club: { address: @club.address, ba_id: @club.ba_id, dbu_entry: @club.dbu_entry, email: @club.email, founded: @club.founded, homepage: @club.homepage, logo: @club.logo, name: @club.name, priceinfo: @club.priceinfo, region_id: @club.region_id, shortname: @club.shortname, status: @club.status } }
    end

    assert_redirected_to club_url(Club.last)
  end

  test "should show club" do
    get club_url(@club)
    assert_response :success
  end

  test "should get edit" do
    get edit_club_url(@club)
    assert_response :success
  end

  test "should update club" do
    patch club_url(@club), params: { club: { address: @club.address, ba_id: @club.ba_id, dbu_entry: @club.dbu_entry, email: @club.email, founded: @club.founded, homepage: @club.homepage, logo: @club.logo, name: @club.name, priceinfo: @club.priceinfo, region_id: @club.region_id, shortname: @club.shortname, status: @club.status } }
    assert_redirected_to club_url(@club)
  end

  test "should destroy club" do
    assert_difference('Club.count', -1) do
      delete club_url(@club)
    end

    assert_redirected_to clubs_url
  end
end
