require "test_helper"

class CategoryCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @category_cc = category_ccs(:one)
  end

  test "should get index" do
    get category_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_category_cc_url
    assert_response :success
  end

  test "should create category_cc" do
    assert_difference('CategoryCc.count') do
      post category_ccs_url, params: { category_cc: { branch_cc_id: @category_cc.branch_cc_id, cc_id: @category_cc.cc_id, context: @category_cc.context, max_age: @category_cc.max_age, min_age: @category_cc.min_age, name: @category_cc.name, sex: @category_cc.sex, status: @category_cc.status } }
    end

    assert_redirected_to category_cc_url(CategoryCc.last)
  end

  test "should show category_cc" do
    get category_cc_url(@category_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_category_cc_url(@category_cc)
    assert_response :success
  end

  test "should update category_cc" do
    patch category_cc_url(@category_cc), params: { category_cc: { branch_cc_id: @category_cc.branch_cc_id, cc_id: @category_cc.cc_id, context: @category_cc.context, max_age: @category_cc.max_age, min_age: @category_cc.min_age, name: @category_cc.name, sex: @category_cc.sex, status: @category_cc.status } }
    assert_redirected_to category_cc_url(@category_cc)
  end

  test "should destroy category_cc" do
    assert_difference('CategoryCc.count', -1) do
      delete category_cc_url(@category_cc)
    end

    assert_redirected_to category_ccs_url
  end
end
