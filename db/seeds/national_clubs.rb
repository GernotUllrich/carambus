# frozen_string_literal: true

# Seeds for National Clubs (Countries as Clubs for International Players)
puts "Creating national clubs..."

umb_region = Region.find_by(shortname: "UMB")

unless umb_region
  puts "  ✗ UMB region not found. Please run international_regions.rb first."
  exit
end

# Major carom nations with ISO 3166-1 alpha-2 codes
national_clubs = {
  # European nations (strongest in carom)
  "BE" => "Belgium",
  "NL" => "Netherlands", 
  "FR" => "France",
  "DE" => "Germany",
  "ES" => "Spain",
  "IT" => "Italy",
  "TR" => "Turkey",
  "GR" => "Greece",
  "PT" => "Portugal",
  "AT" => "Austria",
  "SE" => "Sweden",
  "DK" => "Denmark",
  "PL" => "Poland",
  "CZ" => "Czech Republic",
  "LU" => "Luxembourg",
  "CH" => "Switzerland",
  
  # Asian nations (very strong in 3-cushion)
  "KR" => "South Korea",
  "VN" => "Vietnam",
  "JP" => "Japan",
  "CN" => "China",
  "TW" => "Taiwan",
  "IN" => "India",
  "TH" => "Thailand",
  
  # American nations
  "US" => "United States",
  "MX" => "Mexico",
  "CO" => "Colombia",
  "EC" => "Ecuador",
  "BR" => "Brazil",
  "AR" => "Argentina",
  "CU" => "Cuba",
  
  # Middle East
  "EG" => "Egypt",
  "IR" => "Iran",
  
  # Other
  "AU" => "Australia",
  "NZ" => "New Zealand"
}

national_clubs.each do |code, name|
  club = Club.find_or_create_by!(shortname: code, region: umb_region) do |c|
    c.name = name
    c.synonyms = [name, code].join("\n")
  end
  puts "  ✓ #{club.shortname} - #{club.name}"
end

puts "✓ #{national_clubs.size} national clubs created successfully"
