# frozen_string_literal: true

require "#{Rails.root}/app/helpers/application_helper"
require "open-uri"
require "uri"
require "net/http"
require "csv"

namespace :scrape do
  desc "daily update"
  task daily_update: :environment do
    Rails.logger.info "##-##-##-##-##-## UPDATE SEASON ##-##-##-##-##-##"
    Season.update_seasons if Season.find_by_name("#{Date.today.year}/#{Date.today.year + 1}").blank?
    season = Season.current_season
    season = Season.find_by_name("2025/2026")
    # Rails.logger.info "##-##-##-##-##-## UPDATE REGION ##-##-##-##-##-##"
    # Region.scrape_regions
    # Rails.logger.info "##-##-##-##-##-## UPDATE LOCATIONS ##-##-##-##-##-##"
    # Location.scrape_locations
    # Rails.logger.info "##-##-##-##-##-## UPDATE CLUBS AND PLAYERS ##-##-##-##-##-##"
    # Club.scrape_clubs(season, from_background: true, player_details: true)
    # Rails.logger.info "##-##-##-##-##-## UPDATE TOURNAMENTS ##-##-##-##-##-##"
    # # season.scrape_single_tournaments_public_cc(optimize_api_access: false, reload_game_results: true, force: true)
    # season.scrape_single_tournaments_public_cc(optimize_api_access: false)
    #  Rails.logger.info "##-##-##-##-##-## UPDATE LEAGUES ##-##-##-##-##-##"
    (Region::SHORTNAMES_ROOF_ORGANIZATION + Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).each do |shortname|
      League.scrape_leagues_from_cc(Region.find_by_shortname(shortname), season, league_details: true, optimize_api_access: false)
    end
  end

  desc "optimized daily update - only sync changes since last synchronization"
  task optimized_daily_update: :environment do
    Rails.logger.info "##-##-##-##-##-## OPTIMIZED DAILY UPDATE ##-##-##-##-##-##"

    # Update seasons if needed
    Season.update_seasons if Season.find_by_name("#{Date.today.year}/#{Date.today.year + 1}").blank?
    season = Season.current_season
    season = Season[16]

    Rails.logger.info "##-##-##-##-##-## UPDATE REGIONS (NEW ONLY) ##-##-##-##-##-##"
    Region.scrape_regions_optimized

    Rails.logger.info "##-##-##-##-##-## UPDATE LOCATIONS (NEW ONLY) ##-##-##-##-##-##"
    Location.scrape_locations_optimized

    Rails.logger.info "##-##-##-##-##-## UPDATE CLUBS AND PLAYERS (NEW/CHANGED) ##-##-##-##-##-##"
    Club.scrape_clubs_optimized(season, from_background: true, player_details: true)

    Rails.logger.info "##-##-##-##-##-## UPDATE TOURNAMENTS (NEW/CHANGED) ##-##-##-##-##-##"
    season.scrape_tournaments_optimized

    Rails.logger.info "##-##-##-##-##-## UPDATE LEAGUES (NEW/CHANGED) ##-##-##-##-##-##"
    (Region::SHORTNAMES_ROOF_ORGANIZATION + Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).each do |shortname|
      region = Region.find_by_shortname(shortname)
      League.scrape_leagues_optimized(region, season) if region.present?
    end
  end

  desc "Update Seasons"
  task update_seasons: :environment do
    Season.update_seasons
  end

  desc "scrape clubs"
  task scrape_clubs: :environment do
    Club.scrape_clubs(from_background: true, player_details: true)
  end

  desc "scrape clubs optimized"
  task scrape_clubs_optimized: :environment do
    season = Season.current_season
    Club.scrape_clubs_optimized(season, from_background: true, player_details: true)
  end

  desc "scrape tournaments optimized"
  task scrape_tournaments_optimized: :environment do
    season = Season.current_season
    season.scrape_tournaments_optimized
  end

  desc "scrape leagues optimized"
  task scrape_leagues_optimized: :environment do
    season = Season.current_season
    (Region::SHORTNAMES_ROOF_ORGANIZATION + Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).each do |shortname|
      region = Region.find_by_shortname(shortname)
      League.scrape_leagues_optimized(region, season) if region.present?
    end
  end

  desc "cleanup old abandoned tournament cc records"
  task cleanup_abandoned_tournaments: :environment do
    days = ENV['DAYS'] || 365
    count = AbandonedTournamentCc.cleanup_old_records(days.to_i)
    Rails.logger.info "Cleaned up #{count} abandoned tournament cc records older than #{days} days"
  end

  desc "mark tournament cc as abandoned"
  task mark_tournament_abandoned: :environment do
    cc_id = ENV['CC_ID']
    context = ENV['CONTEXT']
    region_shortname = ENV['REGION']
    season_name = ENV['SEASON']
    tournament_name = ENV['TOURNAMENT']
    reason = ENV['REASON'] || 'Manually marked as abandoned'
    replaced_by_cc_id = ENV['REPLACED_BY_CC_ID']

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
    region_shortname = ENV['REGION']
    season_name = ENV['SEASON']

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
    region_shortname = ENV['REGION']
    season_name = ENV['SEASON']

    if region_shortname.blank? || season_name.blank?
      puts "Usage: rake scrape:analyze_duplicates REGION=REGION_SHORTNAME SEASON=2023/2024"
      exit 1
    end

    result = AbandonedTournamentCc.analyze_duplicates(region_shortname, season_name)
    puts result
  end

  desc "mark tournament cc_id as abandoned (simple)"
  task mark_abandoned_simple: :environment do
    cc_id = ENV['CC_ID']
    context = ENV['CONTEXT']

    if cc_id.blank? || context.blank?
      puts "Usage: rake scrape:mark_abandoned_simple CC_ID=123 CONTEXT=region_context"
      exit 1
    end

    AbandonedTournamentCcSimple.mark_abandoned!(cc_id.to_i, context)
    puts "Marked tournament cc_id #{cc_id} as abandoned"
  end

  desc "fix wrong tournament cc associations"
  task fix_tournament_cc_associations: :environment do
    tournament_id = ENV['TOURNAMENT_ID']
    correct_cc_id = ENV['CC_ID']
    context = ENV['CONTEXT']

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
        new_tc = TournamentCc.create!(
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
