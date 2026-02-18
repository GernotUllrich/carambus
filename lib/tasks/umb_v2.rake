# frozen_string_literal: true

namespace :umb_v2 do
  desc "Scrape a single UMB tournament by external_id"
  task :scrape, [:external_id] => :environment do |t, args|
    unless args[:external_id]
      puts "Usage: rails umb_v2:scrape[EXTERNAL_ID]"
      puts "Example: rails umb_v2:scrape[310]"
      exit 1
    end
    
    external_id = args[:external_id].to_i
    puts "Scraping UMB Tournament #{external_id}..."
    
    scraper = UmbScraperV2.new
    tournament = scraper.scrape_tournament(external_id)
    
    if tournament
      puts "\n✓ SUCCESS: #{tournament.title}"
      puts "  ID: #{tournament.id}"
      puts "  Date: #{tournament.date}"
      puts "  Location: #{tournament.location_text}"
      puts "  Seedings: #{tournament.seedings.count}"
      
      games = Game.where(tournament_id: tournament.id)
      puts "  Games: #{games.count}"
      
      if games.any?
        puts "\n  Sample Game:"
        game = games.first
        game.game_participations.order(:role).each do |gp|
          puts "    #{gp.player.fullname}: #{gp.points} pts in #{gp.innings} inn (avg #{gp.gd&.round(3)}, HS #{gp.hs})"
        end
      end
    else
      puts "\n✗ Failed to scrape tournament #{external_id}"
    end
  end
  
  desc "Show statistics for UMB data"
  task stats: :environment do
    puts "\n=== UMB Statistics ===\n"
    
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    if umb_source
      tournaments = InternationalTournament.where(international_source: umb_source)
      puts "Total Tournaments: #{tournaments.count}"
      
      tournaments_with_seedings = tournaments.joins(:seedings).distinct.count
      puts "  With Seedings: #{tournaments_with_seedings}"
      
      total_seedings = Seeding.joins(:tournament).where(tournaments: { type: 'InternationalTournament', international_source_id: umb_source.id }).count
      puts "  Total Seedings: #{total_seedings}"
      
      total_games = Game.joins(:tournament).where(tournaments: { type: 'InternationalTournament', international_source_id: umb_source.id }).count
      puts "  Total Games: #{total_games}"
      
      total_game_participations = GameParticipation.joins(game: :tournament).where(tournaments: { type: 'InternationalTournament', international_source_id: umb_source.id }).count
      puts "  Total GameParticipations: #{total_game_participations}"
      
      # Group by year
      puts "\n  By Year:"
      tournaments.group("EXTRACT(YEAR FROM date)").count.sort.each do |year, count|
        puts "    #{year}: #{count} tournaments"
      end
      
      # Group by tournament_type
      puts "\n  By Type:"
      tournaments.group("data->>'tournament_type'").count.each do |type, count|
        puts "    #{type}: #{count} tournaments"
      end
    else
      puts "UMB source not found"
    end
  end
  
  desc "Scrape multiple tournaments by ID range"
  task :scrape_range, [:start_id, :end_id] => :environment do |t, args|
    start_id = (args[:start_id] || 300).to_i
    end_id = (args[:end_id] || 320).to_i
    
    puts "Scraping UMB Tournaments #{start_id}..#{end_id}"
    
    scraper = UmbScraperV2.new
    success_count = 0
    failed_count = 0
    
    (start_id..end_id).each do |external_id|
      print "  Tournament #{external_id}... "
      
      tournament = scraper.scrape_tournament(external_id)
      
      if tournament
        games_count = Game.where(tournament_id: tournament.id).count
        puts "✓ #{tournament.title} (#{tournament.seedings.count} seedings, #{games_count} games)"
        success_count += 1
      else
        puts "✗ Not found or failed"
        failed_count += 1
      end
      
      sleep 2  # Be nice to the server
    end
    
    puts "\n✓ Complete: #{success_count} succeeded, #{failed_count} failed"
  end
end
