# frozen_string_literal: true

require "test_helper"

# Scope-Band-Ziel auf Detailseiten.
#
# Current.scope filtert ausschliesslich Listen (SearchService). Eine Detailansicht rendert den
# Record aus :id und ignoriert den Ausschnitt. Zielte das Band-Formular dort auf request.path,
# schrieb capture_scope die neue Facette still in session[:scope] (inkl. persistenter
# User-Preference), waehrend die Anzeige unveraendert blieb -> widerspruechlicher Zustand
# ("Pool" im Band, Karambol-Liga im Inhalt).
#
# Erwartung: auf Member-Seiten zielt das Band auf die Liste des Modells, sodass eine
# Ausschnitt-Aenderung auf das Listen-Level im NEUEN Ausschnitt zurueckfuehrt.
class ScopeBandFormTargetTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:club_admin)
    @location = locations(:one)
    sign_in @admin
  end

  test "Detailseite: Band-Formular zielt auf die Liste, nicht auf die Detailseite" do
    get location_url(@location)
    assert_response :success

    assert_select "#scope-band form[action=?]", locations_path
    assert_select "#scope-band form[action=?]", location_path(@location), 0,
      "Band darf auf der Detailseite NICHT auf sich selbst submitten (stiller Scope-Wechsel)"
  end

  test "Liste: Band-Formular bleibt auf dem aktuellen Pfad" do
    get locations_url
    assert_response :success

    assert_select "#scope-band form[action=?]", locations_path
  end
end
