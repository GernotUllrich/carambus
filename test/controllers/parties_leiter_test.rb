# frozen_string_literal: true

require "test_helper"

# Plan 20-02: Begegnungsleiter einsetzen/entfernen und PartyMonitor starten (PartiesController).
#   assign_leiter/remove_leiter -> PartyPolicy#assign_leiter? (Sportwart im Wirkbereich, Admin)
#   party_monitor (Start)       -> PartyPolicy#operate?       (dazu der Leiter)
# Vorher: Start nur admin_only_check, einen Begegnungsleiter gab es nicht.
class PartiesLeiterTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test" # local_server?
    @party = parties(:party_one)
    @location = locations(:one)
    @party.update_columns(location_id: @location.id)
    @club_admin = users(:club_admin)
    @kandidat = users(:two)
    @player = users(:one)

    @sportwart = users(:regular)
    @sportwart.update!(persona_grants: ["sportwart"])
    @sportwart.sportwart_locations << @location
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  def leiter_rows
    UserParty.where(party: @party, user: @kandidat, role: "party_leiter")
  end

  test "der Sportwart im Wirkbereich setzt einen Leiter ein und entfernt ihn — granted_by wird gesetzt" do
    sign_in @sportwart
    assert_difference -> { leiter_rows.count }, 1 do
      post assign_leiter_party_path(@party), params: {user_id: @kandidat.id}
    end
    assert_equal @sportwart.id, leiter_rows.first.granted_by_user_id
    assert_difference -> { leiter_rows.count }, -1 do
      delete remove_leiter_party_path(@party, user_id: @kandidat.id)
    end
  end

  test "anonym, als Spieler und als Leiter selbst: kein Einsetzen, kein Entfernen" do
    UserParty.create!(user: @kandidat, party: @party, granted_by: @club_admin)
    [nil, @player, @kandidat].each do |user|
      reset!
      sign_in user if user
      assert_no_difference -> { UserParty.count } do
        post assign_leiter_party_path(@party), params: {user_id: @player.id}
        delete remove_leiter_party_path(@party, user_id: @kandidat.id)
      end
      assert_redirected_to party_path(@party)
      assert_not_nil flash[:alert]
    end
  end

  test "ein unbestaetigtes Konto kann nicht eingesetzt werden" do
    @kandidat.update_columns(confirmed_at: nil)
    sign_in @club_admin
    assert_no_difference -> { UserParty.count } do
      post assign_leiter_party_path(@party), params: {user_id: @kandidat.id}
    end
  end

  test "PartyMonitor starten: Leiter und Sportwart ja, anonym und Spieler nein" do
    UserParty.create!(user: @kandidat, party: @party, granted_by: @club_admin)
    [[nil, false], [@player, false], [@kandidat, true], [@sportwart, true]].each do |user, allowed|
      reset!
      PartyMonitor.where(party_id: @party.id).destroy_all
      sign_in user if user
      get party_monitor_party_path(@party)
      assert_equal allowed, PartyMonitor.exists?(party_id: @party.id),
        "Start als #{user&.email || "anonym"}: erwartet #{allowed ? "gestartet" : "abgewiesen"}"
    end
  end

  test "Begegnungsseite: Leiter-Auswahl und Start-Knopf nur mit Recht" do
    get party_path(@party)
    assert_response :success
    assert_no_match assign_leiter_party_path(@party), response.body
    assert_no_match party_monitor_party_path(@party), response.body

    sign_in @sportwart
    get party_path(@party)
    assert_match assign_leiter_party_path(@party), response.body
    assert_match party_monitor_party_path(@party), response.body
  end
end
