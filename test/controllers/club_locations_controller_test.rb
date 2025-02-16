require "test_helper"

class ClubLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @club_location = club_locations(:one)
  end

  test "should get index" do
    get club_locations_url
    assert_response :success
  end

  test "should get new" do
    get new_club_location_url
    assert_response :success
  end

  test "should create club_location" do
    assert_difference("ClubLocation.count") do
      post club_locations_url, params: {club_location: {club_id: @club_location.club_id, location_id: @club_location.location_id, status: @club_location.status}}
    end

    assert_redirected_to club_location_url(ClubLocation.last)
  end

  test "should show club_location" do
    get club_location_url(@club_location)
    assert_response :success
  end

  test "should get edit" do
    get edit_club_location_url(@club_location)
    assert_response :success
  end

  test "should update club_location" do
    patch club_location_url(@club_location), params: {club_location: {club_id: @club_location.club_id, location_id: @club_location.location_id, status: @club_location.status}}
    assert_redirected_to club_location_url(@club_location)
  end

  test "should destroy club_location" do
    assert_difference("ClubLocation.count", -1) do
      delete club_location_url(@club_location)
    end

    assert_redirected_to club_locations_url
  end
end
