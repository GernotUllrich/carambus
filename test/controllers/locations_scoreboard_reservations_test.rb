# frozen_string_literal: true

require "test_helper"

# Die Reservierungsseite am Scoreboard (LocationsController#show, sb_state=reservations).
#
# 2026-09-17 (Betreiber): Das Formular "Neue Reservierung" ist von dieser Seite entfernt. Am
# Scoreboard ist kein Benutzer bekannt — ein Kalendereintrag ohne Urheber ist niemandem
# zuzuordnen. Die Seite zeigt nur noch die Belegung; eingetragen wird im Google Kalender.
# Ein spaeterer Wiedereinbau ist fuer den persoenlichen Bereich (PIN-Anmeldung) vorgesehen,
# wo die E-Mail-Adresse bekannt ist.
class LocationsScoreboardReservationsTest < ActionDispatch::IntegrationTest
  setup do
    # ⚠️ PFLICHT: der Scoreboard-Zweig haengt an `if local_server?`
    # (locations_controller.rb), dessen else-Zweig ein STILLER redirect_back ist.
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))
    @location = locations(:one)
  end

  teardown do
    Carambus.config = @original_config
  end

  def get_reservations_page
    get location_path(@location, sb_state: "reservations")
  end

  test "die Seite rendert und zeigt die Belegung" do
    get_reservations_page
    assert_response :success
    assert_match(/#{Regexp.escape(@location.name)}/, response.body)
  end

  test "kein Formular und kein Knopf fuer eine neue Reservierung" do
    get_reservations_page

    assert_no_match(/create_event/, response.body,
      "Die Seite bietet weiterhin das Formular zum Anlegen eines Kalendertermins an")
    assert_no_match(/modal-new-reservation/, response.body,
      "Der Dialog fuer eine neue Reservierung ist noch im HTML")
    assert_no_match(/new_reservation_mode/, response.body,
      "Die JavaScript-Funktion des Dialogs ist noch da")
    assert_no_match(/Neue Reservierung/i, response.body,
      "Der Knopf 'Neue Reservierung' ist noch sichtbar")
  end

  test "der Text verspricht keine Reservierung auf dieser Seite mehr" do
    get_reservations_page

    assert_no_match(/direkt hier/, response.body,
      "Der Infotext behauptet weiterhin, hier liesse sich reservieren")
    assert_match(/Google Kalender/, response.body,
      "Der Infotext nennt den Weg ueber den Google Kalender nicht mehr")
  end

  # Gegenprobe 2026-09-17: Von diesen vier Tests sind am alten Stand zwei rot (Formular/Knopf,
  # Infotext) und zwei gruen. Das ist so gewollt — die beiden gruenen sichern, dass beim Ausbau
  # nichts VERLOREN geht: die Seite muss weiterhin rendern, und die Namenskonvention muss weiter
  # zu lesen sein (vorher im Dialog, jetzt auf der Seite).
  test "die Namenskonvention fuer Kalendertitel bleibt sichtbar" do
    get_reservations_page

    # Sie stand bisher NUR im entfernten Dialog, gilt fuer den Kalender-Weg aber weiter —
    # ohne sie erfaehrt niemand, wie ein Titel aussehen muss, damit die Heizung schaltet.
    assert_match(/Namenskonvention/, response.body,
      "Die Namenskonvention ist mit dem Dialog verschwunden")
    assert_match(/T6-T8|Ausrufungszeichen/, response.body,
      "Die Einzelheiten der Namenskonvention fehlen")
  end
end
