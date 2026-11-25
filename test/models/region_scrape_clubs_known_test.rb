# frozen_string_literal: true

require "test_helper"

# Nächtlicher Vereins-Scrape mit skip_known_clubs: bekannte Vereine kosten keinen cbdet-POST (CC-Kontingent),
# außer an ihrem Rotationstag; unbekannte und umbenannte Vereine werden weiter gelesen.
class RegionScrapeClubsKnownTest < ActiveSupport::TestCase
  BASE = "https://cc-test.example/"

  LIST = <<~HTML
    <article><table class="silver">
      <tr><td><a href="#" onclick="return cp(0,1001)" title="BC Alt" class="cc_bluelink">BC Alt</a></td></tr>
      <tr><td><a href="#" onclick="return cp(0,1002)" title="BC Neu" class="cc_bluelink">BC Neu</a></td></tr>
    </table></article>
  HTML

  def details(name, dbu)
    <<~HTML
      <aside><table class="silver">
        <tr><td>Verband</td><td>Testverband e.V. (TSTV)</td></tr>
        <tr><td>Verein</td><td>#{name}</td></tr>
        <tr><td>DBU-Nr.</td><td>#{dbu}</td></tr>
      </table></aside>
    HTML
  end

  setup do
    @region = Region.create!(name: "Testverband e.V.", shortname: "TSTV", cc_id: 77, public_cc_url_base: BASE)
    @alt = Club.create!(name: "Billard-Club Alt e.V.", shortname: "BC Alt", region: @region, cc_id: 1001,
      synonyms: "Billard-Club Alt e.V.", source_url: "#{BASE}cbdet.php?a=1001&f=77")
    @pages = {[nil] => LIST, [1001] => details("Billard-Club Alt e.V.", 11), [1002] => details("Billard-Club Neu e.V.", 12)}
  end

  def run_scrape(**opts)
    calls = []
    http = lambda do |uri, params|
      calls << params[:a]
      ["200", @pages.fetch([params[:a]])]
    end
    client = ClubCloudPublicClient.new(base_url: BASE, fed_id: 77, http: http, sleeper: ->(_) {})
    ClubCloudPublicClient.stub(:new, client) do
      @region.scrape_clubs(Season.current_season, {from_background: true, player_details: false}.merge(opts))
    end
    calls
  end

  # Ein Tag, an dem @alt NICHT in der Rotation ist.
  def off_rotation_day
    (1..Region::KNOWN_CLUB_ROTATION).map { |d| Date.new(2026, 1, 1) + d }
      .find { |d| @alt.id % Region::KNOWN_CLUB_ROTATION != d.yday % Region::KNOWN_CLUB_ROTATION }
  end

  test "bekannter Verein: kein Detail-POST; neuer Verein wird gelesen und angelegt" do
    calls = travel_to(off_rotation_day) { run_scrape(skip_known_clubs: true) }

    assert_equal [nil, 1002], calls, "nur Vereinsliste + Details des neuen Vereins"
    neu = Club.find_by(cc_id: 1002, region_id: @region.id)
    assert_equal "BC Neu", neu.shortname
    assert_equal "#{BASE}cbdet.php?a=1002&f=77", neu.source_url
  end

  test "ohne skip_known_clubs (clubs:scrape_region, Portal) wie bisher alle Details" do
    calls = travel_to(off_rotation_day) { run_scrape }

    assert_equal [nil, 1001, 1002], calls
  end

  test "mit player_details wird nicht übersprungen (Roster braucht den Verein)" do
    calls = travel_to(off_rotation_day) { run_scrape(skip_known_clubs: true, player_details: true) }

    assert_includes calls, 1001
  end

  test "umbenannter Kurzname in der Liste → Details werden gelesen" do
    @alt.update!(shortname: "BC Alt (alt)")
    calls = travel_to(off_rotation_day) { run_scrape(skip_known_clubs: true) }

    assert_includes calls, 1001
    assert_equal "BC Alt", @alt.reload.shortname
  end

  test "alte source_url (verein-details) gilt als unbekannt" do
    @alt.update!(source_url: "#{BASE}verein-details.php?p=77|||1001||1|100000|0")
    calls = travel_to(off_rotation_day) { run_scrape(skip_known_clubs: true) }

    assert_includes calls, 1001
  end

  test "Rotation: jeder bekannte Verein wird innerhalb von KNOWN_CLUB_ROTATION Tagen gelesen" do
    days = (0...Region::KNOWN_CLUB_ROTATION).map { |d| Date.new(2026, 3, 1) + d }
    read_days = days.reject { |d| @region.known_cc_club?(1001, "BC Alt", @alt.source_url, today: d) }

    assert_equal 1, read_days.size
  end
end
