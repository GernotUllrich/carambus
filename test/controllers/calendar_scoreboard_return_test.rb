# frozen_string_literal: true

require "test_helper"

# Der Rueckweg vom Kalender zum Scoreboard.
#
# Anlass: am Touchdisplay war der Kalender eine Sackgasse — zurueck ging es nur ueber das
# ausklappbare Menue, und das ist dort praktisch unauffindbar (Betreiber-Befund 2026-08-29).
#
# ⚠️ Der Knopf haengt NICHT an einem URL-Parameter, sondern an derselben Bedingung wie der
# Menue-Link in `application/_left_nav`: angemeldeter Scoreboard-User UND
# `Carambus.config.location_id`. Beide lesen `ApplicationHelper#scoreboard_return_path`.
class CalendarScoreboardReturnTest < ActionDispatch::IntegrationTest
  setup do
    @region = regions(:nbv)
    @monat = Date.current.strftime("%Y-%m")
    @original_config = Carambus.config
  end

  teardown do
    Carambus.config = @original_config
  end

  def mit_location_id(id)
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(location_id: id))
  end

  # `User.scoreboard` liefert in der Testumgebung bewusst nil (user.rb:85) — der Check laeuft
  # deshalb ueber die E-Mail, genau wie in `_left_nav`.
  def scoreboard_user!
    User.find_by(email: "scoreboard@carambus.de") ||
      User.create!(email: "scoreboard@carambus.de", password: "sb-test-passwort",
        first_name: "Score", last_name: "Board",
        accepted_terms_at: Time.current, accepted_privacy_at: Time.current,
        confirmed_at: Time.current)
  end

  test "am Scoreboard fuehrt ein Knopf aus dem Kalender zurueck" do
    mit_location_id(locations(:one).id)
    sign_in scoreboard_user!

    get calendar_url(month: @monat)
    assert_response :success
    assert_match(/Zurück zum Scoreboard/, response.body,
      "der Rueckweg muss auf dem Kalenderblatt selbst stehen")
    assert_select "a[href*=?]", "/locations/#{locations(:one).id}", {minimum: 1},
      "und auf die konfigurierte Location zeigen"

    # `sb_state`/`table_id` haengen an der Session und sind hier leer — der Link laesst sie
    # dann weg. Im Betrieb traegt er sie mit und kehrt dorthin zurueck, wo man war.
  end

  test "ein normaler Besucher sieht keinen Rueckweg" do
    mit_location_id(locations(:one).id)
    sign_in users(:admin)

    get calendar_url(month: @monat)
    assert_response :success
    refute_match(/Zurück zum Scoreboard/, response.body,
      "der Knopf gehoert auf den Kiosk, nicht auf die oeffentliche Seite")
  end

  test "ohne angemeldeten Benutzer kein Rueckweg" do
    mit_location_id(locations(:one).id)

    get calendar_url(month: @monat)
    assert_response :success
    refute_match(/Zurück zum Scoreboard/, response.body)
  end

  # Auf einem Server, der keine eigene Location fuehrt (z.B. die Authority), gibt es kein Ziel.
  test "ohne konfigurierte location_id kein Rueckweg" do
    mit_location_id(nil)
    sign_in scoreboard_user!

    get calendar_url(month: @monat)
    assert_response :success
    refute_match(/Zurück zum Scoreboard/, response.body)
  end

  # Der Knopf steht in der KLEBENDEN Filterleiste, nicht im Seitenkopf: der Strom laedt beim
  # Scrollen nach, ein Knopf im Kopf waere nach wenigen Kacheln unerreichbar.
  test "der Rueckweg steht in der klebenden Filterleiste" do
    mit_location_id(locations(:one).id)
    sign_in scoreboard_user!

    get calendar_url(month: @monat)
    assert_response :success
    assert_select "div.sticky a", {minimum: 1}
    assert_select "div.sticky" do
      assert_select "a", {text: /Zurück zum Scoreboard/, minimum: 1}
    end
  end
end
