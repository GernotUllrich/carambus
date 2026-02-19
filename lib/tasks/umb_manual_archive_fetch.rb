#!/usr/bin/env ruby
# frozen_string_literal: true

# Helper script to manually fetch UMB tournament archive list
# The UMB archive page requires JavaScript and form submissions,
# so this script provides a manual workflow for getting tournament IDs

require 'net/http'
require 'uri'
require 'openssl'
require 'nokogiri'

puts "=== UMB Manual Archive Fetch ==="
puts ""
puts "The UMB archive page (https://www.umb-carom.org/PG342L2/Union-Mondiale-de-Billard.aspx)"
puts "requires JavaScript and ASP.NET form submission."
puts ""
puts "Manual workflow:"
puts "1. Open https://www.umb-carom.org/ in browser"
puts "2. Navigate to: Results → Tournament Archive"
puts "3. Select filters:"
puts "   - By Events: All Tournaments"
puts "   - By Years: All Years (or specific year)"
puts "   - By Disciplines: 3-Cushion (or other)"
puts "4. Click Search/Submit"
puts "5. Right-click on tournament name → Copy Link"
puts "6. Extract tournament ID from URL:"
puts "   Example: /public/TournamentDetails.aspx?ID=512"
puts "   Tournament ID = 512"
puts ""
puts "Then use:"
puts "  rails runner \"InternationalTournament.create!(external_id: '512', ...)\""
puts "  rails umb:scrape_tournament_details[TOURNAMENT_DB_ID]"
puts ""
puts "=== OR: Use Selenium (automated) ==="
puts ""
puts "Uncomment Selenium code in UmbScraper to automate this process."
puts ""

# Example code for Selenium automation (commented out)
puts "Example Selenium code:"
puts <<~RUBY
  require 'selenium-webdriver'
  
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  driver = Selenium::WebDriver.for :chrome, options: options
  
  driver.get('https://www.umb-carom.org/')
  # Navigate to archive
  # Fill form fields
  # Extract tournament links
  # Parse tournament IDs
  driver.quit
RUBY
