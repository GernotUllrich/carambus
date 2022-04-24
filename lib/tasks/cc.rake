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
      regions_done = Region.get_regions_from_cc(region).map(&:id)
    else
      Rails.logger.info "ERROR CC [synchronize_region_structure] unknown context Region #{context}"
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      Rails.logger.error "ERROR CC [synchronize_region_structure] regions with context #{context} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}"
    end
    regions_overdone = regions_done - regions_todo
    unless regions_overdone.blank?
      Rails.logger.error "ERROR CC [synchronize_region_structure] more regions with context #{context} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}"
    end
  end

  desc "synchronize branch structure"
  task :synchronize_branch_structure => :environment do
    branches_todo = []
    branches_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    unless region.blank?
      branches_todo = Branch.all.ids
      branches_done = Branch.get_branches_from_cc(region).map(&:id)
    else
      Rails.logger.info "ERROR CC [synchronize_branch_structure] unknown context Region #{context}"
      exit 1
    end
    branches_still_todo = branches_todo - branches_done
    unless branches_still_todo.blank?
      Rails.logger.error "ERROR CC [synchronize_branch_structure] branches with context #{context} not yet in CC: #{Branch.where(id: branches_todo).map(&:name)}"
    end
    branches_overdone = branches_done - branches_todo
    unless branches_overdone.blank?
      Rails.logger.error "ERROR CC [synchronize_branch_structure] more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}"
    end
  end

  desc "synchronize competition structure"
  task :synchronize_competition_structure => :environment do
    competitions_todo = []
    competitions_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    unless region.blank?
      competitions_todo = Competition.all.ids
      competitions_done = Competition.get_competitions_from_cc(region).map(&:id)
    else
      Rails.logger.info "ERROR CC [synchronize_branch_structure] unknown context Region #{context}"
      exit 1
    end
    competitions_still_todo = competitions_todo - competitions_done
    unless competitions_still_todo.blank?
      Rails.logger.error "ERROR CC [synchronize_branch_structure] branches with context #{context} not yet in CC: #{Branch.where(id: competitions_todo).map(&:name)}"
    end
    branches_overdone = competitions_done - competitions_todo
    unless branches_overdone.blank?
      Rails.logger.error "ERROR CC [synchronize_branch_structure] more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}"
    end
  end

  desc "synchronize season structure"
  task :synchronize_season_structure => :environment do
    ["2010/2011"].each do |season_name|
      competition_cc_ids_todo = []
      competition_cc_ids_done = []
      context = ENV["REGION"] || "NBV"
      region = Region.find_by_shortname(context)
      unless region.blank?
        competition_cc_ids_todo = CompetitionCc.where(context: context.downcase).all.map(&:cc_id)
        competition_cc_ids_done = Season.get_competition_cc_ids_from_cc(season_name, region).map(&:id)
      else
        Rails.logger.info "ERROR CC [synchronize_season_structure] unknown context Region #{context}"
        exit 1
      end
      competition_cc_ids_still_todo = competition_cc_ids_todo - competition_cc_ids_done
      unless competition_cc_ids_still_todo.blank?
        Rails.logger.error "ERROR CC [synchronize_season_structure] season #{season_name} for competition_cc ids #{competition_cc_ids_still_todo.inspect} with context #{context} not yet in CC: #{SeasonCC.where(competition_cc_id: competition_cc_ids_todo).map(&:name)}"
      end
      competition_cc_ids_overdone = competition_cc_ids_done - competition_cc_ids_todo
      unless competition_cc_ids_overdone.blank?
        Rails.logger.error "ERROR CC [synchronize_season_structure] more competions_cc_ids with context #{context} than expected in CC: #{CompetitionCc.where(id: competition_cc_ids_overdone).map(&:cc_id)}"
      end
    end
  end
end
