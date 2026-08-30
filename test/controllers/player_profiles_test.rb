# frozen_string_literal: true

require "test_helper"

# Persoenlicher Bereich eines angemeldeten Mitglieds (Plan 02.1-02).
#
# ⚠️ LITERALE PFADE, keine Rails-URL-Helper: `default_url_options` haengt `locale` an jede
# erzeugte URL, sobald die Sprache nicht Deutsch ist (Falle aus Quick-Task 2).
class PlayerProfilesTest < ActionDispatch::IntegrationTest
  setup do
    # ⚠️ Beides noetig: `carambus_api_url` (sonst gilt der Lauf als Authority und `PlayerLocal`
    # verweigert jedes Schreiben) und `club_id` (sonst ist `selectable_players` leer und die
    # Anmeldung schlaegt fehl — die Fixtures haengen an Club 50000001, Default ist 357).
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(
      @original_config.to_h.merge(carambus_api_url: "http://localhost:3131", club_id: 50_000_001)
    )
    @player = players(:nbv_ullrich)
    @kontakt = PlayerLocal.create!(player: @player, pin: "4711")
  end

  teardown { Carambus.config = @original_config }

  def anmelden(pin: "4711", player: nil)
    post "/player_session", params: {player_id: (player || @player).id, pin: pin}
  end

  # --------------------------------------------------------------------- Zugang

  test "ohne Anmeldung fuehrt der Bereich zur Anmeldeseite" do
    get "/player_profile"
    assert_redirected_to "/player_session/new"

    patch "/player_profile", params: {player_local: {email: "x@y.de"}}
    assert_redirected_to "/player_session/new"

    patch "/player_profile/pin", params: {current_pin: "4711", new_pin: "1379"}
    assert_redirected_to "/player_session/new"
  end

  test "die Anmeldung landet direkt im persoenlichen Bereich" do
    anmelden
    assert_redirected_to "/player_profile"
    follow_redirect!
    assert_response :success
    assert_includes response.body, @player.fl_name
  end

  # --------------------------------------------------------------------- AC-1 Adresse

  test "die eigene Adresse laesst sich eintragen" do
    anmelden
    patch "/player_profile", params: {player_local: {email: "Max@Example.COM"}}

    assert_redirected_to "/player_profile"
    assert_equal "max@example.com", @kontakt.reload.email, "die Normalisierung muss greifen"
  end

  test "eine unsinnige Adresse wird mit sichtbarer Meldung abgewiesen" do
    anmelden
    patch "/player_profile", params: {player_local: {email: "kein-at-zeichen"}}

    assert_response :unprocessable_entity
    assert_nil @kontakt.reload.email
    assert_match(/E-Mail|Email/i, response.body)
  end

  # --------------------------------------------------------------------- AC-2 Einwilligung

  test "Einwilligung erteilen macht anschreibbar" do
    anmelden
    patch "/player_profile", params: {player_local: {email: "max@example.com"}}
    patch "/player_profile", params: {consent: "grant"}

    assert @kontakt.reload.contactable?
    assert_includes PlayerLocal.contactable, @kontakt
  end

  test "Widerruf nimmt die Anschreibbarkeit, behaelt aber die Adresse" do
    anmelden
    patch "/player_profile", params: {player_local: {email: "max@example.com"}}
    patch "/player_profile", params: {consent: "grant"}
    patch "/player_profile", params: {consent: "revoke"}

    @kontakt.reload
    refute @kontakt.contactable?
    assert @kontakt.revoked?
    assert_equal "max@example.com", @kontakt.email, "der Widerruf darf die Adresse NICHT loeschen"
  end

  test "erneutes Erteilen nach Widerruf macht wieder anschreibbar" do
    anmelden
    patch "/player_profile", params: {player_local: {email: "max@example.com"}}
    patch "/player_profile", params: {consent: "grant"}
    patch "/player_profile", params: {consent: "revoke"}
    patch "/player_profile", params: {consent: "grant"}

    @kontakt.reload
    assert @kontakt.contactable?, "grant_consent! muss consent_revoked_at zuruecksetzen"
    assert_nil @kontakt.consent_revoked_at
  end

  test "eine Einwilligung allein loescht die Adresse nicht" do
    anmelden
    patch "/player_profile", params: {player_local: {email: "max@example.com"}}
    # Das Einwilligungs-Formular schickt KEIN email-Feld mit.
    patch "/player_profile", params: {consent: "grant"}

    assert_equal "max@example.com", @kontakt.reload.email
  end

  # --------------------------------------------------------------------- AC-3 PIN

  test "der PIN laesst sich mit korrektem alten PIN aendern" do
    anmelden
    patch "/player_profile/pin", params: {current_pin: "4711", new_pin: "1379"}
    assert_redirected_to "/player_profile"

    delete "/player_session"
    anmelden(pin: "4711")
    assert_response :unprocessable_entity, "der alte PIN darf nicht mehr gelten"

    anmelden(pin: "1379")
    assert_redirected_to "/player_profile", "der neue PIN muss gelten"
  end

  test "falscher alter PIN aendert nichts" do
    anmelden
    vorher = @kontakt.pin_digest

    patch "/player_profile/pin", params: {current_pin: "0815", new_pin: "1379"}

    assert_response :unprocessable_entity
    assert_equal vorher, @kontakt.reload.pin_digest
  end

  test "ein trivialer neuer PIN wird abgewiesen, der alte bleibt gueltig" do
    anmelden
    vorher = @kontakt.pin_digest

    patch "/player_profile/pin", params: {current_pin: "4711", new_pin: "1234"}

    assert_response :unprocessable_entity
    assert_equal vorher, @kontakt.reload.pin_digest
    assert_includes response.body, "zu leicht zu erraten"
  end

  test "ein leerer neuer PIN meldet einen Fehler statt Erfolg" do
    anmelden
    vorher = @kontakt.pin_digest

    patch "/player_profile/pin", params: {current_pin: "4711", new_pin: ""}

    assert_response :unprocessable_entity
    assert_equal vorher, @kontakt.reload.pin_digest
    refute_match(/geändert|changed/i, response.body)
  end

  test "die Anmeldung ueberlebt die PIN-Aenderung" do
    anmelden
    patch "/player_profile/pin", params: {current_pin: "4711", new_pin: "1379"}

    get "/player_profile"
    assert_response :success, "das Mitglied steht vor dem Display und arbeitet weiter"
  end

  # --------------------------------------------------------------------- AC-4 Fremdzugriff

  test "eine mitgeschickte fremde id bleibt folgenlos" do
    fremd = PlayerLocal.create!(player: players(:nbv_andresen), email: "fremd@example.com")
    anmelden

    patch "/player_profile", params: {id: fremd.id, player_local: {id: fremd.id, email: "gekapert@example.com"}}

    assert_equal "fremd@example.com", fremd.reload.email, "fremde Daten duerfen sich nie aendern"
    assert_equal "gekapert@example.com", @kontakt.reload.email, "die eigene schon"
  end
  # --------------------------------------------------------------- AC-5 Einstiegspunkte

  test "die Welcome-Page traegt den Knopf in den persoenlichen Bereich" do
    quelle = File.read(Rails.root.join("app/views/locations/scoreboard_welcome.html.erb"))

    assert_match(/id: "player_area"/, quelle, "kein Knopf mit der id player_area")
    assert_match(/player_profile_path/, quelle, "der Knopf zeigt nicht in den persoenlichen Bereich")
  end

  # ⚠️ DER WICHTIGSTE TEST DIESES PLANS.
  #
  # Die Welcome-Page steuert die Knoepfe per Tastatur ueber die Kette `tabbed_elements`:
  #   document.getElementById(tabbed_elements[current]).focus()
  #
  # Steht dort ein Eintrag OHNE zugehoeriges Element, wirft `getElementById(...).focus()` und
  # die GESAMTE Tastensteuerung bricht — real passiert mit dem Sprach-Link (Plan 40-02), die
  # Datei dokumentiert es selbst. Fehlt umgekehrt ein Element in der Kette, wird es nie
  # angesprungen. Dieser Test haelt beide Richtungen fest.
  test "die Navigationskette der Welcome-Page ist geschlossen und vollstaendig" do
    quelle = File.read(Rails.root.join("app/views/locations/scoreboard_welcome.html.erb"))

    kette = quelle[/var tabbed_elements = \{(.*?)\}/m, 1]
    refute_nil kette, "tabbed_elements nicht gefunden — wurde die Tastensteuerung umgebaut?"

    paare = kette.scan(/"([a-z_]+)":\s*"([a-z_]+)"/)
    schluessel = paare.map(&:first)
    ziele = paare.map(&:last)

    # Jede id in der Kette muss auf der Seite auch wirklich als Element existieren.
    (schluessel + ziele).uniq.each do |id|
      assert_match(/id: "#{id}"/, quelle,
        "tabbed_elements nennt '#{id}', aber die Seite hat kein Element mit dieser id — " \
        "getElementById(...).focus() wirft und die Tastensteuerung bricht")
    end

    # Der Ring muss geschlossen sein: jedes Ziel ist selbst wieder ein Ausgangspunkt.
    ziele.each do |ziel|
      assert_includes schluessel, ziel, "'#{ziel}' ist Sprungziel, aber kein Ausgangspunkt — Sackgasse"
    end

    assert_includes schluessel, "player_area", "der neue Knopf wird nie angesprungen"
  end

  test "die Seitenleiste fuehrt zustandsabhaengig ins Profil oder zur Anmeldung" do
    quelle = File.read(Rails.root.join("app/views/application/_left_nav.html.erb"))

    assert_match(/player_signed_in\?/, quelle)
    assert_match(/player_profile_path/, quelle)
    assert_match(%r{/player_session/new}, quelle)
    # ⚠️ Der PIN-Login ist KEIN Devise-Scope — `user_signed_in?` waere hier falsch.
    refute_match(/user_signed_in\?.*player_profile/, quelle)
  end

  # ⚠️ Betreiber-Korrektur 2026-08-30: Die Beschriftung des Menueeintrags ist FEST und wechselt
  # nicht auf „Anmelden". Grund: die obere Navigationsleiste traegt bereits ein „Anmelden"
  # (_navbar.html.erb → new_user_session_path, Devise). Zweimal dasselbe Wort mit zwei
  # Bedeutungen auf einer Seite. Dieser Test haelt die Korrektur fest.
  test "der Menueeintrag traegt eine feste, unterscheidbare Beschriftung" do
    quelle = File.read(Rails.root.join("app/views/application/_left_nav.html.erb"))

    assert_match(/t\("player_profiles\.nav\.my_area"\)/, quelle)
    refute_match(/player_profiles\.nav\.sign_in/, quelle,
      "die zustandsabhaengige Beschriftung ist bewusst entfallen")

    %i[de en].each do |sprache|
      beschriftung = I18n.t("player_profiles.nav.my_area", locale: sprache)
      navbar_anmelden = I18n.t("application.navbar.log_in", locale: sprache)
      refute_equal navbar_anmelden, beschriftung,
        "#{sprache}: der Menueeintrag heisst genauso wie die Benutzeranmeldung in der Navbar"
    end
  end
end
