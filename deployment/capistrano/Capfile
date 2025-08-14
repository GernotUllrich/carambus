# frozen_string_literal: true

# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

# Include tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#   https://github.com/capistrano/passenger
#
# require 'capistrano/rvm'
require "capistrano/rbenv"
# require 'capistrano/chruby'
require "capistrano/bundler"
require "capistrano/rails/assets"
require "capistrano/rails/migrations"


# require 'capistrano/maintenance'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob("lib/capistrano/tasks/*.cap").each { |r| import r }
Dir.glob("lib/capistrano/**/*.rb").each { |r| import r }
set :yarn_cmd, "/var/www/.nvm/versions/node/v20.15.0/bin/yarn"
set :node_cmd, "/var/www/.nvm/versions/node/v20.15.0/bin/node"
