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
    regions_todo = []
    regions_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context.upcase)
    unless region.blank?
      regions_todo = [region.id]
      regions_done = RegionCc.sync_regions(region).map(&:id)
    else
      raise_err_msg("synchronize_region_structure", "unknown context Region #{context}")
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      raise_err_msg("synchronize_region_structure", "regions with context #{context} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}")
    end
    regions_overdone = regions_done - regions_todo
    unless regions_overdone.blank?
      raise_err_msg("synchronize_region_structure", "more regions with context #{context} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}")
    end
  end

  desc "synchronize branch structure"
  task :synchronize_branch_structure => :environment do
    branches_todo = []
    branches_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    unless region_cc.blank?
      branches_todo = Branch.all.ids
      branches_done = region_cc.sync_branches.map(&:id)
    else
      raise_err_msg("synchronize_branch_structure", "unknown context Region #{context}")
    end
    branches_still_todo = branches_todo - branches_done
    unless branches_still_todo.blank?
      raise_err_msg("synchronize_branch_structure", "branches with context #{context} not yet in CC: #{Branch.where(id: branches_todo).map(&:name)}")
    end
    branches_overdone = branches_done - branches_todo
    unless branches_overdone.blank?
      raise_err_msg("synchronize_branch_structure", "more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}")
    end
  end

  desc "synchronize competition structure"
  task :synchronize_competition_structure => :environment do
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    unless region_cc.blank?
      competitions_todo = Competition.all.ids
      competitions_done = region_cc.sync_competitions.map(&:id)
    else
      raise_err_msg("synchronize_branch_structure", "unknown context Region #{context}")
    end
    competitions_still_todo = competitions_todo - competitions_done
    unless competitions_still_todo.blank?
      raise_err_msg("synchronize_branch_structure", "branches with context #{context} not yet in CC: #{Branch.where(id: competitions_todo).map(&:name)}")
    end
    branches_overdone = competitions_done - competitions_todo
    unless branches_overdone.blank?
      raise_err_msg("synchronize_branch_structure", "more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}")
    end
  end

  desc "synchronize season structure"
  task :synchronize_season_structure => :environment do
    ["2010/2011"].each do |season_name|
      context = ENV["REGION"] || "NBV"
      region = Region.find_by_shortname(context)
      region_cc = region.region_cc
      unless region_cc.blank?
        competition_cc_ids_todo = CompetitionCc.where(context: context.downcase).all.map(&:cc_id)
        competition_cc_ids_done = region_cc.sync_seasons_in_competitions(season_name).map(&:cc_id)
      else
        raise_err_msg("synchronize_season_structure", "unknown context Region #{context}")
      end
      competition_cc_ids_still_todo = competition_cc_ids_todo - competition_cc_ids_done
      unless competition_cc_ids_still_todo.blank?

        Rails.logger.warn "REPORT! [synchronize_season_structure] Saison #{season_name} nicht definiert für Wettbewerbe #{CompetitionCc.where(cc_id: competition_cc_ids_still_todo).map{|ccc| "#{ccc.branch_cc.name} - #{ccc.name} (#{ccc.cc_id})"}}"
      end
      competition_cc_ids_overdone = competition_cc_ids_done - competition_cc_ids_todo
      unless competition_cc_ids_overdone.blank?
        raise_err_msg("synchronize_season_structure", "more competions_cc_ids with context #{context} than expected in CC: #{CompetitionCc.where(id: competition_cc_ids_overdone).map(&:cc_id)}")
      end
    end
  end

  desc "synchronize league structure"
  task :synchronize_league_structure => :environment do
    ["2010/2011"].each do |season_name|
      season = Season.find_by_name(season_name)
      if season.blank?
        raise ArgumentError, "unknown season name #{season_name}", caller
      end
      context = ENV["REGION"] || "NBV"
      region = Region.find_by_shortname(context)
      region_cc = region.region_cc
      leagues_region_todo = League.joins(:league_teams => :club).where(season: season, organizer_type: "Region", organizer_id: region.id).where("clubs.region_id = ?", region.id).uniq
      dbu_region = Region.find_by_shortname("portal")
      dbu_leagues_todo = League.joins(:league_teams => :club).where(season: season, organizer_type: "Region", organizer_id: dbu_region.id).where("clubs.region_id = ?", region.id).uniq

      unless region_cc.blank?
        competition_cc_ids_todo = CompetitionCc.where(context: context.downcase).all.map(&:cc_id)
        competition_cc_ids_done = region_cc.sync_seasons_in_competitions(season_name).map(&:cc_id)
      else
        raise_err_msg("synchronize_season_structure", "unknown context Region #{context}")
      end
      competition_cc_ids_still_todo = competition_cc_ids_todo - competition_cc_ids_done
      unless competition_cc_ids_still_todo.blank?

        Rails.logger.warn "REPORT! [synchronize_season_structure] Saison #{season_name} nicht definiert für Wettbewerbe #{CompetitionCc.where(cc_id: competition_cc_ids_still_todo).map{|ccc| "#{ccc.branch_cc.name} - #{ccc.name} (#{ccc.cc_id})"}}"
      end
      competition_cc_ids_overdone = competition_cc_ids_done - competition_cc_ids_todo
      unless competition_cc_ids_overdone.blank?
        raise_err_msg("synchronize_season_structure", "more competions_cc_ids with context #{context} than expected in CC: #{CompetitionCc.where(id: competition_cc_ids_overdone).map(&:cc_id)}")
      end
    end
  end

  private

  def raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg}"
    raise ArgumentError, msg, caller
  end
end
