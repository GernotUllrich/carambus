require 'test_helper'

class TableKindsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @table_kind = table_kinds(:one)
  end

  test "should get index" do
    get table_kinds_url
    assert_response :success
  end

  test "should get new" do
    get new_table_kind_url
    assert_response :success
  end

  test "should create table_kind" do
    assert_difference('TableKind.count') do
      post table_kinds_url, params: { table_kind: { measures: @table_kind.measures, name: @table_kind.name, short: @table_kind.short } }
    end

    assert_redirected_to table_kind_url(TableKind.last)
  end

  test "should show table_kind" do
    get table_kind_url(@table_kind)
    assert_response :success
  end

  test "should get edit" do
    get edit_table_kind_url(@table_kind)
    assert_response :success
  end

  test "should update table_kind" do
    patch table_kind_url(@table_kind), params: { table_kind: { measures: @table_kind.measures, name: @table_kind.name, short: @table_kind.short } }
    assert_redirected_to table_kind_url(@table_kind)
  end

  test "should destroy table_kind" do
    assert_difference('TableKind.count', -1) do
      delete table_kind_url(@table_kind)
    end

    assert_redirected_to table_kinds_url
  end
end
