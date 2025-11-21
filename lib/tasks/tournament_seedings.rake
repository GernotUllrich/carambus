# frozen_string_literal: true

namespace :tournament do
  desc "Check for problematic version records that might delete seedings"
  task :check_seeding_versions, [:tournament_id] => :environment do |t, args|
    tournament_id = args[:tournament_id]&.to_i
    unless tournament_id
      puts "Usage: rake tournament:check_seeding_versions[TOURNAMENT_ID]"
      puts "Example: rake tournament:check_seeding_versions[17518]"
      exit 1
    end

    tournament = Tournament.find_by(id: tournament_id)
    unless tournament
      puts "❌ Tournament #{tournament_id} nicht gefunden!"
      exit 1
    end

    puts "=" * 80
    puts "SEEDING VERSION RECORDS CHECK"
    puts "Tournament: #{tournament.title} (ID: #{tournament.id})"
    puts "=" * 80
    puts ""

    # Finde alle Seedings für dieses Turnier
    seedings = tournament.seedings
    puts "Aktuelle Seedings: #{seedings.count}"
    puts "  - Lokale (ID >= #{Seeding::MIN_ID}): #{seedings.where('seedings.id >= ?', Seeding::MIN_ID).count}"
    puts "  - ClubCloud (ID < #{Seeding::MIN_ID}): #{seedings.where('seedings.id < ?', Seeding::MIN_ID).count}"
    puts ""

    # Finde alle Version Records für Seedings dieses Turniers
    seeding_ids = seedings.pluck(:id)
    
    if ApplicationRecord.local_server?
      puts "⚠️  WARNUNG: Dies ist ein Local Server!"
      puts "   Version Records werden hier nicht gespeichert (werden nach Sync gelöscht)."
      puts "   Bitte diese Task auf dem API Server ausführen!"
      puts ""
      
      # Prüfe ob es Version Records gibt
      destroy_versions = Version.where(item_type: 'Seeding', item_id: seeding_ids, event: 'destroy')
      if destroy_versions.any?
        puts "⚠️  Gefunden: #{destroy_versions.count} destroy-Version Records"
        puts "   Diese könnten Seedings beim nächsten Sync löschen!"
      else
        puts "✅ Keine destroy-Version Records gefunden (oder bereits gelöscht)"
      end
    else
      puts "📋 Prüfe Version Records auf API Server..."
      
      # Alle Version Records für Seedings dieses Turniers
      all_versions = Version.where(item_type: 'Seeding', item_id: seeding_ids)
      puts "   Gesamt: #{all_versions.count} Version Records"
      
      # Nach Event gruppieren
      create_versions = all_versions.where(event: 'create')
      update_versions = all_versions.where(event: 'update')
      destroy_versions = all_versions.where(event: 'destroy')
      
      puts "   - create: #{create_versions.count}"
      puts "   - update: #{update_versions.count}"
      puts "   - destroy: #{destroy_versions.count}"
      puts ""
      
      if destroy_versions.any?
        puts "⚠️  PROBLEM: #{destroy_versions.count} destroy-Version Records gefunden!"
        puts "   Diese werden beim Sync zum Local Server übertragen und löschen dort die Seedings."
        puts ""
        puts "Neueste destroy-Version Records:"
        destroy_versions.order(id: :desc).limit(10).each do |v|
          seeding = Seeding.find_by(id: v.item_id)
          player_name = seeding&.player&.fullname || "UNKNOWN"
          puts "   - Version #{v.id}: Seeding[#{v.item_id}] (#{player_name}) - #{v.created_at}"
        end
        puts ""
        puts "💡 Lösung: Diese destroy-Version Records löschen:"
        puts "   rake tournament:cleanup_seeding_versions[#{tournament_id}]"
      else
        puts "✅ Keine destroy-Version Records gefunden - Seedings sollten synchronisiert werden können"
      end
    end
    
    puts ""
    puts "=" * 80
  end

  desc "Clean up problematic destroy version records for a tournament"
  task :cleanup_seeding_versions, [:tournament_id] => :environment do |t, args|
    tournament_id = args[:tournament_id]&.to_i
    unless tournament_id
      puts "Usage: rake tournament:cleanup_seeding_versions[TOURNAMENT_ID]"
      puts "Example: rake tournament:cleanup_seeding_versions[17518]"
      exit 1
    end

    tournament = Tournament.find_by(id: tournament_id)
    unless tournament
      puts "❌ Tournament #{tournament_id} nicht gefunden!"
      exit 1
    end

    if ApplicationRecord.local_server?
      puts "❌ FEHLER: Diese Task muss auf dem API Server ausgeführt werden!"
      puts "   Local Server haben keine Version Records."
      exit 1
    end

    puts "=" * 80
    puts "CLEANUP SEEDING VERSION RECORDS"
    puts "Tournament: #{tournament.title} (ID: #{tournament.id})"
    puts "=" * 80
    puts ""

    # Finde alle Seedings für dieses Turnier
    seedings = tournament.seedings
    seeding_ids = seedings.pluck(:id)
    
    destroy_versions = Version.where(item_type: 'Seeding', item_id: seeding_ids, event: 'destroy')
    
    if destroy_versions.none?
      puts "✅ Keine destroy-Version Records gefunden - nichts zu löschen"
      exit 0
    end

    count = destroy_versions.count
    puts "⚠️  Gefunden: #{count} destroy-Version Records"
    puts ""
    puts "Diese werden jetzt gelöscht..."
    
    destroyed_count = destroy_versions.delete_all
    
    puts "✅ #{destroyed_count} destroy-Version Records gelöscht"
    puts ""
    puts "💡 Seedings sollten jetzt korrekt synchronisiert werden können."
    puts ""
    puts "=" * 80
  end
end


