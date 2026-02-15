# frozen_string_literal: true

require "test_helper"

class SourceHandlerTest < ActiveSupport::TestCase
  # SourceHandler manages synchronization dates for scraped records
  # Critical for tracking when data was last updated from external sources
  
  test "remember_sync_date sets sync_date after save with source_url" do
    tournament = Tournament.create!(
      id: 50_000_010,
      title: "Test Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      source_url: "https://example.com/tournament/123"
    )
    
    # sync_date should be set automatically
    assert_not_nil tournament.reload.sync_date,
                   "sync_date should be set when source_url is present"
    
    assert_in_delta Time.current, tournament.sync_date, 5.seconds,
                    "sync_date should be recent"
  end
  
  test "remember_sync_date does not set sync_date without source_url" do
    tournament = Tournament.create!(
      id: 50_000_011,
      title: "Local Tournament",
      season: seasons(:current),
      organizer: regions(:nbv)
      # No source_url
    )
    
    assert_nil tournament.reload.sync_date,
               "sync_date should not be set without source_url"
  end
  
  test "sync_date updates on each save when source_url present" do
    tournament = Tournament.create!(
      id: 50_000_012,
      title: "Synced Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      source_url: "https://example.com/tournament/456"
    )
    
    first_sync = tournament.reload.sync_date
    
    travel_to 1.hour.from_now do
      tournament.update!(title: "Updated Title")
      second_sync = tournament.reload.sync_date
      
      assert second_sync > first_sync,
             "sync_date should update on subsequent saves"
    end
  end
  
  test "remember_sync_date only runs when record has changes" do
    tournament = Tournament.create!(
      id: 50_000_013,
      title: "Test",
      season: seasons(:current),
      organizer: regions(:nbv),
      source_url: "https://example.com/tournament/789"
    )
    
    initial_sync = tournament.reload.sync_date
    
    # Save without changes
    assert_nothing_raised { tournament.save! }
  end
end
