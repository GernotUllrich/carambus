# frozen_string_literal: true

namespace :umb do
  desc "Test UMB scraper improvements (discipline detection, knockout parsing)"
  task test_improvements: :environment do
    puts "\n" + "="*80
    puts "UMB SCRAPER IMPROVEMENTS TEST"
    puts "="*80
    
    scraper = UmbScraper.new
    
    # Test 1: Discipline Detection
    puts "\n--- TEST 1: Discipline Detection ---\n"
    
    test_tournaments = [
      { name: "World Championship 3 Cushion", expected: "Dreiband" },
      { name: "European Championship Cadre 47/2", expected: "Cadre 47" },
      { name: "World Cup Cadre 57/2", expected: "Cadre 57" },
      { name: "World Cup Cadre 71/2", expected: "Cadre 71" },
      { name: "National Championship 3-Cushion", expected: "Dreiband" },
      { name: "International Tournament Three Cushion", expected: "Dreiband" },
      { name: "World Cup 5-Pins", expected: "5-Pin" }
    ]
    
    passed = 0
    failed = 0
    
    test_tournaments.each do |test|
      discipline = scraper.send(:find_discipline_from_name, test[:name])
      result = discipline&.name || "NOT FOUND"
      status = result.include?(test[:expected]) ? "✓" : "✗"
      
      if status == "✓"
        passed += 1
      else
        failed += 1
      end
      
      puts "#{status} #{test[:name]}"
      puts "   → #{result}"
      if status == "✗"
        puts "   Expected: #{test[:expected]}"
      end
      puts
    end
    
    puts "Results: #{passed} passed, #{failed} failed\n"
    
    # Test 2: Method Availability
    puts "\n--- TEST 2: Method Availability ---\n"
    
    methods_to_check = [
      :parse_knockout_results_pdf,
      :create_games_from_matches
    ]
    
    methods_to_check.each do |method|
      if scraper.respond_to?(method, true)
        puts "✓ Method #{method} exists"
      else
        puts "✗ Method #{method} NOT FOUND"
      end
    end
    
    # Test 3: Real Tournament Check
    puts "\n--- TEST 3: Real Tournament Check ---\n"
    
    tournament = InternationalTournament.joins(:international_source)
      .where(international_sources: { source_type: 'umb' })
      .where('external_id IS NOT NULL')
      .order(date: :desc)
      .first
    
    if tournament
      puts "Sample tournament: #{tournament.title}"
      puts "External ID: #{tournament.external_id}"
      puts "Date: #{tournament.date}"
      puts "Current discipline: #{tournament.discipline&.name}"
      
      detected_discipline = scraper.send(:find_discipline_from_name, tournament.title)
      puts "Detected discipline: #{detected_discipline&.name}"
      
      if detected_discipline == tournament.discipline
        puts "✓ Discipline detection matches"
      else
        puts "⚠ Discipline mismatch (may need migration)"
      end
      
      # Check for PDF links
      if tournament.data.present?
        data = tournament.data.is_a?(String) ? JSON.parse(tournament.data) : tournament.data
        
        if data['pdf_links'].present?
          pdf_count = data['pdf_links'].size
          puts "✓ Tournament has #{pdf_count} PDF links"
          
          # Count game types
          game_types = data['game_types'] || []
          group_results = game_types.select { |gt| gt['category'] == 'group' }.size
          knockout_results = game_types.select { |gt| gt['category'] == 'main_tournament' }.size
          
          puts "  - Group phases: #{group_results}"
          puts "  - Knockout phases: #{knockout_results}"
        else
          puts "⚠ No PDF links found (tournament not fully scraped)"
        end
      end
    else
      puts "⚠ No UMB tournaments found in database"
      puts "  Run: rake umb:scrape_future"
    end
    
    puts "\n" + "="*80
    puts "TEST COMPLETE"
    puts "="*80 + "\n"
  end
end
