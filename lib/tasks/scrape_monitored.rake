# frozen_string_literal: true

# Rake Tasks für gemonitortes Scraping
#
# Usage:
#   rake scrape:daily_update_monitored
#   rake scrape:stats
#   rake scrape:stats[tournaments]
#   rake scrape:check_health
#   rake scrape:cleanup_logs[90]

namespace :scrape do
  desc "Daily Update mit Monitoring (empfohlen!)"
  task daily_update_monitored: :environment do
    puts "🔍 Starting monitored daily scraping..."
    
    monitor = ScrapingMonitor.new("daily_update", "scheduled")
    
    monitor.run do |m|
      # Region-Level Scraping
      # Only scrape regions that have a region_cc (ClubCloud integration)
      Region.joins(:region_cc).each do |region|
        region_monitor = ScrapingMonitor.new("region_scraping", "Region[#{region.id}]")
        
        region_monitor.run do |rm|
          # Scrape Tournaments
          region.seasons.active.each do |season|
            tournaments = region.tournaments.where(season: season)
            
            tournaments.each do |tournament|
              begin
                old_attrs = tournament.attributes.slice('title', 'date', 'discipline_id')
                
                result = tournament.scrape_single_tournament_public
                
                if result == true
                  tournament.reload
                  new_attrs = tournament.attributes.slice('title', 'date', 'discipline_id')
                  
                  if old_attrs != new_attrs
                    rm.record_updated(tournament)
                  else
                    rm.record_unchanged(tournament)
                  end
                elsif result == false
                  rm.record_unchanged(tournament)
                end
                
                rm.track_method("scrape_single_tournament_public")
              rescue => e
                rm.record_error(tournament, e)
                Rails.logger.error "Tournament scraping failed: #{e.message}"
              end
            end
          end
          
          # Scrape Locations
          begin
            count_before = Location.count
            region.scrape_locations
            count_after = Location.count
            
            (count_after - count_before).times { rm.record_created(Location.new) }
            rm.track_method("scrape_locations")
          rescue => e
            rm.record_error(region, e)
          end
          
          # Scrape Clubs
          begin
            count_before = Club.count
            region.scrape_clubs
            count_after = Club.count
            
            (count_after - count_before).times { rm.record_created(Club.new) }
            rm.track_method("scrape_clubs")
          rescue => e
            rm.record_error(region, e)
          end
        end
      end
    end
    
    puts "\n✅ Monitored scraping completed!"
    puts "   Run 'rake scrape:stats' to see statistics"
  end
  
  desc "Zeige Scraping-Statistiken [optional: operation_name]"
  task :stats, [:operation] => :environment do |_t, args|
    operation = args[:operation]
    
    if operation.present?
      puts "\n📊 Statistiken für '#{operation}' (letzte 7 Tage):"
      puts "=" * 60
      
      stats = ScrapingLog.stats_for(operation, since: 7.days.ago)
      
      puts "Gesamt-Durchläufe:  #{stats[:total_runs]}"
      puts "Ø Laufzeit:         #{stats[:avg_duration]}s"
      puts "Created:            #{stats[:total_created]}"
      puts "Updated:            #{stats[:total_updated]}"
      puts "Deleted:            #{stats[:total_deleted]}"
      puts "Errors:             #{stats[:total_errors]}"
      puts "Erfolgsrate:        #{stats[:success_rate]}%"
      puts "Letzter Lauf:       #{stats[:last_run]&.strftime('%Y-%m-%d %H:%M')}"
    else
      puts "\n📊 Alle Scraping-Operationen (letzte 7 Tage):"
      puts "=" * 80
      
      ScrapingLog.all_operations_stats(since: 7.days.ago).each do |stats|
        puts "\n#{stats[:operation]}:"
        puts "  Durchläufe:  #{stats[:total_runs].to_s.rjust(6)} │ Ø #{stats[:avg_duration]}s"
        puts "  Created:     #{stats[:total_created].to_s.rjust(6)} │ Updated: #{stats[:total_updated].to_s.rjust(6)}"
        puts "  Errors:      #{stats[:total_errors].to_s.rjust(6)} │ Rate: #{stats[:success_rate]}%"
        puts "  Letzter Lauf: #{stats[:last_run]&.strftime('%Y-%m-%d %H:%M')}"
      end
    end
    
    puts "\n" + "=" * 80
  end
  
  desc "Prüfe Scraping-Gesundheit (Anomalien)"
  task check_health: :environment do
    puts "\n🏥 Scraping Health Check..."
    puts "=" * 60
    
    anomalies = ScrapingLog.check_anomalies
    
    if anomalies.empty?
      puts "✅ Alles OK! Keine Anomalien gefunden."
    else
      puts "⚠️  #{anomalies.count} Anomalie(n) gefunden:\n\n"
      
      anomalies.each_with_index do |anomaly, i|
        puts "#{i + 1}. #{anomaly[:operation]}"
        puts "   Problem: #{anomaly[:issue]}"
        puts "   Details: #{anomaly[:details][:total_runs]} Durchläufe, #{anomaly[:details][:total_errors]} Errors"
        puts ""
      end
      
      # Exit mit Error-Code für CI/CD
      exit 1
    end
  end
  
  desc "Cleanup alte Scraping-Logs [Tage (default: 90)]"
  task :cleanup_logs, [:keep_days] => :environment do |_t, args|
    keep_days = (args[:keep_days] || 90).to_i
    
    puts "🧹 Cleanup: Entferne Logs älter als #{keep_days} Tage..."
    deleted = ScrapingLog.cleanup_old_logs(keep_days: keep_days)
    puts "✅ #{deleted} Log-Einträge gelöscht."
  end
  
  desc "Zeige letzte Scraping-Errors"
  task recent_errors: :environment do
    puts "\n❌ Letzte Scraping-Errors (24h):"
    puts "=" * 80
    
    logs = ScrapingLog.where("executed_at >= ?", 24.hours.ago)
                      .where("error_count > 0")
                      .order(executed_at: :desc)
                      .limit(20)
    
    if logs.empty?
      puts "✅ Keine Errors in den letzten 24 Stunden!"
    else
      logs.each do |log|
        puts "\n#{log.executed_at.strftime('%Y-%m-%d %H:%M')} - #{log.operation} (#{log.context})"
        puts "  Errors: #{log.error_count} │ Duration: #{log.duration}s"
        
        if log.errors_parsed.any?
          log.errors_parsed.first(3).each do |error|
            puts "  └─ #{error['error']['class']}: #{error['error']['message']}"
          end
        end
      end
    end
    
    puts "\n" + "=" * 80
  end
  
  desc "Exportiere Scraping-Statistiken als CSV"
  task :export_stats, [:since_days] => :environment do |_t, args|
    since_days = (args[:since_days] || 30).to_i
    since = since_days.days.ago
    
    filename = "scraping_stats_#{Date.current}.csv"
    filepath = Rails.root.join("tmp", filename)
    
    require 'csv'
    
    CSV.open(filepath, "w") do |csv|
      csv << ["Operation", "Executed At", "Duration (s)", "Created", "Updated", "Deleted", "Errors"]
      
      ScrapingLog.where("executed_at >= ?", since).order(executed_at: :desc).find_each do |log|
        csv << [
          log.operation,
          log.executed_at.iso8601,
          log.duration&.round(2),
          log.created_count,
          log.updated_count,
          log.deleted_count,
          log.error_count
        ]
      end
    end
    
    puts "✅ Statistiken exportiert nach: #{filepath}"
    puts "   (#{ScrapingLog.where("executed_at >= ?", since).count} Einträge)"
  end
end
