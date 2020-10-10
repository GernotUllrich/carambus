#!/usr/bin/env ruby
require 'rubygems'
require 'bundler'
Bundler.setup

require 'daemons'
require 'pp'

rails_dir = File.expand_path(File.dirname(__FILE__) + '/../')

options = {
    dir_mode: :normal,
    dir: "#{rails_dir}/tmp/pids",
    log_output: true,
    multiple: true,
    monitor: true
}
file = "#{rails_dir}/config/jobs.rb"

process_name = 'worker'

Daemons.run_proc(process_name, options) do

  exec "bundle exec stalk #{file}"

end