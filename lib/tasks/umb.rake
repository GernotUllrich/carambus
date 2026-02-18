# frozen_string_literal: true

namespace :umb do
  desc "Scrape UMB future tournaments"
  task scrape_future: :environment do
    puts "Scraping UMB future tournaments..."
    
    scraper = UmbScraper.new
    count = scraper.scrape_future_tournaments
    
    puts "✓ Saved #{count} future tournaments"
  end
  
  desc "Scrape UMB tournament archive"
  task :scrape_archive, [:discipline, :year, :event_type] => :environment do |t, args|
    discipline = args[:discipline] || '3-Cushion'
    year = args[:year]
    event_type = args[:event_type]
    
    puts "Scraping UMB archive: #{discipline}, #{year || 'All Years'}, #{event_type || 'All Tournaments'}"
    
    scraper = UmbScraper.new
    count = scraper.scrape_tournament_archive(
      discipline: discipline,
      year: year,
      event_type: event_type
    )
    
    puts "✓ Saved #{count} tournaments"
  end
  
  desc "Scrape all historical data (all disciplines, all years)"
  task scrape_all_historical: :environment do
    disciplines = ['3-Cushion', '5-Pins', 'Artistique', 'Cadre 47/2', 'Cadre 71/2']
    total_count = 0
    
    disciplines.each do |discipline|
      puts "\n=== Scraping #{discipline} ==="
      scraper = UmbScraper.new
      count = scraper.scrape_tournament_archive(discipline: discipline)
      total_count += count
      puts "  → #{count} tournaments"
      
      # Rate limiting
      sleep 2 if count > 0
    end
    
    puts "\n✓ Total: #{total_count} tournaments saved"
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
      
      puts "\n=== UMB Tournament Statistics ==="
      puts "Total tournaments: #{total}"
      puts "\nBy type:"
      by_type.each { |type, count| puts "  #{type}: #{count}" }
      puts "\nBy year:"
      by_year.each { |year, count| puts "  #{year.to_i}: #{count}" }
    else
      puts "UMB source not found. Please run: rails db:seed"
    end
  end
end
