# frozen_string_literal: true

require "test_helper"

# Phase 17 / 17-01: AC-3 — nur Admin ODER Sportwart der Location darf
# toggle_reservation aufrufen. Die uebrigen CRUD-Pfade bleiben admin-only.
class TablesControllerReservationTest < ActionDispatch::IntegrationTest
  setup do
    @table = tables(:one) # location: one
    @table.update!(reserved: false)
    @admin = users(:admin)  # admin: true
    @user = users(:one)    # weder admin noch Sportwart
  end

  test "admin darf reservieren" do
    sign_in @admin
    patch toggle_reservation_table_path(@table)
    assert_response :redirect
    assert tables(:one).reload.reserved?, "Admin reserviert den Tisch"
  end

  test "nicht-admin ohne Sportwart-Scope darf nicht reservieren" do
    sign_in @user
    patch toggle_reservation_table_path(@table)
    assert_response :redirect
    assert_not tables(:one).reload.reserved?, "Unautorisiert: keine Reservierung"
  end

  test "Sportwart der Location darf reservieren" do
    SportwartLocation.create!(id: 50_000_900, user: @user, location: @table.location)
    sign_in @user
    patch toggle_reservation_table_path(@table)
    assert_response :redirect
    assert tables(:one).reload.reserved?, "Location-Sportwart reserviert den Tisch"
  end
end
