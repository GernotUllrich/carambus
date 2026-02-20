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
  TOURNAMENT_DETAILS_URL = "#{BASE_URL}/public/TournametDetails.aspx"
  TIMEOUT = 30 # seconds
  
  # Game type mappings from PDF filenames
  GAME_TYPE_MAPPINGS = {
    'PPPQ' => 'Pre-Pre-Pre-Qualification',
    'PPQ' => 'Pre-Pre-Qualification',
    'PQ' => 'Pre-Qualification',
    'Q' => 'Qualification',
    'R16' => 'Round of 16',
    'R32' => 'Round of 32',
    'Rank_8' => 'Match for 8th Place',
    'Quarter_Final' => 'Quarter Final',
    'Semi_Final-Final' => 'Semi Final & Final',
    'Semi_Final' => 'Semi Final',
    'Final' => 'Final'
  }.freeze

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

  # Detect discipline from tournament name
  def detect_discipline_from_name(tournament_name)
    return nil if tournament_name.blank?
    
    name_lower = tournament_name.to_s.downcase
    
    # 3-Cushion (Dreiband) - Most common for international tournaments
    if name_lower.match?(/3-?cushion|three ?cushion|dreiband|drei ?band|3-?bandes|3-?banden/i)
      # Default to "Dreiband halb" (Match Billard) for international tournaments
      return Discipline.find_by(name: 'Dreiband halb')&.id || 12
    end
    
    # 5-Pin Billards
    if name_lower.match?(/5-?pin|five ?pin/i)
      return Discipline.find_by(name: '5-Pin Billards')&.id || 26
    end
    
    # 1-Cushion (Einband)
    if name_lower.match?(/1-?cushion|one ?cushion|einband|een ?band/i)
      return Discipline.find_by(name: 'Einband halb')&.id || 11
    end
    
    # Straight Rail / Freie Partie
    if name_lower.match?(/straight ?rail|libre|freie ?partie|vrije ?partij/i)
      return Discipline.find_by(name: 'Freie Partie klein')&.id || 34
    end
    
    # Cadre / Balkline
    if name_lower.match?(/cadre|balkline|(\d+)\/(\d+)/i)
      # Try to detect specific cadre size
      if name_lower.match?(/47\/2/)
        return Discipline.find_by(name: 'Cadre 47/2')&.id || 40
      elsif name_lower.match?(/71\/2/)
        return Discipline.find_by(name: 'Cadre 71/2')&.id || 39
      elsif name_lower.match?(/57\/2/)
        return Discipline.find_by(name: 'Cadre 57/2')&.id || 10
      elsif name_lower.match?(/52\/2/)
        return Discipline.find_by(name: 'Cadre 52/2')&.id || 36
      elsif name_lower.match?(/35\/2/)
        return Discipline.find_by(name: 'Cadre 35/2')&.id || 35
      else
        # Default cadre
        return Discipline.find_by(name: 'Cadre 47/2')&.id || 40
      end
    end
    
    # Default: Dreiband halb (most international tournaments are 3-cushion)
    Discipline.find_by(name: 'Dreiband halb')&.id || 12
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

  # Fetch basic tournament data from details page
  def fetch_tournament_basic_data(external_id)
    detail_url = "#{TOURNAMENT_DETAILS_URL}?ID=#{external_id}"
    html = fetch_url(detail_url)
    return nil if html.blank?
    
    doc = Nokogiri::HTML(html)
    
    # Extract tournament info from table
    data = { external_id: external_id, url: detail_url }
    
    doc.css('table tr').each do |row|
      cells = row.css('td')
      next if cells.size < 2
      
      label = cells[0].text.strip.downcase
      value = cells[1].text.strip
      
      case label
      when /tournament:/
        data[:name] = value
      when /starts on:/
        data[:start_date] = value
      when /ends on:/
        data[:end_date] = value
      when /place:/
        data[:location] = value
      when /organized by:/
        data[:organizer] = value
      end
    end
    
    data[:name].present? ? data : nil
  end
  
  # Create tournament from basic data
  def save_tournament_from_details(data)
    location, country = parse_location_country(data[:location])
    
    # Parse dates (format: "04-November-2024")
    start_date = parse_single_date(data[:start_date])
    end_date = parse_single_date(data[:end_date])
    
    # Use placeholder discipline if none found
    discipline = Discipline.find_by(name: 'Dreiband') || 
                 Discipline.find_by(name: 'Unknown Discipline')
    
    # Prepare tournament attributes with enhanced location/season/organizer handling
    season = find_or_create_season_from_date(start_date)
    umb_organizer = find_or_create_umb_organizer
    
    # CRITICAL: Warn if organizer is missing
    if umb_organizer.nil?
      Rails.logger.error "[UmbScraper] WARNING: Creating tournament '#{data[:name]}' WITHOUT organizer!"
    end
    
    location_record = find_or_create_location_from_text(location) if location.present?
    
    tournament = InternationalTournament.new(
      title: data[:name],
      external_id: data[:external_id].to_s,
      international_source: @umb_source,
      discipline: discipline,
      date: start_date,
      end_date: end_date,
      location_text: location,
      location_id: location_record&.id,
      modus: 'international',
      plan_or_show: 'show',
      single_or_league: 'single',
      state: 'finished',
      source_url: data[:url],
      season_id: season&.id,
      organizer_id: umb_organizer&.id,
      organizer_type: 'Region'
    )
    
    if tournament.save(validate: false)
      Rails.logger.info "[UmbScraper] Created tournament: #{tournament.title}"
      tournament
    else
      Rails.logger.error "[UmbScraper] Failed to create tournament: #{tournament.errors.full_messages}"
      nil
    end
  end
  
  # Scrape details for a specific tournament by ID
  # @param tournament_id_or_record [Integer, InternationalTournament] Tournament ID or record
  # @param create_games [Boolean] Whether to create Game records
  # @param parse_pdfs [Boolean] Whether to parse PDFs for match details
  def scrape_tournament_details(tournament_id_or_record, create_games: true, parse_pdfs: false)
    tournament = tournament_id_or_record.is_a?(InternationalTournament) ? 
                 tournament_id_or_record : 
                 InternationalTournament.find(tournament_id_or_record)
    
    # If tournament has an external_id, we can build the detail URL
    if tournament.external_id.present?
      detail_url = "#{TOURNAMENT_DETAILS_URL}?ID=#{tournament.external_id}"
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
    
    # Parse tournament information from the details table
    tournament_info = {}
    doc.css('table tr').each do |row|
      cells = row.css('td')
      next if cells.size < 2
      
      label = cells[0].text.strip.gsub(':', '')
      value = cells[1].text.strip
      
      case label
      when 'Tournament'
        tournament_info[:name] = value
      when 'Starts on'
        tournament_info[:start_date] = value
      when 'Ends on'
        tournament_info[:end_date] = value
      when 'Organized by'
        tournament_info[:organizer] = value
      when 'Place'
        tournament_info[:location] = value
      when 'Material'
        tournament_info[:material] = value
      when 'Delegate UMB'
        tournament_info[:delegate] = value.gsub(/\[.*\]/, '').strip
      end
    end
    
    # Update location_text if we found it and tournament doesn't have one
    if tournament_info[:location].present? && tournament.location_text.blank?
      tournament.location_text = tournament_info[:location]
      Rails.logger.info "[UmbScraper] Found location: #{tournament_info[:location]}"
    end
    
    # Find all PDF links on the detail page
    pdf_links = {}
    game_types = []
    ranking_files = []
    
    doc.css('a[href*=".pdf"]').each do |link|
      href = link['href']
      text = link.text.strip
      absolute_url = make_absolute_url(href)
      
      # Store all PDFs
      pdf_links[text] = absolute_url
      
      # Categorize PDFs by their purpose (old categorization for backward compatibility)
      text_lower = text.downcase
      case text_lower
      when /players.*list|seeding/i
        pdf_links[:players_list] ||= absolute_url
      when /^b\.\s*groups/i
        pdf_links[:groups] ||= absolute_url
      when /timetable|schedule/i
        pdf_links[:timetable] ||= absolute_url
      when /results.*by.*round/i
        pdf_links[:results_by_round] ||= absolute_url
      when /final.*ranking|final.*results/i
        pdf_links[:final_ranking] ||= absolute_url
      end
      
      # Extract game types from filenames
      GAME_TYPE_MAPPINGS.each do |key, description|
        if text.match?(/GroupResults_#{key}\.pdf/i) || 
           text.match?(/MTResults_#{key}\.pdf/i)
          
          game_types << {
            key: key,
            name: description,
            pdf_url: absolute_url,
            pdf_filename: text,
            category: text.include?('GroupResults') ? 'group' : 'main_tournament'
          }
        end
      end
      
      # Extract ranking files
      if text.match?(/Ranking/i)
        phase = if text.match?(/FinalRanking/i)
                  'final'
                elsif (match = text.match(/Groups?_Ranking_(\w+)\.pdf/i))
                  match[1].downcase
                else
                  'unknown'
                end
        
        ranking_files << {
          phase: phase,
          pdf_url: absolute_url,
          pdf_filename: text
        }
      end
    end
    
    # Store enhanced data in tournament
    tournament.data ||= {}
    tournament.data['pdf_links'] = pdf_links.compact
    tournament.data['game_types'] = game_types
    tournament.data['ranking_files'] = ranking_files
    tournament.data['detail_scraped_at'] = Time.current.iso8601
    
    # Remember original organizer to avoid overwriting it
    original_organizer_id = tournament.organizer_id
    original_organizer_type = tournament.organizer_type
    
    # 1. LOCATION: Create Location from location_text if needed
    if tournament.location_id.blank? && tournament.location_text.present?
      location = find_or_create_location_from_text(tournament.location_text)
      tournament.location_id = location&.id if location
    end
    
    # 2. SEASON: Create Season from date if needed (billiard season starts July 1st)
    if tournament.season_id.blank? && tournament.date.present?
      season = find_or_create_season_from_date(tournament.date)
      tournament.season_id = season&.id if season
    end
    
    # 3. ORGANIZER: Set UMB as organizer for all UMB tournaments (only if not set)
    if original_organizer_id.blank?
      umb_region = find_or_create_umb_organizer
      tournament.organizer_id = umb_region&.id
      tournament.organizer_type = 'Region'
    else
      # Restore original organizer to prevent overwriting
      tournament.organizer_id = original_organizer_id
      tournament.organizer_type = original_organizer_type
    end
    
    if tournament.save(validate: false)
      Rails.logger.info "[UmbScraper] Saved #{pdf_links.size} PDF links, #{game_types.size} game types for #{tournament.name}"
      
      # Create games if requested (InternationalTournament IS a Tournament via STI)
      if create_games && game_types.any?
        create_games_for_tournament(tournament, game_types, parse_pdfs: parse_pdfs)
      end
      
      # Note: Players list and final ranking use InternationalParticipation
      # which should be created via separate process
      # Game participations are created directly from GroupResults PDFs above
      
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
    
    Timeout.timeout(TIMEOUT + 5) do  # Overall timeout slightly longer than individual timeouts
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
    end
  rescue Timeout::Error
    Rails.logger.error "[UmbScraper] Timeout fetching #{url}"
    nil
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
  
  # Parse location text to extract city and country code
  # Returns: { city: "Nice", country_code: "FR" }
  def parse_location_components(location_text)
    return nil if location_text.blank?
    
    # Match patterns like "NICE (France)" or "Nice (FR)"
    if (match = location_text.match(/([A-Za-z\s\-]+)\s*\(([A-Za-z\s]{2,})\)/))
      city = match[1].strip.titleize
      country = match[2].strip
      
      # Try to convert country name to code
      country_code = country_name_to_code(country)
      
      return { city: city, country_code: country_code, full_text: location_text }
    end
    
    # Fallback: just return the text as city
    { city: location_text, country_code: nil, full_text: location_text }
  end
  
  # Convert country name to ISO 2-letter code
  def country_name_to_code(country_name)
    mapping = {
      'France' => 'FR', 'FR' => 'FR',
      'Germany' => 'DE', 'DE' => 'DE', 'Deutschland' => 'DE',
      'Belgium' => 'BE', 'BE' => 'BE', 'Belgique' => 'BE', 'België' => 'BE',
      'Netherlands' => 'NL', 'NL' => 'NL', 'Nederland' => 'NL',
      'Spain' => 'ES', 'ES' => 'ES', 'España' => 'ES',
      'Italy' => 'IT', 'IT' => 'IT', 'Italia' => 'IT',
      'Turkey' => 'TR', 'TR' => 'TR', 'Türkiye' => 'TR',
      'Austria' => 'AT', 'AT' => 'AT', 'Österreich' => 'AT',
      'Switzerland' => 'CH', 'CH' => 'CH', 'Schweiz' => 'CH',
      'Egypt' => 'EG', 'EG' => 'EG',
      'Korea' => 'KR', 'KR' => 'KR', 'South Korea' => 'KR',
      'Vietnam' => 'VN', 'VN' => 'VN',
      'USA' => 'US', 'US' => 'US', 'United States' => 'US',
      'Luxembourg' => 'LU', 'LU' => 'LU',
      'Portugal' => 'PT', 'PT' => 'PT',
      'Greece' => 'GR', 'GR' => 'GR',
      'Poland' => 'PL', 'PL' => 'PL',
      'Czech Republic' => 'CZ', 'CZ' => 'CZ',
      'Slovenia' => 'SI', 'SI' => 'SI',
      'Denmark' => 'DK', 'DK' => 'DK'
    }
    
    mapping[country_name] || country_name[0, 2].upcase rescue 'XX'
  end
  
  # Find or create a Location from location_text
  def find_or_create_location_from_text(location_text)
    return nil if location_text.blank?
    
    # Parse components first
    components = parse_location_components(location_text)
    return nil unless components
    
    # Check if location already exists (by city name)
    existing = Location.find_by(name: components[:city])
    return existing if existing
    
    # Create new location
    Location.create!(
      name: components[:city],
      address: components[:full_text],
      data: {
        country_code: components[:country_code],
        created_from: 'umb_scraper',
        created_at: Time.current.iso8601
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[UmbScraper] Could not create location '#{location_text}': #{e.message}"
    nil
  end
  
  # Find or create Season from date (billiard season starts July 1st)
  def find_or_create_season_from_date(date)
    return nil if date.blank?
    
    # Try existing season logic first
    season = Season.season_from_date(date)
    return season if season
    
    # Create new season if it doesn't exist
    # Billiard season runs from July 1st to June 30th
    year = date.year
    season_start_year = date.month >= 7 ? year : year - 1
    season_end_year = season_start_year + 1
    season_name = "#{season_start_year}/#{season_end_year}"
    
    Season.find_or_create_by!(name: season_name) do |s|
      s.ba_id = nil
      s.data = "created_from: umb_scraper, start: #{Date.new(season_start_year, 7, 1)}, end: #{Date.new(season_end_year, 6, 30)}"
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[UmbScraper] Could not create season for date #{date}: #{e.message}"
    Season.find_by(name: 'Unknown Season')
  end
  
  # Find or create UMB organizer region
  def find_or_create_umb_organizer
    # Try to find existing UMB region first
    umb = Region.find_by(shortname: 'UMB')
    return umb if umb
    
    # Create new UMB region
    Region.create!(
      shortname: 'UMB',
      name: 'Union Mondiale de Billard',
      email: 'info@umb-carom.org',
      website: 'https://www.umb-carom.org',
      scrape_data: {
        'created_from' => 'umb_scraper',
        'description' => 'World governing body for carom billiards',
        'created_at' => Time.current.iso8601
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[UmbScraper] CRITICAL: Could not create UMB region: #{e.message}"
    # Try to find fallback, but log error if it doesn't exist
    fallback = Region.find_by(shortname: 'UNKNOWN')
    unless fallback
      Rails.logger.error "[UmbScraper] CRITICAL: No UNKNOWN fallback region found! Tournament will be created without organizer!"
    end
    fallback
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
          # Prepare enhanced attributes for new tournament
          season = find_or_create_season_from_date(dates[:start_date])
          umb_organizer = find_or_create_umb_organizer
          location_record = find_or_create_location_from_text(data[:location]) if data[:location].present?
          
          tournament.assign_attributes(
            end_date: dates[:end_date],
            location_text: data[:location],
            location_id: location_record&.id,
            discipline: discipline,
            international_source: @umb_source,
            source_url: data[:source_url],
            season_id: season&.id,
            organizer_id: umb_organizer&.id,
            organizer_type: 'Region',
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
            data: tournament_data.merge(
              umb_official: true,
              umb_type: data[:tournament_type_hint],
              umb_organization: data[:organization],
              last_updated: Time.current.iso8601
            ).to_json
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
  
  # Parse single date like "04-November-2024"
  def parse_single_date(date_str)
    return nil if date_str.blank?
    
    # Try standard date parsing
    begin
      Date.parse(date_str)
    rescue
      nil
    end
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
    
    # Check for Cadre variants FIRST (more specific)
    if name_lower.match?(/cadre|balkline/)
      # Try to detect specific cadre size from name
      if name_lower.match?(/47[\s\/\-]*2/)
        return Discipline.find_by('name ILIKE ?', '%cadre%47%2%') ||
               Discipline.find_by('name ILIKE ?', '%47%2%')
      elsif name_lower.match?(/71[\s\/\-]*2/)
        return Discipline.find_by('name ILIKE ?', '%cadre%71%2%') ||
               Discipline.find_by('name ILIKE ?', '%71%2%')
      elsif name_lower.match?(/57[\s\/\-]*2/)
        return Discipline.find_by('name ILIKE ?', '%cadre%57%2%') ||
               Discipline.find_by('name ILIKE ?', '%57%2%')
      elsif name_lower.match?(/52[\s\/\-]*2/)
        return Discipline.find_by('name ILIKE ?', '%cadre%52%2%') ||
               Discipline.find_by('name ILIKE ?', '%52%2%')
      elsif name_lower.match?(/35[\s\/\-]*2/)
        return Discipline.find_by('name ILIKE ?', '%cadre%35%2%') ||
               Discipline.find_by('name ILIKE ?', '%35%2%')
      else
        # Generic cadre - default to 47/2
        return Discipline.find_by('name ILIKE ?', '%cadre%47%2%') ||
               Discipline.find_by('name ILIKE ?', '%cadre%')
      end
    end
    
    # Check for 3-Cushion (case insensitive)
    if name_lower.match?(/3[\s\-]*cushion|three[\s\-]*cushion|dreiband|drei[\s\-]*band|3[\s\-]*bandes|3[\s\-]*banden/)
      # International UMB 3-Cushion tournaments are ALWAYS on full-size tables = "Dreiband groß"
      # Only German national leagues use match tables ("Dreiband halb")
      return Discipline.find_by('name ILIKE ?', '%dreiband%groß%') ||
             Discipline.find_by('name ILIKE ?', '%dreiband%gross%') ||
             Discipline.find_by('name ILIKE ?', '%three%cushion%') ||
             Discipline.find_by('name ILIKE ?', '%3%cushion%') ||
             Discipline.find_by('name ILIKE ?', '%dreiband%halb%') ||  # Fallback
             Discipline.find_by('name ILIKE ?', 'Karambol')  # Ultimate fallback
    end
    
    # 5-Pin Billards
    if name_lower.match?(/5[\s\-]*pin/)
      return Discipline.find_by('name ILIKE ?', '%5%pin%') ||
             Discipline.find_by('name ILIKE ?', '%fünf%') || 
             Discipline.find_by('name ILIKE ?', '%five%')
    end
    
    # 1-Cushion (Einband)
    if name_lower.match?(/1[\s\-]*cushion|one[\s\-]*cushion|einband/)
      return Discipline.find_by('name ILIKE ?', '%einband%') ||
             Discipline.find_by('name ILIKE ?', '%1%cushion%')
    end
    
    # Artistique / Artistic
    if name_lower.match?(/artistique|artistic|künstlerisch/)
      return Discipline.find_by('name ILIKE ?', '%artist%')
    end
    
    # Libre / Free Game / Freie Partie
    if name_lower.match?(/libre|straight[\s\-]*rail|freie[\s\-]*partie/)
      return Discipline.find_by('name ILIKE ?', '%frei%parti%') || 
             Discipline.find_by('name ILIKE ?', '%libre%')
    end
    
    # Default to Dreiband groß (3-Cushion on full-size table is most common for UMB tournaments)
    # Use placeholder if nothing matches
    Discipline.find_by('name ILIKE ?', '%dreiband%groß%') ||
      Discipline.find_by('name ILIKE ?', '%dreiband%gross%') ||
      Discipline.find_by('name ILIKE ?', '%karambol%') || 
      Discipline.find_by(name: 'Unknown Discipline')
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
    # Try to detect discipline from tournament name first
    # NEVER use Discipline.first - it returns a random discipline!
    discipline_id = tournament_data[:discipline]&.id || 
                    detect_discipline_from_name(tournament_data[:name]) ||
                    Discipline.find_by(name: 'Unknown Discipline')&.id
    
    # Get season and organizer for required fields - use placeholders if not available
    # NEVER use Season.first or Region.first - they return random records!
    season = tournament_data[:start_date] ? Season.season_from_date(tournament_data[:start_date]) : nil
    # Enhanced tournament creation with auto-created Location, Season, and UMB Organizer
    season = find_or_create_season_from_date(tournament_data[:start_date]) if tournament_data[:start_date]
    season ||= Season.find_by(name: 'Unknown Season')
    
    umb_organizer = find_or_create_umb_organizer
    location_record = find_or_create_location_from_text(tournament_data[:location]) if tournament_data[:location].present?
    
    tournament = InternationalTournament.new(
      international_source: @umb_source,
      title: tournament_data[:name],
      date: tournament_data[:start_date],
      end_date: tournament_data[:end_date],
      location_text: tournament_data[:location],
      location_id: location_record&.id,
      discipline_id: discipline_id,
      external_id: tournament_data[:external_id],
      source_url: tournament_data[:source_url],
      season_id: season&.id,
      organizer_id: umb_organizer&.id,
      organizer_type: 'Region',
      modus: 'international',
      plan_or_show: 'show',
      single_or_league: 'single',
      state: tournament_data[:start_date] && tournament_data[:start_date] < Date.today ? 'finished' : 'planned',
      data: tournament_data[:data].merge(
        country: tournament_data[:country],
        organizer_text: tournament_data[:organizer],
        tournament_type: tournament_data[:tournament_type]
      ).to_json
    )
    
    if tournament.save(validate: false)
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
      
      # Use Seeding instead of InternationalParticipation
      seeding = Seeding.find_or_initialize_by(
        player: player,
        tournament: tournament
      )
      
      # Store metadata in data field
      seeding.data ||= {}
      seeding.data['source'] = 'result_list'
      seeding.data['country'] = data[:country]
      seeding.state = 'confirmed'
      
      if seeding.save
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
  
  # Create game records for each game type found
  # Note: InternationalTournament is a Tournament (STI), so it has games directly
  # Note: tournament_type is used for polymorphic association, not for game type!
  def create_games_for_tournament(tournament, game_types, parse_pdfs: false)
    Rails.logger.info "[UmbScraper]   Creating games for tournament: #{tournament.title}"
    
    created_count = 0
    updated_count = 0
    
    game_types.each do |game_type|
      # Create or update game record
      game = tournament.games.find_or_initialize_by(
        gname: game_type[:name]
      )
      
      is_new = game.new_record?
      
      # Store all game type info in data (tournament_type is polymorphic column!)
      game_data = game.data || {}
      game_data['umb_game_type'] = game_type[:key]
      game_data['umb_category'] = game_type[:category] # 'group' or 'main_tournament'
      game_data['umb_pdf_url'] = game_type[:pdf_url]
      game_data['umb_pdf_filename'] = game_type[:pdf_filename]
      game_data['umb_scraped_at'] = Time.current.iso8601
      game.data = game_data # Keep as Hash, not JSON string
      
      if game.save(validate: false)
        if is_new
          created_count += 1
          Rails.logger.info "[UmbScraper]     ✓ Created game: #{game_type[:name]}"
        else
          updated_count += 1
          Rails.logger.debug "[UmbScraper]     ✓ Updated game: #{game_type[:name]}"
        end
        
        # Parse PDF for game details if requested
        if parse_pdfs && game_type[:pdf_url].present?
          begin
            Timeout.timeout(60) do  # 60 second timeout per PDF
              if game_type[:pdf_filename].match?(/GroupResults/i)
                parse_group_results_pdf(game, game_type[:pdf_url])
              elsif game_type[:pdf_filename].match?(/MTResults/i)
                parse_knockout_results_pdf(game, game_type[:pdf_url])
              end
            end
          rescue Timeout::Error
            Rails.logger.error "[UmbScraper]     ✗ PDF parsing timeout for #{game_type[:pdf_filename]}"
          rescue => e
            Rails.logger.error "[UmbScraper]     ✗ PDF parsing error: #{e.message}"
          end
        end
      else
        Rails.logger.error "[UmbScraper]     ✗ Failed to save game: #{game.errors.full_messages}"
      end
    end
    
    Rails.logger.info "[UmbScraper]   Games: #{created_count} created, #{updated_count} updated"
    created_count + updated_count
  end
  
  # Parse GroupResults PDF to extract match data and create individual Games (one per match)
  # Each match has exactly 2 players
  def parse_group_results_pdf(phase_game, pdf_url)
    Rails.logger.info "[UmbScraper]     Parsing PDF for phase: #{phase_game.gname}"
    
    unless defined?(PDF::Reader)
      Rails.logger.warn "[UmbScraper]     PDF parsing requires 'pdf-reader' gem"
      return 0
    end
    
    pdf_content = download_pdf(pdf_url)
    return 0 unless pdf_content
    
    begin
      require 'stringio'
      reader = PDF::Reader.new(StringIO.new(pdf_content))
      text = reader.pages.map(&:text).join("\n")
      
      player_lines = []
      current_group = nil
      
      # Parse text line by line to extract player performance data
      text.split("\n").each do |line|
        next if line.blank?
        
        # Detect group header
        if line.match?(/^\s*([A-Z])\s{3,}/) && line.match?(/\d+\s+\d+\s+[\d.]+/)
          group_match = line.match(/^\s*([A-Z])\s+/)
          current_group = group_match[1] if group_match
        elsif line.match?(/^\s*([A-Z])\s{3,}/) && !line.match?(/\d+/)
          current_group = line.match(/^\s*([A-Z])/)[1]
          next
        end
        
        # Parse player line
        if line.match?(/([A-Z][A-Za-z\s]+?)\s{3,}(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$/)
          match_data = line.match(/([A-Z][A-Za-z\s]+?)\s{3,}(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$/)
          
          player_name = match_data[1].strip.sub(/^[A-Z]\s+/, '')
          
          # Skip summary lines
          next if player_name.match?(/Players|^(TR|ES|KR|DK|JP|VN|SE)\s/)
          
          player_lines << {
            group: current_group,
            player_name: player_name,
            points: match_data[2].to_i,
            innings: match_data[3].to_i,
            average: match_data[4].to_f,
            match_points: match_data[5].to_i,
            high_run_1: match_data[6].to_i,
            high_run_2: match_data[7].to_i
          }
        end
      end
      
      # Group player lines into matches (pairs of consecutive players)
      matches = []
      player_lines.each_slice(2) do |player_pair|
        if player_pair.size == 2
          matches << player_pair
        end
      end
      
      Rails.logger.info "[UmbScraper]     Found #{matches.size} matches (#{player_lines.size} player performances)"
      
      # Create individual games for each match (with round_name for display)
      games_created = create_games_from_matches(
        phase_game.tournament, 
        phase_game, 
        matches,
        round_name: nil  # Group phase doesn't have round names
      )
      
      games_created
    rescue StandardError => e
      Rails.logger.error "[UmbScraper]     Error parsing PDF: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      0
    end
  end
  
  # Create individual Game records for each match (2 players per game)
  def create_games_from_matches(tournament, phase_game, matches, round_name: nil)
    return 0 if matches.empty?
    
    umb_region = Region.find_by(shortname: 'UMB')
    games_created = 0
    participations_created = 0
    
    matches.each_with_index do |player_pair, match_index|
      player1_data = player_pair[0]
      player2_data = player_pair[1]
      
      # Create game name based on context
      if player1_data[:group].present?
        # Group phase: "Phase - Group X - Match Y"
        game_name = "#{phase_game.gname} - Group #{player1_data[:group]} - Match #{match_index + 1}"
        group_no = player1_data[:group]
      else
        # Knockout phase: "Phase - Round - Match Y" or just "Phase - Match Y"
        if round_name.present?
          game_name = "#{phase_game.gname} - #{round_name} - Match #{match_index + 1}"
        else
          game_name = "#{phase_game.gname} - Match #{match_index + 1}"
        end
        group_no = nil
      end
      
      # Create individual game for this match
      match_game = tournament.games.find_or_initialize_by(
        gname: game_name,
        group_no: group_no
      )
      
      match_game.assign_attributes(
        data: {
          phase: phase_game.gname,
          phase_game_id: phase_game.id,
          round_name: round_name,
          umb_match_number: match_index + 1,
          umb_scraped_from: player1_data[:group].present? ? 'group_results_pdf' : 'knockout_results_pdf'
        }
      )
      
      if match_game.save(validate: false)
        games_created += 1 if match_game.previously_new_record?
        
        # Create participations for both players
        [player1_data, player2_data].each do |player_data|
          player = find_or_create_international_player(
            firstname: player_data[:player_name].split(' ').first,
            lastname: player_data[:player_name].split(' ')[1..-1].join(' '),
            nationality: nil,
            region: umb_region
          )
          
          next unless player
          
          participation = match_game.game_participations.find_or_initialize_by(
            player: player
          )
          
          participation.assign_attributes(
            result: player_data[:points],
            innings: player_data[:innings],
            gd: player_data[:average],
            hs: [player_data[:high_run_1], player_data[:high_run_2]].max,
            points: player_data[:match_points],
            data: {
              group: player_data[:group],
              round_name: round_name,
              high_runs: [player_data[:high_run_1], player_data[:high_run_2]],
              umb_scraped_from: player_data[:group].present? ? 'group_results_pdf' : 'knockout_results_pdf'
            }
          )
          
          if participation.save(validate: false)
            participations_created += 1 if participation.previously_new_record?
          end
        end
      end
    end
    
    Rails.logger.info "[UmbScraper]     Created #{games_created} individual games with #{participations_created} participations"
    games_created
  end
  
  # Parse MTResults (Knockout/Main Tournament) PDF to extract match data
  # Format is different from group results: typically shows bracket-style matches
  def parse_knockout_results_pdf(phase_game, pdf_url)
    Rails.logger.info "[UmbScraper]     Parsing Knockout PDF for phase: #{phase_game.gname}"
    
    unless defined?(PDF::Reader)
      Rails.logger.warn "[UmbScraper]     PDF parsing requires 'pdf-reader' gem"
      return 0
    end
    
    pdf_content = download_pdf(pdf_url)
    return 0 unless pdf_content
    
    begin
      require 'stringio'
      reader = PDF::Reader.new(StringIO.new(pdf_content))
      text = reader.pages.map(&:text).join("\n")
      
      player_lines = []
      current_round = nil
      
      # Parse text line by line to extract knockout match data
      # Knockout format typically shows pairs of players with their match results
      text.split("\n").each do |line|
        next if line.blank?
        
        # Detect round/section headers (e.g., "Quarter Final", "Semi Final", "Final")
        if line.match?(/^\s*(Quarter[\s\-]*Final|Semi[\s\-]*Final|Final|Round\s+of\s+\d+)/i)
          round_match = line.match(/^\s*(Quarter[\s\-]*Final|Semi[\s\-]*Final|Final|Round\s+of\s+\d+)/i)
          current_round = round_match[1].gsub(/[\s\-]+/, ' ').strip if round_match
          next
        end
        
        # Parse player line in knockout format
        # Format: Player Name    Points  Innings  Average  MP  HighRun1  HighRun2
        # Similar to group format but without group letter
        if line.match?(/([A-Z][A-Za-z\s]+?)\s{3,}(\d+)\s+(\d+)\s+([\d.]+)(?:\s+(\d+)\s+(\d+)\s+(\d+))?\s*$/)
          match_data = line.match(/([A-Z][A-Za-z\s]+?)\s{3,}(\d+)\s+(\d+)\s+([\d.]+)(?:\s+(\d+)\s+(\d+)\s+(\d+))?\s*$/)
          
          player_name = match_data[1].strip
          
          # Skip summary/header lines
          next if player_name.match?(/Players|Match|Total|^(TR|ES|KR|DK|JP|VN|SE|NL|BE|FR|DE)\s/)
          next if player_name.length < 3
          
          player_lines << {
            round: current_round,
            player_name: player_name,
            points: match_data[2].to_i,
            innings: match_data[3].to_i,
            average: match_data[4].to_f,
            match_points: match_data[5]&.to_i || (match_data[2].to_i > 0 ? 2 : 0), # Winner gets 2 points
            high_run_1: match_data[6]&.to_i || 0,
            high_run_2: match_data[7]&.to_i || 0
          }
        end
      end
      
      # Group player lines into matches (pairs of consecutive players)
      matches = []
      current_round_name = nil
      
      player_lines.each_slice(2) do |player_pair|
        if player_pair.size == 2
          # Use the round name from the first player
          current_round_name = player_pair[0][:round] if player_pair[0][:round].present?
          matches << player_pair
        end
      end
      
      Rails.logger.info "[UmbScraper]     Found #{matches.size} knockout matches (#{player_lines.size} player performances)"
      
      # Create individual games for each knockout match
      games_created = create_games_from_matches(
        phase_game.tournament, 
        phase_game, 
        matches,
        round_name: current_round_name
      )
      
      games_created
    rescue StandardError => e
      Rails.logger.error "[UmbScraper]     Error parsing Knockout PDF: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      0
    end
  end
  
end
