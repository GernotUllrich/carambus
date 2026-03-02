# UMB Historical Data Scraping - Implementation Plan

## Übersicht

Erweiterung des bestehenden `UmbScraper` Service zum Scraping historischer Turnierdaten von der UMB-Website (https://www.umb-carom.org).

## Phase 1: Schema-Erweiterungen (Datenmodell)

### 1.1 Players Table erweitern

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_international_fields_to_players.rb
class AddInternationalFieldsToPlayers < ActiveRecord::Migration[7.0]
  def change
    add_column :players, :umb_player_id, :integer
    add_column :players, :nationality, :string, limit: 2  # ISO 3166-1 alpha-2
    add_column :players, :international_player, :boolean, default: false
    
    add_index :players, :umb_player_id
    add_index :players, :nationality
    add_index :players, :international_player
  end
end
```

**Rationale:**
- `umb_player_id`: Eindeutige UMB-ID für internationale Spieler (analog zu `cc_id`, `dbu_nr`)
- `nationality`: ISO Country Code (2-stellig: "DE", "FR", "NL", "BE", "TR", "KR", etc.)
- `international_player`: Flag für schnelle Filterung internationaler Spieler

### 1.2 Internationale Regions/Clubs erstellen

**Option A: Neue Regions für Kontinentalverbände**
```ruby
# db/seeds/international_regions.rb
Region.find_or_create_by!(shortname: "UMB") do |r|
  r.name = "Union Mondiale de Billard"
  r.website = "https://www.umb-carom.org"
  r.country_id = nil  # International
end

Region.find_or_create_by!(shortname: "CEB") do |r|
  r.name = "Confédération Européenne de Billard"
  r.website = "https://www.eurobillard.org"
end

Region.find_or_create_by!(shortname: "CPB") do |r|
  r.name = "Confederation Panamericana de Billar"
end

Region.find_or_create_by!(shortname: "ACC") do |r|
  r.name = "Asian Confederation of Carom"
end

Region.find_or_create_by!(shortname: "ABSC") do |r|
  r.name = "African Billiards and Snooker Confederation"
end
```

**Option B: "Nationale Clubs" als Pseudo-Clubs** (Ihr Vorschlag)
```ruby
# db/seeds/national_clubs.rb
umb_region = Region.find_by(shortname: "UMB")

# Beispiele für wichtigste Nationen im Karambolage
{
  "DE" => "Germany",
  "FR" => "France", 
  "NL" => "Netherlands",
  "BE" => "Belgium",
  "TR" => "Turkey",
  "KR" => "South Korea",
  "ES" => "Spain",
  "IT" => "Italy",
  "VN" => "Vietnam",
  "JP" => "Japan"
}.each do |code, name|
  Club.find_or_create_by!(shortname: code, region: umb_region) do |c|
    c.name = name
    c.synonyms = "#{name}\n#{code}"
  end
end
```

**Empfehlung:** **Option B** ist pragmatischer für Ihr bestehendes System - minimale Änderungen, nutzt bestehende Club/SeasonParticipation-Logik.

## Phase 2: UmbScraper erweitern

### 2.1 Tournament Archive Index Scraping

```ruby
# app/services/umb_scraper.rb

ARCHIVE_URL = "#{BASE_URL}/PG342L2/Union-Mondiale-de-Billard.aspx"

# Scrape tournament archive by filters
def scrape_tournament_archive(discipline: nil, year: nil, event_type: nil)
  Rails.logger.info "[UmbScraper] Scraping tournament archive: discipline=#{discipline}, year=#{year}, event_type=#{event_type}"
  
  # POST request with form data
  form_data = {
    'cboEvents' => event_type || 'All Tournaments',
    'cboYears' => year || 'All Years',
    'cboDisciplines' => discipline || '3-Cushion',
    'Submit' => 'Search'
  }
  
  html = post_form(ARCHIVE_URL, form_data)
  doc = Nokogiri::HTML(html)
  
  tournaments = []
  
  # Parse tournament list (table with links)
  doc.css('table tr').each do |row|
    cells = row.css('td')
    next if cells.empty?
    
    # Extract tournament data
    tournament_link = cells[0].css('a').first
    next unless tournament_link
    
    tournament_url = "#{BASE_URL}#{tournament_link['href']}"
    tournament_name = tournament_link.text.strip
    
    # Parse location, date, etc. from cells
    location = cells[1]&.text&.strip
    date_range = cells[2]&.text&.strip
    
    tournaments << {
      name: tournament_name,
      url: tournament_url,
      location: location,
      date_range: date_range,
      discipline: discipline
    }
  end
  
  Rails.logger.info "[UmbScraper] Found #{tournaments.size} tournaments"
  
  # Save to database
  save_archived_tournaments(tournaments)
end

private

def post_form(url, form_data)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(form_data)
  request['User-Agent'] = 'Carambus International Bot/1.0'
  
  response = http.request(request)
  response.code == '200' ? response.body : nil
end

def save_archived_tournaments(tournaments)
  saved_count = 0
  
  tournaments.each do |data|
    # Parse dates from date_range string
    dates = parse_date_range_from_archive(data[:date_range])
    
    # Find or create discipline
    discipline = find_discipline_from_name(data[:discipline])
    next unless discipline
    
    # Extract location and country
    location, country = parse_location_country(data[:location])
    
    # Determine tournament type
    tournament_type = determine_tournament_type(data[:name])
    
    # Check for existing tournament (avoid duplicates)
    existing = InternationalTournament
      .where(name: data[:name])
      .where('start_date BETWEEN ? AND ?', 
             dates[:start_date] - 30.days, 
             dates[:start_date] + 30.days)
      .first
    
    tournament = existing || InternationalTournament.new
    
    tournament.assign_attributes(
      name: data[:name],
      start_date: dates[:start_date],
      end_date: dates[:end_date],
      location: location,
      country: country,
      discipline: discipline,
      tournament_type: tournament_type,
      international_source: @umb_source,
      source_url: data[:url],
      data: {
        umb_official: true,
        archived: true,
        scraped_at: Time.current.iso8601
      }
    )
    
    if tournament.save
      Rails.logger.info "[UmbScraper] Saved tournament: #{data[:name]}"
      saved_count += 1
      
      # Queue detail scraping job
      ScrapeUmbTournamentDetailsJob.perform_later(tournament.id) if tournament.source_url.present?
    else
      Rails.logger.error "[UmbScraper] Failed to save tournament: #{tournament.errors.full_messages}"
    end
  end
  
  saved_count
end

def parse_location_country(location_string)
  # Parse strings like "ANKARA (Turkey)" or "GURI (KOR)"
  if (match = location_string.match(/([A-Z\s]+)\s*\(([^)]+)\)/))
    city = match[1].strip.titleize
    country = match[2].strip
    [city, country]
  else
    [location_string, nil]
  end
end

def parse_date_range_from_archive(date_string)
  # Parse UMB archive date formats:
  # "18-21 December 2025"
  # "February 26 - March 1, 2026"
  # Reuse existing parse_date_range logic
  parse_date_range(date_string)
end
```

### 2.2 Tournament Detail Page Scraping

```ruby
def scrape_tournament_details(tournament_id)
  tournament = InternationalTournament.find(tournament_id)
  return unless tournament.source_url.present?
  
  Rails.logger.info "[UmbScraper] Scraping details for: #{tournament.name}"
  
  html = fetch_url(tournament.source_url)
  return if html.blank?
  
  doc = Nokogiri::HTML(html)
  
  # Find PDF links on detail page
  pdf_links = {
    players_list: nil,
    groups: nil,
    timetable: nil,
    results_by_round: nil,
    final_ranking: nil
  }
  
  doc.css('a').each do |link|
    href = link['href']
    text = link.text.downcase
    
    case text
    when /players.*list/i
      pdf_links[:players_list] = href
    when /groups/i
      pdf_links[:groups] = href
    when /timetable/i
      pdf_links[:timetable] = href
    when /results.*by.*round/i
      pdf_links[:results_by_round] = href
    when /final.*ranking/i
      pdf_links[:final_ranking] = href
    end
  end
  
  # Store PDF URLs in tournament data
  tournament.data ||= {}
  tournament.data['pdf_links'] = pdf_links.compact
  tournament.save
  
  # Parse Players List PDF if available
  if pdf_links[:players_list].present?
    scrape_players_from_pdf(tournament, pdf_links[:players_list])
  end
  
  # Parse Final Ranking PDF if available
  if pdf_links[:final_ranking].present?
    scrape_results_from_pdf(tournament, pdf_links[:final_ranking])
  end
end
```

### 2.3 PDF Parsing (Players List & Final Ranking)

**Herausforderung:** PDF-Parsing ist komplex. UMB PDFs sind nicht immer konsistent strukturiert.

**Empfohlene Gems:**
- `pdf-reader` - Text-Extraktion aus PDFs
- `prawn` - Falls OCR nötig (weniger wahrscheinlich bei UMB PDFs)

```ruby
# Gemfile
gem 'pdf-reader'

# app/services/umb_scraper.rb
require 'pdf-reader'

def scrape_players_from_pdf(tournament, pdf_url)
  Rails.logger.info "[UmbScraper] Parsing Players List PDF: #{pdf_url}"
  
  # Download PDF
  pdf_content = download_pdf(pdf_url)
  return unless pdf_content
  
  # Parse PDF text
  reader = PDF::Reader.new(StringIO.new(pdf_content))
  text = reader.pages.map(&:text).join("\n")
  
  # Pattern matching for player entries
  # Typical format in UMB PDFs:
  #   1. SURNAME Firstname (COUNTRY)
  #   2. VAN DER BERG Dick (NED)
  
  players_data = []
  
  text.scan(/(\d+)\.\s+([A-Z\s]+)\s+([A-Z][a-z]+.*?)\s*\(([A-Z]{2,3})\)/) do |position, lastname, firstname, country|
    players_data << {
      position: position.to_i,
      lastname: lastname.strip.titleize,
      firstname: firstname.strip,
      country: country.strip
    }
  end
  
  Rails.logger.info "[UmbScraper] Found #{players_data.size} players in PDF"
  
  # Create InternationalParticipation records
  save_participations(tournament, players_data)
end

def scrape_results_from_pdf(tournament, pdf_url)
  Rails.logger.info "[UmbScraper] Parsing Final Ranking PDF: #{pdf_url}"
  
  pdf_content = download_pdf(pdf_url)
  return unless pdf_content
  
  reader = PDF::Reader.new(StringIO.new(pdf_content))
  text = reader.pages.map(&:text).join("\n")
  
  # Pattern matching for rankings
  # Typical format:
  #   1. SURNAME Firstname (COUNTRY) - Points: 120, Avg: 2.456
  
  results_data = []
  
  text.scan(/(\d+)\.\s+([A-Z\s]+)\s+([A-Z][a-z]+.*?)\s*\(([A-Z]{2,3})\).*?Points:?\s*(\d+).*?Avg:?\s*([\d.]+)/i) do |position, lastname, firstname, country, points, average|
    results_data << {
      position: position.to_i,
      lastname: lastname.strip.titleize,
      firstname: firstname.strip,
      country: country.strip,
      points: points.to_i,
      average: average.to_f
    }
  end
  
  Rails.logger.info "[UmbScraper] Found #{results_data.size} results in PDF"
  
  # Create InternationalResult records
  save_results(tournament, results_data)
end

private

def download_pdf(url)
  full_url = url.start_with?('http') ? url : "#{BASE_URL}#{url}"
  
  uri = URI(full_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.open_timeout = TIMEOUT
  http.read_timeout = TIMEOUT
  
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = 'Carambus International Bot/1.0'
  
  response = http.request(request)
  response.code == '200' ? response.body : nil
rescue StandardError => e
  Rails.logger.error "[UmbScraper] Failed to download PDF #{url}: #{e.message}"
  nil
end

def save_participations(tournament, players_data)
  umb_region = Region.find_by(shortname: "UMB")
  return unless umb_region
  
  players_data.each do |data|
    # Find or create international player
    player = find_or_create_international_player(
      firstname: data[:firstname],
      lastname: data[:lastname],
      nationality: data[:country],
      region: umb_region
    )
    
    next unless player
    
    # Create participation record
    InternationalParticipation.find_or_create_by!(
      player: player,
      international_tournament: tournament
    ) do |participation|
      participation.source = InternationalParticipation::RESULT_LIST
      participation.confirmed = true
    end
    
    Rails.logger.info "[UmbScraper] Added participation: #{player.fl_name} (#{data[:country]})"
  end
end

def save_results(tournament, results_data)
  umb_region = Region.find_by(shortname: "UMB")
  return unless umb_region
  
  results_data.each do |data|
    # Find or create player
    player = find_or_create_international_player(
      firstname: data[:firstname],
      lastname: data[:lastname],
      nationality: data[:country],
      region: umb_region
    )
    
    player_name = "#{data[:firstname]} #{data[:lastname]}"
    
    # Create result record
    result = InternationalResult.find_or_create_by!(
      international_tournament: tournament,
      position: data[:position]
    ) do |r|
      r.player = player
      r.player_name = player_name
      r.player_country = data[:country]
      r.points = data[:points]
      r.metadata = {
        average: data[:average],
        scraped_from: 'umb_pdf'
      }
    end
    
    Rails.logger.info "[UmbScraper] Added result: #{data[:position]}. #{player_name} (#{data[:points]} pts)"
  end
end

def find_or_create_international_player(firstname:, lastname:, nationality:, region:)
  fl_name = "#{firstname} #{lastname}".strip
  
  # Try to find existing player
  player = Player.where(
    firstname: firstname,
    lastname: lastname,
    type: nil
  ).first
  
  # If not found, create new international player
  player ||= Player.new(
    firstname: firstname,
    lastname: lastname,
    fl_name: fl_name,
    nationality: nationality,
    international_player: true,
    region: region
  )
  
  # Update nationality if missing
  if player.nationality.blank?
    player.nationality = nationality
    player.international_player = true
  end
  
  player.save! if player.changed? || player.new_record?
  player
rescue StandardError => e
  Rails.logger.error "[UmbScraper] Failed to create player #{fl_name}: #{e.message}"
  nil
end
```

## Phase 3: Background Jobs (Async Processing)

```ruby
# app/jobs/scrape_umb_tournament_details_job.rb
class ScrapeUmbTournamentDetailsJob < ApplicationJob
  queue_as :default
  
  def perform(tournament_id)
    scraper = UmbScraper.new
    scraper.scrape_tournament_details(tournament_id)
  end
end

# app/jobs/scrape_umb_archive_job.rb
class ScrapeUmbArchiveJob < ApplicationJob
  queue_as :default
  
  def perform(discipline: '3-Cushion', year: nil, event_type: nil)
    scraper = UmbScraper.new
    scraper.scrape_tournament_archive(
      discipline: discipline,
      year: year,
      event_type: event_type
    )
  end
end
```

## Phase 4: Rake Tasks (CLI Interface)

```ruby
# lib/tasks/umb.rake
namespace :umb do
  desc "Scrape UMB tournament archive"
  task :scrape_archive, [:discipline, :year, :event_type] => :environment do |t, args|
    discipline = args[:discipline] || '3-Cushion'
    year = args[:year]
    event_type = args[:event_type]
    
    puts "Scraping UMB archive: #{discipline}, #{year || 'All Years'}, #{event_type || 'All Tournaments'}"
    
    scraper = UmbScraper.new
    count = scraper.scrape_tournament_archive(
      discipline: discipline,
      year: year,
      event_type: event_type
    )
    
    puts "✓ Saved #{count} tournaments"
  end
  
  desc "Scrape details for all UMB tournaments without details"
  task scrape_details: :environment do
    tournaments = InternationalTournament
      .where(international_source: InternationalSource.find_by(source_type: 'umb'))
      .where("data->>'pdf_links' IS NULL")
    
    puts "Scraping details for #{tournaments.count} tournaments..."
    
    scraper = UmbScraper.new
    tournaments.find_each do |tournament|
      scraper.scrape_tournament_details(tournament.id)
      sleep 2  # Rate limiting
    end
    
    puts "✓ Done"
  end
  
  desc "Scrape all historical data (all disciplines, all years)"
  task scrape_all_historical: :environment do
    disciplines = ['3-Cushion', '5-Pins', 'Artistique', 'Cadre 47/2', 'Cadre 71/2']
    
    disciplines.each do |discipline|
      puts "\n=== Scraping #{discipline} ==="
      Rake::Task['umb:scrape_archive'].execute(discipline: discipline, year: nil, event_type: nil)
    end
  end
end
```

**Usage:**
```bash
# Scrape all 3-Cushion tournaments
bundle exec rake umb:scrape_archive[3-Cushion]

# Scrape all World Championships from 2023
bundle exec rake umb:scrape_archive[3-Cushion,2023,"World Championship"]

# Scrape all historical data
bundle exec rake umb:scrape_all_historical

# Scrape details (PDFs) for all tournaments
bundle exec rake umb:scrape_details
```

## Phase 5: UI Integration (Optional)

### Admin Interface für internationale Turniere

```ruby
# app/controllers/admin/international_tournaments_controller.rb
class Admin::InternationalTournamentsController < ApplicationController
  def index
    @tournaments = InternationalTournament
      .includes(:discipline, :international_source)
      .order(start_date: :desc)
      .page(params[:page])
  end
  
  def show
    @tournament = InternationalTournament.find(params[:id])
    @participations = @tournament.international_participations
      .includes(:player)
      .order('players.lastname')
    @results = @tournament.international_results
      .includes(:player)
      .order(:position)
  end
  
  def scrape
    @tournament = InternationalTournament.find(params[:id])
    ScrapeUmbTournamentDetailsJob.perform_later(@tournament.id)
    
    redirect_to admin_international_tournament_path(@tournament), 
                notice: 'Scraping queued. Details will be available shortly.'
  end
end
```

## Phase 6: Player Matching & Deduplication

**Herausforderung:** Internationale Spieler mit deutschen Spielern matchen

```ruby
# app/services/international_player_matcher.rb
class InternationalPlayerMatcher
  def match_players
    # Find German players in UMB data
    Player.where(international_player: true, nationality: 'DE').find_each do |intl_player|
      # Try to find matching German player (by name, dbu_nr, etc.)
      german_player = find_matching_german_player(intl_player)
      
      if german_player
        Rails.logger.info "Match found: #{intl_player.fl_name} → #{german_player.fl_name}"
        
        # Option A: Merge players
        merge_players(intl_player, german_player)
        
        # Option B: Link via foreign key
        intl_player.update(merged_into_player_id: german_player.id)
      end
    end
  end
  
  private
  
  def find_matching_german_player(intl_player)
    # Try exact name match first
    candidates = Player.where(
      firstname: intl_player.firstname,
      lastname: intl_player.lastname,
      type: nil
    ).where.not(id: intl_player.id)
    
    return candidates.first if candidates.one?
    
    # Try fuzzy matching
    # ... implement Levenshtein distance or similar
    
    nil
  end
  
  def merge_players(source, target)
    # Move international associations to target player
    source.international_participations.update_all(player_id: target.id)
    source.international_results.update_all(player_id: target.id)
    
    # Copy international fields
    target.update(
      umb_player_id: source.umb_player_id,
      nationality: source.nationality || target.nationality,
      international_player: true
    )
    
    # Optionally delete source player
    source.destroy
  end
end
```

## Zusammenfassung: Empfohlene Reihenfolge

1. ✅ **Schema-Migrations** ausführen (Player nationality, umb_player_id)
2. ✅ **Seeds** für internationale Regions/Clubs
3. ✅ **UmbScraper erweitern** (Archive Index + Detail Scraping)
4. ✅ **PDF Parsing** implementieren (Players List + Final Ranking)
5. ✅ **Background Jobs** für asynchrone Verarbeitung
6. ✅ **Rake Tasks** für manuelles Scraping
7. ⚠️  **Player Matching** (optional, später)
8. ⚠️  **UI** für Admin-Interface (optional, später)

## Offene Fragen / Entscheidungen

1. **"Clubs" für Nationen?**
   - ✅ **Ja, empfohlen**: Minimale Änderungen am System
   - Nutzt bestehende Club/SeasonParticipation-Logik
   - Alternative: Neue `Country` oder `Nation` Model (mehr Aufwand)

2. **PDF Parsing - Alternative zu pdf-reader?**
   - Falls UMB PDFs schlecht geparst werden können:
     - Manual CSV Import als Fallback
     - OCR via Tesseract (sehr aufwändig)
   
3. **Rate Limiting / Scraping-Frequenz?**
   - Empfehlung: 1-2 Sekunden Pause zwischen Requests
   - UMB hat keine robots.txt - trotzdem vorsichtig sein

4. **Historische Daten: Wie weit zurück?**
   - Alle verfügbaren Jahre? (1980er bis heute?)
   - Oder nur letzte 5-10 Jahre?

5. **Duplicate Detection:**
   - Wie handhaben Sie doppelte Turniere (falls bereits manuell angelegt)?
   - Matching via `name + start_date ± 30 days` (wie im Code vorgeschlagen)?

---

## Nächste Schritte

**Soll ich mit der Implementierung beginnen?**

Option A: Ich erstelle die Migrations + Seeds
Option B: Ich erweitere den UmbScraper (Phase 2)
Option C: Ich erstelle einen vollständigen Prototypen (alle Phasen)

Was wäre Ihnen am hilfreichsten?
