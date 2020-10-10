# config valid only for current version of Capistrano
lock '3.6.1'

set :application, 'carambus'
set :repo_url, 'git@github.com:GernotUllrich/carambus.git'

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'
set :deploy_to, '/var/www/web1.carombus.de/web/'

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
append :linked_files,'config/database.yml', 'config/secrets.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system'

append :linked_dirs, '.bundle'

set :rbenv_type, :local
set :rbenv_ruby, '2.4.4'
set :maintenance_template_path, "#{current_path}/config/maintenance_pages/maintenance.html.erb"
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}

# path to customized templates (see below for details)
# default value: "config/deploy/templates"
set :templates_path, "config/deploy/templates"

# server name for nginx, default value: "localhost <application>.local"
# set this to your site name as it is visible from outside
# this will allow 1 nginx to serve several sites with different `server_name`
set :nginx_server_name, "iptvit.co"

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
#set :nginx_upload_local_certificate, { true }

# remote file name of the certificate, only makes sense if `nginx_use_ssl` is set
# default value: `nginx_server_name + ".crt"`
#set :nginx_ssl_certificate, "#{nginx_server_name}.crt"

# remote file name of the certificate, only makes sense if `nginx_use_ssl` is set
# default value: `nginx_server_name + ".key"`
#set :nginx_ssl_certificate_key, "#{nginx_server_name}.key"

# nginx config file location
# centos users can set `/etc/nginx/conf.d`
# default value: `/etc/nginx/sites-available`
set :nginx_config_path, "/etc/nginx/sites-available"

# path, where unicorn pid file will be stored
# default value: `"#{current_path}/tmp/pids/unicorn.pid"`

# path, where unicorn config file will be stored
# default value: `"#{shared_path}/config/unicorn.rb"`
set :unicorn_config, "#{shared_path}/config/unicorn.rb"

# path, where unicorn log file will be stored
# default value: `"#{shared_path}/config/unicorn.rb"`

# user name to run unicorn
# default value: `user` (user varibale defined in your `deploy.rb`)
set :unicorn_user, "www-data"

# number of unicorn workers
# default value: 2
set :unicorn_workers, 2

# local path to file with certificate, only makes sense if `nginx_use_ssl` is set
# this file will be copied to remote server
# default value: none (will be prompted if not set)
#set :nginx_ssl_certificate_local_path, "/home/ivalkeen/ssl/myssl.cert"

# local path to file with certificate key, only makes sense if `nginx_use_ssl` is set
# this file will be copied to remote server
# default value: none (will be prompted if not set)
#set :nginx_ssl_certificate_key_local_path, "/home/ivalkeen/ssl/myssl.key"

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
      if fetch(:stage).to_s == 'production'
        execute "cd #{current_path} && BEANSTALK_URL=beanstalk://web1.carombus.de:11300 RAILS_ENV=production ~www-data/.rbenv/shims/bundle exec #{current_path}/script/worker.rb stop"
        execute "cd #{current_path} && BEANSTALK_URL=beanstalk://web1.carombus.de:11300 RAILS_ENV=production ~www-data/.rbenv/shims/bundle exec #{current_path}/script/worker.rb start"
      end
    end
    # on roles(:web), in: :sequence, wait: 5 do
    #   sudo "service #{fetch(:unicorn_service_name_web)} reload"
    # end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end


# Clear existing task so we can replace it rather than "add" to it.

#Rake::Task["deploy:compile_assets"].clear


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


# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5
