# frozen_string_literal: true

require "test_helper"

# Render-Gate fuer die PIN-Erstvergabe unter /admin/player_locals (Plan 02.1-01).
#
# ⚠️ Warum es diesen Test gibt: In diesem Projekt sind schon einmal Admin-Views "repariert"
# worden, ohne dass eine einzige davon tatsaechlich gerendert wurde — ERB-Compile und
# Runner-Smoke-Checks hatten den Fehler nicht gefangen. `Field::Password` ist genau so ein
# Fall: die Klasse laedt erst mit dem Dashboard, ein Tippfehler faellt sonst erst im Browser auf.
class AdminPlayerLocalsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # `PlayerLocal` schreibt nur auf einem lokalen Server.
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))
    @player = players(:nbv_ullrich)
    # `selectable_players` filtert auf den konfigurierten Club; die Fixtures haengen an 50000001.
    Carambus.config = OpenStruct.new(Carambus.config.to_h.merge(club_id: 50_000_001))
    # ⚠️ `Admin::ApplicationController#authenticate_admin` laesst ausschliesslich
    # `system_admin?` durch — ohne Anmeldung antwortet jede Admin-Route mit 302.
    sign_in users(:system_admin)
  end

  teardown do
    Carambus.config = @original_config
  end

  test "Index rendert" do
    PlayerLocal.create!(player: @player, email: "max@example.com")

    get "/admin/player_locals"

    assert_response :success
    assert_not_includes response.body, "We're sorry, but something went wrong"
  end

  test "das Anlage-Formular rendert und traegt ein Passwortfeld fuer den PIN" do
    get "/admin/player_locals/new"

    assert_response :success
    assert_not_includes response.body, "We're sorry, but something went wrong"
    # Administrate rendert `Field::Password` als <input type="password">.
    assert_match(/type="password"[^>]*name="player_local\[pin\]"|name="player_local\[pin\]"[^>]*type="password"/,
      response.body, "kein Passwortfeld fuer den PIN im Formular")
  end

  test "Show rendert und zeigt den PIN NICHT" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")

    get "/admin/player_locals/#{k.id}"

    assert_response :success
    assert_not_includes response.body, "4711"
    assert_not_includes response.body, k.pin_digest
  end

  test "Index zeigt weder PIN noch Hash" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")

    get "/admin/player_locals"

    assert_not_includes response.body, "4711"
    assert_not_includes response.body, k.pin_digest
  end
  test "das Bearbeiten-Formular spielt den PIN nicht zurueck" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")

    get "/admin/player_locals/#{k.id}/edit"

    assert_response :success
    assert_not_includes response.body, "4711"
    assert_not_includes response.body, k.pin_digest
    # Das Feld ist da, aber leer — sonst waere der PIN beim naechsten Speichern weg.
    assert_match(/name="player_local\[pin\]"/, response.body)
    assert_no_match(/name="player_local\[pin\]"[^>]*value="."/, response.body)
  end

  test "Adresse speichern mit leerem PIN-Feld behaelt den PIN" do
    k = PlayerLocal.create!(player: @player, email: "max@example.com", pin: "4711")
    vorher = k.pin_digest

    patch "/admin/player_locals/#{k.id}",
      params: {player_local: {email: "neu@example.com", pin: ""}}

    assert_equal "neu@example.com", k.reload.email
    assert_equal vorher, k.pin_digest, "das leere Formularfeld hat den PIN geloescht"
  end
  # Betreiber-Abnahme 2026-08-30: nach dem Speichern zurueck zur Liste, nicht auf die
  # Detailseite. Administrate leitet von Haus aus auf SHOW — diese Tests halten die
  # Abweichung fest, damit sie ein Gem-Update nicht still zurueckdreht.
  test "Anlegen leitet auf die Liste, nicht auf die Detailseite" do
    post "/admin/player_locals",
      params: {player_local: {player_id: @player.id, email: "a@b.de", pin: "4711"}}

    assert_redirected_to "/admin/player_locals"
    assert_equal 1, PlayerLocal.count
  end

  test "Bearbeiten leitet ebenfalls auf die Liste" do
    k = PlayerLocal.create!(player: @player, email: "a@b.de")

    patch "/admin/player_locals/#{k.id}", params: {player_local: {email: "neu@b.de"}}

    assert_redirected_to "/admin/player_locals"
    assert_equal "neu@b.de", k.reload.email
  end

  test "ein abgelehnter PIN nennt den Grund sichtbar im Formular" do
    post "/admin/player_locals",
      params: {player_local: {player_id: @player.id, email: "a@b.de", pin: "1234"}}

    assert_response :unprocessable_entity
    assert_includes response.body, "zu leicht zu erraten"
    assert_equal 0, PlayerLocal.count, "ein trivialer PIN darf nicht angelegt werden"
  end

  test "ein zu kurzer PIN nennt den Grund sichtbar im Formular" do
    post "/admin/player_locals",
      params: {player_local: {player_id: @player.id, email: "a@b.de", pin: "12"}}

    assert_response :unprocessable_entity
    assert_includes response.body, "4 bis 8 Ziffern"
  end
end
