# frozen_string_literal: true

require "test_helper"

class ChangeDetectionTest < ActiveSupport::TestCase
  # Change Detection wird hauptsächlich durch SourceHandler Concern implementiert
  # Diese Tests sind ergänzend - Haupttests in test/concerns/source_handler_test.rb
  
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
  end
  
  # ============================================================================
  # BASIC CHANGE DETECTION (via SourceHandler)
  # ============================================================================
  
  test "sync_date is set when source_url is present" do
    tournament = Tournament.create!(
      id: 50_000_200,
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      source_url: "https://ndbv.de/tournament/123"  # SourceHandler triggert
    )
    
    assert_not_nil tournament.reload.sync_date,
                   "sync_date should be set when source_url is present"
  end
  
  test "sync_date updates when record changes with source_url" do
    tournament = Tournament.create!(
      id: 50_000_201,
      title: "Original Title",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      source_url: "https://ndbv.de/tournament/123"
    )
    
    original_sync_date = tournament.reload.sync_date
    sleep 0.01  # Minimal wait für unterschiedliche timestamps
    
    # Änderung durchführen
    tournament.title = "Changed Title"
    tournament.save!
    
    # sync_date sollte aktualisiert sein
    assert_not_equal original_sync_date, tournament.reload.sync_date,
                     "sync_date should update when record changes"
  end
  
  test "sync_date does not update when no changes" do
    tournament = Tournament.create!(
      id: 50_000_202,
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      source_url: "https://ndbv.de/tournament/123"
    )
    
    original_sync_date = tournament.reload.sync_date
    
    # Save ohne Änderungen
    tournament.save!
    
    # sync_date sollte NICHT aktualisiert sein
    assert_equal original_sync_date, tournament.reload.sync_date,
                 "sync_date should not update when no changes"
  end
  
  test "sync_date is not set when source_url is missing" do
    tournament = Tournament.create!(
      id: 50_000_203,
      title: "Local Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band)
      # Kein source_url!
    )
    
    assert_nil tournament.reload.sync_date,
               "sync_date should not be set without source_url"
  end
  
  # ============================================================================
  # REAL-WORLD CHANGE DETECTION SCENARIOS
  # ============================================================================
  
  test "multiple saves track sync_date correctly" do
    tournament = Tournament.create!(
      id: 50_000_204,
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      source_url: "https://ndbv.de/tournament/123"
    )
    
    sync_dates = []
    sync_dates << tournament.reload.sync_date
    
    # Erste Änderung
    sleep 0.01
    tournament.title = "Changed 1"
    tournament.save!
    sync_dates << tournament.reload.sync_date
    
    # Zweite Änderung
    sleep 0.01
    tournament.title = "Changed 2"
    tournament.save!
    sync_dates << tournament.reload.sync_date
    
    # Alle sync_dates sollten unterschiedlich sein
    assert_equal 3, sync_dates.uniq.size,
                 "Each change should create new sync_date"
  end
  
  # ============================================================================
  # DOCUMENTATION
  # ============================================================================
  
  # Weitere Change Detection Tests sind in test/concerns/source_handler_test.rb
  # 
  # Dort werden getestet:
  # - remember_sync_date Callback-Logik
  # - Verhalten mit/ohne source_url
  # - Verhalten mit/ohne Änderungen
  #
  # Diese Tests hier sind ergänzend und testen das Verhalten auf Model-Ebene
end
