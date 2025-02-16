require "test_helper"

class TableLocalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @table_local = table_locals(:one)
  end

  test "should get index" do
    get table_locals_url
    assert_response :success
  end

  test "should get new" do
    get new_table_local_url
    assert_response :success
  end

  test "should create table_local" do
    assert_difference("TableLocal.count") do
      post table_locals_url, params: {table_local: {ip_address: @table_local.ip_address, table_id: @table_local.table_id, tpl_ip_address: @table_local.tpl_ip_address}}
    end

    assert_redirected_to table_local_url(TableLocal.last)
  end

  test "should show table_local" do
    get table_local_url(@table_local)
    assert_response :success
  end

  test "should get edit" do
    get edit_table_local_url(@table_local)
    assert_response :success
  end

  test "should update table_local" do
    patch table_local_url(@table_local), params: {table_local: {ip_address: @table_local.ip_address, table_id: @table_local.table_id, tpl_ip_address: @table_local.tpl_ip_address}}
    assert_redirected_to table_local_url(@table_local)
  end

  test "should destroy table_local" do
    assert_difference("TableLocal.count", -1) do
      delete table_local_url(@table_local)
    end

    assert_redirected_to table_locals_url
  end
end
