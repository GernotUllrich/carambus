#!/usr/bin/env ruby
# Test script to diagnose UMB organizer issue

puts "\n=== UMB Organizer Diagnostic Test ==="
puts

# 1. Check if UMB Region exists
puts "1. Checking UMB Region..."
umb_region = Region.find_by(shortname: 'UMB')
if umb_region
  puts "   ✓ UMB Region found:"
  puts "     ID: #{umb_region.id}"
  puts "     Name: #{umb_region.name}"
  puts "     Class: #{umb_region.class.name}"
else
  puts "   ✗ UMB Region NOT found!"
  exit 1
end

# 2. Check InternationalSource
puts "\n2. Checking UMB Source..."
umb_source = InternationalSource.find_by(source_type: 'umb')
if umb_source
  puts "   ✓ UMB Source found (ID: #{umb_source.id})"
else
  puts "   ✗ UMB Source NOT found!"
  exit 1
end

# 3. Find a discipline
puts "\n3. Finding discipline..."
discipline = Discipline.find_by('name ILIKE ?', '%dreiband%groß%')
if discipline
  puts "   ✓ Discipline found: #{discipline.name} (ID: #{discipline.id})"
else
  puts "   ✗ No discipline found!"
  exit 1
end

# 4. Find or create season
puts "\n4. Finding/creating season..."
season = Season.find_or_create_by!(name: 'Season 2025/26')
puts "   ✓ Season: #{season.name} (ID: #{season.id})"

# 5. Try to create a test tournament
puts "\n5. Creating test tournament..."
test_tournament = InternationalTournament.new(
  title: "TEST UMB Tournament #{Time.current.to_i}",
  date: Date.today + 30.days,
  end_date: Date.today + 32.days,
  location_text: "Test Location",
  discipline: discipline,
  international_source: umb_source,
  season: season,
  organizer_id: umb_region.id,
  organizer_type: 'Region',
  modus: 'international',
  single_or_league: 'single',
  plan_or_show: 'show',
  state: 'planned',
  data: {
    umb_official: true,
    test: true,
    created_at: Time.current.iso8601
  }
)

puts "\n6. Checking assigned attributes BEFORE save..."
puts "   title: #{test_tournament.title}"
puts "   organizer_id: #{test_tournament.organizer_id}"
puts "   organizer_type: #{test_tournament.organizer_type}"
puts "   organizer (association): #{test_tournament.organizer.inspect}"

puts "\n7. Validating..."
if test_tournament.valid?
  puts "   ✓ Tournament is valid!"
else
  puts "   ✗ Tournament is INVALID:"
  test_tournament.errors.full_messages.each do |msg|
    puts "     - #{msg}"
  end
  
  puts "\n   Errors by attribute:"
  test_tournament.errors.messages.each do |attr, messages|
    puts "     #{attr}: #{messages.join(', ')}"
  end
  
  exit 1
end

puts "\n8. Saving tournament..."
if test_tournament.save
  puts "   ✓ Tournament saved successfully!"
  puts "     ID: #{test_tournament.id}"
  
  # Clean up
  puts "\n9. Cleaning up test tournament..."
  test_tournament.destroy
  puts "   ✓ Test tournament deleted"
else
  puts "   ✗ Failed to save tournament:"
  test_tournament.errors.full_messages.each do |msg|
    puts "     - #{msg}"
  end
  exit 1
end

puts "\n✅ All tests passed! UMB organizer setup is working correctly."
puts
