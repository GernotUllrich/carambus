# frozen_string_literal: true

require "test_helper"

# Abbruch des Vereins-Scrapes einer Region wird zurückgegeben statt verschluckt (02.–24.11.2026 brach er jede
# Nacht ab, der ScrapingMonitor meldete error_count = 0).
class ClubScrapeClubsFailuresTest < ActiveSupport::TestCase
  BASE = "https://cc-test.example/"

  setup do
    @region = Region.create!(name: "Testverband e.V.", shortname: "TSTV", cc_id: 77, public_cc_url_base: BASE)
  end

  def scrape_with(code)
    http = ->(_uri, _params) { [code, "<article></article>"] }
    client = ClubCloudPublicClient.new(base_url: BASE, fed_id: 77, http: http, sleeper: ->(_) {})
    ClubCloudPublicClient.stub(:new, client) do
      @region.scrape_clubs(Season.current_season, from_background: true, player_details: false)
    end
  end

  test "Region#scrape_clubs gibt den abgefangenen Fehler zurück (429 nach allen Wiederholungen)" do
    result = scrape_with("429")

    assert_kind_of ClubCloudPublicClient::Error, result
    assert_match "HTTP 429", result.message
  end

  test "Region#scrape_clubs ohne Fehler gibt kein Exception-Objekt zurück" do
    assert_not_kind_of Exception, scrape_with("200")
  end

  test "Club.scrape_clubs sammelt die abgebrochenen Regionen und scrapt die übrigen weiter" do
    scraped = []
    ok = Object.new
    ok.define_singleton_method(:scrape_clubs) { |*| scraped << :ok and nil }
    broken = Object.new
    broken.define_singleton_method(:scrape_clubs) { |*| scraped << :broken and ClubCloudPublicClient::Error.new("HTTP 429") }
    lookup = ->(shortname) { %w[BVW SBV].include?(shortname) ? broken : ok }

    failures = Region.stub(:find_by_shortname, lookup) { Club.scrape_clubs(Season.current_season) }

    shortnames = Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS
    assert_equal shortnames.size, scraped.size, "jede Region wird versucht"
    assert_equal %w[BVW SBV], failures.keys.sort
    assert_kind_of ClubCloudPublicClient::Error, failures["BVW"]
  end
end
