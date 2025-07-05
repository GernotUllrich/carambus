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
    season = Season[16]
    Rails.logger.info "##-##-##-##-##-## UPDATE REGION ##-##-##-##-##-##"
    Region.scrape_regions
    Rails.logger.info "##-##-##-##-##-## UPDATE LOCATIONS ##-##-##-##-##-##"
    Location.scrape_locations
    Rails.logger.info "##-##-##-##-##-## UPDATE CLUBS AND PLAYERS ##-##-##-##-##-##"
    Club.scrape_clubs(season, from_background: true, player_details: true)
    Rails.logger.info "##-##-##-##-##-## UPDATE TOURNAMENTS ##-##-##-##-##-##"
    season.scrape_single_tournaments_public_cc(optimize_api_access: false, reload_game_results: false)
    Rails.logger.info "##-##-##-##-##-## UPDATE LEAGUES ##-##-##-##-##-##"
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
end
