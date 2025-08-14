#!/usr/bin/env ruby

# Debug script to test current state of ID-based filtering
require_relative 'config/environment'

puts "🔍 Testing current ID-based filtering state"
puts "=" * 50

# Test 1: Check if BC Wedel club exists and has an ID
puts "\n1. Testing BC Wedel club lookup:"
bc_wedel = Club.find_by(shortname: 'BC Wedel')
if bc_wedel
  puts "✅ BC Wedel found with ID: #{bc_wedel.id}"
  puts "   Region: #{bc_wedel.region&.shortname} (ID: #{bc_wedel.region_id})"
else
  puts "❌ BC Wedel not found"
end

# Test 2: Check NBV region
puts "\n2. Testing NBV region lookup:"
nbv_region = Region.find_by(shortname: 'NBV')
if nbv_region
  puts "✅ NBV region found with ID: #{nbv_region.id}"
else
  puts "❌ NBV region not found"
end

# Test 3: Test search with club_id
if bc_wedel
  puts "\n3. Testing search with club_id:#{bc_wedel.id}:"
  search_service = SearchService.new(
    model: Player,
    search: "club_id:#{bc_wedel.id}",
    sort: 'players.id',
    direction: 'asc',
    distinct: true
  )
  results = search_service.call
  puts "   Found #{results.count} players"
  if results.any?
    puts "   Sample players:"
    results.limit(3).each do |player|
      puts "     - #{player.name} (ID: #{player.id})"
    end
  end
end

# Test 4: Test search with region_id
if nbv_region
  puts "\n4. Testing search with region_id:#{nbv_region.id}:"
  search_service = SearchService.new(
    model: Player,
    search: "region_id:#{nbv_region.id}",
    sort: 'players.id',
    direction: 'asc',
    distinct: true
  )
  results = search_service.call
  puts "   Found #{results.count} players"
  if results.any?
    puts "   Sample players:"
    results.limit(3).each do |player|
      puts "     - #{player.name} (ID: #{player.id})"
    end
  end
end

# Test 5: Test combined search
if bc_wedel && nbv_region
  puts "\n5. Testing combined search (club_id:#{bc_wedel.id} region_id:#{nbv_region.id}):"
  search_service = SearchService.new(
    model: Player,
    search: "club_id:#{bc_wedel.id} region_id:#{nbv_region.id}",
    sort: 'players.id',
    direction: 'asc',
    distinct: true
  )
  results = search_service.call
  puts "   Found #{results.count} players"
  if results.any?
    puts "   Sample players:"
    results.limit(3).each do |player|
      puts "     - #{player.name} (ID: #{player.id})"
    end
  end
end

puts "\n" + "=" * 50
puts "🎯 Next steps:"
puts "1. Open http://localhost:3001/players in your browser"
puts "2. Open browser console (F12 → Console)"
puts "3. Wait for debug messages to appear"
puts "4. Try selecting region NBV and club BC Wedel"
puts "5. Check what search string is generated"
puts "6. Report the console debug messages back" 