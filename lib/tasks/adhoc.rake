require "#{Rails.root}/app/helpers/application_helper"

namespace :adhoc do

  desc "test settings"
  task :test_setting => :environment do
    Setting.connection
    Setting.key_delete(:admin_email)

  end
end

