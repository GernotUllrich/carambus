# frozen_string_literal: true

require "test_helper"

# Tests for ScrapeUmbArchiveJob kwargs fix (SCRP-04).
# Verifies that perform passes start_id/end_id/batch_size to UmbScraper#scrape_tournament_archive.
class ScrapeUmbArchiveJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "perform calls scrape_tournament_archive with default kwargs" do
    fake_scraper = Minitest::Mock.new
    fake_scraper.expect(:scrape_tournament_archive, 0, [], start_id: 1, end_id: 500, batch_size: 50)

    UmbScraper.stub(:new, fake_scraper) do
      ScrapeUmbArchiveJob.new.perform
    end

    assert_mock fake_scraper
  end

  test "perform forwards custom start_id, end_id, batch_size to scraper" do
    fake_scraper = Minitest::Mock.new
    fake_scraper.expect(:scrape_tournament_archive, 5, [], start_id: 100, end_id: 200, batch_size: 25)

    UmbScraper.stub(:new, fake_scraper) do
      ScrapeUmbArchiveJob.new.perform(start_id: 100, end_id: 200, batch_size: 25)
    end

    assert_mock fake_scraper
  end

  test "perform does not accept discipline, year, or event_type parameters" do
    # The method signature must not include the old kwargs
    method = ScrapeUmbArchiveJob.instance_method(:perform)
    param_names = method.parameters.map(&:last)

    assert_includes param_names, :start_id
    assert_includes param_names, :end_id
    assert_includes param_names, :batch_size
    refute_includes param_names, :discipline
    refute_includes param_names, :year
    refute_includes param_names, :event_type
  end

  test "perform returns scraper result count" do
    fake_scraper = Minitest::Mock.new
    fake_scraper.expect(:scrape_tournament_archive, 42, [], start_id: 1, end_id: 500, batch_size: 50)

    UmbScraper.stub(:new, fake_scraper) do
      result = ScrapeUmbArchiveJob.new.perform
      assert_equal 42, result
    end

    fake_scraper.verify
  end
end
