# frozen_string_literal: true

namespace :umb do
  desc "Efficiently update UMB tournaments (incremental scraping)"
  task update: :environment do
    puts "\n" + "="*80
    puts "UMB INCREMENTAL UPDATE"
    puts "="*80 + "\n"
    
    scraper = UmbScraper.new
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    unless umb_source
      puts "✗ UMB source not found. Run: rake placeholders:create"
      exit 1
    end
    
    stats = {
      future_tournaments: 0,
      new_tournaments: 0,
      updated_tournaments: 0,
      fixed_organizers: 0,
      errors: []
    }
    
    # Step 0: Ensure UMB organizer exists (critical!)
    umb_organizer = scraper.send(:find_or_create_umb_organizer)
    unless umb_organizer
      puts "✗ CRITICAL ERROR: Could not create/find UMB organizer!"
      puts "Please check your database and run: rake placeholders:create"
      exit 1
    end
    puts "✓ UMB Organizer ready: #{umb_organizer.name} (ID: #{umb_organizer.id})\n"
    
    # Step 1: Scrape future tournaments
    puts "Step 1: Scraping future tournaments..."
    puts "-"*80
    begin
      future_count = scraper.scrape_future_tournaments
      stats[:future_tournaments] = future_count
      puts "✓ Found #{future_count} future tournaments\n"
    rescue => e
      puts "✗ Error scraping future tournaments: #{e.message}"
      stats[:errors] << "future: #{e.message}"
    end
    
    # Step 2: Check for new tournament IDs beyond current max
    puts "\nStep 2: Checking for new tournament IDs..."
    puts "-"*80
    current_max = InternationalTournament
      .where(international_source: umb_source)
      .where.not(external_id: nil)
      .maximum(:external_id)
      .to_i
    
    # Check from current_max to current_max + 100 for new tournaments
    check_from = [current_max, 350].max
    check_to = check_from + 100
    
    puts "Current max external_id: #{current_max}"
    puts "Checking IDs #{check_from}..#{check_to} for new tournaments..."
    
    (check_from..check_to).each do |external_id|
      next if InternationalTournament.exists?(
        international_source: umb_source,
        external_id: external_id.to_s
      )
      
      print "  Checking ID #{external_id}... "
      tournament_data = scraper.send(:fetch_tournament_basic_data, external_id)
      
      if tournament_data && tournament_data[:name].present?
        tournament = scraper.send(:save_tournament_from_details, tournament_data)
        if tournament
          puts "✓ NEW: #{tournament_data[:name]}"
          stats[:new_tournaments] += 1
          sleep 0.5 # Rate limiting
        else
          puts "✗ Failed to save"
        end
      else
        puts "not found"
      end
    end
    
    # Step 3: Fix missing organizers
    puts "\nStep 3: Fixing missing organizers..."
    puts "-"*80
    tournaments_without_organizer = InternationalTournament
      .where(international_source: umb_source, organizer_id: nil)
    
    puts "Found #{tournaments_without_organizer.count} tournaments without organizer"
    
    umb_organizer = scraper.send(:find_or_create_umb_organizer)
    
    if umb_organizer
      tournaments_without_organizer.find_each do |tournament|
        tournament.update_columns(
          organizer_id: umb_organizer.id,
          organizer_type: 'Region'
        )
        stats[:fixed_organizers] += 1
      end
      puts "✓ Fixed #{stats[:fixed_organizers]} tournaments"
    else
      puts "✗ Could not create UMB organizer"
    end
    
    # Step 4: Update recent tournaments with results
    puts "\nStep 4: Updating recent tournaments with results..."
    puts "-"*80
    
    # Get tournaments from last 2 years that need updates
    # (either no games or haven't been updated recently)
    cutoff_date = 2.years.ago
    all_recent = InternationalTournament
      .where(international_source: umb_source)
      .where('date >= ?', cutoff_date)
      .includes(:games)
      .order(date: :desc)
    
    recent_tournaments = all_recent.select do |t|
      t.games.empty? || (t.data.is_a?(Hash) && t.data['detail_scraped_at'].nil?) || 
        (t.data.is_a?(String) && !t.data.include?('detail_scraped_at'))
    end.first(50)
    
    puts "Found #{recent_tournaments.count} recent tournaments to update"
    
    recent_tournaments.each_with_index do |tournament, index|
      puts "\n[#{index + 1}/#{recent_tournaments.count}] #{tournament.title} (#{tournament.date&.strftime('%Y-%m-%d')})"
      
      if scraper.scrape_tournament_details(tournament, create_games: true, parse_pdfs: true)
        stats[:updated_tournaments] += 1
        puts "  ✓ Updated with results"
      else
        puts "  ✗ Failed to update"
        stats[:errors] << "#{tournament.title}: update failed"
      end
      
      sleep 1 # Rate limiting
    end
    
    # Summary
    puts "\n" + "="*80
    puts "UPDATE COMPLETE"
    puts "="*80
    puts "\nStatistics:"
    puts "  Future tournaments scraped: #{stats[:future_tournaments]}"
    puts "  New tournaments discovered: #{stats[:new_tournaments]}"
    puts "  Recent tournaments updated: #{stats[:updated_tournaments]}"
    puts "  Organizers fixed: #{stats[:fixed_organizers]}"
    puts "  Errors: #{stats[:errors].size}"
    
    if stats[:errors].any?
      puts "\nErrors:"
      stats[:errors].each { |err| puts "  - #{err}" }
    end
    
    puts ""
  end
  
  desc "Quick check for new UMB tournaments (scans recent IDs only)"
  task check_new: :environment do
    puts "\n" + "="*80
    puts "UMB NEW TOURNAMENT CHECK"
    puts "="*80 + "\n"
    
    scraper = UmbScraper.new
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    current_max = InternationalTournament
      .where(international_source: umb_source)
      .where.not(external_id: nil)
      .maximum(:external_id)
      .to_i
    
    check_from = [current_max - 10, 1].max
    check_to = current_max + 50
    
    puts "Scanning IDs #{check_from}..#{check_to}..."
    puts "-"*80
    
    new_count = 0
    
    (check_from..check_to).each do |external_id|
      next if InternationalTournament.exists?(
        international_source: umb_source,
        external_id: external_id.to_s
      )
      
      tournament_data = scraper.send(:fetch_tournament_basic_data, external_id)
      
      if tournament_data && tournament_data[:name].present?
        puts "NEW: ID #{external_id} - #{tournament_data[:name]} (#{tournament_data[:start_date]})"
        new_count += 1
      end
      
      sleep 0.5
    end
    
    puts "\n✓ Found #{new_count} new tournaments"
    puts "Run 'rake umb:update' to import them"
    puts ""
  end
  
  desc "Fix all UMB tournament organizers"
  task fix_organizers: :environment do
    puts "\n" + "="*80
    puts "FIX UMB ORGANIZERS"
    puts "="*80 + "\n"
    
    scraper = UmbScraper.new
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    umb_organizer = scraper.send(:find_or_create_umb_organizer)
    
    unless umb_organizer
      puts "✗ Could not create/find UMB organizer"
      exit 1
    end
    
    puts "UMB Organizer: #{umb_organizer.name} (ID: #{umb_organizer.id})"
    
    tournaments = InternationalTournament
      .where(international_source: umb_source)
      .where(organizer_id: nil)
    
    puts "Found #{tournaments.count} tournaments without organizer"
    
    if tournaments.any?
      updated = tournaments.update_all(
        organizer_id: umb_organizer.id,
        organizer_type: 'Region'
      )
      puts "✓ Fixed #{updated} tournaments"
    else
      puts "✓ All tournaments already have organizer"
    end
    
    puts ""
  end
  
  desc "Comprehensive UMB status report"
  task status: :environment do
    umb_source = InternationalSource.find_by(source_type: 'umb')
    
    puts "\n" + "="*80
    puts "UMB SCRAPING STATUS REPORT"
    puts "="*80 + "\n"
    
    if umb_source
      total = InternationalTournament.where(international_source: umb_source).count
      
      with_organizer = InternationalTournament
        .where(international_source: umb_source)
        .where.not(organizer_id: nil)
        .count
      
      with_details = InternationalTournament
        .where(international_source: umb_source)
        .where("data LIKE ?", '%pdf_links%')
        .count
      
      with_games = InternationalTournament
        .where(international_source: umb_source)
        .joins(:games)
        .distinct
        .count
      
      future = InternationalTournament
        .where(international_source: umb_source)
        .where('date > ?', Date.today)
        .count
      
      past_30_days = InternationalTournament
        .where(international_source: umb_source)
        .where('date > ?', 30.days.ago)
        .count
      
      max_external_id = InternationalTournament
        .where(international_source: umb_source)
        .where.not(external_id: nil)
        .maximum(:external_id)
        .to_i
      
      puts "Database Status:"
      puts "  Total tournaments: #{total}"
      puts "  With organizer: #{with_organizer} (#{((with_organizer.to_f / total * 100).round(1) rescue 0)}%)"
      puts "  With PDF details: #{with_details} (#{((with_details.to_f / total * 100).round(1) rescue 0)}%)"
      puts "  With games: #{with_games} (#{((with_games.to_f / total * 100).round(1) rescue 0)}%)"
      puts "  Future tournaments: #{future}"
      puts "  In last 30 days: #{past_30_days}"
      puts "  Highest external_id: #{max_external_id}"
      
      puts "\nData Quality Issues:"
      puts "  Missing organizer: #{total - with_organizer}"
      puts "  Missing details: #{total - with_details}"
      puts "  Missing games: #{total - with_games}"
      
      puts "\nRecommendations:"
      if with_organizer < total
        puts "  → Run: rake umb:fix_organizers"
      end
      if future == 0
        puts "  → Run: rake umb:update (includes future tournaments)"
      end
      if with_details < total * 0.8
        puts "  → Run: rake umb:update (updates tournament details)"
      end
      
    else
      puts "✗ UMB source not found"
      puts "Run: rake placeholders:create"
    end
    
    puts "\n" + "="*80 + "\n"
  end
end
