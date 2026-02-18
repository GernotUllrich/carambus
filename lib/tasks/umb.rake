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
    
    tournaments = InternationalTournament
      .where(international_source: umb_source)
      .where("external_id IS NOT NULL OR data->>'umb_detail_url' IS NOT NULL")
    
    puts "Scraping details for #{tournaments.count} tournaments with detail URLs..."
    
    scraper = UmbScraper.new
    success_count = 0
    
    tournaments.find_each do |tournament|
      puts "\n#{tournament.name} (#{tournament.start_date})..."
      
      if scraper.scrape_tournament_details(tournament)
        success_count += 1
        puts "  ✓ Success"
      else
        puts "  ✗ Failed"
      end
      
      sleep 2  # Rate limiting
    end
    
    puts "\n✓ Completed: #{success_count}/#{tournaments.count} tournaments"
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
