require "test_helper"

class RegionCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @region_cc = region_ccs(:one)
  end

  test "should get index" do
    get region_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_region_cc_url
    assert_response :success
  end

  test "should create region_cc" do
    assert_difference('RegionCc.count') do
      post region_ccs_url, params: { region_cc: { cc_id: @region_cc.cc_id, context: @region_cc.context, name: @region_cc.name, region_id: @region_cc.region_id, shortname: @region_cc.shortname } }
    end

    assert_redirected_to region_cc_url(RegionCc.last)
  end

  test "should show region_cc" do
    get region_cc_url(@region_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_region_cc_url(@region_cc)
    assert_response :success
  end

  test "should update region_cc" do
    patch region_cc_url(@region_cc), params: { region_cc: { cc_id: @region_cc.cc_id, context: @region_cc.context, name: @region_cc.name, region_id: @region_cc.region_id, shortname: @region_cc.shortname } }
    assert_redirected_to region_cc_url(@region_cc)
  end

  test "should destroy region_cc" do
    assert_difference('RegionCc.count', -1) do
      delete region_cc_url(@region_cc)
    end

    assert_redirected_to region_ccs_url
  end
end
