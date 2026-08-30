# frozen_string_literal: true

require "test_helper"

# Pflege der lokalen Kontaktdaten im Admin-Dashboard (Betreiber-Vorgabe 2026-08-30:
# „über eine admin Seite des sysadmin").
#
# ⚠️ Es sind personenbezogene Daten. Der Zugriffsschutz ist deshalb der wichtigste Test hier:
# `Admin::ApplicationController#authenticate_admin` lässt ausschließlich `system_admin?` durch.
class Admin::PlayerLocalsTest < ActionDispatch::IntegrationTest
  setup do
    # `PlayerLocal` speichert nur auf einem lokalen Server — ohne diese Config gilt der Lauf
    # als Authority und jedes Anlegen wird abgewiesen.
    @original_config = Carambus.config
    @club = clubs(:bcw)
    Carambus.config = OpenStruct.new(
      @original_config.to_h.merge(carambus_api_url: "http://localhost:3131", club_id: @club.id)
    )
    @player = players(:nbv_ullrich)
  end

  teardown do
    Carambus.config = @original_config
  end

  def system_admin!
    users(:system_admin)
  end

  # --- Zugriffsschutz ----------------------------------------------------------------------

  test "ohne Anmeldung kein Zugriff" do
    get admin_player_locals_path
    assert_response :redirect
    refute_equal 200, response.status
  end

  test "ein gewoehnlicher Benutzer kommt nicht hinein" do
    sign_in users(:admin)

    get admin_player_locals_path
    assert_redirected_to root_path
  end

  # ⚠️ Bewusst auch der Club-Admin: `admin?` umfasst ihn, `system_admin?` nicht. Kontaktdaten
  # des ganzen Clubs sind nichts, was ein Vereins-Admin nebenbei einsehen soll.
  test "auch ein Club-Admin kommt nicht hinein" do
    sign_in users(:club_admin)

    get admin_player_locals_path
    assert_redirected_to root_path
  end

  test "der System-Admin sieht die Liste" do
    sign_in system_admin!

    get admin_player_locals_path
    assert_response :success
  end

  # --- Pflege ------------------------------------------------------------------------------

  test "der System-Admin legt eine Adresse an" do
    sign_in system_admin!

    assert_difference("PlayerLocal.count", 1) do
      post admin_player_locals_path, params: {
        player_local: {player_id: @player.id, email: "mitglied@example.com",
                       consent_given_at: Time.current}
      }
    end
    assert_equal "mitglied@example.com", PlayerLocal.last.email
  end

  test "die Liste zeigt Adresse und Einwilligung" do
    PlayerLocal.create!(player: @player, email: "sichtbar@example.com",
      consent_given_at: 1.day.ago)
    sign_in system_admin!

    get admin_player_locals_path
    assert_response :success
    assert_match(/sichtbar@example.com/, response.body)
  end

  # --- Die Auswahl im Formular -------------------------------------------------------------

  # ⚠️ Ohne Einschränkung rendert Administrate ein <select> mit ALLEN 47.716 Spielern.
  test "das Formular bietet nur Clubmitglieder zur Auswahl" do
    sign_in system_admin!

    get new_admin_player_local_path
    assert_response :success

    auswaehlbar = PlayerLocal.selectable_players
    assert_operator auswaehlbar.count, :<, Player.count,
      "die Auswahl muss enger sein als der gesamte Spielerbestand"
    assert_includes auswaehlbar, @player
  end

  # Gäste sind flüchtig — `Player.remove_inactive_guests` löscht sie samt Adresse.
  test "Gaeste stehen nicht zur Auswahl" do
    gast = players(:nbv_hansen)
    SeasonParticipation.where(player_id: gast.id, club_id: @club.id).destroy_all
    SeasonParticipation.create!(id: 50_900_001, player: gast, club: @club,
      season: Season.current_season, status: "guest")

    refute_includes PlayerLocal.selectable_players, gast
  end

  test "ohne konfigurierten Club bleibt die Auswahl leer" do
    Carambus.config = OpenStruct.new(
      @original_config.to_h.merge(carambus_api_url: "http://localhost:3131", club_id: nil)
    )

    assert_empty PlayerLocal.selectable_players
  end
end
