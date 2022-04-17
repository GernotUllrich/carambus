require "#{Rails.root}/app/helpers/application_helper"

namespace :adhoc do


  desc "test league scraping"
  task :test_league_scraping => :environment do
    l = League.first
    l.scrape_single_league
  end
  desc "test settings"
  task :test_setting => :environment do
    Setting.connection
    Setting.key_delete(:admin_email)

  end

  task :clean_local => :environment do
    TournamentMonitor.where("id > 50000000").destroy_all
    TableMonitor.where("id > 50000000").destroy_all
    Game.where("id > 50000000").destroy_all
    GameParticipation.where("id > 50000000").destroy_all
    Account.where("id > 50000000").destroy_all
    User.where("id > 50000000").destroy_all
  end

  task :test_player_id_from_ranking => :environment do
    tm = TournamentMonitor[50000018]
    player_id = tm.player_id_from_ranking("(g1.rk4 + g2.rk4 +g3.rk4).rk2")
    puts player_id
  end

  task :test_accumulate_results => :environment do
    tm = TournamentMonitor[50000026]
    tm.accumulate_results
  end



  end

