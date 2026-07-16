# frozen_string_literal: true

require "test_helper"

# Tests for League::ClubCloudScraper ApplicationService.
# Verifies guard clauses, error handling, and delegation via WebMock stubs.
class League::ClubCloudScraperTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 90_000

  @@counter = 0

  def next_id
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  def create_test_league
    base = next_id
    League.create!(
      id: base,
      name: "CC Scraper Test League #{base}",
      shortname: "CCST#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band),
      cc_id: base
    )
  end

  # Without league_details: true, call returns early (guard clause)
  test "call returns without error when league_details not set" do
    league = create_test_league
    assert_nothing_raised do
      League::ClubCloudScraper.call(league: league)
    end
  end

  # With league_details: true and HTTP returning empty HTML — no team table found, returns without error
  test "call handles empty HTML response without error" do
    league = create_test_league
    stub_request(:get, /sb_spielplan\.php/)
      .to_return(status: 200, body: "<html><body><aside><section></section></aside></body></html>",
                 headers: { "Content-Type" => "text/html" })

    assert_nothing_raised do
      League::ClubCloudScraper.call(league: league, league_details: true)
    end
  end

  # With league_details: true and HTTP timeout — broad rescue swallows the error
  test "call handles HTTP timeout without propagating error" do
    league = create_test_league
    stub_request(:get, /sb_spielplan\.php/).to_timeout

    assert_nothing_raised do
      League::ClubCloudScraper.call(league: league, league_details: true)
    end
  end

  # Robustes Datums-Parsing: valide DD.MM.YYYY parsen, malformte Zellen → nil (kein stilles Garbage-Datum,
  # das früher als Party-Datum landete: "21.02.206"→0206, "21.2."→heute, "01.01.1970"→1970 usw.)
  test "parse_cc_datetime parses valid dates and rejects malformed cells" do
    s = League::ClubCloudScraper.new
    assert_equal "2026-02-21 20:00",
      s.send(:parse_cc_datetime, "21.02.2026<br>20:00 Uhr").strftime("%Y-%m-%d %H:%M")
    assert_equal "2025-11-01 00:00",
      s.send(:parse_cc_datetime, "Sa, 01.11.2025").strftime("%Y-%m-%d %H:%M")
    ["21.02.206", "21.02.20", "9.1.1", "21.2.", "01.01.1970", "31.13.2026", "Termin folgt", ""].each do |bad|
      assert_nil s.send(:parse_cc_datetime, bad), "#{bad.inspect} sollte nil ergeben (kein Garbage-Datum)"
    end
  end
end
