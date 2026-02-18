# frozen_string_literal: true

# Seeds for International Regions (Continental Federations)
puts "Creating international regions..."

# Main governing body
umb = Region.find_or_create_by!(shortname: "UMB") do |r|
  r.name = "Union Mondiale de Billard"
  r.website = "https://www.umb-carom.org"
  r.public_cc_url_base = "https://files.umb-carom.org"
  r.country_id = nil  # International
end
puts "  ✓ #{umb.shortname} - #{umb.name}"

# Continental Confederations
ceb = Region.find_or_create_by!(shortname: "CEB") do |r|
  r.name = "Confédération Européenne de Billard"
  r.website = "https://www.eurobillard.org"
  r.country_id = nil  # International
end
puts "  ✓ #{ceb.shortname} - #{ceb.name}"

cpb = Region.find_or_create_by!(shortname: "CPB") do |r|
  r.name = "Confederacion Panamericana de Billar"
  r.country_id = nil  # International
end
puts "  ✓ #{cpb.shortname} - #{cpb.name}"

acc = Region.find_or_create_by!(shortname: "ACC") do |r|
  r.name = "Asian Confederation of Carom"
  r.country_id = nil  # International
end
puts "  ✓ #{acc.shortname} - #{acc.name}"

absc = Region.find_or_create_by!(shortname: "ABSC") do |r|
  r.name = "African Billiards and Snooker Confederation"
  r.country_id = nil  # International
end
puts "  ✓ #{absc.shortname} - #{absc.name}"

puts "✓ International regions created successfully"
