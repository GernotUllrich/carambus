#!/usr/bin/env ruby
# frozen_string_literal: true

# Test browser search simulation
# Run with: rails runner test_browser_search.rb

puts "🌐 Testing Browser Search Simulation"
puts "=" * 50

# Simulate the browser search with different scenarios
test_cases = [
  "region_id:3 club_id:239",
  "region_id:3",
  "club_id:239",
  "region_id:3 club_id:123",
  "Wedel",  # This should fall back to text search
  "region_shortname:NBV club_shortname:BC Wedel"  # Old text-based format
]

test_cases.each do |search_string|
  puts "\nTesting search: '#{search_string}'"
  
  search_hash = Player.search_hash({})
  search_service = SearchService.new(
    model: Player,
    sort: 'players.id',
    direction: 'asc',
    search: search_string,
    column_names: search_hash[:column_names],
    raw_sql: search_hash[:raw_sql],
    joins: search_hash[:joins]
  )
  
  result = search_service.call
  puts "  Results: #{result.count} players"
  
  if result.count > 0
    result.limit(3).each do |player|
      puts "    - #{player.fl_name} (ID: #{player.id})"
    end
  else
    puts "    No players found"
  end
end

puts "\n✅ Browser Search Test Complete!"
puts "=" * 50 