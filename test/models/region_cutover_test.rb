# frozen_string_literal: true

require "test_helper"

# Guard-Tests für den TBV-Cutover (Phase 12 v0.4): TBV wurde vom ClubCloud-Scrape auf den
# LigaManager migriert. „TBV" darf in keiner Scrape-Iterationsliste mehr auftauchen (sonst würde
# der abgeschaltete CC-Pull wieder laufen), aber die Namensauflösung muss erhalten bleiben.
class RegionCutoverTest < ActiveSupport::TestCase
  test "TBV ist aus allen CC-Scrape-Listen entfernt" do
    assert_not_includes Region::SHORTNAMES_OTHERS, "TBV",
      "TBV darf nicht in SHORTNAMES_OTHERS stehen (steuert Club-/Turnier-/Liga-Scrape)"
    assert_not_includes Region::SHORTNAMES, "TBV",
      "TBV darf nicht in der zusammengesetzten SHORTNAMES-Liste stehen"
    assert_not Region::SHORTNAMES_CC.key?("TBV"),
      "TBV darf keine CC-URL mehr haben (scrape_regions setzt public_cc_url_base sonst)"
  end

  test "Namensauflösung Thüringer Billard-Verband → TBV-Region bleibt intakt" do
    map = Region.region_map
    assert map.key?("Thüringer Billard-Verband"),
      "region_map muss den TBV-Verbandsnamen weiterhin auflösen"
    assert map.key?("Thüringer Billard-Verband e.V.")
  end
end
