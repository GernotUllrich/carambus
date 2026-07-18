# frozen_string_literal: true

require "test_helper"

# Characterization tests for League scraping pipeline methods.
# Uses WebMock stubs to pin that scraping methods can be called without
# unhandled exceptions and produce expected side-effects.
#
# Strategy: stub HTTP calls, verify no-crash behavior, pin return types
# and error handling. Parsing accuracy is tested in the extraction phase.
class LeagueScrapingTest < ActiveSupport::TestCase
  include ScrapingHelpers

  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 70_000
  CC_URL_BASE = "https://club-cloud.test.example/"

  @@counter = 0

  def next_base
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  def create_scrapable_region
    base = next_base
    Region.create!(
      id: base,
      name: "NBV Scraping Test #{base}",
      shortname: "NBVT#{@@counter}",
      public_cc_url_base: CC_URL_BASE,
      cc_id: base
    )
  end

  def create_scrapable_league(region)
    base = next_base
    League.create!(
      id: base,
      name: "Scraping Test League #{base}",
      shortname: "SCR#{@@counter}",
      organizer: region,
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band),
      cc_id: base
    )
  end

  # Minimal HTML fixture for a ClubCloud league list page with empty table
  def minimal_leagues_html
    <<~HTML
      <html>
        <body>
          <article>
            <table class="silver"></table>
            <table class="silver"><tbody></tbody></table>
          </article>
        </body>
      </html>
    HTML
  end

  # --- scrape_leagues_from_cc ---

  test "scrape_leagues_from_cc returns without error when HTTP stubbed with empty table" do
    region = create_scrapable_region
    stub_request(:get, /#{Regexp.escape(CC_URL_BASE)}sb_spielplan/)
      .to_return(status: 200, body: minimal_leagues_html, headers: { "Content-Type" => "text/html" })

    assert_nothing_raised do
      League.scrape_leagues_from_cc(region, seasons(:current))
    end
  end

  test "scrape_leagues_from_cc handles HTTP 404 response without error (HTML parsed, empty table)" do
    region = create_scrapable_region
    stub_request(:get, /#{Regexp.escape(CC_URL_BASE)}sb_spielplan/)
      .to_return(status: 404, body: "<html><body>Not Found</body></html>")

    # 404 body is parsed as HTML with no matching table, method returns without error
    assert_nothing_raised do
      League.scrape_leagues_from_cc(region, seasons(:current))
    end
  end

  # --- timeout handling ---

  test "scrape_leagues_from_cc raises on timeout (re-raises as StandardError)" do
    region = create_scrapable_region
    stub_request(:get, /#{Regexp.escape(CC_URL_BASE)}sb_spielplan/)
      .to_timeout

    # scrape_leagues_from_cc re-raises any StandardError — Timeout is a subclass
    assert_raises(StandardError) do
      League.scrape_leagues_from_cc(region, seasons(:current))
    end
  end
end
