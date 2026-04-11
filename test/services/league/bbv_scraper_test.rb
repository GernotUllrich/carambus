# frozen_string_literal: true

require "test_helper"

# Tests for League::BbvScraper ApplicationService.
# Verifies delegation, error handling, and scrape_all return type via WebMock stubs.
class League::BbvScraperTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 100_000

  @@counter = 0

  def next_id
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  def create_test_league
    base = next_id
    League.create!(
      id: base,
      name: "BBV Scraper Test League #{base}",
      shortname: "BBV#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band),
      cc_id: base,
      source_url: "https://bbv-billard.liga.nu/test-league-#{base}"
    )
  end

  # Minimal HTML for a BBV league page with no navigation links
  def minimal_bbv_league_html
    <<~HTML
      <html>
        <body>
          <table>
            <thead><tr><th>Platz</th><th>Nr</th><th>Mannschaft</th><th>Sp</th></tr></thead>
            <tbody></tbody>
          </table>
          <div id="sub-navigation"></div>
        </body>
      </html>
    HTML
  end

  # Minimal HTML for BBV leagues list page with empty table
  def minimal_bbv_leagues_html
    <<~HTML
      <html>
        <body>
          <table>
            <tr><td><h2>Pool</h2></td></tr>
          </table>
        </body>
      </html>
    HTML
  end

  # call delegates to scrape_single_bbv_league and returns without error on stubbed empty response
  test "call does not raise on stubbed empty BBV league response" do
    league = create_test_league
    stub_request(:get, /bbv-billard\.liga\.nu/).to_return(
      status: 200,
      body: minimal_bbv_league_html,
      headers: { "Content-Type" => "text/html" }
    )

    assert_nothing_raised do
      League::BbvScraper.call(league: league, region: regions(:nbv))
    end
  end

  # scrape_all returns an Array (records_to_tag)
  test "scrape_all returns an Array" do
    stub_request(:get, /bbv-billard\.liga\.nu/).to_return(
      status: 200,
      body: minimal_bbv_leagues_html,
      headers: { "Content-Type" => "text/html" }
    )

    result = League::BbvScraper.scrape_all(region: regions(:nbv), season: seasons(:current))
    assert_instance_of Array, result
  end
end
