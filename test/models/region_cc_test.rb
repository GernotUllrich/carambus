# frozen_string_literal: true

require "test_helper"

# Plan 25-01 T2: Regression-Schutz für discover_admin_url_from_public_site.
#
# Hintergrund (siehe .paul/phases/25-mcp-demo-haertung/25-DIAGNOSE-LOG.md):
# Production-Befund 2026-06-02 — `RegionCc.base_url` für NBV stand auf
# `https://ndbv.de/` (Verbandswebseite) statt der CC-Tenant-URL. Wurzel:
# `discover_admin_url_from_public_site` akzeptierte ohne Filter jeden ersten
# `<a title*="Anmeldung">`-Link auf der Verbands-Public-Seite. Bei NBV ist das
# eine ndbv.de-interne Mitglieder-Anmeldung — die discovered_url wurde via
# `ensure_admin_base_url!` in `RegionCc.base_url` geschrieben → alle CC-Admin-
# Calls liefen ins 404 → MCP-Server lieferte 0 Treffer.
#
# Fix: Sanity-Filter in discover_admin_url_from_public_site — nur Links
# akzeptieren, die `club-cloud.de` enthalten.
class RegionCcTest < ActiveSupport::TestCase
  fixtures :regions

  setup do
    @region = regions(:nbv)
    @region.update!(public_cc_url_base: "https://ndbv.de/")
    @region_cc = RegionCc.new(
      region: @region,
      base_url: "https://ndbv.de/" # bewusst falsch — discover soll das korrigieren
    )
  end

  test "discover_admin_url rejects non-CC-Tenant Anmeldung link" do
    # NBV-Verbandswebseite hat einen Mitglieder-Anmeldungs-Link auf eigene Subseite
    html = <<~HTML
      <html><body>
        <a title="Anmeldung NBV-Mitglied werden" href="https://ndbv.de/mitglied/anmeldung.php">Mitglied werden</a>
      </body></html>
    HTML
    stub_request(:get, "https://ndbv.de").to_return(status: 200, body: html)

    result = @region_cc.discover_admin_url_from_public_site
    assert_nil result, "Expected nil because Anmeldung link doesn't point to *.club-cloud.de"
  end

  test "discover_admin_url accepts Anmeldung link pointing to CC-Tenant" do
    cc_tenant = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"
    html = <<~HTML
      <html><body>
        <a title="ClubCloud-Anmeldung" href="#{cc_tenant}/login">Login</a>
      </body></html>
    HTML
    stub_request(:get, "https://ndbv.de").to_return(status: 200, body: html)

    result = @region_cc.discover_admin_url_from_public_site
    # discover liefert href.chomp("/"), behält Pfad-Suffix — Normalization ist Sache
    # von ensure_admin_base_url! / BASE_URL-Fallback. Hier nur: Filter passt.
    assert_includes result.to_s, "club-cloud.de"
    refute_includes result.to_s, "ndbv.de"
  end

  test "discover_admin_url falls through to club-cloud.de fallback when Anmeldung link is non-CC" do
    # Anmeldung-Link ist non-CC (würde rejected), aber es gibt einen separaten
    # club-cloud.de-Link auf der Seite → Fallback greift.
    cc_tenant = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"
    html = <<~HTML
      <html><body>
        <a title="Anmeldung Verein" href="https://ndbv.de/verein/anmeldung.php">Vereinsanmeldung</a>
        <a href="#{cc_tenant}/admin">Admin-Bereich</a>
      </body></html>
    HTML
    stub_request(:get, "https://ndbv.de").to_return(status: 200, body: html)

    result = @region_cc.discover_admin_url_from_public_site
    assert_includes result.to_s, "club-cloud.de"
    refute_includes result.to_s, "ndbv.de"
  end

  test "discover_admin_url returns nil when no usable link present" do
    html = <<~HTML
      <html><body>
        <p>Keine Anmeldung, kein CC-Link</p>
      </body></html>
    HTML
    stub_request(:get, "https://ndbv.de").to_return(status: 200, body: html)

    result = @region_cc.discover_admin_url_from_public_site
    assert_nil result
  end
end
