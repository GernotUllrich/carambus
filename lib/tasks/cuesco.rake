# frozen_string_literal: true

namespace :cuesco do
  desc "Scrape live/recent tournaments and games from UMB Cuesco (Five&Six) and sync with local tournaments"
  task scrape_live: :environment do
    puts "Starting Cuesco live scraper..."

    games_imported = CuescoScraper.sync_active_tournaments

    puts "DONE. Imported #{games_imported} new games."

    if games_imported.positive?
      puts "Running auto-matching for videos..."
      Rake::Task["videos:match_to_games"].invoke
    end
  end

  desc "Scrape a specific tournament directly by internal tournament ID and Cuesco IDX"
  task :scrape_tournament, %i[tournament_id cuesco_idx] => :environment do |_, args|
    tournament = Tournament.find(args[:tournament_id])
    imported = CuescoScraper.scrape_tournament(tournament, args[:cuesco_idx])
    puts "Imported #{imported} new games for tournament '#{tournament.name}'."
  end
end
