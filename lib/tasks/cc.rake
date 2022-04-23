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
    region_shortname = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(region_shortname)
    unless region.blank?
      regions_todo = [region.id]
      regions_done = Region.get_regions_from_cc(region_shortname.downcase.strip).map(&:id)
    else
      Rails.logger.info "ERROR CC [synchronize_region_structure] unknown Region #{region_shortname}"
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      Rails.logger.error "ERROR CC [synchronize_region_structure] regions with context #{} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}"
    end
    regions_overdone = regions_done - regions_todo
    unless regions_overdone.blank?
      Rails.logger.error "ERROR CC [synchronize_region_structure] more regions with context #{} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}"
    end
  end


  desc "synchronize branch structure"
  task :synchronize_region_structure => :environment do
    regions_todo = []
    regions_done = []
    region_shortname = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(region_shortname)
    unless region.blank?
      regions_todo = [region.id]
      regions_done = Region.get_regions_from_cc(region_shortname.downcase.strip).map(&:id)
    else
      Rails.logger.info "ERROR CC [synchronize_region_structure] unknown Region #{region_shortname}"
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      Rails.logger.error "ERROR CC [synchronize_region_structure] regions with context #{} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}"
    end
    regions_overdone = regions_done - regions_todo
    unless regions_overdone.blank?
      Rails.logger.error "ERROR CC [synchronize_region_structure] more regions with context #{} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}"
    end
  end

end
