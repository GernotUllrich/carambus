require "#{Rails.root}/app/helpers/application_helper"
require "open-uri"
require "uri"
require "net/http"
require "csv"

include ApplicationHelper

namespace :cc do
  desc "login"
  task login_to_cc: :environment do
    Setting.login_to_cc
  end

  desc "logoff"
  task logoff_from_cc: :environment do
    Setting.logoff_from_cc
  end

  desc "synchronize everything"
  task synchronize_everything: :environment do
    opts = get_base_opts_from_environment
    Season.where.not(name: opts[:exclude_season_names]).order(name: :asc).each_with_index do |season, ix|
      opts[:season_name] = season.name
      opts[:armed] = true
      opts[:update_from_cc] = false
      RegionCcAction.remove_local_objects(opts) if ix == 0
      # RegionCcAction.synchronize_region_structure(opts) if ix == 0
      # RegionCcAction.synchronize_club_structure(opts) if ix == 0
      # RegionCcAction.synchronize_branch_structure(opts) if ix == 0
      # RegionCcAction.synchronize_game_plan_structure(opts) if ix == 0
      # RegionCcAction.synchronize_competition_structure(opts) if ix == 0
      # RegionCcAction.synchronize_season_structure(opts)
      # RegionCcAction.synchronize_league_structure(opts)
      # RegionCcAction.synchronize_league_team_structure_new(opts)
      # ######RegionCcAction.synchronize_league_team_structure(opts)
      # RegionCcAction.synchronize_league_plan_structure(opts) #if season.name == "2014/2015"
      # RegionCcAction.sync_team_players_structure(opts)
      # RegionCcAction.sync_game_details(opts) #if season.name == "2014/2015"
      RegionCcAction.synchronize_category_structure(opts) if ix == 0
      RegionCcAction.synchronize_group_structure(opts) if ix == 0
      RegionCcAction.synchronize_championship_type_structure(opts) if ix == 0
      RegionCcAction.synchronize_tournament_series_structure(opts)
      RegionCcAction.synchronize_registration_list_structure(opts)
      RegionCcAction.synchronize_tournament_structure(opts)

      # ### TODO done by synchronize_league_plan_structure! RegionCcAction.synchronize_party_structure(opts)
      # #### TODO what's this?  RegionCcAction.sync_party_game_structure(opts)
    end
  end

  desc "remove local objects"
  task remove_local_objects: :environment do
    opts = get_base_opts_from_environment.merge(armed: true)
    RegionCcAction.remove_local_objects(opts)
  end

  desc "synchronize region structure"
  task synchronize_region_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_region_structure(opts)
  end

  desc "synchronize club structure"
  task synchronize_club_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_club_structure(opts)
  end

  desc "synchronize branch structure"
  task synchronize_branch_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_branch_structure(opts)
  end

  desc "synchronize competition structure"
  task synchronize_competition_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_competition_structure(opts)
  end

  desc "synchronize season structure"
  task synchronize_season_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_season_structure(opts)
  end

  desc "synchronize league structure"
  task synchronize_league_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_league_structure(opts)
  end

  desc "synchronize league plan structure"
  task synchronize_league_plan_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_league_plan_structure(opts)
  end

  desc "synchronize league_team structure"
  task synchronize_league_team_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_league_team_structure(opts)
  end

  desc "synchronize party structure"
  task synchronize_party_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_party_structure(opts)
  end

  desc "synchronize party game structure"
  task synchronize_party_game_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.sync_party_game_structure(opts)
  end

  desc "synchronize team players structure"
  task synchronize_team_players_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.sync_team_players_structure(opts)
  end

  desc "synchronize game reports structure"
  task synchronize_game_plan_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_game_plan_structure(opts)
  end

  desc "synchronize category structure"
  task synchronize_category_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_category_structure(opts)
  end

  desc "synchronize group structure"
  task synchronize_group_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_group_structure(opts)
  end

  desc "synchronize discipline structure"
  task synchronize_discipline_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_discipline_structure(opts)
  end

  desc "synchronize championship type structure"
  task synchronize_championship_type_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_championship_type_structure(opts)
  end

  desc "synchronize registration list structure"
  task synchronize_registration_list_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_registration_list_structure(opts)
  end

  desc "release registration list structure"
  task release_registration_list_structure: :environment do
    opts = get_base_opts_from_environment
    opts.merge!(branch_cc_cc_id: 10)
    RegionCcAction.synchronize_registration_list_structure(opts.merge(release: true))
  end

  desc "synchronize tournament series structure"
  task synchronize_tournament_series_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_tournament_series_structure(opts)
  end

  desc "synchronize tournament structure"
  task synchronize_tournament_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.synchronize_tournament_structure(opts.merge(update_from_cc: false))
  end

  desc "scrape cc tournament structure"
  task scrape_cc_tournament_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.scrape_cc_tournament_structure(opts.merge(update_from_cc: false))
  end

  desc "fix tournament structure"
  task fix_tournament_structure: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.fix_tournament_structure(opts)
  end

  desc "upload tournament results"
  task upload_tournament_results: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.upload_tournament_results(opts)
  end

  desc "delete tournament results"
  task delete_tournament_results: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.delete_tournament_results(opts)
  end

  desc "synchronize game details"
  task synchronize_game_details: :environment do
    opts = get_base_opts_from_environment
    RegionCcAction.sync_game_details(opts)
  end

  desc "Remove duplicate Players"
  task remove_duplicate_players: :environment do
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
    RegionCcAction.get_base_opts_from_environment
  end
end
