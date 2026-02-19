# frozen_string_literal: true

# Placeholder Records für fehlende Referenzen
# Diese Records werden verwendet, wenn Daten von externen Quellen (z.B. UMB) importiert werden
# und erforderliche Referenzen nicht verfügbar sind.

puts "\n" + "="*80
puts "CREATING PLACEHOLDER RECORDS"
puts "="*80 + "\n"

# 1. Unknown Season
season_unknown = Season.find_or_create_by!(name: "Unknown Season") do |season|
  season.ba_id = nil
  season.data = {
    placeholder: true,
    description: "Placeholder for tournaments with unknown season",
    created_by: "seeds/placeholder_records.rb"
  }.to_json
end
puts "✓ Season: #{season_unknown.name} (ID: #{season_unknown.id})"

# 2. Unknown Discipline
discipline_unknown = Discipline.find_or_create_by!(name: "Unknown Discipline") do |discipline|
  discipline.table_kind_id = nil
  discipline.data = {
    placeholder: true,
    description: "Placeholder for tournaments with unknown discipline",
    created_by: "seeds/placeholder_records.rb"
  }.to_json
end
puts "✓ Discipline: #{discipline_unknown.name} (ID: #{discipline_unknown.id})"

# 3. Unknown Location
location_unknown = Location.find_or_create_by!(name: "Unknown Location") do |location|
  location.address = "Location not specified"
  location.data = {
    placeholder: true,
    description: "Placeholder for tournaments with unknown location",
    created_by: "seeds/placeholder_records.rb"
  }
  location.add_md5
end
puts "✓ Location: #{location_unknown.name} (ID: #{location_unknown.id})"

# 4. Unknown Region (für Organizer)
region_unknown = Region.find_or_create_by!(shortname: "UNKNOWN") do |region|
  region.name = "Unknown Region"
  region.scrape_data = {
    placeholder: true,
    description: "Placeholder for tournaments with unknown organizer",
    created_by: "seeds/placeholder_records.rb"
  }
end
puts "✓ Region: #{region_unknown.name} (ID: #{region_unknown.id})"

# 5. Unknown Club (optional, falls Club als Organizer verwendet wird)
club_unknown = Club.find_or_create_by!(shortname: "UNKNOWN") do |club|
  club.name = "Unknown Club"
  club.region_id = region_unknown.id
  club.homepage = "https://carambus.org"
  club.address = "Unknown"
end
puts "✓ Club: #{club_unknown.name} (ID: #{club_unknown.id})"

puts "\n" + "-"*80
puts "SUMMARY"
puts "-"*80
puts "Placeholder records created successfully!"
puts "These records will be used when importing data with missing references."
puts ""
puts "To view incomplete records:"
puts "  rake placeholders:list_incomplete"
puts ""
puts "To fix incomplete records (admin):"
puts "  Visit: /admin/incomplete_records"
puts "="*80 + "\n"
