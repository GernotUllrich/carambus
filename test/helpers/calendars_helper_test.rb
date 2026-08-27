# frozen_string_literal: true

require "test_helper"

# Die Wochenstruktur des Monatsrasters: Reihenfolge ab Samstag und die Spaltenbreiten,
# die sich nach den Terminen des angezeigten Monats richten.
class CalendarsHelperTest < ActionView::TestCase
  include CalendarsHelper

  # AC-1 — der Versatz in `abbr_day_names` ist sonntagsbasiert und wird leicht falsch gerechnet.
  test "die Wochentage stehen ab Samstag" do
    assert_equal %w[Sa So Mo Di Mi Do Fr], calendar_weekday_labels
  end

  test "die Wochentagsfolge deckt sich mit den wday-Werten" do
    assert_equal [6, 0, 1, 2, 3, 4, 5], CalendarsHelper::WDAY_ORDER
    # Gegenprobe gegen den alten Montags-Versatz: der lieferte etwas anderes.
    refute_equal %w[Mo Di Mi Do Fr Sa So], calendar_weekday_labels
  end

  test "der Wochenanfang traegt bis in die Datumsrechnung" do
    # 1.11.2026 ist ein Sonntag — die Woche beginnt am Samstag davor.
    assert_equal Date.new(2026, 10, 31),
      Date.new(2026, 11, 1).beginning_of_week(CalendarsHelper::WEEK_START)
  end

  # --- AC-2 / AC-3: Spaltenbreiten ------------------------------------------------------------

  # Die sieben Spuren aus dem Stil zurueckholen. Gescannt statt an Leerzeichen zerlegt —
  # `minmax(6rem, 1fr)` traegt selbst eines und wuerde dabei mitten durchgeschnitten.
  def spuren(stil)
    stil[/grid-template-columns:\s*([^;]+);/, 1].to_s.scan(/minmax\([^)]*\)|[\d.]+rem/)
  end

  # AC-2 — der Regelfall im NBV: nur Samstag und Sonntag belegt.
  test "Wochentage ohne Termin schrumpfen" do
    stil = calendar_grid_style([6, 0])
    assert_equal [
      CalendarsHelper::SPUR_BELEGT, CalendarsHelper::SPUR_BELEGT,
      CalendarsHelper::SPUR_LEER, CalendarsHelper::SPUR_LEER,
      CalendarsHelper::SPUR_LEER, CalendarsHelper::SPUR_LEER, CalendarsHelper::SPUR_LEER
    ], spuren(stil)
  end

  # AC-3 — der BVNR-/DBU-Fall. DIES ist der Test, der ein fest verdrahtetes
  # „Mo–Fr schmal" rot macht.
  test "ein Wochentag MIT Terminen schrumpft nicht" do
    # Mittwoch (wday 3) belegt — Position 4 in der Sa-Folge [6, 0, 1, 2, 3, 4, 5].
    stil = calendar_grid_style([6, 3])
    assert_equal CalendarsHelper::SPUR_BELEGT, spuren(stil)[4],
      "ein Mittwoch mit Terminen (BVNR 22, DBU 13) darf nicht auf Zahlenbreite gequetscht werden"
    assert_equal CalendarsHelper::SPUR_LEER, spuren(stil)[2],
      "der leere Montag daneben schrumpft weiterhin"
  end

  test "die Mindestbreite folgt den Spuren und macht das Raster mobil schmaler" do
    nur_wochenende = calendar_grid_style([6, 0])[/min-width:\s*([\d.]+)rem/, 1].to_f
    alle_tage = calendar_grid_style([0, 1, 2, 3, 4, 5, 6])[/min-width:\s*([\d.]+)rem/, 1].to_f

    assert_equal 2 * 6 + 5 * 2.5, nur_wochenende
    assert_equal 7 * 6, alle_tage
    assert_operator nur_wochenende, :<, 44,
      "der Zweck der Uebung ist ein schmaleres Raster als die alte feste min-w-[44rem]"
  end

  test "ohne belegten Tag bleibt das Raster unveraendert breit statt zusammenzufallen" do
    assert_equal [CalendarsHelper::SPUR_BELEGT] * 7, spuren(calendar_grid_style([]))
  end

  test "der Stil traegt keine Farbe — die UI-Wache flaggt nur color/background/hex" do
    stil = calendar_grid_style([6, 0])
    refute_match(/#\h{3,6}|\bcolor\b|\bbackground/i, stil)
  end
end
