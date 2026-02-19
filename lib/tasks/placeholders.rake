# frozen_string_literal: true

namespace :placeholders do
  desc "Create placeholder records for missing references"
  task create: :environment do
    load Rails.root.join('db', 'seeds', 'placeholder_records.rb')
  end
  
  desc "List all records with placeholder references"
  task list_incomplete: :environment do
    puts "\n" + "="*80
    puts "INCOMPLETE RECORDS (with placeholder references)"
    puts "="*80 + "\n"
    
    # InternationalTournaments
    incomplete_tournaments = InternationalTournament.with_placeholders
    
    if incomplete_tournaments.any?
      puts "InternationalTournaments: #{incomplete_tournaments.count}"
      puts "-" * 80
      
      incomplete_tournaments.limit(20).each do |tournament|
        puts "ID: #{tournament.id}"
        puts "  Title: #{tournament.title}"
        puts "  Date: #{tournament.date}"
        puts "  Issues: #{tournament.placeholder_description}"
        
        # Show current values
        if tournament.is_placeholder_field?(:discipline_id)
          puts "    → Discipline: #{tournament.discipline&.name}"
        end
        if tournament.is_placeholder_field?(:season_id)
          puts "    → Season: #{tournament.season&.name}"
        end
        if tournament.is_placeholder_field?(:location_id)
          puts "    → Location: #{tournament.location&.name}"
        end
        if tournament.is_placeholder_field?(:organizer_id)
          puts "    → Organizer: #{tournament.organizer&.name rescue 'N/A'}"
        end
        puts
      end
      
      if incomplete_tournaments.count > 20
        puts "... and #{incomplete_tournaments.count - 20} more"
        puts
      end
    else
      puts "✓ No incomplete InternationalTournaments found!"
    end
    
    puts "="*80 + "\n"
  end
  
  desc "Show statistics about placeholder usage"
  task stats: :environment do
    puts "\n" + "="*80
    puts "PLACEHOLDER STATISTICS"
    puts "="*80 + "\n"
    
    total = InternationalTournament.count
    incomplete = InternationalTournament.with_placeholders.count
    complete = InternationalTournament.complete.count
    
    puts "InternationalTournaments:"
    puts "  Total: #{total}"
    puts "  Complete: #{complete} (#{(complete.to_f / total * 100).round(1)}%)"
    puts "  Incomplete: #{incomplete} (#{(incomplete.to_f / total * 100).round(1)}%)"
    puts
    
    # Breakdown by field
    unknown_discipline = InternationalTournament.joins(:discipline)
      .where(disciplines: { name: 'Unknown Discipline' }).count
    unknown_season = InternationalTournament.joins(:season)
      .where(seasons: { name: 'Unknown Season' }).count
    unknown_location = InternationalTournament.joins(:location)
      .where(locations: { name: 'Unknown Location' }).count
    unknown_organizer = InternationalTournament
      .where(organizer_type: 'Region')
      .joins('LEFT JOIN regions ON regions.id = tournaments.organizer_id')
      .where('regions.shortname = ?', 'UNKNOWN').count
    
    puts "Breakdown by field:"
    puts "  Unknown Discipline: #{unknown_discipline}"
    puts "  Unknown Season: #{unknown_season}"
    puts "  Unknown Location: #{unknown_location}"
    puts "  Unknown Organizer: #{unknown_organizer}"
    puts
    
    puts "="*80 + "\n"
  end
  
  desc "Fix incomplete records interactively"
  task fix_interactive: :environment do
    require 'io/console'
    
    puts "\n" + "="*80
    puts "INTERACTIVE FIX FOR INCOMPLETE RECORDS"
    puts "="*80 + "\n"
    
    incomplete_tournaments = InternationalTournament.with_placeholders.order(date: :desc)
    
    if incomplete_tournaments.empty?
      puts "✓ No incomplete records found!"
      exit
    end
    
    puts "Found #{incomplete_tournaments.count} incomplete tournaments"
    puts "Press 'q' to quit, 's' to skip, or Enter to fix each record\n\n"
    
    incomplete_tournaments.each_with_index do |tournament, index|
      puts "\n" + "-"*80
      puts "[#{index + 1}/#{incomplete_tournaments.count}] Tournament: #{tournament.title}"
      puts "Date: #{tournament.date}"
      puts "Issues: #{tournament.placeholder_description}"
      puts
      
      # Fix discipline
      if tournament.is_placeholder_field?(:discipline_id)
        puts "Current Discipline: #{tournament.discipline.name}"
        puts "Available disciplines:"
        Discipline.where.not(name: 'Unknown Discipline').limit(10).each_with_index do |d, i|
          puts "  #{i + 1}. #{d.name}"
        end
        puts "Enter number (or 's' to skip): "
        input = STDIN.gets.chomp
        
        case input
        when 'q'
          puts "Exiting..."
          exit
        when 's'
          next
        when /^\d+$/
          discipline = Discipline.where.not(name: 'Unknown Discipline').limit(10).offset(input.to_i - 1).first
          if discipline
            tournament.update(discipline: discipline)
            puts "✓ Updated discipline to: #{discipline.name}"
          end
        end
      end
      
      # Similar for other fields...
      # (can be expanded)
    end
    
    puts "\n✓ Interactive fix completed!"
  end
  
  desc "Auto-fix discipline based on tournament title"
  task auto_fix_disciplines: :environment do
    puts "\n" + "="*80
    puts "AUTO-FIX DISCIPLINES"
    puts "="*80 + "\n"
    
    scraper = UmbScraper.new
    unknown_discipline = Discipline.find_by(name: 'Unknown Discipline')
    
    return unless unknown_discipline
    
    tournaments = InternationalTournament.where(discipline: unknown_discipline)
    
    puts "Found #{tournaments.count} tournaments with unknown discipline"
    
    fixed = 0
    tournaments.each do |tournament|
      detected_discipline = scraper.send(:find_discipline_from_name, tournament.title)
      
      if detected_discipline && detected_discipline != unknown_discipline
        tournament.update(discipline: detected_discipline)
        puts "✓ #{tournament.title} → #{detected_discipline.name}"
        fixed += 1
      end
    end
    
    puts "\n✓ Fixed #{fixed} of #{tournaments.count} tournaments"
    puts "="*80 + "\n"
  end
  
  desc "Check for suspicious placeholder usage (tournaments with first record IDs)"
  task check_suspicious: :environment do
    puts "\n" + "="*80
    puts "SUSPICIOUS PLACEHOLDER USAGE CHECK"
    puts "="*80 + "\n"
    
    # Get the IDs of first records (which should NOT be used as fallback)
    first_discipline_id = Discipline.order(:id).first&.id
    first_season_id = Season.order(:id).first&.id
    first_region_id = Region.order(:id).first&.id
    
    # Get placeholder IDs
    unknown_discipline_id = Discipline.find_by(name: 'Unknown Discipline')&.id
    unknown_season_id = Season.find_by(name: 'Unknown Season')&.id
    unknown_region_id = Region.find_by(shortname: 'UNKNOWN')&.id
    
    suspicious_count = 0
    
    # Check for tournaments using first records (excluding placeholders)
    if first_discipline_id && first_discipline_id != unknown_discipline_id
      count = InternationalTournament.where(discipline_id: first_discipline_id).count
      if count > 0
        puts "⚠ WARNING: #{count} tournaments use Discipline.first (ID: #{first_discipline_id})"
        puts "   This is likely incorrect!"
        suspicious_count += count
      end
    end
    
    if first_season_id && first_season_id != unknown_season_id
      count = InternationalTournament.where(season_id: first_season_id).count
      if count > 0
        puts "⚠ WARNING: #{count} tournaments use Season.first (ID: #{first_season_id})"
        puts "   This is likely incorrect!"
        suspicious_count += count
      end
    end
    
    if first_region_id && first_region_id != unknown_region_id
      count = InternationalTournament.where(organizer_id: first_region_id, organizer_type: 'Region').count
      if count > 0
        puts "⚠ WARNING: #{count} tournaments use Region.first (ID: #{first_region_id})"
        puts "   This is likely incorrect!"
        suspicious_count += count
      end
    end
    
    if suspicious_count == 0
      puts "✓ No suspicious usage detected!"
      puts "  All tournaments use proper placeholders or valid references."
    else
      puts "\n⚠ Total suspicious records: #{suspicious_count}"
      puts "\nRecommendation:"
      puts "  Run: rake placeholders:auto_fix_disciplines"
      puts "  Then manually review remaining records in /admin/incomplete_records"
    end
    
    puts "\n" + "="*80 + "\n"
  end
  
  desc "Migrate existing records that use .first to use placeholders instead"
  task migrate_to_placeholders: :environment do
    puts "\n" + "="*80
    puts "MIGRATE EXISTING RECORDS TO PLACEHOLDERS"
    puts "="*80 + "\n"
    
    # Get IDs
    first_discipline_id = Discipline.order(:id).first&.id
    first_season_id = Season.order(:id).first&.id
    first_region_id = Region.order(:id).first&.id
    
    unknown_discipline = Discipline.find_by(name: 'Unknown Discipline')
    unknown_season = Season.find_by(name: 'Unknown Season')
    unknown_region = Region.find_by(shortname: 'UNKNOWN')
    
    unless unknown_discipline && unknown_season && unknown_region
      puts "❌ ERROR: Placeholder records not found!"
      puts "   Run: rake placeholders:create"
      exit 1
    end
    
    total_migrated = 0
    
    # Migrate disciplines
    if first_discipline_id && first_discipline_id != unknown_discipline.id
      tournaments = InternationalTournament.where(discipline_id: first_discipline_id)
      count = tournaments.count
      
      if count > 0
        puts "Migrating #{count} tournaments from Discipline.first to Unknown Discipline..."
        
        # Try to auto-fix based on title first
        scraper = UmbScraper.new
        auto_fixed = 0
        
        tournaments.find_each do |tournament|
          detected = scraper.send(:find_discipline_from_name, tournament.title)
          
          if detected && detected.id != first_discipline_id
            tournament.update_column(:discipline_id, detected.id)
            auto_fixed += 1
            print "."
          else
            tournament.update_column(:discipline_id, unknown_discipline.id)
            print "u"
          end
        end
        
        puts "\n  ✓ Auto-fixed: #{auto_fixed}"
        puts "  ✓ Set to Unknown: #{count - auto_fixed}"
        total_migrated += count
      end
    end
    
    # Migrate seasons
    if first_season_id && first_season_id != unknown_season.id
      tournaments = InternationalTournament.where(season_id: first_season_id)
      count = tournaments.count
      
      if count > 0
        puts "\nMigrating #{count} tournaments from Season.first to Unknown Season..."
        
        # Try to derive from date
        derived = 0
        
        tournaments.find_each do |tournament|
          if tournament.date.present?
            season = Season.season_from_date(tournament.date)
            if season && season.id != first_season_id
              tournament.update_column(:season_id, season.id)
              derived += 1
              print "."
            else
              tournament.update_column(:season_id, unknown_season.id)
              print "u"
            end
          else
            tournament.update_column(:season_id, unknown_season.id)
            print "u"
          end
        end
        
        puts "\n  ✓ Derived from date: #{derived}"
        puts "  ✓ Set to Unknown: #{count - derived}"
        total_migrated += count
      end
    end
    
    # Migrate organizers
    if first_region_id && first_region_id != unknown_region.id
      tournaments = InternationalTournament.where(organizer_id: first_region_id, organizer_type: 'Region')
      count = tournaments.count
      
      if count > 0
        puts "\nMigrating #{count} tournaments from Region.first to Unknown Region..."
        
        # Try to find UMB region
        umb_region = Region.find_by(shortname: 'UMB')
        umb_fixed = 0
        
        tournaments.find_each do |tournament|
          # If from UMB source, use UMB region
          if tournament.international_source&.source_type == 'umb' && umb_region
            tournament.update_columns(organizer_id: umb_region.id, organizer_type: 'Region')
            umb_fixed += 1
            print "."
          else
            tournament.update_columns(organizer_id: unknown_region.id, organizer_type: 'Region')
            print "u"
          end
        end
        
        puts "\n  ✓ Set to UMB: #{umb_fixed}"
        puts "  ✓ Set to Unknown: #{count - umb_fixed}"
        total_migrated += count
      end
    end
    
    puts "\n" + "-"*80
    puts "SUMMARY"
    puts "-"*80
    puts "Total migrated: #{total_migrated}"
    puts "\nNext steps:"
    puts "  1. Run: rake placeholders:stats"
    puts "  2. Visit: /admin/incomplete_records"
    puts "  3. Auto-fix remaining: rake placeholders:auto_fix_disciplines"
    puts "="*80 + "\n"
  end
end
