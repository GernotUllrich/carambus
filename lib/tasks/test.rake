# frozen_string_literal: true

require "signet/oauth_2/client"
require "google-apis-calendar_v3"

namespace :test do
  desc "Current Test"
  task current: :environment do
    #Tournament[14213].scrape_single_tournament_public(reload_game_results: true)

    #Region.scrape_regions
    tm = Tournament[15743].tournament_monitor
    tm.update_ranking
  end

  desc "TP Link"
  task tp_link: :environment do
    table = Location[1].tables.find_by_name("Tisch 2")
    table.tpl_ip_address = "192.168.2.30"
    raise StandardError unless table.valid?
    raise StandardError unless table.table_local.present?

    table.save
    table.reload
    v = table.heater_on!
    v = JSON.parse(v)
    raise StandardError unless (v["system"]["set_relay_state"]["err_code"]).zero?

    v = table.heater_on?
    raise StandardError unless v

    v = table.heater_off!
    v = JSON.parse(v)
    raise StandardError unless (v["system"]["set_relay_state"]["err_code"]).zero?

    v = table.heater_on?
    raise StandardError if v
  end

end
