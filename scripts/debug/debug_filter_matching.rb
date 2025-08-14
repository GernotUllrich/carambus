#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for filter matching
# Run with: rails runner debug_filter_matching.rb

puts "🔍 Debugging Filter Matching"
puts "=" * 50

# Test the matching logic
key = "region_id"
columns = {
  "Id" => "players.id",
  "CC_ID" => "players.cc_id", 
  "DBU_ID" => "players.dbu_nr",
  "Nickname" => "players.nickname",
  "Firstname" => "players.firstname",
  "Lastname" => "players.lastname",
  "Title" => "players.title",
  "Club" => "clubs.shortname",
  "Region" => "regions.shortname",
  "region_id" => "players.region_id",
  "club_id" => "season_participations.club_id"
}

puts "Testing key: '#{key}'"
puts "Columns:"
columns.each do |ext_name, int_name|
  matches = /^#{key.strip}/i.match?(ext_name)
  puts "  '#{ext_name}' => '#{int_name}' (matches: #{matches})"
end

puts "\nTesting club_id:"
key2 = "club_id"
columns.each do |ext_name, int_name|
  matches = /^#{key2.strip}/i.match?(ext_name)
  puts "  '#{ext_name}' => '#{int_name}' (matches: #{matches})"
end

puts "\n✅ Debug Complete!" 