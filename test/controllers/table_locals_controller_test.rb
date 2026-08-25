# frozen_string_literal: true

require "test_helper"

class TableLocalsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @table_local = table_locals(:one)
    # TableLocalsController haengt an before_action :system_admin_only — ohne
    # angemeldeten System-Admin endet jede Action im 302 auf /.
    sign_in users(:system_admin)
  end

  test "should get index" do
    get table_locals_url
    assert_response :success
  end

  test "should get new" do
    get new_table_local_url
    assert_response :success
  end

  # `tables(:two)` hat bewusst noch kein TableLocal. Seit dem Unique-Index auf
  # `table_locals.table_id` ist ein zweiter Eintrag fuer denselben Tisch nicht mehr moeglich —
  # der Scaffold-Controller wuerde hier sonst eine Dublette anlegen.
  test "should create table_local" do
    assert_difference("TableLocal.count") do
      post table_locals_url, params: {table_local: {ip_address: @table_local.ip_address, table_id: tables(:two).id, tpl_ip_address: @table_local.tpl_ip_address}}
    end

    assert_redirected_to table_local_url(TableLocal.last)
  end

  test "ein zweites TableLocal fuer denselben Tisch wird abgewiesen" do
    assert_no_difference("TableLocal.count") do
      post table_locals_url, params: {table_local: {ip_address: "10.0.0.1", table_id: @table_local.table_id}}
    end
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
