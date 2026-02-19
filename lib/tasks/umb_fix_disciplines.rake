# frozen_string_literal: true

namespace :umb do
  desc "Fix discipline detection for existing UMB tournaments"
  task fix_disciplines: :environment do
    puts "\n" + "="*80
    puts "UMB DISCIPLINE DETECTION FIX"
    puts "="*80 + "\n"
    
    scraper = UmbScraper.new
    
    # Find all UMB tournaments
    tournaments = InternationalTournament.joins(:international_source)
      .where(international_sources: { source_type: 'umb' })
      .order(date: :desc)
    
    puts "Found #{tournaments.count} UMB tournaments"
    puts "Checking discipline detection...\n"
    
    changes = []
    no_change = 0
    errors = 0
    
    tournaments.each do |tournament|
      begin
        current_discipline = tournament.discipline
        detected_discipline = scraper.send(:find_discipline_from_name, tournament.title)
        
        if detected_discipline && detected_discipline.id != current_discipline&.id
          changes << {
            tournament: tournament,
            old_discipline: current_discipline,
            new_discipline: detected_discipline
          }
          
          puts "CHANGE: #{tournament.title}"
          puts "  Current:  #{current_discipline&.name || 'NONE'}"
          puts "  Detected: #{detected_discipline.name}"
          puts
        else
          no_change += 1
        end
      rescue StandardError => e
        errors += 1
        puts "ERROR: #{tournament.title}: #{e.message}"
      end
    end
    
    puts "\n" + "-"*80
    puts "Summary:"
    puts "  Total tournaments: #{tournaments.count}"
    puts "  Needs change: #{changes.size}"
    puts "  No change needed: #{no_change}"
    puts "  Errors: #{errors}"
    puts "-"*80 + "\n"
    
    if changes.any?
      puts "Apply changes? (y/n)"
      response = STDIN.gets.chomp.downcase
      
      if response == 'y'
        updated = 0
        changes.each do |change|
          tournament = change[:tournament]
          new_discipline = change[:new_discipline]
          
          if tournament.update(discipline: new_discipline)
            updated += 1
            puts "✓ Updated: #{tournament.title} → #{new_discipline.name}"
          else
            puts "✗ Failed: #{tournament.title}: #{tournament.errors.full_messages}"
          end
        end
        
        puts "\n✓ Updated #{updated} of #{changes.size} tournaments"
      else
        puts "\nNo changes applied."
      end
    else
      puts "No changes needed!"
    end
    
    puts "\n" + "="*80 + "\n"
  end
  
  desc "Show discipline statistics for UMB tournaments"
  task discipline_stats: :environment do
    puts "\n" + "="*80
    puts "UMB TOURNAMENT DISCIPLINE STATISTICS"
    puts "="*80 + "\n"
    
    tournaments = InternationalTournament.joins(:international_source)
      .where(international_sources: { source_type: 'umb' })
      .includes(:discipline)
    
    by_discipline = tournaments.group_by { |t| t.discipline&.name || 'Unknown' }
    
    puts "Total UMB tournaments: #{tournaments.count}\n"
    puts "By discipline:"
    
    by_discipline.sort_by { |_, ts| -ts.size }.each do |discipline_name, ts|
      puts "  #{discipline_name}: #{ts.size}"
      
      # Show a few examples
      ts.first(3).each do |t|
        puts "    - #{t.title} (#{t.date&.year})"
      end
      puts "    ..." if ts.size > 3
      puts
    end
    
    puts "="*80 + "\n"
  end
end
