# frozen_string_literal: true

module ScrapingHelpers
  # Helper to create a snapshot name from test context
  def snapshot_name(prefix, *args)
    suffix = args.map(&:to_s).map { |s| s.parameterize.underscore }.join('_')
    "#{prefix}_#{suffix}"
  end
  
  # Helper to mock ClubCloud HTML response
  def mock_clubcloud_html(url, html_content)
    stub_request(:get, url)
      .to_return(status: 200, body: html_content, headers: { 'Content-Type' => 'text/html' })
  end
  
  # Helper to read HTML fixture
  def read_html_fixture(filename)
    File.read(Rails.root.join('test', 'fixtures', 'html', filename))
  end
  
  # Helper to compare sync dates with tolerance
  def assert_sync_date_updated(record, since:, tolerance: 5.seconds)
    assert record.sync_date.present?, "sync_date should be set"
    assert record.sync_date >= since - tolerance,
           "sync_date (#{record.sync_date}) should be after #{since}"
  end
  
  # Helper to assert no sync date change
  def assert_sync_date_unchanged(record, original_sync_date)
    assert_equal original_sync_date, record.reload.sync_date,
                 "sync_date should not have changed"
  end
  
  # Helper to create a minimal tournament for scraping tests
  def create_scrapable_tournament(attrs = {})
    defaults = {
      title: "Test Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      state: "registration",
      discipline: disciplines(:carom_3band)
    }
    
    Tournament.create!(defaults.merge(attrs))
  end
  
  # Helper to verify tournament data was scraped correctly
  def assert_tournament_scraped(tournament)
    assert tournament.title.present?, "title should be scraped"
    assert tournament.date.present?, "date should be scraped"
    # Location might be optional depending on tournament
    assert tournament.sync_date.present?, "sync_date should be set"
  end
  
  # Helper to check if scraping detected changes
  def assert_scraping_detected_changes(record, *changed_attributes)
    changed_attributes.each do |attr|
      assert record.previous_changes.key?(attr.to_s),
             "Expected #{attr} to have changed during scraping"
    end
  end
  
  # Helper to stub ClubCloud authentication
  def stub_clubcloud_auth(region_cc)
    stub_request(:post, %r{#{region_cc.base_url}/.*login.*})
      .to_return(
        status: 200,
        body: '{"success": true, "sessionId": "test_session_123"}',
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
