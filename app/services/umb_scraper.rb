# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'openssl'

# Service to scrape tournament data from UMB (Union Mondiale de Billard)
# Official website: https://files.umb-carom.org
class UmbScraper
  BASE_URL = 'https://files.umb-carom.org'
  FUTURE_TOURNAMENTS_URL = "#{BASE_URL}/public/FutureTournaments.aspx"
  ARCHIVE_URL = 'https://www.umb-carom.org/PG342L2/Union-Mondiale-de-Billard.aspx'
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
  
  # Scrape tournament archive by sequential ID scanning
  # UMB tournament detail URLs use sequential IDs: /TournametDetails.aspx?ID=1, ID=2, etc.
  # We can scan through a range of IDs to discover all tournaments
  def scrape_tournament_archive(start_id: 1, end_id: 500, batch_size: 50)
    Rails.logger.info "[UmbScraper] Scraping tournament archive: IDs #{start_id}..#{end_id}"
    
    total_found = 0
    total_saved = 0
    not_found_count = 0
    max_consecutive_404s = 50  # Stop if we hit 50 consecutive 404s
    
    (start_id..end_id).each do |id|
      break if not_found_count >= max_consecutive_404s
      
      Rails.logger.info "[UmbScraper] Checking tournament ID #{id}..."
      
      # Build detail URL
      detail_url = "#{BASE_URL}/public/TournametDetails.aspx?ID=#{id}"
      
      html = fetch_url(detail_url)
      
      if html.blank? || html.include?('404') || html.length < 500
        not_found_count += 1
        Rails.logger.debug "[UmbScraper] Tournament ID #{id} not found (consecutive 404s: #{not_found_count})"
        next
      end
      
      # Found a valid tournament
      not_found_count = 0
      total_found += 1
      
      begin
        doc = Nokogiri::HTML(html)
        tournament_data = parse_tournament_detail_for_archive(doc, id, detail_url)
        
        if tournament_data && save_archived_tournament(tournament_data)
          total_saved += 1
          Rails.logger.info "[UmbScraper] ✓ Saved tournament ID #{id}: #{tournament_data[:name]}"
        end
      rescue StandardError => e
        Rails.logger.error "[UmbScraper] Error parsing tournament ID #{id}: #{e.message}"
      end
      
      # Rate limiting
      sleep 1 if id % 10 == 0
    end
    
    Rails.logger.info "[UmbScraper] Archive scan complete: found #{total_found}, saved #{total_saved}"
    total_saved
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Error in archive scan: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    total_saved
  end

  # Scrape details for a specific tournament by ID
  def scrape_tournament_details(tournament_id_or_record)
    tournament = tournament_id_or_record.is_a?(Tournament) ? 
                 tournament_id_or_record : 
                 Tournament.find(tournament_id_or_record)
    
    # If tournament has an external_id, we can build the detail URL
    if tournament.external_id.present?
      detail_url = "#{BASE_URL}/public/TournametDetails.aspx?ID=#{tournament.external_id}"
    elsif tournament.data&.dig('umb_detail_url').present?
      detail_url = tournament.data['umb_detail_url']
    else
      Rails.logger.warn "[UmbScraper] No detail URL available for tournament #{tournament.id}"
      return false
    end
    
    Rails.logger.info "[UmbScraper] Scraping details for: #{tournament.name} (#{detail_url})"
    
    html = fetch_url(detail_url)
    return false if html.blank?
    
    doc = Nokogiri::HTML(html)
    
    # Find all PDF links on the detail page
    pdf_links = {}
    doc.css('a[href$=".pdf"]').each do |link|
      href = link['href']
      text = link.text.strip.downcase
      
      # Categorize PDFs by their purpose
      case text
      when /players.*list|seeding/i
        pdf_links[:players_list] = make_absolute_url(href)
      when /groups/i
        pdf_links[:groups] = make_absolute_url(href)
      when /timetable|schedule/i
        pdf_links[:timetable] = make_absolute_url(href)
      when /results.*by.*round/i
        pdf_links[:results_by_round] = make_absolute_url(href)
      when /final.*ranking|final.*results/i
        pdf_links[:final_ranking] = make_absolute_url(href)
      else
        pdf_links[:other] ||= []
        pdf_links[:other] << { text: link.text.strip, url: make_absolute_url(href) }
      end
    end
    
    # Store PDF links in tournament data
    tournament.data ||= {}
    tournament.data['pdf_links'] = pdf_links.compact
    tournament.data['detail_scraped_at'] = Time.current.iso8601
    
    if tournament.save
      Rails.logger.info "[UmbScraper] Saved #{pdf_links.size} PDF links for #{tournament.name}"
      
      # Automatically scrape players list if available
      if pdf_links[:players_list].present?
        scrape_players_from_pdf(tournament, pdf_links[:players_list])
      end
      
      # Automatically scrape final ranking if available
      if pdf_links[:final_ranking].present?
        scrape_results_from_pdf(tournament, pdf_links[:final_ranking])
      end
      
      true
    else
      Rails.logger.error "[UmbScraper] Failed to save tournament details: #{tournament.errors.full_messages}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Error scraping tournament details: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    false
  end

  private

  # Fetch URL with timeout and redirect handling
  def fetch_url(url, follow_redirects: true, max_redirects: 5)
    uri = URI(url)
    redirects = 0
    
    loop do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Carambus International Bot/1.0'
      request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      request['Accept-Language'] = 'en-US,en;q=0.5'
      
      response = http.request(request)
      
      case response
      when Net::HTTPSuccess
        return response.body
      when Net::HTTPRedirection
        if follow_redirects && redirects < max_redirects
          redirects += 1
          location = response['location']
          uri = URI.join(uri, location)
          Rails.logger.debug "[UmbScraper] Following redirect #{redirects}/#{max_redirects} to #{uri}"
          next
        else
          Rails.logger.error "[UmbScraper] Too many redirects for #{url}"
          return nil
        end
      else
        Rails.logger.error "[UmbScraper] HTTP #{response.code} for #{url}"
        return nil
      end
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
        # Check for existing by title (not name in Tournament), location and approximate date (within 30 days)
        # This catches duplicates even if dates are off by a day or year
        candidates = InternationalTournament
                    .where(title: data[:name])
                    .where(location_text: data[:location])
                    .where('date BETWEEN ? AND ?', 
                           dates[:start_date] - 30.days, 
                           dates[:start_date] + 30.days)
                    .to_a
        
        # Find the closest match by date
        existing = candidates.min_by { |t| (t.date.to_date - dates[:start_date]).abs }
        
        Rails.logger.debug "[UmbScraper]   → #{existing ? 'Found existing' : 'Creating new'}: #{data[:name]}"
        
        tournament = existing || InternationalTournament.new(
          title: data[:name],
          date: dates[:start_date]
        )
        
        if tournament.new_record?
          tournament.assign_attributes(
            end_date: dates[:end_date],
            location_text: data[:location],
            discipline: discipline,
            international_source: @umb_source,
            source_url: data[:source_url],
            modus: 'international',
            single_or_league: 'single',
            plan_or_show: 'show',
            state: dates[:start_date] > Date.today ? 'planned' : 'finished',
            data: {
              umb_official: true,
              umb_type: data[:tournament_type_hint],
              umb_organization: data[:organization],
              tournament_type: tournament_type,
              scraped_at: Time.current.iso8601
            }.to_json
          )
          
          if tournament.save
            Rails.logger.info "[UmbScraper] Created tournament: #{data[:name]} (#{dates[:start_date]})"
            saved_count += 1
          else
            Rails.logger.error "[UmbScraper] Failed to save tournament: #{tournament.errors.full_messages}"
          end
        else
          # Update existing
          tournament_data = tournament.data.is_a?(String) ? JSON.parse(tournament.data) : (tournament.data || {})
          tournament_data.merge!({
            umb_type: data[:tournament_type_hint],
            umb_organization: data[:organization],
            tournament_type: tournament_type,
            scraped_at: Time.current.iso8601
          })
          
          tournament.update(
            end_date: dates[:end_date],
            location_text: data[:location],
            source_url: data[:source_url],
            data: tournament_data.to_json,
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
  
  # Parse tournament detail page for archive scanning
  def parse_tournament_detail_for_archive(doc, external_id, detail_url)
    # Extract tournament info from detail page table
    tournament_info = {}
    
    # Find the tournament info table
    doc.css('table tr').each do |row|
      cells = row.css('td')
      next unless cells.size == 2
      
      label = cells[0].text.strip.downcase
      value = cells[1].text.strip
      
      case label
      when /tournament:/i
        tournament_info[:name] = value
      when /starts on:/i
        tournament_info[:start_date] = parse_date(value)
      when /ends on:/i
        tournament_info[:end_date] = parse_date(value)
      when /organized by:/i
        tournament_info[:organizer] = value
      when /place:/i
        city, country = parse_location_country(value)
        tournament_info[:location] = value
        tournament_info[:country] = country
      end
    end
    
    # Must have at least a name
    return nil unless tournament_info[:name].present?
    
    # Try to determine discipline from name
    discipline_name = determine_discipline_from_name(tournament_info[:name])
    discipline = Discipline.find_by(name: discipline_name)
    
    # Determine tournament type
    tournament_type = determine_tournament_type(tournament_info[:name])
    
    {
      name: tournament_info[:name],
      start_date: tournament_info[:start_date],
      end_date: tournament_info[:end_date],
      location: tournament_info[:location],
      country: tournament_info[:country],
      organizer: tournament_info[:organizer],
      discipline: discipline,
      tournament_type: tournament_type,
      external_id: external_id.to_s,
      source_url: detail_url,
      data: {
        umb_organization: tournament_info[:organizer],
        scraped_from: 'sequential_scan',
        scraped_at: Time.current.iso8601
      }
    }
  end
  
  # Save single archived tournament
  def save_archived_tournament(tournament_data)
    return false unless tournament_data[:name].present?
    
    # Check if tournament already exists
    existing = InternationalTournament.find_by(
      international_source: @umb_source,
      external_id: tournament_data[:external_id]
    )
    
    if existing
      Rails.logger.debug "[UmbScraper] Tournament #{tournament_data[:external_id]} already exists"
      return false
    end
    
    # Build attributes, discipline_id is required so we use a default if not found
    discipline_id = tournament_data[:discipline]&.id || Discipline.first&.id
    
    tournament = InternationalTournament.new(
      international_source: @umb_source,
      name: tournament_data[:name],
      start_date: tournament_data[:start_date],
      end_date: tournament_data[:end_date],
      location: tournament_data[:location],
      country: tournament_data[:country],
      organizer: tournament_data[:organizer],
      discipline_id: discipline_id,
      tournament_type: tournament_data[:tournament_type],
      external_id: tournament_data[:external_id],
      source_url: tournament_data[:source_url],
      data: tournament_data[:data]
    )
    
    if tournament.save
      true
    else
      Rails.logger.error "[UmbScraper] Failed to save tournament: #{tournament.errors.full_messages}"
      false
    end
  end
  
  # Parse date from various formats
  def parse_date(date_string)
    return nil if date_string.blank?
    
    # Try common UMB formats:
    # "24-February-2025"
    # "2025-02-24"
    # "24/02/2025"
    
    formats = [
      '%d-%B-%Y',    # 24-February-2025
      '%Y-%m-%d',    # 2025-02-24
      '%d/%m/%Y',    # 24/02/2025
      '%d.%m.%Y'     # 24.02.2025
    ]
    
    formats.each do |format|
      begin
        return Date.strptime(date_string, format)
      rescue ArgumentError
        next
      end
    end
    
    nil
  rescue StandardError => e
    Rails.logger.debug "[UmbScraper] Could not parse date: #{date_string}"
    nil
  end
  
  # Determine discipline from tournament name
  def determine_discipline_from_name(name)
    return '3-Cushion' if name =~ /3-cushion/i
    return 'Cadre 47/2' if name =~ /cadre.*47.*2|47.*2.*cadre/i
    return '5-Pins' if name =~ /5-pins?/i
    return 'Artistique' if name =~ /artistique/i
    return 'Balkline' if name =~ /balkline/i
    
    '3-Cushion'  # Default
  end
  
  # Save archived tournaments to database
  def save_archived_tournaments(tournaments)
    saved_count = 0
    
    tournaments.each do |data|
      # Parse dates from date_range string
      dates = parse_date_range(data[:date_range]) if data[:date_range].present?
      next unless dates && dates[:start_date]
      
      # Find or create discipline
      discipline = find_discipline_from_name(data[:discipline] || '3-Cushion')
      next unless discipline
      
      # Extract location and country
      location, country = parse_location_country(data[:location])
      
      # Determine tournament type
      tournament_type = determine_tournament_type(data[:name], data[:tournament_type_hint])
      
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
        Rails.logger.info "[UmbScraper] Saved archived tournament: #{data[:name]}"
        saved_count += 1
      else
        Rails.logger.error "[UmbScraper] Failed to save tournament: #{tournament.errors.full_messages}"
      end
    end
    
    saved_count
  end
  
  # Parse location and country from strings like "ANKARA (Turkey)"
  def parse_location_country(location_string)
    return [nil, nil] if location_string.blank?
    
    if (match = location_string.match(/([A-Z\s]+)\s*\(([^)]+)\)/))
      city = match[1].strip.titleize
      country = match[2].strip
      [city, country]
    else
      [location_string, nil]
    end
  end
  
  # Make relative URL absolute
  def make_absolute_url(url)
    return url if url.nil? || url.start_with?('http')
    
    if url.start_with?('/')
      "https://files.umb-carom.org#{url}"
    else
      "#{BASE_URL}/public/#{url}"
    end
  end
  
  # Download PDF file
  def download_pdf(url)
    full_url = make_absolute_url(url)
    Rails.logger.info "[UmbScraper] Downloading PDF: #{full_url}"
    
    uri = URI(full_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT * 2  # PDFs can be larger
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Carambus International Bot/1.0'
    
    response = http.request(request)
    
    if response.code == '200' && response['content-type']&.include?('pdf')
      response.body
    else
      Rails.logger.error "[UmbScraper] Failed to download PDF: HTTP #{response.code}, Content-Type: #{response['content-type']}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Failed to download PDF #{url}: #{e.message}"
    nil
  end
  
  # Scrape players from Players List PDF
  def scrape_players_from_pdf(tournament, pdf_url)
    Rails.logger.info "[UmbScraper] Parsing Players List PDF for: #{tournament.name}"
    
    # Note: PDF parsing requires 'pdf-reader' gem
    # For now, we'll log and return - full implementation needs the gem
    unless defined?(PDF::Reader)
      Rails.logger.warn "[UmbScraper] PDF parsing requires 'pdf-reader' gem - add to Gemfile"
      Rails.logger.warn "[UmbScraper] Run: bundle add pdf-reader"
      return 0
    end
    
    pdf_content = download_pdf(pdf_url)
    return 0 unless pdf_content
    
    begin
      require 'stringio'
      reader = PDF::Reader.new(StringIO.new(pdf_content))
      text = reader.pages.map(&:text).join("\n")
      
      # UMB player lists are in table format:
      # Number  LASTNAME Firstname  COUNTRY  RankPos  RankPts  PlayerID  Status
      # Example: "1      JASPERS Dick                               NL         1          480         0106      Main Tournament    Confirmed"
      players_data = []
      
      text.split("\n").each do |line|
        # Match table row: Position  LASTNAME Firstname  COUNTRY  RankingPos  RankingPts  PlayerID
        if line =~ /^\s*(\d+)\s+([A-Z][A-Z\s]+?[A-Z])\s+([A-Z][a-z]+.*?)\s+([A-Z]{2,3})\s+\d+\s+\d+\s+(\d+)/
          players_data << {
            position: $1.to_i,
            lastname: $2.strip,
            firstname: $3.strip,
            country: $4.strip.upcase,
            umb_player_id: $5.to_i
          }
        end
      end
      
      Rails.logger.info "[UmbScraper] Found #{players_data.size} players in PDF"
      
      # Save participations
      save_participations(tournament, players_data)
    rescue StandardError => e
      Rails.logger.error "[UmbScraper] Error parsing Players List PDF: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      0
    end
  end
  
  # Scrape results from Final Ranking PDF
  def scrape_results_from_pdf(tournament, pdf_url)
    Rails.logger.info "[UmbScraper] Parsing Final Ranking PDF for: #{tournament.name}"
    
    unless defined?(PDF::Reader)
      Rails.logger.warn "[UmbScraper] PDF parsing requires 'pdf-reader' gem"
      return 0
    end
    
    pdf_content = download_pdf(pdf_url)
    return 0 unless pdf_content
    
    begin
      require 'stringio'
      reader = PDF::Reader.new(StringIO.new(pdf_content))
      text = reader.pages.map(&:text).join("\n")
      
      # Pattern for UMB final rankings (more flexible to capture various formats)
      results_data = []
      
      # Try pattern with points and average
      text.scan(/(\d+)[\.\)]\s+([A-Z][A-Z\s]+?)\s+([A-Z][a-z]+.*?)\s*\(([A-Z]{2,3})\).*?(?:Points?:?\s*(\d+))?.*?(?:Avg:?\s*([\d.]+))?/mi) do |position, lastname, firstname, country, points, average|
        results_data << {
          position: position.to_i,
          lastname: lastname.strip.titleize,
          firstname: firstname.strip,
          country: country.strip.upcase,
          points: points&.to_i,
          average: average&.to_f
        }
      end
      
      Rails.logger.info "[UmbScraper] Found #{results_data.size} results in PDF"
      
      # Save results
      save_results(tournament, results_data)
    rescue StandardError => e
      Rails.logger.error "[UmbScraper] Error parsing Final Ranking PDF: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      0
    end
  end
  
  # Save international participations
  def save_participations(tournament, players_data)
    saved_count = 0
    umb_region = Region.find_by(shortname: "UMB")
    
    unless umb_region
      Rails.logger.error "[UmbScraper] UMB region not found - run seeds first"
      return 0
    end
    
    players_data.each do |data|
      player = find_or_create_international_player(
        firstname: data[:firstname],
        lastname: data[:lastname],
        nationality: data[:country],
        umb_player_id: data[:umb_player_id],
        region: umb_region
      )
      
      next unless player
      
      participation = InternationalParticipation.find_or_initialize_by(
        player: player,
        international_tournament: tournament
      )
      
      participation.source = InternationalParticipation::RESULT_LIST
      participation.confirmed = true
      
      if participation.save
        saved_count += 1
        Rails.logger.info "[UmbScraper] Added participation: #{player.fl_name} (#{data[:country]})"
      else
        Rails.logger.error "[UmbScraper] Failed to save participation: #{participation.errors.full_messages}"
      end
    end
    
    saved_count
  end
  
  # Save international results
  def save_results(tournament, results_data)
    saved_count = 0
    umb_region = Region.find_by(shortname: "UMB")
    
    unless umb_region
      Rails.logger.error "[UmbScraper] UMB region not found"
      return 0
    end
    
    results_data.each do |data|
      player = find_or_create_international_player(
        firstname: data[:firstname],
        lastname: data[:lastname],
        nationality: data[:country],
        region: umb_region
      )
      
      player_name = "#{data[:firstname]} #{data[:lastname]}"
      
      result = InternationalResult.find_or_initialize_by(
        international_tournament: tournament,
        position: data[:position]
      )
      
      result.assign_attributes(
        player: player,
        player_name: player_name,
        player_country: data[:country],
        points: data[:points],
        metadata: {
          average: data[:average],
          scraped_from: 'umb_pdf',
          scraped_at: Time.current.iso8601
        }.compact
      )
      
      if result.save
        saved_count += 1
        Rails.logger.info "[UmbScraper] Added result: #{data[:position]}. #{player_name} (#{data[:points]} pts)"
      else
        Rails.logger.error "[UmbScraper] Failed to save result: #{result.errors.full_messages}"
      end
    end
    
    saved_count
  end
  
  # Find or create international player
  def find_or_create_international_player(firstname:, lastname:, nationality:, region:, umb_player_id: nil)
    fl_name = "#{firstname} #{lastname}".strip
    
    # Try to find by umb_player_id first
    player = Player.find_by(umb_player_id: umb_player_id) if umb_player_id.present?
    
    # If not found by ID, try to find existing player by name
    if player.nil?
      player = Player.where(
        "LOWER(firstname) = ? AND LOWER(lastname) = ?",
        firstname.downcase,
        lastname.downcase
      ).where(type: nil).first
    end
    
    # If still not found, create new international player
    if player.nil?
      player = Player.new(
        firstname: firstname,
        lastname: lastname,
        fl_name: fl_name,
        nationality: nationality,
        umb_player_id: umb_player_id,
        international_player: true,
        region: region
      )
    end
    
    # Update fields if missing
    player.umb_player_id ||= umb_player_id
    player.nationality ||= nationality
    player.international_player = true
    player.region ||= region
    
    if player.save
      player
    else
      Rails.logger.error "[UmbScraper] Failed to create player #{fl_name}: #{player.errors.full_messages}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[UmbScraper] Error finding/creating player #{firstname} #{lastname}: #{e.message}"
    nil
  end
  
end
