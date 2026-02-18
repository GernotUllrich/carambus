# frozen_string_literal: true

require 'net/http'
require 'nokogiri'

# Service to scrape tournament data from UMB (Union Mondiale de Billard)
# Official website: https://files.umb-carom.org
class UmbScraper
  BASE_URL = 'https://files.umb-carom.org'
  FUTURE_TOURNAMENTS_URL = "#{BASE_URL}/public/FutureTournaments.aspx"
  TIMEOUT = 30 # seconds

  attr_reader :umb_source

  def initialize
    @umb_source = InternationalSource.find_or_create_by!(
      name: 'Union Mondiale de Billard',
      source_type: 'umb'
    ) do |source|
      source.base_url = BASE_URL
      source.metadata = {
        key: 'umb',
        priority: 1,
        description: 'World governing body for carom billiards'
      }
    end
  end

  # Scrape future tournaments from UMB
  def scrape_future_tournaments
    Rails.logger.info "[UmbScraper] Fetching future tournaments from UMB"
    
    begin
      html = fetch_url(FUTURE_TOURNAMENTS_URL)
      return [] if html.blank?
      
      doc = Nokogiri::HTML(html)
      tournaments = parse_future_tournaments(doc)
      
      Rails.logger.info "[UmbScraper] Found #{tournaments.size} future tournaments"
      
      saved_count = save_tournaments(tournaments)
      
      @umb_source.mark_scraped!
      
      Rails.logger.info "[UmbScraper] Saved #{saved_count} tournaments"
      saved_count
    rescue StandardError => e
      Rails.logger.error "[UmbScraper] Error scraping future tournaments: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      0
    end
  end

  # Scrape rankings for a specific discipline
  def scrape_rankings(discipline_name: '3-Cushion', year: Time.current.year)
    Rails.logger.info "[UmbScraper] Fetching #{discipline_name} rankings for #{year}"
    
    # UMB ranking PDFs are at: files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf
    # Example: https://files.umb-carom.org/Public/Ranking/1_WP_Ranking/2025/W30_2025.pdf
    
    # For now, just log that this is planned
    Rails.logger.warn "[UmbScraper] Ranking scraping not yet implemented"
    0
  end

  private

  # Fetch URL with timeout
  def fetch_url(url)
    uri = URI(url)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Carambus International Bot/1.0'
    
    response = http.request(request)
    
    if response.code == '200'
      response.body
    else
      Rails.logger.error "[UmbScraper] HTTP #{response.code} for #{url}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Failed to fetch #{url}: #{e.message}"
    nil
  end

  # Parse future tournaments from HTML
  def parse_future_tournaments(doc)
    tournaments = []
    
    # UMB uses a table structure for tournaments
    # Look for table rows with tournament data
    doc.css('table tr').each do |row|
      cells = row.css('td')
      next if cells.size < 4 # Skip header rows or incomplete data
      
      # Common UMB table structure:
      # | Date | Event | Location | Discipline |
      tournament_data = extract_tournament_from_row(cells)
      tournaments << tournament_data if tournament_data
    end
    
    tournaments
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Error parsing tournaments: #{e.message}"
    []
  end

  # Extract tournament data from table row
  def extract_tournament_from_row(cells)
    # Try to extract date, name, location, discipline
    # This is a heuristic parser - structure may vary
    
    date_text = cells[0]&.text&.strip
    event_text = cells[1]&.text&.strip
    location_text = cells[2]&.text&.strip
    discipline_text = cells[3]&.text&.strip
    
    return nil if event_text.blank?
    
    {
      name: event_text,
      location: location_text,
      discipline_name: discipline_text,
      date_range: date_text,
      source: 'umb',
      source_url: FUTURE_TOURNAMENTS_URL
    }
  rescue StandardError => e
    Rails.logger.warn "[UmbScraper] Failed to extract tournament from row: #{e.message}"
    nil
  end

  # Save tournaments to database
  def save_tournaments(tournaments)
    saved_count = 0
    
    tournaments.each do |data|
      begin
        # Parse dates
        dates = parse_date_range(data[:date_range])
        
        # Find discipline
        discipline = find_discipline(data[:discipline_name])
        next unless discipline
        
        # Determine tournament type from name
        tournament_type = determine_tournament_type(data[:name])
        
        # Find or create tournament
        tournament = InternationalTournament.find_or_initialize_by(
          name: data[:name],
          start_date: dates[:start_date]
        )
        
        if tournament.new_record?
          tournament.assign_attributes(
            end_date: dates[:end_date],
            location: data[:location],
            discipline: discipline,
            tournament_type: tournament_type,
            international_source: @umb_source,
            source_url: data[:source_url],
            data: {
              umb_official: true,
              scraped_at: Time.current.iso8601
            }
          )
          
          if tournament.save
            Rails.logger.info "[UmbScraper] Created tournament: #{data[:name]}"
            saved_count += 1
          else
            Rails.logger.error "[UmbScraper] Failed to save tournament: #{tournament.errors.full_messages}"
          end
        else
          # Update existing
          tournament.update(
            location: data[:location],
            source_url: data[:source_url],
            data: tournament.data.merge(
              umb_official: true,
              last_updated: Time.current.iso8601
            )
          )
          Rails.logger.info "[UmbScraper] Updated tournament: #{data[:name]}"
        end
      rescue StandardError => e
        Rails.logger.error "[UmbScraper] Error saving tournament #{data[:name]}: #{e.message}"
      end
    end
    
    saved_count
  end

  # Parse date range string (e.g. "18-21 Dec 2025" or "Feb 26 - Mar 1, 2026")
  def parse_date_range(date_str)
    return { start_date: nil, end_date: nil } if date_str.blank?
    
    # Clean up string
    cleaned = date_str.strip.gsub(/\s+/, ' ')
    
    # Try different patterns
    result = parse_day_range_with_month(cleaned) ||
             parse_month_day_range(cleaned) ||
             parse_full_month_range(cleaned)
    
    if result
      result
    else
      Rails.logger.warn "[UmbScraper] Could not parse date: #{date_str}"
      { start_date: nil, end_date: nil }
    end
  rescue StandardError => e
    Rails.logger.warn "[UmbScraper] Failed to parse date: #{date_str} - #{e.message}"
    { start_date: nil, end_date: nil }
  end

  # Parse "18-21 Dec 2025" or "December 18-21, 2025"
  def parse_day_range_with_month(str)
    # Pattern: "18-21 Dec 2025"
    if (match = str.match(/(\d{1,2})-(\d{1,2})\s+([A-Za-z]+)[\s,]+(\d{4})/))
      start_day = match[1].to_i
      end_day = match[2].to_i
      month_str = match[3]
      year = match[4].to_i
      
      month = parse_month_name(month_str)
      return nil unless month
      
      return {
        start_date: Date.new(year, month, start_day),
        end_date: Date.new(year, month, end_day)
      }
    end
    
    # Pattern: "December 18-21, 2025"
    if (match = str.match(/([A-Za-z]+)\s+(\d{1,2})-(\d{1,2})[\s,]+(\d{4})/))
      month_str = match[1]
      start_day = match[2].to_i
      end_day = match[3].to_i
      year = match[4].to_i
      
      month = parse_month_name(month_str)
      return nil unless month
      
      return {
        start_date: Date.new(year, month, start_day),
        end_date: Date.new(year, month, end_day)
      }
    end
    
    nil
  end

  # Parse "Feb 26 - Mar 1, 2026" (spans months)
  def parse_month_day_range(str)
    # Pattern: "Feb 26 - Mar 1, 2026"
    if (match = str.match(/([A-Za-z]+)\s+(\d{1,2})\s*-\s*([A-Za-z]+)\s+(\d{1,2})[\s,]+(\d{4})/))
      start_month_str = match[1]
      start_day = match[2].to_i
      end_month_str = match[3]
      end_day = match[4].to_i
      year = match[5].to_i
      
      start_month = parse_month_name(start_month_str)
      end_month = parse_month_name(end_month_str)
      
      return nil unless start_month && end_month
      
      # Handle year wrap (e.g. Dec 28 - Jan 3)
      end_year = year
      if end_month < start_month
        end_year += 1
      end
      
      return {
        start_date: Date.new(year, start_month, start_day),
        end_date: Date.new(end_year, end_month, end_day)
      }
    end
    
    nil
  end

  # Parse "September 15-27, 2026" or "Sept 15-27, 2026"
  def parse_full_month_range(str)
    # Already handled by parse_day_range_with_month
    nil
  end

  # Parse month name to number (1-12)
  def parse_month_name(name)
    return nil if name.blank?
    
    months = {
      'january' => 1, 'jan' => 1,
      'february' => 2, 'feb' => 2,
      'march' => 3, 'mar' => 3,
      'april' => 4, 'apr' => 4,
      'may' => 5,
      'june' => 6, 'jun' => 6,
      'july' => 7, 'jul' => 7,
      'august' => 8, 'aug' => 8,
      'september' => 9, 'sept' => 9, 'sep' => 9,
      'october' => 10, 'oct' => 10,
      'november' => 11, 'nov' => 11,
      'december' => 12, 'dec' => 12
    }
    
    months[name.downcase]
  end

  # Find discipline by name
  def find_discipline(name)
    return nil if name.blank?
    
    # Map UMB discipline names to our database
    mapping = {
      '3-cushion' => 'Dreiband',
      '3 cushion' => 'Dreiband',
      'libre' => 'Freie Partie',
      'cadre' => 'Cadre',
      '5-pins' => 'Fünfkampf',
      'balkline' => 'Cadre'
    }
    
    discipline_search = mapping[name.downcase] || name
    
    # Find in database
    Discipline.where('name ILIKE ?', "%#{discipline_search}%").first ||
      Discipline.find_by('name ILIKE ?', 'Karambol')
  end

  # Determine tournament type from name
  def determine_tournament_type(name)
    name_lower = name.downcase
    
    case name_lower
    when /world championship/
      'world_championship'
    when /world cup/
      'world_cup'
    when /european championship/
      'european_championship'
    when /world masters/
      'invitation'
    when /national championship/
      'national_championship'
    else
      'other'
    end
  end
end
