#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for search service
# Run with: rails runner debug_search.rb

puts "🔍 Debugging Search Service"
puts "=" * 50

# Test 1: Direct model query with ID-based filtering
puts "\n1. Testing Direct Model Query"

# Test region_id search
puts "Testing region_id:3 search..."
players_region = Player.joins(:region).where(regions: { id: 3 }).limit(3)
puts "Found #{players_region.count} players in region 3:"
players_region.each { |p| puts "  - #{p.fl_name} (ID: #{p.id})" }

# Test club_id search
puts "\nTesting club_id:239 search (BC Wedel)..."
players_club = Player.joins(season_participations: :club).where(clubs: { id: 239 }).limit(3)
puts "Found #{players_club.count} players in club 239:"
players_club.each { |p| puts "  - #{p.fl_name} (ID: #{p.id})" }

# Test 2: Search service with ID-based parameters
puts "\n2. Testing Search Service"

search_hash = Player.search_hash({})
search_service = SearchService.new(
  model: search_hash[:model],
  sort: search_hash[:sort],
  direction: search_hash[:direction],
  search: "region_id:3 club_id:239",
  column_names: search_hash[:column_names],
  raw_sql: search_hash[:raw_sql],
  joins: search_hash[:joins]
)

puts "Search service initialized with:"
puts "  Search: #{search_service.instance_variable_get(:@sSearch)}"
puts "  Column names: #{search_service.instance_variable_get(:@column_names)}"
puts "  Joins: #{search_service.instance_variable_get(:@joins)}"

# Test 3: Apply filters manually
puts "\n3. Testing Manual Filter Application"

require_relative 'app/helpers/filters_helper.rb'
include FiltersHelper

@sSearch = "region_id:3 club_id:239"
query = Player.joins(:season_participations, :region)
result = apply_filters(query, search_hash[:column_names], search_hash[:raw_sql])

puts "Manual filter result: #{result.count} players"
result.limit(5).each { |p| puts "  - #{p.fl_name} (ID: #{p.id})" }

# Test 4: Check what search string is being generated
puts "\n4. Testing Search String Generation"

# Simulate the JavaScript filter generation
region_id = 3
club_id = 239
search_string = "region_id:#{region_id} club_id:#{club_id}"
puts "Generated search string: '#{search_string}'"

# Test 5: Check if the search service handles this correctly
puts "\n5. Testing Search Service with Generated String"

search_service2 = SearchService.new(
  model: Player,
  sort: 'players.id',
  direction: 'asc',
  search: search_string,
  column_names: search_hash[:column_names],
  raw_sql: search_hash[:raw_sql],
  joins: search_hash[:joins]
)

result2 = search_service2.call
puts "Search service result: #{result2.count} players"
result2.limit(5).each { |p| puts "  - #{p.fl_name} (ID: #{p.id})" }

puts "\n✅ Debug Complete!"
puts "=" * 50 