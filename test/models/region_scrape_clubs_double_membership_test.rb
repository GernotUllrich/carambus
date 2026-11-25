# frozen_string_literal: true

require "test_helper"

# Doppelmitgliedschaft: ABG Trier-Mosel steht in den Vereinslisten von BVRP und BVS, je mit eigener cc_id.
# Früher schrieben beide Regionen region_id/cc_id/Stammdaten jede Nacht hin und her (2026-11-25: 14 Vereine).
class RegionScrapeClubsDoubleMembershipTest < ActiveSupport::TestCase
  HOME = "https://home-cc.example/"
  OTHER = "https://other-cc.example/"

  def list(cc_id, shortname)
    "<article><table class='silver'><tr><td><a href='#' onclick='return cp(0,#{cc_id})' title='#{shortname}' " \
      "class='cc_bluelink'>#{shortname}</a></td></tr></table></article>"
  end

  def details(verband, name, dbu)
    "<aside><table class='silver'><tr><td>Verband</td><td>#{verband}</td></tr>" \
      "<tr><td>Verein</td><td>#{name}</td></tr><tr><td>DBU-Nr.</td><td>#{dbu}</td></tr></table></aside>"
  end

  setup do
    @home = Region.create!(name: "Heimatverband e.V.", shortname: "HOMV", cc_id: 23, public_cc_url_base: HOME)
    @other = Region.create!(name: "Nachbarverband e.V.", shortname: "NBRV", cc_id: 17, public_cc_url_base: OTHER)
    @club = Club.create!(name: "Amateur Billardgemeinschaft Mosel", shortname: "ABG Trier-Mosel", region: @home,
      cc_id: 3163, dbu_nr: 2754, synonyms: "ABG Trier-Mosel\nAmateur Billardgemeinschaft Mosel",
      source_url: "#{HOME}cbdet.php?a=3163&f=23")
    @home_entry = ClubCcEntry.record!(@club, @home, 3163)
    @pages = {
      [OTHER, nil] => list(2754, "ABG Trier"),
      [OTHER, 2754] => details("Nachbarverband e.V. (NBRV)", "Amateur Billardgemeinschaft Mosel", 2754),
      [HOME, nil] => list(3163, "ABG Trier-Mosel"),
      [HOME, 3163] => details("Heimatverband e.V. (HOMV)", "Amateur Billardgemeinschaft Mosel", 2754)
    }
  end

  def scrape(region, **opts)
    calls = []
    base = region.public_cc_url_base
    http = lambda do |_uri, params|
      calls << params[:a]
      ["200", @pages.fetch([base, params[:a]])]
    end
    client = ClubCloudPublicClient.new(base_url: base, fed_id: region.cc_id, http: http, sleeper: ->(_) {})
    ClubCloudPublicClient.stub(:new, client) do
      region.scrape_clubs(Season.current_season, {from_background: true, player_details: false}.merge(opts))
    end
    calls
  end

  test "Fremdlistung ändert den Verein nicht und merkt sich die fremde cc_id" do
    assert_no_changes -> { @club.reload.attributes.except("updated_at") } do
      scrape(@other)
    end

    assert_equal @club, ClubCcEntry.club_for(@other.id, 2754)
    assert_equal @club, ClubCcEntry.club_for(@home.id, 3163)
  end

  test "danach kostet die Fremdlistung nachts keinen Detail-Abruf mehr" do
    scrape(@other)

    assert_equal [nil], scrape(@other, skip_known_clubs: true)
  end

  test "Heimat-Liste frischt seen_at ohne Detail-Abruf auf" do
    n = Region::KNOWN_CLUB_ROTATION
    day = (1..n).map { |d| Date.new(2026, 1, 1) + d }.find { |d| @club.id % n != d.yday % n }
    travel_to(day.to_time + 12.hours) do
      @home_entry.update_columns(seen_at: 3.days.ago)

      assert_equal [nil], scrape(@home, skip_known_clubs: true), "nur die Vereinsliste"
      assert_in_delta Time.current, @home_entry.reload.seen_at, 1.minute
    end
  end

  test "echter Verbandswechsel: Heimat-CC listet den Verein seit über 7 Tagen nicht mehr → andere Region übernimmt" do
    @home_entry.update_columns(seen_at: 8.days.ago)

    scrape(@other)

    @club.reload
    assert_equal @other.id, @club.region_id
    assert_equal 2754, @club.cc_id
    assert_equal "ABG Trier", @club.shortname
  end

  test "neuer Verein ohne Heimat wird wie bisher angelegt und eingetragen" do
    @pages[[OTHER, nil]] = list(4711, "BC Neu")
    @pages[[OTHER, 4711]] = details("Nachbarverband e.V. (NBRV)", "Billard-Club Neu e.V.", 9999)

    scrape(@other)

    neu = ClubCcEntry.club_for(@other.id, 4711)
    assert_equal "BC Neu", neu.shortname
    assert_equal @other.id, neu.region_id
  end
end
