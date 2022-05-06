require "test_helper"

class MetaMapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @meta_map = meta_maps(:one)
  end

  test "should get index" do
    get meta_maps_url
    assert_response :success
  end

  test "should get new" do
    get new_meta_map_url
    assert_response :success
  end

  test "should create meta_map" do
    assert_difference('MetaMap.count') do
      post meta_maps_url, params: { meta_map: { ba_base_url: @meta_map.ba_base_url, cc_base_url: @meta_map.cc_base_url, class_ba: @meta_map.class_ba, class_cc: @meta_map.class_cc, data: @meta_map.data } }
    end

    assert_redirected_to meta_map_url(MetaMap.last)
  end

  test "should show meta_map" do
    get meta_map_url(@meta_map)
    assert_response :success
  end

  test "should get edit" do
    get edit_meta_map_url(@meta_map)
    assert_response :success
  end

  test "should update meta_map" do
    patch meta_map_url(@meta_map), params: { meta_map: { ba_base_url: @meta_map.ba_base_url, cc_base_url: @meta_map.cc_base_url, class_ba: @meta_map.class_ba, class_cc: @meta_map.class_cc, data: @meta_map.data } }
    assert_redirected_to meta_map_url(@meta_map)
  end

  test "should destroy meta_map" do
    assert_difference('MetaMap.count', -1) do
      delete meta_map_url(@meta_map)
    end

    assert_redirected_to meta_maps_url
  end
end
