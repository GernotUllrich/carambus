# frozen_string_literal: true

require "test_helper"

class RegionTest < ActiveSupport::TestCase
  # cc_admin_base_url_from: leitet RegionCc.base_url (CC-Admin-Tenant-Host) aus dem
  # "Anmeldung"-Link der öffentlichen Region-Seite ab. Behebt die base_url-Falle, bei der
  # scrape_region_public public_cc_url_base in base_url schrieb → täglich CC-Admin-Login 404.
  test "cc_admin_base_url_from: Anmeldung-Link → base_url scheme://host (ohne Trailing-Slash)" do
    doc = Nokogiri::HTML(
      '<ul><li><a href="https://abc123def.club-cloud.de" title="Anmeldung NBV" target="_blank">Anmeldung</a></li></ul>'
    )
    assert_equal "https://abc123def.club-cloud.de",
      Region.new(shortname: "NBV").cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  test "cc_admin_base_url_from: href mit Pfad → nur scheme://host (Root, kein Slash)" do
    doc = Nokogiri::HTML('<a href="https://abc.club-cloud.de/admin/login.php">Anmeldung</a>')
    assert_equal "https://abc.club-cloud.de",
      Region.new.cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  test "cc_admin_base_url_from: kein Anmeldung-Link → nil (base_url bleibt unangetastet)" do
    doc = Nokogiri::HTML('<a href="https://ndbv.de/impressum">Impressum</a>')
    assert_nil Region.new.cc_admin_base_url_from(doc, "https://ndbv.de/")
  end

  test "cc_admin_base_url_from: Anmeldung-Anchor ohne href → nil" do
    doc = Nokogiri::HTML("<a>Anmeldung</a>")
    assert_nil Region.new.cc_admin_base_url_from(doc, "https://ndbv.de/")
  end
end
