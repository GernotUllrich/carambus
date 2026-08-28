# frozen_string_literal: true

require "test_helper"

# Die Grenzen des Kalender-Stroms.
#
# Die Tests zur Wochenstruktur des Monatsrasters (42-03) sind mit dem Raster selbst entfallen:
# der Kalender hat nur noch die Strom-Ansicht (Betreiber-Entscheidung 2026-08-27).
class CalendarsHelperTest < ActionView::TestCase
  include CalendarsHelper

  # --- Grenzen des Kalender-Stroms (42-04) ----------------------------------------------------

  test "der Strom beginnt im Juli 2009" do
    von, _ = calendar_month_bounds
    assert_equal Date.new(2009, 7, 1), von
  end

  test "der Strom endet drei Saisons nach dem aktuellen Startjahr" do
    _, bis = calendar_month_bounds
    startjahr = Season.current_season.name.split("/").first.to_i
    assert_equal Date.new(startjahr + 3, 6, 1), bis
  end

  test "calendar_months laeuft vorwaerts und rueckwaerts, rueckwaerts aufsteigend sortiert" do
    vor = calendar_months(Date.new(2026, 11, 1), 3)
    assert_equal [Date.new(2026, 12, 1), Date.new(2027, 1, 1), Date.new(2027, 2, 1)], vor

    zurueck = calendar_months(Date.new(2026, 11, 1), -3)
    assert_equal [Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1)], zurueck,
      "rueckwaerts muss aufsteigend kommen, damit sich die Kacheln am Stueck davorsetzen lassen"
  end

  # ⚠️ Der Test, der den Strom davor bewahrt, ins Jahr 1 zu scrollen. Gemessen am 2026-08-27:
  # `tournaments.date` laeuft von 0001-01-03 bis 2999-09-18, der NBV traegt einen
  # Epoch-Null-Monat 1970-01 — die Datenraender taugen NICHT als Grenze.
  test "vor Juli 2009 kommt nichts mehr" do
    assert_empty calendar_months(Date.new(2009, 7, 1), -3)
    assert_equal [Date.new(2009, 7, 1)], calendar_months(Date.new(2009, 8, 1), -3),
      "von August 2009 drei Monate zurueck: nur der Juli liegt noch im Strom"
    refute calendar_month_in_bounds?(Date.new(2009, 6, 1))
    refute calendar_month_in_bounds?(Date.new(1970, 1, 1)),
      "der Epoch-Null-Monat aus den Daten darf nie im Strom auftauchen"
  end

  test "hinter der oberen Grenze kommt nichts mehr" do
    _, bis = calendar_month_bounds
    assert_empty calendar_months(bis, 3)
    refute calendar_month_in_bounds?(bis >> 1)
    assert calendar_month_in_bounds?(bis)
  end

  test "calendar_months mit count 0 oder ohne Monat liefert leer statt zu werfen" do
    assert_empty calendar_months(Date.new(2026, 11, 1), 0)
    assert_empty calendar_months(nil, 3)
  end
end
