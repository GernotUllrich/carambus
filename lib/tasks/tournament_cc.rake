# frozen_string_literal: true

# Wartungs-Tasks für tournament_cc-Datensätze (Duplikat-/Abandoned-Verwaltung).
# Ausgelagert aus scrape.rake (Phase 23-Cleanup): der tägliche Scrape läuft über
# scrape:daily_update_monitored (scrape_monitored.rake); diese Tasks sind manuelle
# Operations-Utilities für die AbandonedTournamentCc(-Simple)-Funktion, die live im
# Turnier-Scrape genutzt wird (Region#scrape_single_tournament_public → is_abandoned?).
# Namespace bleibt :scrape, damit die etablierten Task-Namen (scrape:mark_tournament_abandoned
# usw.) unverändert bleiben.
namespace :scrape do
  desc "cleanup old abandoned tournament cc records"
  task cleanup_abandoned_tournaments: :environment do
    days = ENV["DAYS"] || 365
    count = AbandonedTournamentCc.cleanup_old_records(days.to_i)
    Rails.logger.info "Cleaned up #{count} abandoned tournament cc records older than #{days} days"
  end

  desc "mark tournament cc as abandoned"
  task mark_tournament_abandoned: :environment do
    cc_id = ENV["CC_ID"]
    context = ENV["CONTEXT"]
    region_shortname = ENV["REGION"]
    season_name = ENV["SEASON"]
    tournament_name = ENV["TOURNAMENT"]
    reason = ENV["REASON"] || "Manually marked as abandoned"
    replaced_by_cc_id = ENV["REPLACED_BY_CC_ID"]

    if cc_id.blank? || context.blank? || region_shortname.blank? || season_name.blank? || tournament_name.blank?
      puts "Usage: rake scrape:mark_tournament_abandoned CC_ID=123 CONTEXT=region_context REGION=REGION_SHORTNAME SEASON=2023/2024 TOURNAMENT='Tournament Name' [REASON='reason'] [REPLACED_BY_CC_ID=456]"
      exit 1
    end

    AbandonedTournamentCc.mark_abandoned!(
      cc_id.to_i,
      context,
      region_shortname,
      season_name,
      tournament_name,
      reason: reason,
      replaced_by_cc_id: replaced_by_cc_id&.to_i
    )
    puts "Marked tournament cc_id #{cc_id} as abandoned"
  end

  desc "list abandoned tournaments for a region/season"
  task list_abandoned_tournaments: :environment do
    region_shortname = ENV["REGION"]
    season_name = ENV["SEASON"]

    if region_shortname.blank? || season_name.blank?
      puts "Usage: rake scrape:list_abandoned_tournaments REGION=REGION_SHORTNAME SEASON=2023/2024"
      exit 1
    end

    abandoned = AbandonedTournamentCc.for_region_season(region_shortname, season_name)

    if abandoned.empty?
      puts "No abandoned tournaments found for #{region_shortname} #{season_name}"
    else
      puts "Abandoned tournaments for #{region_shortname} #{season_name}:"
      abandoned.each do |record|
        puts "  cc_id: #{record.cc_id}, tournament: '#{record.tournament_name}', abandoned: #{record.abandoned_at}, reason: #{record.reason}"
      end
    end
  end

  desc "analyze duplicate tournaments for a region/season"
  task analyze_duplicates: :environment do
    region_shortname = ENV["REGION"]
    season_name = ENV["SEASON"]

    if region_shortname.blank? || season_name.blank?
      puts "Usage: rake scrape:analyze_duplicates REGION=REGION_SHORTNAME SEASON=2023/2024"
      exit 1
    end

    result = AbandonedTournamentCc.analyze_duplicates(region_shortname, season_name)
    puts result
  end

  desc "mark tournament cc_id as abandoned (simple)"
  task mark_abandoned_simple: :environment do
    cc_id = ENV["CC_ID"]
    context = ENV["CONTEXT"]

    if cc_id.blank? || context.blank?
      puts "Usage: rake scrape:mark_abandoned_simple CC_ID=123 CONTEXT=region_context"
      exit 1
    end

    AbandonedTournamentCcSimple.mark_abandoned!(cc_id.to_i, context)
    puts "Marked tournament cc_id #{cc_id} as abandoned"
  end

  desc "fix wrong tournament cc associations"
  task fix_tournament_cc_associations: :environment do
    tournament_id = ENV["TOURNAMENT_ID"]
    correct_cc_id = ENV["CC_ID"]
    context = ENV["CONTEXT"]

    if tournament_id.blank? || correct_cc_id.blank? || context.blank?
      puts "Usage: rake scrape:fix_tournament_cc_associations TOURNAMENT_ID=123 CC_ID=456 CONTEXT=nbv"
      exit 1
    end

    tournament = Tournament.find(tournament_id)
    old_tc = tournament.tournament_cc

    if old_tc.present?
      old_cc_id = old_tc.cc_id
      if old_cc_id != correct_cc_id.to_i
        # Mark the old cc_id as abandoned
        AbandonedTournamentCcSimple.mark_abandoned!(old_cc_id, context)
        puts "Marked old cc_id #{old_cc_id} as abandoned"

        # Create new TournamentCc with correct cc_id
        TournamentCc.create!(
          cc_id: correct_cc_id.to_i,
          name: tournament.title,
          context: context,
          tournament: tournament
        )
        puts "Created new TournamentCc with cc_id #{correct_cc_id}"

        # Remove old TournamentCc
        old_tc.destroy
        puts "Removed old TournamentCc"
      else
        puts "Tournament already has correct cc_id #{correct_cc_id}"
      end
    else
      puts "Tournament has no TournamentCc record"
    end
  end
end
