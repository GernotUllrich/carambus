# frozen_string_literal: true

namespace :umb do
  desc "Re-scrape tournament details for UMB tournaments without location_id"
  task rescrape_missing_locations: :environment do
    require_relative '../../app/services/umb_scraper'
    
    puts "=" * 80
    puts "Re-scraping UMB Tournament Details for Missing Locations"
    puts "=" * 80
    
    umb_region = Region.find_by(shortname: 'UMB')
    unless umb_region
      puts "ERROR: UMB region not found!"
      exit 1
    end
    
    # Find tournaments without location_id but with external_id
    tournaments = InternationalTournament
                    .where(organizer_id: umb_region.id, location_id: nil)
                    .where.not(external_id: nil)
                    .order(:external_id)
    
    total = tournaments.count
    puts "Found #{total} tournaments to re-scrape"
    puts
    
    scraper = UmbScraper.new
    success_count = 0
    failed_count = 0
    
    tournaments.each_with_index do |tournament, index|
      external_id = tournament.external_id.to_i
      puts "[#{index + 1}/#{total}] Tournament #{tournament.id}: #{tournament.title}"
      puts "  External ID: #{external_id}"
      
      begin
        # Scrape tournament details
        details = scraper.scrape_tournament_details(tournament, create_games: false, parse_pdfs: false)
        
        if details
          # Reload tournament to check if location was set
          tournament.reload
          
          if tournament.location_id.present?
            location_record = Location.find_by(id: tournament.location_id)
            puts "  ✓ Location set: #{location_record&.name} (ID: #{tournament.location_id})"
            success_count += 1
          else
            puts "  ⚠ No location found in details"
            puts "  location_text: '#{tournament.location_text}'"
            failed_count += 1
          end
        else
          puts "  ✗ Failed to scrape details"
          failed_count += 1
        end
        
        # Be nice to the server
        sleep(1) if (index + 1) % 5 == 0
        
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}"
        failed_count += 1
      end
      
      puts
    end
    
    puts "=" * 80
    puts "Summary:"
    puts "  Total tournaments: #{total}"
    puts "  Successfully updated: #{success_count}"
    puts "  Failed: #{failed_count}"
    puts "=" * 80
    puts
    puts "✓ Done!"
  end
end
