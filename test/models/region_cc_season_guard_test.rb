# frozen_string_literal: true

require "test_helper"

# Rollover-Guard (CC-Incident 2026-07-16): ClubCloud liefert bei einer Saison, die der Tenant noch
# nicht im Saison-Selektor anbietet, Daten einer ANDEREN Saison — die Links tragen trotzdem die
# angefragte Saison, der season_name-Filter im Scrape schützt also nicht. Der Guard prüft den
# Saison-Selektor (select name="s" in sb_spielplan.php) und überspringt Region/Saison sonst.
class RegionCcSeasonGuardTest < ActiveSupport::TestCase
  SELECTOR_HTML = <<~HTML
    <html><body><table><tbody><tr class="odd"><td width="100%"><strong>Saison</strong><br>
    <select size="1" name="s" onchange="refreshPage()">
      <option value="2026/2027" selected="">2026/2027</option>
      <option value="2025/2026">2025/2026</option>
      <option value="2024/2025">2024/2025</option>
    </select></td></tr></tbody></table></body></html>
  HTML

  SELECTOR_HTML_OLD = <<~HTML
    <html><body><select size="1" name="s">
      <option value="2025/2026" selected="">2025/2026</option>
      <option value="2024/2025">2024/2025</option>
    </select></body></html>
  HTML

  def build_region(url = "https://cc-guard.example/")
    Region.new(shortname: "XXX", name: "Guard-Test", public_cc_url_base: url)
  end

  test "cc_season_available? true wenn Selektor die Saison enthält" do
    stub_request(:get, "https://cc-guard.example/sb_spielplan.php")
      .to_return(status: 200, body: SELECTOR_HTML)
    region = build_region
    assert region.cc_season_available?(Season.new(name: "2026/2027"))
    assert region.cc_season_available?(Season.new(name: "2025/2026"))
  end

  test "cc_season_available? false wenn Selektor die Saison NICHT enthält (Rollover-Fall)" do
    stub_request(:get, "https://cc-guard.example/sb_spielplan.php")
      .to_return(status: 200, body: SELECTOR_HTML_OLD)
    refute build_region.cc_season_available?(Season.new(name: "2026/2027")),
      "Saison fehlt im Selektor → Region darf nicht gescrapt werden"
  end

  test "fail-closed: HTTP-Fehler, fehlender Selektor oder fehlende CC-URL → false" do
    stub_request(:get, "https://cc-guard.example/sb_spielplan.php").to_timeout
    refute build_region.cc_season_available?(Season.new(name: "2026/2027")), "Timeout muss fail-closed sein"

    stub_request(:get, "https://cc-guard.example/sb_spielplan.php")
      .to_return(status: 200, body: "<html><body>kein Selektor</body></html>")
    refute build_region.cc_season_available?(Season.new(name: "2026/2027")), "ohne Selektor fail-closed"

    refute build_region(nil).cc_season_available?(Season.new(name: "2026/2027")), "ohne CC-URL fail-closed"
  end

  test "Selektor wird memoisiert (nur ein Fetch je Region-Instanz)" do
    stub = stub_request(:get, "https://cc-guard.example/sb_spielplan.php")
      .to_return(status: 200, body: SELECTOR_HTML)
    region = build_region
    region.cc_season_available?(Season.new(name: "2026/2027"))
    region.cc_season_available?(Season.new(name: "2025/2026"))
    assert_requested stub, times: 1
  end

  test "scrape_leagues_from_cc überspringt Region ohne Saison im Selektor (kein Liga-Fetch)" do
    stub_request(:get, "https://cc-guard.example/sb_spielplan.php")
      .to_return(status: 200, body: SELECTOR_HTML_OLD)
    # NUR die Selektor-URL ist gestubbt — würde weiter gescrapt, schlüge WebMock auf der Liga-URL fehl.
    assert_nothing_raised do
      League.scrape_leagues_from_cc(build_region, Season.new(name: "2026/2027"))
    end
  end

  test "scrape_single_tournament_public überspringt Region ohne Saison im Selektor (kein Turnier-Fetch)" do
    stub_request(:get, "https://cc-guard.example/sb_spielplan.php")
      .to_return(status: 200, body: SELECTOR_HTML_OLD)
    assert_nothing_raised do
      build_region.scrape_single_tournament_public(Season.new(name: "2026/2027"))
    end
  end
end
