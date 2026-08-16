# frozen_string_literal: true

require "test_helper"

# Regressionsschutz fuer den Argument-Vertrag von Region#scrape_clubs.
#
# Die Signatur ist `scrape_clubs(season, opts = {})`. Wird sie ohne Saison als
# `scrape_clubs(player_details: true)` aufgerufen, kollabiert der Keyword-Hash in
# Ruby 3 zum POSITIONALEN Argument: `season == {player_details: true}`, `opts == {}`.
# Das schlaegt nicht fehl, es wirkt still — in production landet der Aufruf im
# else-Zweig (`RegionScrapeClubsJob.perform_later(self, opts)`) mit leerem opts,
# der Job setzt die Saison selbst korrekt ein, aber `player_details` ist weg:
# "Reload mit Details" verhaelt sich dann exakt wie "Reload ohne Details".
#
# Betroffen waren regions_controller (2x) und versions_controller (1x).
class RegionsControllerScrapeClubsArgsTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    # local_server? muss FALSE sein, sonst nimmt die Action den Version-Sync-Zweig
    # statt scrape_clubs.
    Carambus.config.carambus_api_url = nil
    @region = regions(:nbv)
    sign_in users(:admin)
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # Faengt die scrape_clubs-Argumente ab, ohne echtes Scraping auszuloesen.
  def capture_scrape_clubs_args
    captured = []
    @region.define_singleton_method(:scrape_clubs) do |season, opts = {}|
      captured << [season, opts]
      nil
    end
    Region.stub(:find, @region) do
      yield
    end
    captured
  end

  test "reload_from_cc uebergibt eine Season positional und player_details in opts" do
    captured = capture_scrape_clubs_args do
      post reload_from_cc_region_url(@region)
    end

    assert_equal 1, captured.size, "scrape_clubs wurde nicht genau einmal aufgerufen"
    season, opts = captured.first
    assert_kind_of Season, season, "erstes Argument muss eine Season sein, war: #{season.inspect}"
    assert_equal false, opts[:player_details]
  end

  test "reload_from_cc_with_details reicht player_details bis in die opts durch" do
    captured = capture_scrape_clubs_args do
      post reload_from_cc_with_details_region_url(@region)
    end

    assert_equal 1, captured.size
    season, opts = captured.first
    assert_kind_of Season, season, "erstes Argument muss eine Season sein, war: #{season.inspect}"
    assert_equal true, opts[:player_details],
      "player_details ging verloren — genau der Bug, der 'mit Details' wirkungslos machte"
  end
end
