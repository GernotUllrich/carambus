# frozen_string_literal: true

require "test_helper"

# PIN per Einmal-Link setzen (Plan 02.2-01).
#
# ⚠️ LITERALE PFADE, keine URL-Helper: `default_url_options` haengt bei nicht-deutscher Sprache
# `locale` an jede erzeugte URL (Falle aus Quick-Task 2).
class PinSetupsTest < ActionDispatch::IntegrationTest
  setup do
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(
      @original_config.to_h.merge(carambus_api_url: "http://localhost:3131", club_id: 50_000_001)
    )
    @player = players(:nbv_ullrich)
    @kontakt = PlayerLocal.create!(player: @player, email: "max@example.com",
      consent_given_at: Time.current)
  end

  teardown { Carambus.config = @original_config }

  def token
    @kontakt.generate_token_for(:pin_setup)
  end

  # ------------------------------------------------------------------ Der glueckliche Weg

  test "der Link fuehrt auf die Seite und nennt das Mitglied" do
    get "/pin_setup/#{token}"

    assert_response :success
    assert_includes response.body, @player.fl_name
  end

  test "das Mitglied setzt seinen PIN und ist danach angemeldet" do
    patch "/pin_setup/#{token}", params: {pin: "4711", pin_confirmation: "4711"}

    assert_redirected_to "/player_profile"
    assert @kontakt.reload.pin_set?

    # Der PIN gilt auch reguler an der Anmeldung.
    delete "/player_session"
    post "/player_session", params: {player_id: @player.id, pin: "4711"}
    assert_redirected_to "/player_profile"
  end

  # ------------------------------------------------------------------ AC-4 Einmaligkeit

  test "nach dem Setzen ist der Link TOT" do
    alter_token = token
    patch "/pin_setup/#{alter_token}", params: {pin: "4711", pin_confirmation: "4711"}
    assert_redirected_to "/player_profile"

    get "/pin_setup/#{alter_token}"

    assert_response :not_found
    assert_includes response.body, I18n.t("pin_setups.invalid.title")
  end

  test "ein abgelaufener Token gilt nicht" do
    t = token

    travel_to(PlayerLocal::PIN_SETUP_TOKEN_VALIDITY.from_now + 1.hour) do
      get "/pin_setup/#{t}"
      assert_response :not_found
    end
  end

  # ------------------------------------------------------------------ AC-5 keine Preisgabe

  # ⚠️ Der wichtigste Test dieses Plans: die Seite haengt ohne Anmeldung am offenen Netz.
  test "ein ungueltiger Link verraet NICHTS" do
    %w[erfunden abcdefghijklmnop 12345].each do |mist|
      get "/pin_setup/#{mist}"

      assert_response :not_found
      refute_includes response.body, @player.fl_name, "der Name darf nicht erscheinen"
      refute_includes response.body, "max@example.com", "die Adresse erst recht nicht"
      assert_includes response.body, I18n.t("pin_setups.invalid.title")
    end
  end

  test "abgelaufen, verbraucht und erfunden zeigen DIESELBE Meldung" do
    verbraucht = token
    patch "/pin_setup/#{verbraucht}", params: {pin: "4711", pin_confirmation: "4711"}

    get "/pin_setup/#{verbraucht}"
    a = response.body[/#{Regexp.escape(I18n.t("pin_setups.invalid.body"))}/]
    get "/pin_setup/voellig-erfunden"
    b = response.body[/#{Regexp.escape(I18n.t("pin_setups.invalid.body"))}/]

    assert_equal a, b, "unterschiedliche Meldungen waeren eine Auskunft"
    refute_nil a
  end

  # ------------------------------------------------------------------ Eingabepruefung

  test "die Wiederholung muss stimmen" do
    patch "/pin_setup/#{token}", params: {pin: "4711", pin_confirmation: "4712"}

    assert_response :unprocessable_entity
    refute @kontakt.reload.pin_set?, "bei Tippfehler darf kein PIN gesetzt werden"
    assert_includes response.body, I18n.t("pin_setups.update.mismatch")
  end

  test "ein trivialer PIN wird abgewiesen, der Link bleibt gueltig" do
    t = token
    patch "/pin_setup/#{t}", params: {pin: "1234", pin_confirmation: "1234"}

    assert_response :unprocessable_entity
    refute @kontakt.reload.pin_set?

    # ⚠️ Wichtig: der Digest hat sich nicht geaendert, also gilt der Link weiter —
    # sonst waere das Mitglied nach einem Tippfehler ausgesperrt.
    get "/pin_setup/#{t}"
    assert_response :success
  end

  test "ein leerer PIN meldet einen Fehler" do
    patch "/pin_setup/#{token}", params: {pin: "", pin_confirmation: ""}

    assert_response :unprocessable_entity
    refute @kontakt.reload.pin_set?
  end
end
