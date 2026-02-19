# frozen_string_literal: true

namespace :umb do
  desc "Scrape UMB future tournaments"
  task scrape_future: :environment do
    puts "Scraping UMB future tournaments..."
    
    scraper = UmbScraper.new
    count = scraper.scrape_future_tournaments
    
    puts "✓ Saved #{count} future tournaments"
  end
  
  desc "Scrape UMB tournament archive by ID range"
  task :scrape_archive, [:start_id, :end_id] => :environment do |t, args|
    start_id = (args[:start_id] || 1).to_i
    end_id = (args[:end_id] || 500).to_i
    
    puts "Scraping UMB tournament archive: IDs #{start_id}..#{end_id}"
    puts "(This may take a while, checking each ID sequentially)"
    
    scraper = UmbScraper.new
    count = scraper.scrape_tournament_archive(
      start_id: start_id,
      end_id: end_id
    )
    
    puts "✓ Scraped and saved #{count} tournaments"
  end
  
  desc "Scrape all historical data (full sequential scan)"
  task :scrape_all_historical, [:max_id] => :environment do |t, args|
    max_id = (args[:max_id] || 1000).to_i
    
    puts "Scraping ALL historical UMB data (IDs 1..#{max_id})"
    puts "This will take a while, checking each ID sequentially..."
    
    scraper = UmbScraper.new
    count = scraper.scrape_tournament_archive(
      start_id: 1,
      end_id: max_id
    )
    
    puts "\n✓ Total: #{count} tournaments scraped"
  end
  
  desc "Scrape details for a specific tournament by ID"
  task :scrape_tournament_details, [:tournament_id] => :environment do |t, args|
    tournament_id = args[:tournament_id]
    
    unless tournament_id
      puts "Usage: rails umb:scrape_tournament_details[TOURNAMENT_ID]"
      exit 1
    end
    
    tournament = InternationalTournament.find(tournament_id)
    puts "Scraping details for: #{tournament.name}"
    
    scraper = UmbScraper.new
    success = scraper.scrape_tournament_details(tournament)
    
    if success
      puts "✓ Successfully scraped tournament details"
      puts "  PDF links: #{tournament.data['pdf_links']&.keys&.join(', ')}"
    else
      puts "✗ Failed to scrape tournament details"
    end
  end
  
  desc "Scrape details for all UMB tournaments"
  task scrape_all_details: :environment do
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    # Load all UMB tournaments with external_id
    tournaments = InternationalTournament
      .where(international_source: umb_source)
      .where.not(external_id: nil)
      .order(date: :desc)
    
    puts "Scraping details for #{tournaments.count} tournaments..."
    puts "="*80
    
    scraper = UmbScraper.new
    success_count = 0
    error_count = 0
    
    tournaments.find_each.with_index do |tournament, index|
      puts "\n[#{index + 1}/#{tournaments.count}] #{tournament.title} (#{tournament.date&.strftime('%Y-%m-%d')})..."
      
      if scraper.scrape_tournament_details(tournament, create_games: false, parse_pdfs: false)
        success_count += 1
        
        # Show what was updated
        updates = []
        updates << "Location: #{Location.find_by(id: tournament.location_id)&.name}" if tournament.location_id
        updates << "Season: #{tournament.season&.name}" if tournament.season_id
        updates << "Organizer: #{tournament.organizer_type&.constantize&.find_by(id: tournament.organizer_id)&.name rescue 'UMB'}" if tournament.organizer_id
        
        puts "  ✓ Updated: #{updates.join(', ')}"
      else
        error_count += 1
        puts "  ✗ Failed"
      end
      
      sleep 1  # Rate limiting
    end
    
    puts "\n" + "="*80
    puts "✓ Completed: #{success_count} successful, #{error_count} failed"
  end
  
  # All valid UMB tournament IDs (from form results - All Years, All Tournaments)
  VALID_TOURNAMENT_IDS = [
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
    40, 41, 42, 43, 45, 46, 48, 49, 50, 51, 52, 54, 55, 60, 61, 62, 63, 64, 65, 66,
    67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86,
    87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105,
    106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
    122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 136, 137, 138,
    139, 140, 141, 142, 143, 144, 146, 147, 148, 149, 150, 151, 152, 153, 154, 157,
    158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173,
    174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189,
    190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205,
    206, 207, 208, 209, 210, 211, 212, 214, 215, 216, 217, 218, 219, 220, 221, 222,
    223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238,
    239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254,
    255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 267, 268, 269, 270, 271,
    272, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291,
    293, 294, 295, 296, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 310, 311,
    312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 326, 327, 328,
    329, 330, 331, 332, 333, 335, 336, 337, 338, 346, 347, 348, 350, 351, 355, 356,
    357, 358, 359, 362, 363, 373, 374, 375
  ].freeze
  
  desc "Debug import for specific IDs"
  task :debug_import, [:ids] => :environment do |t, args|
    ids = args[:ids].split(',').map(&:to_i)
    
    puts "\n=== UMB Debug Import ==="
    puts "IDs: #{ids.inspect}"
    puts "="*80
    
    umb_source = InternationalSource.find_by(source_type: 'umb')
    scraper = UmbScraper.new
    
    ids.each_with_index do |external_id, index|
      puts "\n[#{index + 1}/#{ids.size}] ID #{external_id}..."
      
      begin
        # Find or create tournament
        tournament = InternationalTournament.find_by(
          international_source: umb_source,
          external_id: external_id.to_s
        )
        
        unless tournament
          puts "  Fetching tournament data..."
          tournament_data = scraper.send(:fetch_tournament_basic_data, external_id)
          
          if tournament_data
            tournament = scraper.send(:save_tournament_from_details, tournament_data)
            puts "  ✓ Created: #{tournament.title}"
          else
            puts "  ✗ Tournament not found on UMB server"
            next
          end
        else
          puts "  Tournament exists: #{tournament.title}"
        end
        
        # Scrape details with timeout protection
        puts "  Scraping details (with PDF parsing)..."
        Timeout.timeout(120) do  # 2 minute timeout per tournament
          if scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: true)
            tournament.reload
            games_count = tournament.games.count
            participations_count = tournament.games.joins(:game_participations).count rescue 0
            puts "  ✓ Scraped: #{games_count} games, #{participations_count} participations"
          else
            puts "  ✗ Failed to scrape details"
          end
        end
        
      rescue Timeout::Error => e
        puts "  ✗ TIMEOUT after 2 minutes - skipping this tournament"
      rescue => e
        puts "  ✗ ERROR: #{e.class} - #{e.message}"
        puts "    #{e.backtrace.first(3).join("\n    ")}"
      end
      
      sleep 1
    end
    
    puts "\n" + "="*80
    puts "Debug import complete"
  end
  
  desc "Import all valid UMB tournaments from known IDs (newest first)"
  task :import_all => :environment do
    puts "\n=== UMB Complete Import (All Valid Tournaments) ==="
    puts "Total IDs to check: #{VALID_TOURNAMENT_IDS.size}"
    puts "Processing NEWEST to OLDEST (reverse order)"
    puts "="*80
    
    umb_source = InternationalSource.find_by(source_type: 'umb')
    scraper = UmbScraper.new
    
    stats = {
      total: VALID_TOURNAMENT_IDS.size,
      already_exists: 0,
      newly_created: 0,
      failed_fetch: 0,
      details_scraped: 0,
      games_created: 0,
      participations_created: 0
    }
    
    VALID_TOURNAMENT_IDS.reverse.each_with_index do |external_id, index|
      puts "\n[#{index + 1}/#{VALID_TOURNAMENT_IDS.size}] ID #{external_id}..."
      
      # Check if tournament exists
      tournament = InternationalTournament.find_by(
        international_source: umb_source,
        external_id: external_id.to_s
      )
      
      if tournament
        puts "  Tournament exists: #{tournament.title}"
        stats[:already_exists] += 1
      else
        # Fetch basic info from details page to create tournament
        puts "  Fetching tournament data..."
        tournament_data = scraper.send(:fetch_tournament_basic_data, external_id)
        
        if tournament_data
          tournament = scraper.send(:save_tournament_from_details, tournament_data)
          if tournament
            puts "  ✓ Created: #{tournament.title}"
            stats[:newly_created] += 1
          else
            puts "  ✗ Failed to create tournament"
            stats[:failed_fetch] += 1
            next
          end
        else
          puts "  ✗ Tournament not found on UMB server"
          stats[:failed_fetch] += 1
          next
        end
      end
      
      # Scrape details and games
      games_before = tournament.games.count
      participations_before = tournament.games.joins(:game_participations).count rescue 0
      
      if scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: true)
        stats[:details_scraped] += 1
        
        tournament.reload
        games_after = tournament.games.count
        participations_after = tournament.games.joins(:game_participations).count rescue 0
        
        games_new = games_after - games_before
        participations_new = participations_after - participations_before
        
        stats[:games_created] += games_new
        stats[:participations_created] += participations_new
        
        puts "  ✓ Details scraped: #{games_new} new games, #{participations_new} new participations"
      else
        puts "  ✗ Failed to scrape details"
      end
      
      # Be nice to the server
      sleep 1
    end
    
    puts "\n" + "="*80
    puts "IMPORT COMPLETE"
    puts "="*80
    puts "\nStatistics:"
    puts "  Total IDs checked: #{stats[:total]}"
    puts "  Already existed: #{stats[:already_exists]}"
    puts "  Newly created: #{stats[:newly_created]}"
    puts "  Failed to fetch: #{stats[:failed_fetch]}"
    puts "  Details scraped: #{stats[:details_scraped]}"
    puts "  Total games created: #{stats[:games_created]}"
    puts "  Total participations created: #{stats[:participations_created]}"
    puts ""
  end
  
  desc "Scrape tournament details and game results sequentially"
  task :scrape_details, [:start_id, :end_id] => :environment do |t, args|
    start_id = (args[:start_id] || 300).to_i
    end_id = (args[:end_id] || 350).to_i
    
    puts "\n=== UMB Sequential Tournament Details Scraping ==="
    puts "ID Range: #{start_id} to #{end_id}"
    puts "="*80
    
    umb_source = InternationalSource.find_by(source_type: 'umb')
    scraper = UmbScraper.new
    
    stats = {
      total: 0,
      found: 0,
      scraped: 0,
      failed: 0,
      games_created: 0,
      participations_created: 0
    }
    
    (start_id..end_id).each do |external_id|
      stats[:total] += 1
      
      # Find tournament
      tournament = InternationalTournament.find_by(
        international_source: umb_source,
        external_id: external_id.to_s
      )
      
      unless tournament
        puts "  #{external_id}: Not found, skipping"
        next
      end
      
      stats[:found] += 1
      puts "\n#{external_id}: #{tournament.title}"
      
      games_before = tournament.games.count
      participations_before = tournament.games.joins(:game_participations).count
      
      # Scrape with PDF parsing
      if scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: true)
        stats[:scraped] += 1
        
        games_after = tournament.games.count
        participations_after = tournament.games.joins(:game_participations).count
        
        games_new = games_after - games_before
        participations_new = participations_after - participations_before
        
        stats[:games_created] += games_new
        stats[:participations_created] += participations_new
        
        puts "  ✓ Games: #{games_new} new (#{games_after} total)"
        puts "  ✓ Participations: #{participations_new} new (#{participations_after} total)"
      else
        stats[:failed] += 1
        puts "  ✗ Failed to scrape"
      end
      
      # Be nice to the server
      sleep 1
    end
    
    puts "\n" + "="*80
    puts "Summary:"
    puts "  Total IDs checked: #{stats[:total]}"
    puts "  Tournaments found: #{stats[:found]}"
    puts "  Successfully scraped: #{stats[:scraped]}"
    puts "  Failed: #{stats[:failed]}"
    puts "  Games created: #{stats[:games_created]}"
    puts "  Participations created: #{stats[:participations_created]}"
  end
  
  desc "Test scraping a single tournament by external_id"
  task :test_scrape, [:external_id, :parse_pdfs] => :environment do |t, args|
    external_id = args[:external_id] || '310'
    parse_pdfs = args[:parse_pdfs] == 'true' || args[:parse_pdfs] == '1'
    
    puts "\n=== Testing UMB Tournament Scraping ==="
    puts "External ID: #{external_id}"
    puts "Parse PDFs: #{parse_pdfs ? 'YES' : 'NO'}"
    puts "="*80
    
    # Find or create tournament
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    tournament = InternationalTournament.find_by(
      international_source: umb_source,
      external_id: external_id
    )
    
    unless tournament
      puts "✗ Tournament not found with external_id: #{external_id}"
      puts ""
      puts "IMPORTANT: This task does NOT create test tournaments!"
      puts "Please run one of these commands first:"
      puts "  1. rake umb:scrape_archived           # Import all tournaments from archive"
      puts "  2. Create tournament manually in database"
      puts ""
      puts "The tournament must exist before you can scrape its details and games."
      exit 1
    end
    
    puts "\nTournament: #{tournament.title} (ID: #{tournament.id})"
    puts "External ID: #{tournament.external_id}"
    puts ""
    
    scraper = UmbScraper.new
    success = scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: parse_pdfs)
    
    if success
      tournament.reload
      
      puts "\n✓ Successfully scraped tournament details"
      puts "\nData keys: #{tournament.data.keys.join(', ')}"
      
      if tournament.data['game_types'].present?
        puts "\nGame Types (#{tournament.data['game_types'].size}):"
        tournament.data['game_types'].each do |gt|
          puts "  - #{gt['name']} [#{gt['category']}]"
        end
      end
      
      if tournament.data['ranking_files'].present?
        puts "\nRanking Files (#{tournament.data['ranking_files'].size}):"
        tournament.data['ranking_files'].each do |rf|
          puts "  - #{rf['phase']}"
        end
      end
      
      # InternationalTournament IS a Tournament (STI), so it has games directly
      games_count = tournament.games.count
      if games_count > 0
        puts "\nGames created: #{games_count}"
        tournament.games.each do |game|
          participations_count = game.game_participations.count
          puts "  - #{game.gname} (#{participations_count} participations)"
        end
        
        if parse_pdfs
          total_participations = tournament.games.joins(:game_participations).count
          puts "\nTotal participations created: #{total_participations}"
        end
      else
        puts "\n⚠ No games were created"
      end
    else
      puts "\n✗ Failed to scrape tournament details"
    end
  end
  
  desc "Show UMB statistics"
  task stats: :environment do
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    if umb_source
      total = InternationalTournament.where(international_source: umb_source).count
      by_type = InternationalTournament.where(international_source: umb_source)
                                       .group(:tournament_type)
                                       .count
      by_year = InternationalTournament.where(international_source: umb_source)
                                       .group("EXTRACT(YEAR FROM start_date)")
                                       .count
                                       .sort.to_h
      
      with_details = InternationalTournament.where(international_source: umb_source)
                                           .where("data->>'pdf_links' IS NOT NULL")
                                           .count
      
      with_game_types = InternationalTournament.where(international_source: umb_source)
                                              .where("data->>'game_types' IS NOT NULL")
                                              .count
      
      with_participations = InternationalTournament.where(international_source: umb_source)
                                                  .joins(:international_participations)
                                                  .distinct
                                                  .count
      
      with_results = InternationalTournament.where(international_source: umb_source)
                                           .joins(:international_results)
                                           .distinct
                                           .count
      
      puts "\n=== UMB Tournament Statistics ==="
      puts "Total tournaments: #{total}"
      puts "With PDF details: #{with_details}"
      puts "With game types: #{with_game_types}"
      puts "With participations: #{with_participations}"
      puts "With results: #{with_results}"
      puts "\nBy type:"
      by_type.each { |type, count| puts "  #{type}: #{count}" }
      puts "\nBy year:"
      by_year.each { |year, count| puts "  #{year.to_i}: #{count}" }
    else
      puts "UMB source not found. Please run: rails db:seed"
    end
  end
end
