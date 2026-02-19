# frozen_string_literal: true

namespace :umb do
  desc "Fix missing location_id and season_id for all UMB tournaments"
  task fix_tournaments: :environment do
    puts "=" * 80
    puts "Fixing UMB Tournament Location and Season IDs"
    puts "=" * 80
    
    umb_region = Region.find_by(shortname: 'UMB')
    unless umb_region
      puts "ERROR: UMB region not found!"
      exit 1
    end
    
    tournaments = InternationalTournament.where(organizer_id: umb_region.id)
    total = tournaments.count
    
    puts "Found #{total} UMB tournaments"
    puts
    
    # Ensure seasons exist
    puts "Ensuring seasons exist..."
    Season.update_seasons
    puts "✓ Seasons updated"
    puts
    
    fixed_location = 0
    fixed_season = 0
    created_locations = 0
    
    tournaments.find_each.with_index do |tournament, index|
      print "\rProcessing #{index + 1}/#{total}..." if (index + 1) % 10 == 0
      
      updated = false
      
      # Fix location_id if missing
      if tournament.location_id.blank? && tournament.location_text.present? && !tournament.location_text.strip.empty?
        # Parse location
        if tournament.location_text.match(/^(.+?)\s*\(([^)]+)\)\s*$/)
          city = $1.strip
          country_name = $2.strip
        else
          city = tournament.location_text.strip
          country_name = nil
        end
        
        # Find country
        country = if country_name.present?
                    Country.where('name ILIKE ? OR shortname ILIKE ?', country_name, country_name).first
                  end
        
        # Find or create location
        location = if country
                     Location.where('name ILIKE ?', city)
                             .where(country_id: country.id)
                             .first
                   else
                     Location.where('name ILIKE ?', city).first
                   end
        
        unless location
          location = Location.create(
            name: city,
            country_id: country&.id,
            organizer: umb_region,
            global_context: 'international'
          )
          
          if location.persisted?
            created_locations += 1
          else
            puts "\nWarning: Failed to create location for '#{city}': #{location.errors.full_messages.join(', ')}"
            next
          end
        end
        
        tournament.update_column(:location_id, location.id)
        fixed_location += 1
        updated = true
      end
      
      # Fix season_id if missing or pointing to "Unknown Season"
      needs_season_fix = (tournament.season_id.blank? || 
                         (tournament.season_id == 20 && tournament.date.present?))
      
      if needs_season_fix && tournament.date.present?
        season = Season.season_from_date(tournament.date)
        
        if season && season.id != tournament.season_id
          tournament.update_column(:season_id, season.id)
          fixed_season += 1
          updated = true
        end
      end
      
      print " ✓" if updated
    end
    
    puts "\n"
    puts "=" * 80
    puts "Summary:"
    puts "  Total tournaments: #{total}"
    puts "  Fixed location_id: #{fixed_location}"
    puts "  Created locations: #{created_locations}"
    puts "  Fixed season_id: #{fixed_season}"
    puts "=" * 80
    puts
    puts "✓ Done!"
  end
end
