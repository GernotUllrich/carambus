namespace :db do
  desc "reset sequences for a specific table or all tables"
  task :sequence_reset => :environment do
    Version.sequence_reset
  end
end
