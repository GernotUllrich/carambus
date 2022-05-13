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
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_region_structure(opts)

  end

  desc "synchronize branch structure"
  task :synchronize_branch_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_branch_structure(opts)

  end

  desc "synchronize competition structure"
  task :synchronize_competition_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_competition_structure(opts)

  end

  desc "synchronize season structure"
  task :synchronize_season_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_season_structure(opts)
  end

  desc "synchronize league structure"
  task :synchronize_league_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_league_structure(opts)

  end

  desc "synchronize league plan structure"
  task :synchronize_league_plan_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_league_plan_structure(opts)
  end

  desc "get game report"
  # TODO wird nicht mehr gebraucht - siehe synchronize_party_game_structure
  task :get_game_plan => :environment do
    opts = get_base_opts_from_environment
    party_cc = PartyCc.where(cc_id: 6045).first
    res, doc = party_cc.sync_game_details(opts)
  end

  desc "synchronize club structure"
  task :synchronize_club_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_club_structure(opts)

  end

  desc "synchronize league_team structure"
  task :synchronize_league_team_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_league_team_structure(opts)
  end

  desc "synchronize party structure"
  task :synchronize_party_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_party_structure(opts)

  end

  desc "synchronize party game structure"
  task :synchronize_party_game_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.sync_party_game_structure(opts)

  end

  desc "synchronize team players structure"
  task :synchronize_team_players_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.sync_team_players_structure(opts)
  end

  desc "synchronize game reports structure"
  task :synchronize_game_plan_structure => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_game_plan_structure(opts)
  end

  desc "synchronize game details"
  task :synchronize_game_details => :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.sync_game_details(xopts)
  end

  desc "Remove duplicate Players"
  task :remove_duplicate_players => :environment do
    opts = get_base_opts_from_environment
    if false
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
    Player.where("ba_id > 900000000").each do |p|
      next if p.lastname == "Freilos"
      Player.where.not(id: p.id).where(firstname: p.firstname, lastname: p.lastname).each do |player_ok|
        Player.merge_players(player_ok, [p])
      end
    end
  end

  def get_base_opts_from_environment
    session_id = ENV["PHPSESSID"].presence || Setting.key_get_value("session_id")
    context = (ENV["CC_REGION"].andand.upcase.presence || Setting.key_get_value("context") || "NBV").downcase
    season_name = ENV["CC_SEASON"].presence || Setting.key_get_value("season_name")
    force_update = (ENV["CC_UPDATE"].presence || Setting.key_get_value("force_update") ) == "true"
    return {session_id: session_id, armed: force_update, context: context, season_name: season_name}
  end
end
