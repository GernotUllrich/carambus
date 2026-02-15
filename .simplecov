# frozen_string_literal: true

# SimpleCov configuration for Carambus
# Run with: COVERAGE=true bin/rails test

SimpleCov.start 'rails' do
  # Project name
  project_name 'Carambus'
  
  # Filters - Don't include in coverage
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/db/'
  add_filter '/lib/tasks/'
  
  # Groups - Organize coverage by type
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Concerns', 'app/models/concerns'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Jobs', 'app/jobs'
  add_group 'Channels', 'app/channels'
  
  # Track all app files
  track_files '{app}/**/*.rb'
  
  # Minimum coverage percentages (for information, not enforcement)
  minimum_coverage 60
  
  # Refuse to merge coverage between runs (more accurate)
  merge_timeout 3600
  
  # Custom groups for Carambus-specific code
  add_group 'Critical Concerns' do |src_file|
    src_file.filename.include?('app/models/concerns/local_protector') ||
    src_file.filename.include?('app/models/concerns/source_handler') ||
    src_file.filename.include?('app/models/concerns/region_taggable')
  end
  
  add_group 'ClubCloud Integration' do |src_file|
    src_file.filename.include?('_cc.rb') ||
    src_file.filename.include?('region_cc')
  end
end
