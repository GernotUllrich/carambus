# frozen_string_literal: true

require "test_helper"

# Anmeldung im Spielerkontext (Plan 02.1-01).
#
# ⚠️ LITERALE PFADE, keine Rails-URL-Helper: `default_url_options` haengt `locale` an JEDE
# erzeugte URL, sobald die Sprache nicht Deutsch ist (application_controller.rb). Tests, die
# URLs mit Helpern bauen, pruefen bei Sprachthemen deshalb den Parameter statt der Session.
# Real passiert ist genau das in Quick-Task (2).
class PlayerSessionsTest < ActionDispatch::IntegrationTest
  setup do
    # ⚠️ Die Testkonfiguration MUSS beides stellen:
    #   `carambus_api_url` — sonst gilt der Lauf als Authority und jedes Schreiben auf
    #     `PlayerLocal` wird abgewiesen (nur_auf_lokalem_server).
    #   `club_id` — `PlayerLocal.selectable_players` filtert auf die Mitglieder des
    #     konfigurierten Clubs; der Standardwert 357 passt nicht zu den Fixtures
    #     (die haengen an Club 50000001), die Auswahl waere sonst LEER und jede Anmeldung
    #     schluege mit der einheitlichen Fehlermeldung fehl.
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(
      @original_config.to_h.merge(carambus_api_url: "http://localhost:3131", club_id: 50_000_001)
    )
    @player = players(:nbv_ullrich)
    @kontakt = PlayerLocal.create!(player: @player, pin: "4711")
  end

  teardown do
    Carambus.config = @original_config
  end

  def anmelden(pin: "4711", player_id: nil)
    post "/player_session", params: {player_id: player_id || @player.id, pin: pin}
  end

  test "die Anmeldeseite ist ohne Benutzeranmeldung erreichbar" do
    get "/player_session/new"

    assert_response :success
    assert_not_includes response.body, "We're sorry, but something went wrong"
  end

  test "richtiger PIN meldet an" do
    anmelden

    # Seit Plan 02.1-02 landet die Anmeldung direkt im persoenlichen Bereich; der
    # Platzhalter-Landeplatz aus 02.1-01 ist dadurch ersetzt.
    assert_redirected_to "/player_profile"
    follow_redirect!
    assert_response :success
    assert_includes response.body, @player.fl_name
  end

  test "falscher PIN meldet nicht an" do
    anmelden(pin: "0815")

    assert_response :unprocessable_entity
    get "/player_session"
    assert_redirected_to "/player_session/new"
  end

  test "unbekannter Spieler bekommt DIESELBE Meldung wie ein falscher PIN" do
    anmelden(pin: "0815")
    bei_falschem_pin = response.body[/Name oder PIN[^<]*/]

    ohne_kontakt = players(:nbv_andresen)
    anmelden(player_id: ohne_kontakt.id)
    bei_unbekanntem = response.body[/Name oder PIN[^<]*/]

    assert_equal bei_falschem_pin, bei_unbekanntem,
      "getrennte Meldungen verrieten, wer ueberhaupt einen PIN hat"
  end

  test "nach fuenf Fehlversuchen nennt die Meldung die Wartezeit" do
    5.times { anmelden(pin: "0815") }

    assert_response :unprocessable_entity
    assert_match(/Fehlversuche/, response.body)
    assert @kontakt.reload.pin_locked?
  end

  test "abmelden beendet die Anmeldung sofort" do
    anmelden
    delete "/player_session"

    assert_redirected_to "/player_session/new"
    get "/player_session"
    assert_redirected_to "/player_session/new"
  end

  test "Untaetigkeit beendet die Anmeldung" do
    anmelden
    get "/player_profile"
    assert_response :success

    travel_to(11.minutes.from_now) do
      get "/player_profile"
      assert_redirected_to "/player_session/new", "nach Ablauf der Spanne muss abgemeldet sein"
    end
  end

  test "Bedienung innerhalb der Spanne haelt die Anmeldung am Leben" do
    anmelden

    # Zwei Mal je 6 Minuten: zusammen mehr als die Spanne, aber nie eine Luecke groesser als 10.
    travel_to(6.minutes.from_now) do
      get "/player_profile"
      assert_response :success
    end
    travel_to(12.minutes.from_now) do
      get "/player_profile"
      assert_response :success, "die Anmeldung haette am Leben bleiben muessen"
    end
  end

  test "die Sprachwahl ueberlebt die Anmeldung" do
    get "/player_session/new?locale=en"
    anmelden

    get "/player_profile"
    assert_response :success
    # ⚠️ Beweist, dass `sign_in_player` kein `reset_session` macht — das risse session[:locale] mit.
    # Der Text stammt aus dem persoenlichen Bereich (player_profiles.show.title, Plan 02.1-02).
    assert_includes response.body, "My area"
  end

  test "ohne Anmeldung bleibt current_player_local leer" do
    get "/player_session"

    assert_redirected_to "/player_session/new"
  end
end
