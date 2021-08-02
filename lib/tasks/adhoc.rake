require "#{Rails.root}/app/helpers/application_helper"

namespace :adhoc do

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



  end

