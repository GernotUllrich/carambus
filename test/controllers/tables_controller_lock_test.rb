# frozen_string_literal: true

require "test_helper"

# Phase 17 / 17-01: AC-3 — nur Admin ODER Sportwart der Location darf
# toggle_lock aufrufen. Die uebrigen CRUD-Pfade bleiben admin-only.
class TablesControllerLockTest < ActionDispatch::IntegrationTest
  setup do
    @table = tables(:one) # location: one
    @table.update!(locked_for_tournament: false)
    @admin = users(:admin)  # admin: true
    @user = users(:one)    # weder admin noch Sportwart
  end

  test "admin darf sperren" do
    sign_in @admin
    patch toggle_lock_table_path(@table)
    assert_response :redirect
    assert tables(:one).reload.locked_for_tournament?, "Admin sperrt den Tisch"
  end

  test "nicht-admin ohne Sportwart-Scope darf nicht sperren" do
    sign_in @user
    patch toggle_lock_table_path(@table)
    assert_response :redirect
    assert_not tables(:one).reload.locked_for_tournament?, "Unautorisiert: keine Sperre"
  end

  test "Sportwart der Location darf sperren" do
    SportwartLocation.create!(id: 50_000_900, user: @user, location: @table.location)
    sign_in @user
    patch toggle_lock_table_path(@table)
    assert_response :redirect
    assert tables(:one).reload.locked_for_tournament?, "Location-Sportwart sperrt den Tisch"
  end
end
