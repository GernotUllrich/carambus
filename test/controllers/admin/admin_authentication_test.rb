# frozen_string_literal: true

require "test_helper"

# Regression zu einem kritischen Befund vom 2026-08-14: Der gesamte Administrate-Bereich
# war unauthentifiziert erreichbar. Admin::ApplicationController#authenticate_admin war
# seit dem initial commit ein leerer Scaffold-Stub ("TODO Add authentication logic here"),
# in c1e473cb (2025-02-25) durch auskommentierte Zeilen ersetzt — aber nie aktiv.
# Verifiziert auf nbv.carambus.de: GET /admin/users lieferte ohne Login die Benutzerliste
# samt E-Mail und Rolle, inklusive Links auf /admin/users/new und /edit.
#
# Schwelle ist bewusst system_admin? und NICHT admin? (= club_admin || system_admin):
# Administrate erlaubt volle CRUD auf users inkl. Rollenvergabe — wer hereinkommt, kann
# sich selbst hochstufen.
class AdminAuthenticationTest < ActionDispatch::IntegrationTest
  # --- Administrate (Admin::ApplicationController#authenticate_admin) ---

  test "admin/users: anonym wird abgewiesen" do
    get admin_users_path

    assert_response :redirect
  end

  test "admin/users: player wird abgewiesen" do
    sign_in users(:player)
    get admin_users_path

    assert_response :redirect
  end

  test "admin/users: club_admin wird abgewiesen" do
    sign_in users(:club_admin)
    get admin_users_path

    assert_response :redirect
  end

  test "admin/users: system_admin kommt durch" do
    sign_in users(:system_admin)
    get admin_users_path

    assert_response :success
  end

  # --- Controller, die NICHT von Admin::ApplicationController erben ---
  #
  # Fuer diese reicht authenticate_user! nicht: LocationsController meldet jeden anonymen
  # Besucher per bypass_sign_in als scoreboard@carambus.de an, "angemeldet" ist also keine
  # Huerde. Der Scoreboard-User hat role player — genau dieser Fall wird hier geprueft.

  test "admin/player_duplicates: anonym wird abgewiesen" do
    get admin_player_duplicates_path

    assert_response :redirect
  end

  test "admin/player_duplicates: player (= Scoreboard-Rolle) wird abgewiesen" do
    sign_in users(:player)
    get admin_player_duplicates_path

    assert_response :redirect
  end

  test "admin/player_duplicates: merge ist fuer player gesperrt" do
    sign_in users(:player)
    post merge_admin_player_duplicate_path(players(:nbv_ullrich))

    assert_response :redirect
  end

  test "admin/incomplete_records: anonym wird abgewiesen" do
    get admin_incomplete_records_path

    assert_response :redirect
  end

  test "admin/incomplete_records: player wird abgewiesen" do
    sign_in users(:player)
    get admin_incomplete_records_path

    assert_response :redirect
  end
end
