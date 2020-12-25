require "#{Rails.root}/app/helpers/application_helper"

namespace :adhoc do

  desc "test settings"
  task :test_setting => :environment do
    Setting.connection
    Setting.key_delete(:admin_email)

  end

  task :test_rankings => :environment do
    tournament = Tournament[11637]
    tm = tournament.tournament_monitor
    tm.update_ranking
  end
end

