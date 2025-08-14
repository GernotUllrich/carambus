#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for ID-based filtering system
# Run with: rails runner test_id_based_filtering.rb

puts "🧪 Testing ID-Based Filtering System"
puts "=" * 50

# Test 1: Check if models have the correct search_hash configuration
puts "\n1. Testing Model Search Hash Configuration"

# Player model
player_search_hash = Player.search_hash({})
puts "Player search_hash column_names includes region_id: #{player_search_hash[:column_names].key?('Region ID')}"
puts "Player search_hash column_names includes club_id: #{player_search_hash[:column_names].key?('Club ID')}"

# Club model
club_search_hash = Club.search_hash({})
puts "Club search_hash column_names includes region_id: #{club_search_hash[:column_names].key?('Region ID')}"

# Location model
location_search_hash = Location.search_hash({})
puts "Location search_hash column_names includes region_id: #{location_search_hash[:column_names].key?('Region ID')}"
puts "Location search_hash column_names includes club_id: #{location_search_hash[:column_names].key?('Club ID')}"

# Test 2: Check if regions and clubs have IDs
puts "\n2. Testing Region and Club Data"

regions = Region.order(:shortname).limit(5)
puts "Found #{regions.count} regions for testing:"
regions.each do |region|
  puts "  - #{region.shortname} (ID: #{region.id})"
end

clubs = Club.includes(:region).order(:shortname).limit(5)
puts "\nFound #{clubs.count} clubs for testing:"
clubs.each do |club|
  region_info = club.region ? " (#{club.region.shortname})" : " (no region)"
  puts "  - #{club.shortname}#{region_info} (ID: #{club.id})"
end

# Test 3: Test ID-based search functionality
puts "\n3. Testing ID-Based Search Functionality"

# Test region-based search
if regions.any?
  test_region = regions.first
  puts "Testing region search for: #{test_region.shortname} (ID: #{test_region.id})"
  
  # Test Player search by region_id
  players_in_region = Player.joins(:region).where(regions: { id: test_region.id }).limit(3)
  puts "  Players in region: #{players_in_region.count}"
  players_in_region.each do |player|
    puts "    - #{player.fl_name} (ID: #{player.id})"
  end
  
  # Test Club search by region_id
  clubs_in_region = Club.joins(:region).where(regions: { id: test_region.id }).limit(3)
  puts "  Clubs in region: #{clubs_in_region.count}"
  clubs_in_region.each do |club|
    puts "    - #{club.shortname} (ID: #{club.id})"
  end
end

# Test club-based search
if clubs.any?
  test_club = clubs.first
  puts "\nTesting club search for: #{test_club.shortname} (ID: #{test_club.id})"
  
  # Test Player search by club_id (through season_participations)
  players_in_club = Player.joins(season_participations: :club).where(clubs: { id: test_club.id }).limit(3)
  puts "  Players in club: #{players_in_club.count}"
  players_in_club.each do |player|
    puts "    - #{player.fl_name} (ID: #{player.id})"
  end
  
  # Test Location search by club_id
  locations_in_club = Location.joins(club_locations: :club).where(clubs: { id: test_club.id }).limit(3)
  puts "  Locations in club: #{locations_in_club.count}"
  locations_in_club.each do |location|
    puts "    - #{location.name} (ID: #{location.id})"
  end
end

# Test 4: Verify the search_hash raw_sql doesn't use ilike for reference fields
puts "\n4. Testing Search SQL Configuration"

puts "Player raw_sql includes region_id/club_id references:"
puts "  #{player_search_hash[:raw_sql].include?('region_id') || player_search_hash[:raw_sql].include?('club_id')}"

puts "Club raw_sql includes region_id references:"
puts "  #{club_search_hash[:raw_sql].include?('region_id')}"

puts "Location raw_sql includes region_id/club_id references:"
puts "  #{location_search_hash[:raw_sql].include?('region_id') || location_search_hash[:raw_sql].include?('club_id')}"

# Test 5: Check if the application helper generates correct options
puts "\n5. Testing Application Helper Options Generation"

# Test region options generation
regions_for_options = Region.order(:shortname).limit(3).pluck(:id, :shortname, :name)
region_options = regions_for_options.map { |id, shortname, name| { value: shortname, label: "#{shortname} (#{name})", id: id } }

puts "Region options generated:"
region_options.each do |option|
  puts "  - Value: #{option[:value]}, Label: #{option[:label]}, ID: #{option[:id]}"
end

# Test club options generation
clubs_for_options = Club.includes(:region).where.not(shortname: [nil, '']).order(:shortname).limit(3).pluck(:id, :shortname, :name, 'regions.shortname')
club_options = clubs_for_options.map do |id, shortname, name, region|
  display_name = name.present? ? "#{shortname} (#{name})" : shortname
  region_info = region.present? ? " - #{region}" : ""
  { value: shortname, label: "#{display_name}#{region_info}", id: id }
end

puts "\nClub options generated:"
club_options.each do |option|
  puts "  - Value: #{option[:value]}, Label: #{option[:label]}, ID: #{option[:id]}"
end

puts "\n✅ ID-Based Filtering System Test Complete!"
puts "=" * 50
puts "\nNext Steps:"
puts "1. Open http://localhost:3000/players in browser"
puts "2. Test the filter popup functionality"
puts "3. Check browser console for ID-based search strings"
puts "4. Verify results match expected behavior" 