# frozen_string_literal: true

require "#{Rails.root}/app/helpers/application_helper"
require "open-uri"
require "uri"
require "net/http"
require "csv"

namespace :scrape do
  desc "daily update"
  task daily_update: :environment do
    scrape_scope = ENV["SCOPE"] || nil # "latest_and_upcoming"
    Rails.logger.info "##-##-##-##-##-## UPDATE SEASON ##-##-##-##-##-##"
    Season.update_seasons if Season.find_by_name("#{Date.today.year}/#{Date.today.year + 1}").blank?
    season = Season.current_season
    #season = Season.find_by_name("2023/2024")
    Rails.logger.info "##-##-##-##-##-## UPDATE REGION ##-##-##-##-##-##"
    Region.scrape_regions
    Rails.logger.info "##-##-##-##-##-## UPDATE LOCATIONS ##-##-##-##-##-##"
    Location.scrape_locations
    Rails.logger.info "##-##-##-##-##-## UPDATE CLUBS AND PLAYERS ##-##-##-##-##-##"
    Club.scrape_clubs(season, from_background: true,  player_details: true)
    Rails.logger.info "##-##-##-##-##-## UPDATE TOURNAMENTS ##-##-##-##-##-##"
    season.scrape_single_tournaments_public_cc(optimize_api_access: false, reload_game_results: false)
    Rails.logger.info "##-##-##-##-##-## UPDATE LEAGUES ##-##-##-##-##-##"
    (Region::SHORTNAMES_ROOF_ORGANIZATION + Region::SHORTNAMES_CARAMBUS_USERS + Region::SHORTNAMES_OTHERS).each do |shortname|
      League.scrape_leagues_from_cc(Region.find_by_shortname(shortname), season, league_details: true, optimize_api_access: false)
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
end
