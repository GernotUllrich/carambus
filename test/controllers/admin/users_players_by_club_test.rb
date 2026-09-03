# frozen_string_literal: true

require "test_helper"

# Phase 37-01: Admin-Endpoint players_by_club (Player-Cascade im User-Formular).
# Sicherheit (system_admin-gated, da authenticate_admin No-Op) + JSON-Shape.
class Admin::UsersPlayersByClubTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # confirmed_at: User ist :confirmable → ohne Bestätigung endet sign_in im 401/302
    @admin = User.create!(email: "pbc_admin@test.de", password: "password123", role: :system_admin,
      confirmed_at: Time.zone.now)
    @plain = User.create!(email: "pbc_plain@test.de", password: "password123", role: :player,
      confirmed_at: Time.zone.now)
  end

  test "nicht-system_admin → forbidden (kein Spieler-Leak)" do
    sign_in @plain
    get players_by_club_admin_users_path(club_id: 1), as: :json
    assert_response :forbidden
  end

  test "blank club_id → leeres Array" do
    sign_in @admin
    get players_by_club_admin_users_path, as: :json
    assert_response :success
    assert_equal [], JSON.parse(@response.body)
  end

  test "system_admin: Spieler eines Clubs der aktuellen Saison als JSON {id,label}" do
    season = Season.current_season
    sp = SeasonParticipation.where(season_id: season&.id).where.not(player_id: nil, club_id: nil).first
    skip "keine SeasonParticipation in current season (#{season&.name}) in Test-DB" if sp.nil?

    sign_in @admin
    get players_by_club_admin_users_path(club_id: sp.club_id), as: :json
    assert_response :success
    body = JSON.parse(@response.body)
    assert_kind_of Array, body
    assert body.any? { |h| h["id"] == sp.player_id }, "erwarteter Spieler nicht in der Liste"
    assert(body.all? { |h| h.key?("id") && h.key?("label") })
  end

  # Render-Test: Edit-Formular rendert mit Disziplin-Baum + region-Locations + Player-Cascade
  # ohne 500 (exerziert _form_fields + _discipline_node + Admin::UserFormHelper + Route-Helper).
  test "Admin-User-Edit-Formular rendert (kein 500) mit neuen Persona-Setup-Feldern" do
    sign_in @admin
    target = User.create!(email: "pbc_target@test.de", password: "password123", role: :player)
    get edit_admin_user_path(target)
    assert_response :success
    assert_includes @response.body, "Sportwart-Disziplinen"
    assert_includes @response.body, "Sportwart-Spielorte"
    assert_includes @response.body, "data-controller=\"location-picker\""
    # Der Player-Picker hat ZWEI Zweige (_form_fields.html.erb ~156/183): `dependent-select`
    # auf einem Server MIT Region-Kontext (Verein → Spieler) und `region-player-picker`
    # ohne Kontext (Region → Verein → Spieler). Die Testumgebung setzt keinen Kontext,
    # also gilt hier der dreistufige Picker; der Gegenfall folgt unten.
    assert_includes @response.body, "data-controller=\"region-player-picker\""
  end

  # 2026-09-04: Der Region-Kontext-Zweig war ungetestet — beide Pfade sind produktiv
  # (Authority ohne Kontext, Region-/Location-Server mit).
  test "Admin-User-Edit-Formular nutzt MIT Region-Kontext den Verein-Spieler-Picker" do
    sign_in @admin
    target = User.create!(email: "pbc_target_ctx@test.de", password: "password123", role: :player)

    # Das Config-Objekt AUSTAUSCHEN, nicht mutieren: Carambus.config ist in @config
    # memoisiert (config/application.rb:11) und prozessweit geteilt — eine Mutation
    # schlaegt in andere Tests durch (beobachtet 2026-09-04).
    original_config = Carambus.config
    begin
      Carambus.config = OpenStruct.new(original_config.to_h.merge(context: regions(:nbv).shortname))
      get edit_admin_user_path(target)
      assert_response :success
      assert_includes @response.body, "data-controller=\"dependent-select\"",
        "Mit Region-Kontext genuegt die Stufe Verein → Spieler"
      assert_not_includes @response.body, "data-controller=\"region-player-picker\""
    ensure
      Carambus.config = original_config
    end
  end
end
