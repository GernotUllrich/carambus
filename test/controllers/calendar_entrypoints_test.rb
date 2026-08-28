# frozen_string_literal: true

require "test_helper"

# Die Wege ZUM Kalender.
#
# Die Seite war von 42-01 bis 42-04 fertig, aber nirgends verlinkt — wer die URL nicht kannte,
# fand sie nicht. Diese Tests halten die beiden Eingaenge fest, damit sie bei einem Umbau der
# Navigation oder der Startseite nicht still wieder verschwinden.
class CalendarEntrypointsTest < ActionDispatch::IntegrationTest
  test "die Navigation verlinkt den Kalender" do
    get root_path
    assert_response :success
    assert_select "nav a[href=?]", calendar_path, {minimum: 1},
      "der Kalender gehoert in die Navigation"
  end

  test "die Startseite teasert den Kalender an" do
    get root_path
    assert_response :success
    # Ausserhalb der Navigation — der Teaser ist ein eigener Einstieg, kein Menuepunkt.
    assert_select "main a[href=?]", calendar_path, minimum: 1
    assert_match(/Terminkalender/, response.body)
  end

  test "der Kalender ist ohne Login erreichbar und zeigt den Strom" do
    get calendar_path
    assert_response :success
    assert_select "[data-controller=?]", "calendar-stream", minimum: 1
  end

  # Es gibt nur noch EINE Ansicht (Betreiber-Entscheidung 2026-08-27). Ein `view`-Parameter aus
  # einem alten Lesezeichen darf die Seite nicht kippen.
  test "ein alter view-Parameter stoert nicht" do
    get calendar_path(view: "grid")
    assert_response :success
    assert_select "[data-controller=?]", "calendar-stream", minimum: 1
  end
end
