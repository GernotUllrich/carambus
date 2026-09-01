# frozen_string_literal: true

require "test_helper"

# Der Kalender auf dem Scoreboard zeigt EINEN Monat, keinen Strom.
#
# Anlass: Die Scoreboards im Vereinsheim laufen mit 1280x720, und ihre Bildlaufleisten sind
# praktisch nicht bedienbar (Betreiber-Befund 2026-09-01). Ein Strom, der beim Scrollen
# nachlaedt, ist dort ab der ersten Bildschirmhoehe unerreichbar — geblaettert wird
# stattdessen mit den ‹ › der Filterleiste, die es ohnehin gibt.
#
# ⚠️ Dieser Test prueft die STRUKTUR, nicht nur Text: dass genau eine Monatskachel im HTML
# steht und der Strom-Controller fehlt. Ein Test, der bloss nach Woertern sucht, wuerde nicht
# merken, wenn der Strom versehentlich wieder mitgerendert wird.
#
# Siehe docs/ui-conventions.md, Abschnitt 6.
class CalendarScoreboardSingleMonthTest < ActionDispatch::IntegrationTest
  setup do
    @monat = Date.current.strftime("%Y-%m")
    @original_config = Carambus.config
  end

  teardown do
    Carambus.config = @original_config
  end

  def mit_location_id(id)
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(location_id: id))
  end

  # `User.scoreboard` liefert in der Testumgebung bewusst nil (user.rb:85) — das Merkmal
  # laeuft deshalb ueber die E-Mail, genau wie in `ApplicationHelper#scoreboard_context?`.
  def scoreboard_user!
    User.find_by(email: "scoreboard@carambus.de") ||
      User.create!(email: "scoreboard@carambus.de", password: "sb-test-passwort",
        first_name: "Score", last_name: "Board",
        accepted_terms_at: Time.current, accepted_privacy_at: Time.current,
        confirmed_at: Time.current)
  end

  test "am Scoreboard steht genau eine Monatskachel und kein Strom" do
    mit_location_id(locations(:one).id)
    sign_in scoreboard_user!

    get calendar_url(month: @monat)
    assert_response :success

    assert_select "section.calendar-tile", 1,
      "auf dem Scoreboard darf nur der Einstiegsmonat gerendert werden"
    assert_select "[data-controller='calendar-stream']", 0,
      "der Strom-Controller darf dort gar nicht erst eingehaengt werden"
    assert_select "[data-action='calendar-stream#loadEarlier']", 0,
      "und ohne Strom gibt es auch nichts nachzuladen"
  end

  test "ausserhalb des Scoreboards bleibt der Strom unveraendert" do
    get calendar_url(month: @monat)
    assert_response :success

    assert_select "[data-controller='calendar-stream']", 1,
      "am Schreibtisch soll weiter der Strom laufen — die Umstellung gilt nur fuer Scoreboards"
  end
end
