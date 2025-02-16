# frozen_string_literal: true

namespace :unicorn do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      Rails.logger.info "===--- Executing task unicorn:restart ---==="
      execute "#{unicorn_initd_file} stop"
      execute "#{unicorn_initd_file} start"
    end
  end
end
