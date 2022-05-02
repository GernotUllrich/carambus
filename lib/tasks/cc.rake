# encoding: utf-8
require "#{Rails.root}/app/helpers/application_helper"
require 'open-uri'
require 'uri'
require 'net/http'
require 'csv'

include ApplicationHelper

namespace :cc do
  desc "synchronize region structure"
  task :synchronize_region_structure => :environment do
    RegionCcAction.synchronize_region_structure
  end

  desc "synchronize branch structure"
  task :synchronize_branch_structure => :environment do
    RegionCcAction.synchronize_branch_structure
  end

  desc "synchronize competition structure"
  task :synchronize_competition_structure => :environment do
    RegionCcAction.synchronize_competition_structure
  end

  desc "synchronize season structure"
  task :synchronize_season_structure => :environment do
    RegionCcAction.synchronize_season_structure
  end

  desc "synchronize league structure"
  task :synchronize_league_structure => :environment do
    RegionCcAction.synchronize_league_structure
  end

  desc "synchronize club structure"
  task :synchronize_club_structure => :environment do
    RegionCcAction.synchronize_club_structure
  end

  desc "synchronize league_team structure"
  task :synchronize_league_team_structure => :environment do
    RegionCcAction.synchronize_league_team_structure
  end

  desc "synchronize party structure"
  task :synchronize_party_structure => :environment do
    RegionCcAction.synchronize_party_structure
  end

  desc "synchronize party game structure"
  task :synchronize_party_game_structure => :environment do
    RegionCcAction.synchronize_party_game_structure
  end

  desc "synchronize team players structure"
  task :synchronize_team_players_structure => :environment do
    RegionCcAction.synchronize_team_players_structure
  end

  desc "Remove duplicate Players"
  task :remove_duplicate_players => :environment do
    columns_that_make_record_distinct = [:firstname, :lastname, :club_id, :type, :ba_id, :data]
    distinct_ids = Player.select("MIN(id) as id").group(columns_that_make_record_distinct).map(&:id)
    duplicate_record_ids = Player.where.not(id: distinct_ids).ids.to_set
    while true
      break if duplicate_record_ids.blank?
      next_dup = Player[duplicate_record_ids.first]
      args = next_dup.attributes.reject { |k, v| !columns_that_make_record_distinct.include?(k.to_sym) }
      args.inspect
      player_ids = Player.where(args).map(&:id)
      player_ok = Player[player_ids[0]]
      Player.where(id: player_ids[1..-1]).each do |player_tmp|
        Player.merge_players(player_ok, player_tmp)
      end
      duplicate_record_ids.subtract(player_ids[1..-1])
      duplicate_record_ids.count
    end
  end
end
