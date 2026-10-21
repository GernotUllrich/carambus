# frozen_string_literal: true

require "test_helper"

# Scope-Band "Alle Regionen" (Betreiber 2026-10-21): regionsuebergreifend suchen, ohne dass Seiten
# mit konkretem Regionsbezug (Kalender) brechen.
class ScopeBandAllRegionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:club_admin)
  end

  test "Band bietet Alle Regionen an und markiert sie nach der Wahl" do
    get clubs_url(scope: {region: ScopeResolver::ALL_REGIONS})
    assert_response :success

    assert_select "#scope-band select[name=?] option[value=?][selected]", "scope[region]", ScopeResolver::ALL_REGIONS
  end

  test "Vereinsliste zeigt bei Alle Regionen auch Vereine fremder Regionen" do
    fremd = clubs(:club_bochum) # Region BBV
    get clubs_url(scope: {region: regions(:nbv).id})
    assert_response :success
    # Der Name steht auch im Auswahlmenue des Suchfilters — gezaehlt wird der Link in der Liste.
    assert_select "a[href=?]", club_path(fremd), 0, "Gegenprobe: mit NBV-Filter kein BBV-Verein in der Liste"

    get clubs_url(scope: {region: ScopeResolver::ALL_REGIONS})
    assert_response :success
    assert_select "a[href=?]", club_path(fremd)
  end

  test "Kalender laeuft bei Alle Regionen mit der Heimregion" do
    get clubs_url(scope: {region: ScopeResolver::ALL_REGIONS})
    get calendar_url
    assert_response :success
  end
end
