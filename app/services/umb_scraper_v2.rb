# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'openssl'
require 'pdf-reader'

# UmbScraperV2 - Refactored to use Tournament/Seeding/Game models (STI)
# This replaces the old InternationalTournament/InternationalParticipation/InternationalResult models
class UmbScraperV2
  BASE_URL = 'https://files.umb-carom.org'
  TIMEOUT = 30

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

  # Scrape a specific tournament by external_id
  def scrape_tournament(external_id)
    Rails.logger.info "[UmbScraperV2] Scraping tournament #{external_id}"
    
    detail_url = "#{BASE_URL}/public/TournametDetails.aspx?ID=#{external_id}"
    html = fetch_url(detail_url)
    
    return nil if html.blank? || html.length < 500
    
    doc = Nokogiri::HTML(html)
    tournament_data = parse_tournament_details(doc, external_id, detail_url)
    
    return nil unless tournament_data
    
    tournament = save_tournament(tournament_data)
    
    if tournament
      # Parse PDFs if available
      scrape_pdfs_for_tournament(tournament) if tournament_data[:pdf_links].present?
    end
    
    tournament
  end

  private

  # Fetch URL with redirect handling
  def fetch_url(url)
    uri = URI(url)
    redirects = 0
    max_redirects = 5

    loop do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?
      http.read_timeout = TIMEOUT

      path = uri.path.empty? ? '/' : uri.path
      path += "?#{uri.query}" if uri.query
      request = Net::HTTP::Get.new(path)
      
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        return response.body
      when Net::HTTPRedirection
        redirects += 1
        return nil if redirects >= max_redirects
        location = response['location']
        uri = location.start_with?('http') ? URI(location) : URI.join(uri, location)
      else
        Rails.logger.debug "[UmbScraperV2] HTTP #{response.code} for #{url}"
        return nil
      end
    end
  rescue StandardError => e
    Rails.logger.error "[UmbScraperV2] Error fetching #{url}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
  end

  # Parse tournament details from HTML
  def parse_tournament_details(doc, external_id, detail_url)
    # Extract tournament info from spans with IDs
    info = {}
    
    # Name from span#lblTour
    name_span = doc.at_css('span#lblTour, span#lblTourname')
    info[:name] = name_span&.text&.strip
    
    # Dates
    start_span = doc.at_css('span#lblStartOn, span#lblStartsOn')
    end_span = doc.at_css('span#lblEndsON, span#lblEndsOn')
    
    if start_span
      start_text = start_span.text.strip
      info[:start_date] = parse_single_date(start_text)
    end
    
    if end_span
      end_text = end_span.text.strip
      info[:end_date] = parse_single_date(end_text)
    end
    
    # Location/Place
    place_span = doc.at_css('span#lblPlace')
    info[:location] = place_span&.text&.strip
    
    # Organizer
    org_span = doc.at_css('span#lblOrg, span#lblOrganizer')
    info[:organizer] = org_span&.text&.strip
    
    # Discipline (if available)
    disc_span = doc.at_css('span#lblDiscipline')
    info[:discipline_name] = disc_span&.text&.strip if disc_span
    
    return nil unless info[:name].present?
    
    # Parse PDF links
    pdf_links = {}
    doc.css('a[href$=".pdf"], a[href$=".PDF"]').each do |link|
      href = link['href']
      text = link.text.strip
      
      absolute_url = make_absolute_url(href)
      
      case text
      when /Players List/i
        pdf_links[:players_list] = absolute_url
      when /Final Ranking/i
        pdf_links[:final_ranking] = absolute_url
      when /GroupResults/i, /Group Results/i
        pdf_links[:groups] = absolute_url
      when /Groups/i
        # Only use if we don't already have GroupResults
        pdf_links[:groups] ||= absolute_url
      end
    end
    
    # Find discipline
    discipline_name = info[:discipline_name] || determine_discipline_from_name(info[:name])
    discipline = Discipline.find_by('name ILIKE ?', "%#{discipline_name}%") || 
                 Discipline.find_by('name ILIKE ?', '%dreiband%')
    
    tournament_type = determine_tournament_type(info[:name], info[:type])
    
    {
      external_id: external_id.to_s,
      title: info[:name],
      start_date: info[:start_date],
      end_date: info[:end_date],
      location: info[:location],
      country: info[:country],
      organizer: info[:organizer],
      discipline: discipline,
      tournament_type: tournament_type,
      source_url: detail_url,
      pdf_links: pdf_links
    }
  end

  # Save tournament to database
  def save_tournament(data)
    return nil unless data[:title].present? && data[:start_date].present? && data[:discipline].present?
    
    # Check for existing
    existing = InternationalTournament.find_by(
      international_source: @umb_source,
      external_id: data[:external_id]
    )
    
    if existing
      Rails.logger.info "[UmbScraperV2] Tournament #{data[:external_id]} already exists"
      return existing
    end
    
    tournament = InternationalTournament.new(
      title: data[:title],
      date: data[:start_date],
      end_date: data[:end_date],
      location_text: data[:location],
      discipline: data[:discipline],
      international_source: @umb_source,
      external_id: data[:external_id],
      source_url: data[:source_url],
      modus: 'international',
      single_or_league: 'single',
      plan_or_show: 'show',
      state: data[:start_date] > Date.today ? 'planned' : 'finished',
      data: {
        country: data[:country],
        organizer_text: data[:organizer],
        tournament_type: data[:tournament_type],
        pdf_links: data[:pdf_links],
        scraped_at: Time.current.iso8601
      }
    )
    
    if tournament.save(validate: false)
      Rails.logger.info "[UmbScraperV2] Created tournament: #{data[:title]}"
      tournament
    else
      Rails.logger.error "[UmbScraperV2] Failed to save: #{tournament.errors.full_messages}"
      nil
    end
  end

  # Parse PDFs for a tournament
  def scrape_pdfs_for_tournament(tournament)
    pdf_links = tournament.pdf_links
    
    if pdf_links['players_list']
      scrape_players_list_pdf(tournament, pdf_links['players_list'])
    end
    
    # Look for group results or final ranking PDFs
    if pdf_links['groups']
      scrape_group_results_pdf(tournament, pdf_links['groups'])
    elsif pdf_links['final_ranking']
      scrape_final_ranking_pdf(tournament, pdf_links['final_ranking'])
    end
  end

  # Parse Players List PDF → Seedings
  def scrape_players_list_pdf(tournament, pdf_url)
    Rails.logger.info "[UmbScraperV2] Parsing Players List PDF for #{tournament.title}"
    
    pdf_content = download_pdf(pdf_url)
    return unless pdf_content
    
    # Pattern: Position | LASTNAME | Firstname | NAT | ... | UMB_ID
    # Example: "1 DOE John USA 100 50 0106"
    pattern = /^\s*(\d+)\s+([A-Z][A-Z\s]+?[A-Z])\s+([A-Z][a-z]+.*?)\s+([A-Z]{2,3})\s+\d+\s+\d+\s+(\d+)/
    
    players_found = 0
    
    pdf_content.each_line do |line|
      match = line.match(pattern)
      next unless match
      
      position = match[1].to_i
      lastname = match[2].strip
      firstname = match[3].strip
      nationality = match[4].strip
      umb_player_id = match[5].to_i
      
      # Find or create player
      player = find_or_create_player(
        firstname: firstname,
        lastname: lastname,
        nationality: nationality,
        umb_player_id: umb_player_id
      )
      
      next unless player
      
      # Create seeding
      seeding = Seeding.find_or_initialize_by(
        tournament: tournament,
        player: player
      )
      
      seeding.position = position
      seeding.state = 'confirmed'
      seeding.data = { source: 'players_list_pdf', scraped_at: Time.current.iso8601 }
      
      if seeding.save
        players_found += 1
      else
        Rails.logger.error "[UmbScraperV2] Failed to save seeding: #{seeding.errors.full_messages}"
      end
    end
    
    Rails.logger.info "[UmbScraperV2] Created #{players_found} seedings"
    players_found
  end

  # Parse Group Results PDF → Games + GameParticipations
  def scrape_group_results_pdf(tournament, pdf_url)
    Rails.logger.info "[UmbScraperV2] Parsing Group Results PDF for #{tournament.title}"
    
    pdf_content = download_pdf(pdf_url)
    return 0 unless pdf_content
    
    games_created = 0
    current_group = nil
    pending_player = nil  # Store first player of a match pair
    
    pdf_content.each_line do |line|
      # Detect group header
      if line =~ /^Group\s+([A-Z])/i
        current_group = $1
        pending_player = nil
        next
      end
      
      # Skip summary lines (have "Players", "Nat", etc as first word)
      next if line =~ /^\s*(Players|Nat|Group)/i
      
      # Match player line: CAPS_NAME Mixed_Name    stats...
      # Pattern: All-caps word(s), then Mixed-case word(s), then 6+ numbers
      # Example: "JEONGU Park                 30       14     2.142      2        9        4"
      # Example: "KIM Kap Se                 30       26     1.153      2        5        4"
      match = line.match(/^\s*([A-Z][A-Z\s]+?)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)/)
      
      next unless match
      
      caps_name = match[1].strip
      mixed_name = match[2].strip
      
      # Skip if caps_name is just a single letter (group marker like "A", "B")
      next if caps_name.length == 1
      
      # Clean up mixed_name - remove trailing country codes
      mixed_name = mixed_name.gsub(/\s+(KR|VN|TR|JP|FR|DE|BE|NL|EG|SE|GR|JO)$/i, '').strip
      
      player_data = {
        caps_name: caps_name,
        mixed_name: mixed_name,
        points: match[3].to_i,
        innings: match[4].to_i,
        average: match[5].to_f,
        match_points: match[6].to_i,
        highrun_1: match[7].to_i,
        highrun_2: match[8].to_i
      }
      
      if pending_player
        # We have a pair - create game!
        Rails.logger.debug "[UmbScraperV2] Creating game: #{pending_player[:caps_name]} #{pending_player[:mixed_name]} vs #{player_data[:caps_name]} #{player_data[:mixed_name]}"
        game = create_game_from_match(tournament, current_group, pending_player, player_data)
        if game
          games_created += 1
          Rails.logger.debug "[UmbScraperV2]   ✓ Game created!"
        else
          Rails.logger.warn "[UmbScraperV2]   ✗ Failed to create game"
        end
        pending_player = nil
      else
        # Store first player, wait for second
        Rails.logger.debug "[UmbScraperV2] Storing first player: #{player_data[:caps_name]} #{player_data[:mixed_name]}"
        pending_player = player_data
      end
    end
    
    Rails.logger.info "[UmbScraperV2] Created #{games_created} games"
    games_created
  end
  
  # Parse Final Ranking PDF → Games + GameParticipations
  # TODO: Implement based on actual PDF structure
  def scrape_final_ranking_pdf(tournament, pdf_url)
    Rails.logger.info "[UmbScraperV2] Final Ranking PDF parsing not yet implemented"
    0
  end
  
  # Create a game from two players
  def create_game_from_match(tournament, group, player_a_data, player_b_data)
    # Find players - try both caps+mixed and mixed+caps combinations
    player_a = find_player_by_caps_and_mixed(player_a_data[:caps_name], player_a_data[:mixed_name])
    player_b = find_player_by_caps_and_mixed(player_b_data[:caps_name], player_b_data[:mixed_name])
    
    unless player_a && player_b
      Rails.logger.warn "[UmbScraperV2] Could not find players: #{player_a_data[:caps_name]} #{player_a_data[:mixed_name]} vs #{player_b_data[:caps_name]} #{player_b_data[:mixed_name]}"
      return nil
    end
    
    # Determine winner (player with match_points = 2)
    winner = player_a_data[:match_points] > player_b_data[:match_points] ? player_a : player_b
    
    # Calculate general average
    total_points = player_a_data[:points] + player_b_data[:points]
    total_innings = player_a_data[:innings] + player_b_data[:innings]
    gd = total_innings > 0 ? (total_points.to_f / total_innings).round(3) : 0.0
    
    # Create game
    game = Game.new(
      tournament: tournament,
      type: 'InternationalGame',
      data: {
        group: group,
        gd: gd,
        state: 'finished',
        source: 'group_results_pdf',
        scraped_at: Time.current.iso8601
      }
    )
    
    if game.save(validate: false)
      # Create game participations
      create_game_participation(game, player_a, player_a_data, 1)
      create_game_participation(game, player_b, player_b_data, 2)
      
      game
    else
      Rails.logger.error "[UmbScraperV2] Failed to save game: #{game.errors.full_messages}"
      nil
    end
  end
  
  # Create game participation
  def create_game_participation(game, player, player_data, role)
    GameParticipation.create!(
      game: game,
      player: player,
      role: role.to_s,
      points: player_data[:points],
      innings: player_data[:innings],
      gd: player_data[:average],
      hs: player_data[:highrun_1],
      data: {
        match_points: player_data[:match_points],
        highrun_2: player_data[:highrun_2],
        source: 'group_results_pdf'
      }
    )
  end
  
  # Find player by caps_name and mixed_name (tries all combinations)
  def find_player_by_caps_and_mixed(caps_name, mixed_name)
    # Try 1: caps=lastname, mixed=firstname (most common for Western names)
    player = find_player_by_name(mixed_name, caps_name)
    return player if player
    
    # Try 2: caps=firstname, mixed=lastname (happens with some Asian names)
    player = find_player_by_name(caps_name, mixed_name)
    return player if player
    
    # Try 3: Search by partial match on full name
    full_name = "#{caps_name} #{mixed_name}"
    Player.where('LOWER(firstname || \' \' || lastname) = ? OR LOWER(lastname || \' \' || firstname) = ?',
                 full_name.downcase, full_name.downcase).first
  end
  
  # Find player by name (tries both firstname/lastname and swapped)
  def find_player_by_name(firstname, lastname)
    # Try direct match
    player = Player.where('LOWER(firstname) = ? AND LOWER(lastname) = ?',
                          firstname.downcase, lastname.downcase).first
    return player if player
    
    # Try swapped (UMB sometimes swaps name order between PDFs!)
    Player.where('LOWER(firstname) = ? AND LOWER(lastname) = ?',
                 lastname.downcase, firstname.downcase).first
  end

  # Find or create player
  def find_or_create_player(firstname:, lastname:, nationality:, umb_player_id:)
    # Try to find by umb_player_id first
    if umb_player_id > 0
      player = Player.find_by(umb_player_id: umb_player_id)
      return player if player
    end
    
    # Try to find by name
    player = Player.where('LOWER(firstname) = ? AND LOWER(lastname) = ?', 
                         firstname.downcase, lastname.downcase).first
    
    if player
      # Update umb_player_id and nationality if missing
      player.update(umb_player_id: umb_player_id) if player.umb_player_id.nil? && umb_player_id > 0
      player.update(nationality: nationality) if player.nationality.nil?
      return player
    end
    
    # Create new player
    player = Player.new(
      firstname: firstname,
      lastname: lastname,
      nationality: nationality,
      umb_player_id: umb_player_id > 0 ? umb_player_id : nil,
      international_player: true
    )
    
    if player.save
      player
    else
      Rails.logger.error "[UmbScraperV2] Failed to create player: #{player.errors.full_messages}"
      nil
    end
  end

  # Download PDF and extract text
  def download_pdf(url)
    pdf_data = fetch_url(url)
    return nil if pdf_data.blank?
    
    reader = PDF::Reader.new(StringIO.new(pdf_data))
    text = reader.pages.map(&:text).join("\n")
    
    text
  rescue StandardError => e
    Rails.logger.error "[UmbScraperV2] PDF parsing error: #{e.message}"
    nil
  end

  # Helper methods
  
  def make_absolute_url(href)
    return href if href.start_with?('http')
    
    # Remove leading "../" sequences
    clean_href = href.gsub(/^(\.\.\/)+/, '')
    
    clean_href.start_with?('/') ? "#{BASE_URL}#{clean_href}" : "#{BASE_URL}/#{clean_href}"
  end

  def parse_single_date(date_string)
    return nil if date_string.blank?
    
    # Try formats like "15-October-2022"
    formats = [
      '%d-%B-%Y',    # 15-October-2022
      '%d-%b-%Y',    # 15-Oct-2022
      '%Y-%m-%d',    # 2022-10-15
      '%d/%m/%Y',    # 15/10/2022
      '%d.%m.%Y'     # 15.10.2022
    ]
    
    formats.each do |format|
      begin
        return Date.strptime(date_string, format)
      rescue ArgumentError
        next
      end
    end
    
    # Fallback to Date.parse
    Date.parse(date_string) rescue nil
  end
  
  def parse_date_range(date_string)
    return { start_date: nil, end_date: nil } if date_string.blank?
    
    # Try common formats
    if date_string =~ /(\d{1,2})\s*-\s*(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})/
      # "06 - 12 February 2025"
      start_day = $1.to_i
      end_day = $2.to_i
      month_name = $3
      year = $4.to_i
      
      month = Date::ABBR_MONTHNAMES.index(month_name[0..2].capitalize) || 
              Date::MONTHNAMES.index(month_name.capitalize)
      
      return { start_date: nil, end_date: nil } unless month
      
      { 
        start_date: Date.new(year, month, start_day),
        end_date: Date.new(year, month, end_day)
      }
    else
      # Single date or other format
      date = parse_single_date(date_string)
      { start_date: date, end_date: date }
    end
  end

  def determine_discipline_from_name(name)
    return '3-Cushion' if name =~ /3-cushion/i
    return 'Cadre 47/2' if name =~ /cadre.*47.*2/i
    return '5-Pins' if name =~ /5-pins?/i
    return 'Artistique' if name =~ /artistique/i
    '3-Cushion'
  end

  def determine_tournament_type(name, type_hint)
    return 'world_cup' if name =~ /world cup/i || type_hint =~ /world cup/i
    return 'world_championship' if name =~ /world championship/i
    return 'european_championship' if name =~ /european/i
    return 'national_championship' if name =~ /national/i
    'other'
  end
end
