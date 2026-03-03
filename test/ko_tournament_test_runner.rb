#!/usr/bin/env ruby
# frozen_string_literal: true

# KO Tournament Test Runner
# 
# This script runs all KO tournament-related tests and provides a summary.
# 
# Usage:
#   ruby test/ko_tournament_test_runner.rb
#   
# Or via rake:
#   rake test:ko_tournaments

puts "\n" + "=" * 80
puts "  KO TOURNAMENT TEST SUITE"
puts "=" * 80 + "\n"

require_relative "../config/environment"
require "rails/test_help"

# Load all KO tournament tests
test_files = [
  "test/models/tournament_plan_ko_test.rb",
  "test/models/tournament_ko_integration_test.rb",
  "test/models/tournament_monitor_ko_test.rb"
]

puts "Loading test files:"
test_files.each do |file|
  full_path = Rails.root.join(file)
  if File.exist?(full_path)
    puts "  ✓ #{file}"
    require full_path
  else
    puts "  ✗ #{file} (not found)"
  end
end

puts "\n" + "-" * 80
puts "Running tests..."
puts "-" * 80 + "\n"

# Run the tests
exit_code = Minitest.run([])

puts "\n" + "=" * 80
puts "  TEST SUITE COMPLETE"
puts "=" * 80 + "\n"

exit exit_code
