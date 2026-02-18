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
    current_year = Time.current.year
    current_month = nil
    row_count = 0
    pending_cross_month = {} # Track incomplete cross-month events by name+location
    
    # UMB website has structure:
    # Month rows contain just the month name (e.g. "February")
    # Tournament rows contain: Date | Tournament Name | Type | Organization | Location
    
    doc.css('table tr').each do |row|
      row_count += 1
      cells = row.css('td')
      
      if cells.empty?
        Rails.logger.debug "[UmbScraper] Row #{row_count}: No cells"
        next
      end
      
      # Get full row text to check for months/years
      row_text = row.text.strip
      first_cell_raw = cells[0]&.text
      
      # Split first cell by newlines and get the first non-empty line
      # This handles cases where cell contains "2027\n\nApril\n05 - 11\n..."
      first_cell_lines = first_cell_raw&.split(/\n+/)&.map(&:strip)&.reject(&:blank?) || []
      first_line = first_cell_lines.first || ''
      
      Rails.logger.info "[UmbScraper] Row #{row_count}: #{cells.size} cells, first_line='#{first_line&.first(50)}', current_year=#{current_year}, current_month=#{current_month}"
      
      # Check if FIRST LINE of first cell is a year (like "2027" or "2026")
      year_found_this_row = false
      if first_line.match?(/^\s*(2026|2027|2028|2029|2030)\s*$/)
        if (match = first_line.match(/^\s*(2026|2027|2028|2029|2030)\s*$/))
          current_year = match[1].to_i
          year_found_this_row = true
          Rails.logger.info "[UmbScraper] Found year: #{current_year} (first line of cell)"
        end
      end
      
      # IMPORTANT: Check for month AFTER year check
      # Extract just the first recognizable month name from the row
      month_found_this_row = false
      %w[January February March April May June July August September October November December].each do |month_name|
        if row_text.match?(/\b#{month_name}\b/i)
          month_num = Date::MONTHNAMES.index(month_name)
          if month_num
            current_month = month_num
            month_found_this_row = true
            Rails.logger.info "[UmbScraper] Found month: #{month_name} (#{current_month}) with year=#{current_year}"
            break
          end
        end
      end
      
      # Skip year-only rows (but continue if row has both year and month)
      if year_found_this_row && !month_found_this_row
        next
      end
      
      # Try to parse as tournament row
      if cells.size < 5
        Rails.logger.debug "[UmbScraper] Row #{row_count}: Skipping - only #{cells.size} cells"
        next
      end
      
      tournament_data = extract_tournament_from_row(cells, 
                                                     current_month: current_month, 
                                                     current_year: current_year,
                                                     pending_cross_month: pending_cross_month)
      
      if tournament_data
        Rails.logger.info "[UmbScraper] Row #{row_count}: Extracted tournament: #{tournament_data[:name]} (date_range: #{tournament_data[:date_range]})"
        tournaments << tournament_data
      end
    end
    
    Rails.logger.debug "[UmbScraper] Total rows processed: #{row_count}"
    Rails.logger.info "[UmbScraper] Parsed #{tournaments.size} tournament entries from HTML"
    tournaments.compact
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Error parsing tournaments: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    []
  end

  # Extract tournament data from table row
  def extract_tournament_from_row(cells, current_month:, current_year:, pending_cross_month:)
    # UMB structure: Date | Tournament Name | Type | Organization | Location
    date_text = cells[0]&.text&.strip
    name_text = cells[1]&.text&.strip
    type_text = cells[2]&.text&.strip
    org_text = cells[3]&.text&.strip
    location_text = cells[4]&.text&.strip
    
    
    # Skip if this looks like a header row
    return nil if date_text.match?(/^Date$/i)
    return nil if name_text.match?(/^(Tournament|Type|Organization|Place)$/i)
    
    # Skip month header rows that have shifted data
    # Example: "February | 26 - | World Championship N | World Championship | UMB"
    # These rows have the month name in column 0 and partial tournament info in wrong columns
    if date_text.match?(/^(January|February|March|April|May|June|July|August|September|October|November|December)/i)
      Rails.logger.debug "[UmbScraper]   → Skipping month header row with shifted data"
      return nil
    end
    
    # Skip if name is too short
    return nil if name_text.blank? || name_text.length < 5
    
    # Skip rows that are just fragments (less than 3 words)
    return nil if name_text.split(/\s+/).size < 3
    
    # Skip if name is ONLY a date pattern (fragment rows like "26 -", "- 01", "06 - 12")
    return nil if name_text.match?(/^-?\s*\d{1,2}\s*-\s*\d{0,2}\s*$/)
    
    # Skip if name is just a month name with numbers (malformed rows)
    return nil if name_text.match?(/^(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d/i)
    
    # Clean location first (we need it for cross-month matching)
    cleaned_location = extract_location(location_text)
    if cleaned_location.blank?
      Rails.logger.debug "[UmbScraper]   → Skipping: no valid location (was: '#{location_text}')"
      return nil
    end
    
    # Check if this is a cross-month event (date starts with "DD -" or "- DD")
    key = "#{name_text}|#{cleaned_location}"
    
    if date_text.match?(/^(\d{1,2})\s*-\s*$/)
      # Start of cross-month event (e.g. "26 -")
      start_day = date_text.match(/^(\d{1,2})\s*-\s*$/)[1].to_i
      pending_cross_month[key] = {
        name: name_text,
        location: cleaned_location,
        type: type_text,
        org: org_text,
        start_month: current_month,
        start_year: current_year,
        start_day: start_day
      }
      Rails.logger.debug "[UmbScraper]   → Storing cross-month start: #{name_text} (#{start_day}.#{current_month}.#{current_year})"
      return nil # Don't add yet, wait for end date
    elsif date_text.match?(/^-\s*(\d{1,2})$/)
      # End of cross-month event (e.g. "- 05")
      end_day = date_text.match(/^-\s*(\d{1,2})$/)[1].to_i
      
      if pending_cross_month[key]
        # Found matching start! Build complete date range
        start_info = pending_cross_month[key]
        start_month_abbr = Date::ABBR_MONTHNAMES[start_info[:start_month]]
        end_month_abbr = Date::ABBR_MONTHNAMES[current_month]
        
        # Handle year wrap: if end month < start month, it's next year
        # Example: Dec (12) 31 -> Jan (1) 05 means Dec 2026 -> Jan 2027
        start_year = start_info[:start_year]
        end_year = current_month < start_info[:start_month] ? start_year + 1 : start_year
        
        # Build date string that parse_month_day_range can handle
        enhanced_date = "#{start_month_abbr} #{start_info[:start_day]} - #{end_month_abbr} #{end_day}, #{start_year}"
        Rails.logger.info "[UmbScraper]   → Completed cross-month event: #{name_text} (#{enhanced_date}, end_year=#{end_year})"
        
        pending_cross_month.delete(key) # Clean up
        
        return {
          name: name_text,
          location: cleaned_location,
          tournament_type_hint: type_text,
          organization: org_text,
          date_range: enhanced_date,
          source: 'umb',
          source_url: FUTURE_TOURNAMENTS_URL
        }
      else
        # No matching start found, skip this orphaned end
        Rails.logger.warn "[UmbScraper]   → Orphaned cross-month end: #{name_text} (- #{end_day})"
        return nil
      end
    end
    
    # Regular event (has complete date range)
    enhanced_date = enhance_date_with_context(date_text, current_month, current_year)
    
    # Skip if date enhancement failed (incomplete ranges)
    return nil if enhanced_date.nil?
    
    {
      name: name_text,
      location: cleaned_location,
      tournament_type_hint: type_text,
      organization: org_text,
      date_range: enhanced_date,
      source: 'umb',
      source_url: FUTURE_TOURNAMENTS_URL
    }
  rescue StandardError => e
    Rails.logger.warn "[UmbScraper] Failed to extract tournament from row: #{e.message}"
    nil
  end
  
  # Extract actual location from text like "ANKARA (Turkey)" or "UMB / CEB"
  def extract_location(text)
    return nil if text.blank?
    
    # If it looks like "CITY (Country)", extract that
    if (match = text.match(/([A-Z\s]+)\s*\(([^)]+)\)/))
      city = match[1].strip.titleize
      country = match[2].strip
      return "#{city}, #{country}"
    end
    
    # If it's "N/A (Country)", just return country
    if (match = text.match(/N\/A\s*\(([^)]+)\)/))
      return match[1].strip
    end
    
    # If it looks like org info (UMB / ...), return nil
    return nil if text.match?(/^UMB\s*\//)
    return nil if text.match?(/^WCBS/)
    
    # Otherwise return as-is
    text.strip
  end
  
  # Enhance date string with month/year context
  def enhance_date_with_context(date_str, month, year)
    return date_str if date_str.blank? || month.nil? || year.nil?
    
    # Clean up the date string first - remove extra whitespace and newlines
    cleaned = date_str.strip.gsub(/\s+/, ' ').gsub(/\n+/, ' ')
    
    # Extract ONLY the date portion if there's extra text
    # Pattern: find "DD - DD" anywhere in the string (not just at start)
    date_match = cleaned.match(/(\d{1,2}\s*-\s*\d{1,2})/)
    if date_match
      cleaned = date_match[1]
      Rails.logger.debug "[UmbScraper]   → extracted date portion: '#{cleaned}'"
    end
    
    Rails.logger.debug "[UmbScraper] enhance_date_with_context: '#{date_str}' → cleaned: '#{cleaned}' with month=#{month}, year=#{year}"
    
    # If date is just "06 - 12" add the month name
    if cleaned.match?(/^\d{1,2}\s*-\s*\d{1,2}$/)
      month_abbr = Date::ABBR_MONTHNAMES[month]
      enhanced = "#{cleaned} #{month_abbr} #{year}"
      Rails.logger.debug "[UmbScraper]   → enhanced to: '#{enhanced}'"
      return enhanced
    end
    
      # Cross-month events (e.g. "31 -" or "- 05") are now handled in extract_tournament_from_row
      # This should not be reached, but keep as fallback
      if cleaned.match?(/^-?\s*\d{1,2}\s*-\s*$/) || cleaned.match?(/^-\s*\d{1,2}$/)
        Rails.logger.debug "[UmbScraper]   → skipping incomplete cross-month date (handled elsewhere)"
        return nil
      end
    
    # If date already has month/year info, return as-is
    Rails.logger.debug "[UmbScraper]   → returning as-is"
    date_str
  end

  # Save tournaments to database
  def save_tournaments(tournaments)
    saved_count = 0
    
    tournaments.each do |data|
      begin
        # Parse dates
        dates = parse_date_range(data[:date_range])
        
        # Skip tournaments without valid dates
        if dates[:start_date].blank?
          Rails.logger.info "[UmbScraper] Skipping #{data[:name]} - no valid date"
          next
        end
        
        # Find discipline - default to Dreiband groß (3-Cushion on large table is most common)
        discipline = find_discipline_from_name(data[:name]) || 
                    Discipline.find_by('name ILIKE ?', '%dreiband%groß%') ||
                    Discipline.find_by('name ILIKE ?', '%dreiband%gross%')
        unless discipline
          Rails.logger.warn "[UmbScraper] Skipping #{data[:name]} - no discipline found"
          next
        end
        # Determine tournament type from name and type hint
        tournament_type = determine_tournament_type(data[:name], data[:tournament_type_hint])
        
        # Find or create tournament
        # Check for existing by name, location and approximate date (within 30 days)
        # This catches duplicates even if dates are off by a day or year
        candidates = InternationalTournament
                    .where(name: data[:name])
                    .where(location: data[:location])
                    .where('start_date BETWEEN ? AND ?', 
                           dates[:start_date] - 30.days, 
                           dates[:start_date] + 30.days)
                    .to_a
        
        # Find the closest match by date
        existing = candidates.min_by { |t| (t.start_date - dates[:start_date]).abs }
        
        Rails.logger.debug "[UmbScraper]   → #{existing ? 'Found existing' : 'Creating new'}: #{data[:name]}"
        
        tournament = existing || InternationalTournament.new(
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
              umb_type: data[:tournament_type_hint],
              umb_organization: data[:organization],
              scraped_at: Time.current.iso8601
            }
          )
          
          if tournament.save
            Rails.logger.info "[UmbScraper] Created tournament: #{data[:name]} (#{dates[:start_date]})"
            saved_count += 1
          else
            Rails.logger.error "[UmbScraper] Failed to save tournament: #{tournament.errors.full_messages}"
          end
        else
          # Update existing
          tournament.update(
            end_date: dates[:end_date],
            location: data[:location],
            tournament_type: tournament_type,
            source_url: data[:source_url],
            data: tournament.data.merge(
              umb_official: true,
              umb_type: data[:tournament_type_hint],
              umb_organization: data[:organization],
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
  # Note: UMB website often omits month/year - we need context from surrounding rows
  def parse_date_range(date_str, year: Time.current.year)
    return { start_date: nil, end_date: nil } if date_str.blank?
    
    # Clean up string - remove extra whitespace and newlines
    cleaned = date_str.strip.gsub(/\s+/, ' ').gsub(/\n+/, ' ')
    
    # Skip if it's too short or just numbers
    if cleaned.length < 3
      Rails.logger.debug "[UmbScraper] Date too short: '#{date_str}'"
      return { start_date: nil, end_date: nil }
    end
    
    # Try different patterns
    result = parse_day_range_with_month(cleaned, year: year) ||
             parse_month_day_range(cleaned) ||
             parse_full_month_range(cleaned)
    
    if result
      Rails.logger.debug "[UmbScraper] Parsed '#{date_str}' → #{result[:start_date]} to #{result[:end_date]}"
      result
    else
      Rails.logger.info "[UmbScraper] Could not parse date: '#{date_str}' (cleaned: '#{cleaned}')"
      { start_date: nil, end_date: nil }
    end
  rescue StandardError => e
    Rails.logger.warn "[UmbScraper] Failed to parse date: #{date_str} - #{e.message}"
    { start_date: nil, end_date: nil }
  end

  # Parse "18-21 Dec 2025" or "December 18-21, 2025" or just "18 - 24"
  def parse_day_range_with_month(str, year: Time.current.year)
    # Pattern: "18-21 Dec 2025" or "18 - 21 Dec 2025"
    if (match = str.match(/(\d{1,2})\s*-\s*(\d{1,2})\s+([A-Za-z]+)[\s,]*(\d{4})?/))
      start_day = match[1].to_i
      end_day = match[2].to_i
      month_str = match[3]
      year_from_match = match[4]&.to_i || year
      
      month = parse_month_name(month_str)
      return nil unless month
      
      begin
        return {
          start_date: Date.new(year_from_match, month, start_day),
          end_date: Date.new(year_from_match, month, end_day)
        }
      rescue ArgumentError => e
        Rails.logger.warn "[UmbScraper] Invalid date: #{year_from_match}-#{month}-#{start_day} to #{end_day}: #{e.message}"
        return nil
      end
    end
    
    # Pattern: "December 18-21, 2025" or "December 18 - 21, 2025"
    if (match = str.match(/([A-Za-z]+)\s+(\d{1,2})\s*-\s*(\d{1,2})[\s,]*(\d{4})?/))
      month_str = match[1]
      start_day = match[2].to_i
      end_day = match[3].to_i
      year_from_match = match[4]&.to_i || year
      
      month = parse_month_name(month_str)
      return nil unless month
      
      begin
        return {
          start_date: Date.new(year_from_match, month, start_day),
          end_date: Date.new(year_from_match, month, end_day)
        }
      rescue ArgumentError => e
        Rails.logger.warn "[UmbScraper] Invalid date: #{year_from_match}-#{month}-#{start_day} to #{end_day}: #{e.message}"
        return nil
      end
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

  # Find discipline from tournament name
  def find_discipline_from_name(name)
    return nil if name.blank?
    
    name_lower = name.downcase
    
    # Check for discipline keywords in name
    if name_lower.include?('3-cushion') || name_lower.include?('3 cushion')
      # UMB 3-Cushion tournaments are always on large tables = "Dreiband groß"
      return Discipline.find_by('name ILIKE ?', '%dreiband%groß%') ||
             Discipline.find_by('name ILIKE ?', '%dreiband%gross%') ||
             Discipline.find_by('name ILIKE ?', '%three%cushion%') ||
             Discipline.find_by('name ILIKE ?', '%3%cushion%') ||
             Discipline.find_by('name ILIKE ?', 'Karambol')  # Ultimate fallback
    elsif name_lower.include?('5-pins') || name_lower.include?('5 pins')
      return Discipline.find_by('name ILIKE ?', '%fünf%') || 
             Discipline.find_by('name ILIKE ?', '%five%') ||
             Discipline.find_by('name ILIKE ?', '%pin%')
    elsif name_lower.include?('artistique') || name_lower.include?('artistic')
      return Discipline.find_by('name ILIKE ?', '%artist%')
    elsif name_lower.include?('libre') || name_lower.include?('free')
      return Discipline.find_by('name ILIKE ?', '%frei%') || 
             Discipline.find_by('name ILIKE ?', '%libre%')
    elsif name_lower.include?('cadre')
      return Discipline.find_by('name ILIKE ?', '%cadre%')
    end
    
    # Default to generic Karambol (should always exist)
    Discipline.find_by('name ILIKE ?', '%karambol%') || Discipline.first
  end

  # Determine tournament type from name and UMB type hint
  def determine_tournament_type(name, type_hint = nil)
    name_lower = name.downcase
    hint_lower = type_hint&.downcase || ''
    
    # Check type hint first (more reliable)
    return 'world_championship' if hint_lower.include?('world championship')
    return 'world_cup' if hint_lower.include?('world cup')
    return 'european_championship' if hint_lower.include?('european championship')
    return 'invitation' if hint_lower.include?('invitational') || hint_lower.include?('promotional')
    
    # Fallback to name parsing
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
    when /general assembly/
      'other' # Not actually a tournament
    else
      'other'
    end
  end
end
