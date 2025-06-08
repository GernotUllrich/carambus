# config valid only for current version of Capistrano
lock "3.19.2"

set :application, "carambus"
set :basename, File.basename(`pwd`).strip
set :repo_url, "git@github.com:GernotUllrich/#{fetch(:application)}.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, "master"

set :default_env, {
  path: "/var/www/.nvm/versions/node/v20.15.0/bin:$PATH"
}

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'

#-- deploy to local and api server
set :deploy_to, "/var/www/#{fetch(:basename)}"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, 'config/database.yml', 'config/secrets.yml'
# append :linked_files,'config/database.yml', 'config/credentials/production.key'
append :linked_files, "config/database.yml", "config/carambus.yml", "config/scoreboard_url", "config/credentials/production.key", "config/environments/production.rb", "config/credentials/production.yml.enc", "config/puma.rb"

# Default value for linked_dirs is []
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "node_modules", "public/packs", "public/assets"

append :linked_dirs, ".bundle"

set :rbenv_type, :local
set :rbenv_ruby, "3.2.1"
set :maintenance_tournament_plan_path, "#{current_path}/config/maintenance_pages/maintenance.html.erb"
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w[rake gem bundle ruby rails]

# path to customized templates (see below for details)
# default value: "config/deploy/templates"
set :tournament_plans_path, "config/deploy/templates"

# server name for nginx, default value: "localhost <application>.local"
# set this to your site name as it is visible from outside
# this will allow 1 nginx to serve several sites with different `server_name`
# set :nginx_server_name, "iptvit.co"

# path, where nginx pid file will be stored (used in logrotate recipe)
# default value: `"/run/nginx.pid"`
set :nginx_pid, "/run/nginx.pid"

# if set, nginx will be configured to 443 port and port 80 will be auto rewritten to 443
# also, on `nginx:setup`, paths to ssl certificate and key will be configured
# and certificate file and key will be copied to `/etc/ssl/certs` and `/etc/ssl/private/` directories
# default value: false
set :nginx_use_ssl, false

# if set, it will ask to upload certificates from a local path. Otherwise, it will expect
# the certificate and key defined in the next 2 variables to be already in the server.
# set :nginx_upload_local_certificate, { true }

# remote file name of the certificate, only makes sense if `nginx_use_ssl` is set
# default value: `nginx_server_name + ".crt"`
# set :nginx_ssl_certificate, "#{nginx_server_name}.crt"

# remote file name of the certificate, only makes sense if `nginx_use_ssl` is set
# default value: `nginx_server_name + ".key"`
# set :nginx_ssl_certificate_key, "#{nginx_server_name}.key"

# nginx config file location
# centos users can set `/etc/nginx/conf.d`
# default value: `/etc/nginx/sites-available`
set :nginx_config_path, "/etc/nginx/sites-available"

# path, where puma pid file will be stored
# default value: `"#{current_path}/tmp/pids/puma.pid"`

# path, where puma config file will be stored
# default value: `"#{shared_path}/config/puma.rb"`
set :puma_config, "#{shared_path}/config/puma.rb"

# path, where puma log file will be stored
# default value: `"#{shared_path}/config/puma.rb"`

# user name to run puma
# default value: `user` (user varibale defined in your `deploy.rb`)
set :puma_user, "www-data"

# number of puma workers
# default value: 2
set :puma_workers, 2

# local path to file with certificate, only makes sense if `nginx_use_ssl` is set
# this file will be copied to remote server
# default value: none (will be prompted if not set)
# set :nginx_ssl_certificate_local_path, "/home/ivalkeen/ssl/myssl.cert"

# local path to file with certificate key, only makes sense if `nginx_use_ssl` is set
# this file will be copied to remote server
# default value: none (will be prompted if not set)
# set :nginx_ssl_certificate_key_local_path, "/home/ivalkeen/ssl/myssl.key"

after 'deploy:publishing', 'puma:restart'

namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end

namespace :puma do
  desc "Restart application"
  task :restart do
    on roles(:app) do
      execute "sudo #{current_path}/bin/manage-puma.sh #{fetch(:basename)}"
    end
  end
end

# Clear existing task so we can replace it rather than "add" to it.

# Rake::Task["deploy:compile_assets"].clear

namespace :deploy do
  # desc "Precompile assets locally and then rsync to web servers"
  # task :compile_assets do
  #   on roles(:app) do
  #     rsync_host = host.to_s
  #
  #     run_locally do
  #       with rails_env: :production do ## Set your env accordingly.
  #         execute "RAILS_ENV=#{fetch(:stage)} /Users/gullrich/.rbenv/shims/bundle exec rake assets:precompile"
  #       end
  #       execute "rsync -av --delete -e \"ssh -p 8910\" ./public/assets/ #{fetch(:deploy_user)}@#{rsync_host}:#{shared_path}/public/assets/"
  #       # execute "rm -rf public/assets"
  #       # execute "rm -rf tmp/cache/assets" # in case you are not seeing changes
  #     end
  #   end
  # end
  # desc "Clear and precompile assets locally and then rsync to web servers"
  # task :clear_and_compile_assets do
  #   on roles(:web) do
  #     rsync_host = host.to_s
  #
  #     run_locally do
  #       with rails_env: :production do ## Set your env accordingly.
  #         execute "rm -rf public/assets"
  #         execute "rm -rf tmp/cache/assets"
  #         execute "RAILS_ENV=#{fetch(:stage)} /Users/gullrich/.rbenv/shims/bundle exec rake assets:precompile"
  #       end
  #       execute "rsync -av --delete -e \"ssh -p 8910\" ./public/assets/ #{fetch(:deploy_user)}@#{rsync_host}:#{shared_path}/public/assets/"
  #     end
  #   end
  # end
end

desc "Check environment variables"
task :debug_env_vars do
  on roles(:app) do
    execute :printenv
  end
end

desc "Debug Node.js Setup"
task :debug_node_setup do
  on roles(:all) do
    execute :echo, "$(which node)"
    execute :echo, "$(node -v)"
  end
end
desc "Run Node with Absolute Path"
task :run_node_abs do
  on roles(:all) do
    execute "/var/www/.nvm/versions/node/v20.15.0/bin/node -v"
  end
end

task :debug_node_version do
  on roles(:app) do
    execute "node -v"
  end
end

# after "deploy:updating", :debug_env_vars
# after "deploy:updating", :debug_node_setup
# after "deploy:updating", :run_node_abs
# after "deploy:updating", :debug_node_version

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5
