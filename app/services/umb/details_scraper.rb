# frozen_string_literal: true

require "nokogiri"

# Scrapt eine UMB-Turnier-Detailseite und orchestriert optional die PDF-Pipeline.
#
# ApplicationService gemäß D-03 — hat DB-Seiteneffekte (erstellt/aktualisiert
# InternationalTournament, Seeding, InternationalGame, GameParticipation).
#
# Pitfall 3 (aus Research): Game-Erstellung MUSS type: 'InternationalGame' verwenden (V2-Muster).
# Pitfall 5 (aus Research): Alle PDF-Typen unabhängig parsen — kein Kurzschluss.
class Umb::DetailsScraper
  BASE_URL = "https://files.umb-carom.org"
  TOURNAMENT_DETAILS_URL = "#{BASE_URL}/public/TournametDetails.aspx"

  # Game type mappings from PDF filenames (übernommen aus UmbScraper)
  GAME_TYPE_MAPPINGS = {
    "PPPQ" => "Pre-Pre-Pre-Qualification",
    "PPQ" => "Pre-Pre-Qualification",
    "PQ" => "Pre-Qualification",
    "Q" => "Qualification",
    "R16" => "Round of 16",
    "R32" => "Round of 32",
    "Rank_8" => "Match for 8th Place",
    "Quarter_Final" => "Quarter Final",
    "Semi_Final-Final" => "Semi Final & Final",
    "Semi_Final" => "Semi Final",
    "Final" => "Final"
  }.freeze

  BAD_LOCATIONS = ["A", "N/A", "", nil].freeze

  def initialize
    @http = Umb::HttpClient.new
    @player_resolver = Umb::PlayerResolver.new
    @umb_source = InternationalSource.find_or_create_by!(
      name: "Union Mondiale de Billard",
      source_type: "umb"
    ) do |source|
      source.base_url = BASE_URL
      source.metadata = {
        key: "umb",
        priority: 1,
        description: "World governing body for carom billiards"
      }
    end
  end

  # Scrapt Detailseite für ein Turnier und speichert Ergebnisse.
  #
  # @param tournament_id_or_record [Integer, InternationalTournament]
  #   Integer → Turnier wird per ID aus DB geladen (oder per external_id neu angelegt)
  #   InternationalTournament → bestehender Datensatz wird direkt verwendet
  # @param create_games [Boolean] Ob Game-Datensätze aus HTML-Tabelle angelegt werden sollen
  # @param parse_pdfs [Boolean] Ob PDF-Pipeline (PlayerList, GroupResults, Ranking) ausgeführt wird
  # @return [InternationalTournament, false] Turnierdatensatz oder false bei Fehler
  def call(tournament_id_or_record, create_games: true, parse_pdfs: false)
    tournament = resolve_tournament(tournament_id_or_record)
    return false if tournament.nil?

    detail_url = build_detail_url(tournament)
    unless detail_url
      Rails.logger.warn "[Umb::DetailsScraper] No detail URL for tournament #{tournament.id}"
      return false
    end

    Rails.logger.info "[Umb::DetailsScraper] Scraping details for: #{tournament.name} (#{detail_url})"

    html = @http.fetch_url(detail_url)
    return false if html.blank?

    doc = Nokogiri::HTML(html)

    parse_and_update_tournament(tournament, doc, detail_url)
    return false unless tournament.save(validate: false)

    if create_games
      game_types = extract_game_types(doc)
      if game_types.any?
        create_games_for_tournament(tournament, game_types, parse_pdfs: parse_pdfs)
      end
    end

    # PDF-Pipeline unabhängig für jeden Typ ausführen (Pitfall 5: kein Kurzschluss)
    if parse_pdfs
      run_pdf_pipeline(tournament, doc)
    end

    Rails.logger.info "[Umb::DetailsScraper] Saved tournament details for #{tournament.name}"
    tournament
  rescue StandardError => e
    Rails.logger.error "[Umb::DetailsScraper] Error scraping tournament details: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    false
  end

  private

  # Löst tournament_id_or_record auf: Integer → DB-Lookup oder Neuerstellung via fetch_tournament_basic_data
  def resolve_tournament(tournament_id_or_record)
    if tournament_id_or_record.is_a?(InternationalTournament)
      tournament_id_or_record
    elsif tournament_id_or_record.is_a?(Integer)
      InternationalTournament.find_by(id: tournament_id_or_record) ||
        fetch_and_create_tournament(tournament_id_or_record)
    else
      InternationalTournament.find(tournament_id_or_record)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  # Holt Basisdaten für eine neue external_id und erstellt ein Turnier-Stub.
  def fetch_and_create_tournament(external_id)
    data = fetch_tournament_basic_data(external_id)
    return nil unless data
    save_tournament_from_details(data)
  end

  # Holt Turnier-Grunddaten von der Detailseite (aus UmbScraper line 204).
  def fetch_tournament_basic_data(external_id)
    detail_url = "#{TOURNAMENT_DETAILS_URL}?ID=#{external_id}"
    html = @http.fetch_url(detail_url)
    return nil if html.blank?

    doc = Nokogiri::HTML(html)
    data = {external_id: external_id, url: detail_url}

    doc.css("table tr").each do |row|
      cells = row.css("td")
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

  # Erstellt ein Turnier aus Basisdaten (aus UmbScraper line 239).
  def save_tournament_from_details(data)
    location, _country = parse_location_country(data[:location])

    start_date = Umb::DateHelpers.parse_single_date(data[:start_date])
    end_date = Umb::DateHelpers.parse_single_date(data[:end_date])

    discipline = Umb::DisciplineDetector.detect(data[:name]) ||
      Discipline.find_by("name ILIKE ?", "%dreiband%groß%") ||
      Discipline.find_by("name ILIKE ?", "%dreiband%gross%") ||
      Discipline.find_by(name: "Unknown Discipline")

    season = find_or_create_season_from_date(start_date)
    umb_organizer = find_or_create_umb_organizer

    if umb_organizer.nil?
      Rails.logger.error "[Umb::DetailsScraper] WARNING: Creating tournament '#{data[:name]}' WITHOUT organizer!"
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
      modus: "international",
      plan_or_show: "show",
      single_or_league: "single",
      state: "finished",
      source_url: data[:url],
      season_id: season&.id,
      organizer_id: umb_organizer&.id,
      organizer_type: "Region"
    )

    if tournament.save(validate: false)
      Rails.logger.info "[Umb::DetailsScraper] Created tournament: #{tournament.title}"
      tournament
    else
      Rails.logger.error "[Umb::DetailsScraper] Failed to create tournament: #{tournament.errors.full_messages}"
      nil
    end
  end

  # Baut Detail-URL aus externem Turnier-Datensatz.
  def build_detail_url(tournament)
    if tournament.external_id.present?
      "#{TOURNAMENT_DETAILS_URL}?ID=#{tournament.external_id}"
    elsif tournament.data&.dig("umb_detail_url").present?
      tournament.data["umb_detail_url"]
    end
  end

  # Parst die Detailseite und aktualisiert den Turnier-Datensatz in-memory (kein Save hier).
  def parse_and_update_tournament(tournament, doc, detail_url)
    tournament_info = {}
    doc.css("table tr").each do |row|
      cells = row.css("td")
      next if cells.size < 2

      label = cells[0].text.strip.gsub(":", "")
      value = cells[1].text.strip

      case label
      when "Tournament" then tournament_info[:name] = value
      when "Starts on" then tournament_info[:start_date] = value
      when "Ends on" then tournament_info[:end_date] = value
      when "Organized by" then tournament_info[:organizer] = value
      when "Place" then tournament_info[:location] = value
      when "Material" then tournament_info[:material] = value
      when "Delegate UMB" then tournament_info[:delegate] = value.gsub(/\[.*\]/, "").strip
      end
    end

    # Ort aktualisieren wenn gefunden und bisheriger Wert schlecht
    if tournament_info[:location].present? && BAD_LOCATIONS.include?(tournament.location_text)
      tournament.location_text = tournament_info[:location]
    end

    # PDF-Links sammeln und in data speichern
    pdf_links = {}
    game_types = []
    ranking_files = []

    doc.css("a[href*='.pdf']").each do |link|
      href = link["href"]
      text = link.text.strip
      absolute_url = make_absolute_url(href)

      pdf_links[text] = absolute_url

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

      GAME_TYPE_MAPPINGS.each do |key, description|
        if text.match?(/GroupResults_#{key}\.pdf/i) ||
            text.match?(/MTResults_#{key}\.pdf/i)
          game_types << {
            key: key,
            name: description,
            pdf_url: absolute_url,
            pdf_filename: text,
            category: text.include?("GroupResults") ? "group" : "main_tournament"
          }
        end
      end

      if text.match?(/Ranking/i)
        phase = if text.match?(/FinalRanking/i)
          "final"
        elsif (match = text.match(/Groups?_Ranking_(\w+)\.pdf/i))
          match[1].downcase
        else
          "unknown"
        end

        ranking_files << {
          phase: phase,
          pdf_url: absolute_url,
          pdf_filename: text
        }
      end
    end

    tournament.data ||= {}
    tournament.data["pdf_links"] = pdf_links.compact
    tournament.data["game_types"] = game_types
    tournament.data["ranking_files"] = ranking_files
    tournament.data["detail_scraped_at"] = Time.current.iso8601

    # Organizer, Season, Location-Felder füllen ohne bestehende Werte zu überschreiben
    original_organizer_id = tournament.organizer_id
    original_organizer_type = tournament.organizer_type

    should_update_location = tournament.location_text.present? && (
      tournament.location_id.blank? ||
        (tournament.location_id && Location.exists?(tournament.location_id) &&
          Location.find(tournament.location_id).name == "A")
    )

    if should_update_location
      location = find_or_create_location_from_text(tournament.location_text)
      if location && location.name != "A"
        tournament.location_id = location.id
      end
    end

    if tournament.season_id.blank? && tournament.date.present?
      season = find_or_create_season_from_date(tournament.date)
      tournament.season_id = season&.id if season
    end

    if original_organizer_id.blank?
      umb_region = find_or_create_umb_organizer
      tournament.organizer_id = umb_region&.id
      tournament.organizer_type = "Region"
    else
      tournament.organizer_id = original_organizer_id
      tournament.organizer_type = original_organizer_type
    end
  end

  # Extrahiert GAME_TYPE_MAPPINGS-Einträge aus PDF-Links auf Detailseite.
  def extract_game_types(doc)
    game_types = []
    doc.css("a[href*='.pdf']").each do |link|
      href = link["href"]
      text = link.text.strip
      absolute_url = make_absolute_url(href)

      GAME_TYPE_MAPPINGS.each do |key, description|
        if text.match?(/GroupResults_#{key}\.pdf/i) ||
            text.match?(/MTResults_#{key}\.pdf/i)
          game_types << {
            key: key,
            name: description,
            pdf_url: absolute_url,
            pdf_filename: text,
            category: text.include?("GroupResults") ? "group" : "main_tournament"
          }
        end
      end
    end
    game_types
  end

  # Erstellt Game-Datensätze für jeden Spieltyp (HTML-basiert).
  # Pitfall 3: game.type MUSS 'InternationalGame' sein (V2-Ansatz).
  def create_games_for_tournament(tournament, game_types, parse_pdfs: false)
    Rails.logger.info "[Umb::DetailsScraper] Creating games for tournament: #{tournament.title}"

    created_count = 0
    updated_count = 0

    game_types.each do |game_type|
      game = tournament.games.find_or_initialize_by(gname: game_type[:name])
      is_new = game.new_record?

      # type: 'InternationalGame' — V2-Muster (Pitfall 3)
      game.type = "InternationalGame"

      game_data = game.data || {}
      game_data["umb_game_type"] = game_type[:key]
      game_data["umb_category"] = game_type[:category]
      game_data["umb_pdf_url"] = game_type[:pdf_url]
      game_data["umb_pdf_filename"] = game_type[:pdf_filename]
      game_data["umb_scraped_at"] = Time.current.iso8601
      game.data = game_data

      if game.save(validate: false)
        if is_new
          created_count += 1
          Rails.logger.info "[Umb::DetailsScraper] Created game: #{game_type[:name]}"
        else
          updated_count += 1
        end

        # PDF für diesen Spieltyp parsen wenn gewünscht
        if parse_pdfs && game_type[:pdf_url].present?
          begin
            Timeout.timeout(60) do
              if game_type[:pdf_filename].match?(/GroupResults/i)
                parse_group_results_pdf_for_game(game, game_type[:pdf_url])
              end
            end
          rescue Timeout::Error
            Rails.logger.error "[Umb::DetailsScraper] PDF parsing timeout for #{game_type[:pdf_filename]}"
          rescue => e
            Rails.logger.error "[Umb::DetailsScraper] PDF parsing error: #{e.message}"
          end
        end
      else
        Rails.logger.error "[Umb::DetailsScraper] Failed to save game: #{game.errors.full_messages}"
      end
    end

    Rails.logger.info "[Umb::DetailsScraper] Games: #{created_count} created, #{updated_count} updated"
    created_count + updated_count
  end

  # PDF-Pipeline: Parst alle verfügbaren PDF-Typen unabhängig (Pitfall 5: kein Kurzschluss).
  def run_pdf_pipeline(tournament, doc)
    pdf_links = collect_pdf_links(doc)

    # 1. PlayerList-PDF → Seedings anlegen
    if pdf_links[:players_list].present?
      begin
        pdf_text = @http.fetch_pdf_text(pdf_links[:players_list])
        if pdf_text.present?
          parsed = Umb::PdfParser::PlayerListParser.new(pdf_text).parse
          create_seedings_from_player_list(tournament, parsed) if parsed.any?
        end
      rescue StandardError => e
        Rails.logger.error "[Umb::DetailsScraper] PlayerList PDF error: #{e.message}"
      end
    end

    # 2. GroupResult-PDFs → InternationalGame + GameParticipation anlegen
    pdf_links[:group_results].each do |group_pdf_url|
      begin
        pdf_text = @http.fetch_pdf_text(group_pdf_url)
        if pdf_text.present?
          parsed = Umb::PdfParser::GroupResultParser.new(pdf_text).parse
          create_games_from_group_results(tournament, parsed) if parsed.any?
        end
      rescue StandardError => e
        Rails.logger.error "[Umb::DetailsScraper] GroupResults PDF error: #{e.message}"
      end
    end

    # 3. Ranking-PDFs → Seedings mit Endposition anlegen
    pdf_links[:rankings].each do |ranking_info|
      begin
        pdf_text = @http.fetch_pdf_text(ranking_info[:url])
        if pdf_text.present?
          type = ranking_info[:phase] == "final" ? :final : :weekly
          parsed = Umb::PdfParser::RankingParser.new(pdf_text, type: type).parse
          create_seedings_from_ranking(tournament, parsed, ranking_info[:phase]) if parsed.any?
        end
      rescue StandardError => e
        Rails.logger.error "[Umb::DetailsScraper] Ranking PDF error: #{e.message}"
      end
    end
  end

  # Sammelt PDF-Links kategorisiert aus der Detailseite.
  def collect_pdf_links(doc)
    result = {players_list: nil, group_results: [], rankings: []}

    doc.css("a[href*='.pdf']").each do |link|
      href = link["href"]
      text = link.text.strip
      absolute_url = make_absolute_url(href)

      if text.match?(/players.*list|seeding/i)
        result[:players_list] ||= absolute_url
      end

      if text.match?(/GroupResults/i)
        result[:group_results] << absolute_url
      end

      if text.match?(/Ranking/i)
        phase = if text.match?(/FinalRanking/i)
          "final"
        elsif (match = text.match(/Groups?_Ranking_(\w+)\.pdf/i))
          match[1].downcase
        else
          "unknown"
        end
        result[:rankings] << {url: absolute_url, phase: phase}
      end
    end

    result
  end

  # Erstellt Seeding-Datensätze aus PlayerListParser-Output.
  def create_seedings_from_player_list(tournament, parsed_players)
    saved_count = 0

    parsed_players.each do |player_data|
      player = @player_resolver.resolve(
        player_data[:caps_name],
        player_data[:mixed_name],
        nationality: player_data[:nationality]
      )

      next unless player

      seeding = Seeding.find_or_initialize_by(
        player: player,
        tournament: tournament
      )

      seeding.data ||= {}
      seeding.data["source"] = "player_list_pdf"
      seeding.data["position"] = player_data[:position]
      seeding.data["nationality"] = player_data[:nationality]
      seeding.state = "confirmed"

      if seeding.save
        saved_count += 1
      else
        Rails.logger.error "[Umb::DetailsScraper] Failed to save seeding: #{seeding.errors.full_messages}"
      end
    end

    Rails.logger.info "[Umb::DetailsScraper] Created #{saved_count} seedings from player list"
    saved_count
  end

  # Erstellt InternationalGame + GameParticipation aus GroupResultParser-Output.
  # Pitfall 3: type: 'InternationalGame' ist zwingend.
  def create_games_from_group_results(tournament, parsed_matches)
    created_count = 0

    parsed_matches.each do |match_data|
      player_a_data = match_data[:player_a]
      player_b_data = match_data[:player_b]
      group = match_data[:group]

      # Spieler über PlayerResolver auflösen (caps+mixed aus V2)
      # GroupResultParser gibt :name zurück (kein getrenntes caps/mixed)
      # Splitten: erstes CAPS-Token als caps_name, Rest als mixed_name
      player_a = resolve_player_from_name(player_a_data[:name], player_a_data[:nationality])
      player_b = resolve_player_from_name(player_b_data[:name], player_b_data[:nationality])

      unless player_a && player_b
        Rails.logger.warn "[Umb::DetailsScraper] Could not resolve players for match in group #{group}"
        next
      end

      # Gewinner bestimmen
      winner = player_a_data[:match_points] >= player_b_data[:match_points] ? player_a : player_b

      total_points = player_a_data[:points] + player_b_data[:points]
      total_innings = player_a_data[:innings] + player_b_data[:innings]
      gd = total_innings > 0 ? (total_points.to_f / total_innings).round(3) : 0.0

      # InternationalGame anlegen (Pitfall 3: V2 STI-Typ)
      game = Game.new(
        tournament: tournament,
        type: "InternationalGame",
        data: {
          group: group,
          gd: gd,
          state: "finished",
          source: "group_results_pdf",
          scraped_at: Time.current.iso8601
        }
      )

      if game.save(validate: false)
        create_game_participation(game, player_a, player_a_data, 1)
        create_game_participation(game, player_b, player_b_data, 2)
        created_count += 1
      else
        Rails.logger.error "[Umb::DetailsScraper] Failed to save game: #{game.errors.full_messages}"
      end
    end

    Rails.logger.info "[Umb::DetailsScraper] Created #{created_count} games from group results"
    created_count
  end

  # Parst GroupResults-PDF für einen bestehenden Game-Datensatz (HTML-basierte Spiele).
  def parse_group_results_pdf_for_game(phase_game, pdf_url)
    pdf_text = @http.fetch_pdf_text(pdf_url)
    return 0 unless pdf_text.present?

    parsed_matches = Umb::PdfParser::GroupResultParser.new(pdf_text).parse
    return 0 if parsed_matches.empty?

    create_games_from_group_results(phase_game.tournament, parsed_matches)
  end

  # Erstellt Seedings mit finaler Position aus RankingParser-Output.
  def create_seedings_from_ranking(tournament, parsed_ranking, phase)
    saved_count = 0

    parsed_ranking.each do |entry|
      # RankingParser gibt :player_name (kombiniert) zurück — Aufteilung nötig
      caps_name, mixed_name = split_player_name(entry[:player_name])
      player = @player_resolver.resolve(caps_name, mixed_name, nationality: entry[:nationality])

      next unless player

      seeding = Seeding.find_or_initialize_by(
        player: player,
        tournament: tournament
      )

      seeding.data ||= {}
      seeding.data["source"] = "ranking_pdf"
      seeding.data["ranking_phase"] = phase
      seeding.data["final_position"] = entry[:position] || entry[:rank]
      seeding.data["points"] = entry[:points]
      seeding.data["average"] = entry[:average]
      seeding.state = "confirmed"

      if seeding.save
        saved_count += 1
      else
        Rails.logger.error "[Umb::DetailsScraper] Failed to save ranking seeding: #{seeding.errors.full_messages}"
      end
    end

    Rails.logger.info "[Umb::DetailsScraper] Created #{saved_count} seedings from ranking (phase: #{phase})"
    saved_count
  end

  # Erstellt eine GameParticipation für einen Spieler in einem Spiel.
  def create_game_participation(game, player, player_data, role)
    participation = GameParticipation.find_or_initialize_by(
      game: game,
      player: player
    )

    participation.assign_attributes(
      role: role.to_s,
      points: player_data[:points],
      innings: player_data[:innings],
      gd: player_data[:average],
      hs: player_data[:hs].to_i,
      data: {
        match_points: player_data[:match_points],
        source: "group_results_pdf"
      }
    )

    participation.save(validate: false)
  end

  # Löst Spieler aus einem kombinierten Namen auf (für GroupResultParser-Output).
  # Strategie: erstes All-CAPS-Token als caps_name, Rest als mixed_name.
  def resolve_player_from_name(full_name, nationality)
    return nil if full_name.blank?

    parts = full_name.strip.split(/\s+/)
    caps_parts = parts.take_while { |p| p.match?(/^[A-Z\-]+$/) }
    mixed_parts = parts.drop(caps_parts.size)

    caps_name = caps_parts.join(" ")
    mixed_name = mixed_parts.join(" ")

    # Fallback: erstes Token als caps, Rest als mixed
    if caps_name.blank? || mixed_name.blank?
      caps_name = parts.first
      mixed_name = parts[1..]&.join(" ").to_s
    end

    @player_resolver.resolve(caps_name, mixed_name, nationality: nationality)
  end

  # Teilt einen kombinierten Spielernamen "CAPS Mixed" auf.
  def split_player_name(full_name)
    return [full_name, ""] if full_name.blank?

    parts = full_name.strip.split(/\s+/)
    caps_parts = parts.take_while { |p| p.match?(/^[A-Z\-]+$/) }
    mixed_parts = parts.drop(caps_parts.size)

    if caps_parts.empty?
      [parts.first, parts[1..]&.join(" ").to_s]
    else
      [caps_parts.join(" "), mixed_parts.join(" ")]
    end
  end

  # Wandelt relative URL in absolute URL um.
  def make_absolute_url(url)
    return url if url.nil? || url.start_with?("http")

    if url.start_with?("/")
      "#{BASE_URL}#{url}"
    else
      "#{BASE_URL}/public/#{url}"
    end
  end

  # --- Hilfsklassen-Methoden (identisch mit FutureScraper/ArchiveScraper) ---

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

  def parse_location_components(location_text)
    return nil if location_text.blank?

    if (match = location_text.match(/N\/A\s*\(([A-Za-z\s]+)\)/i))
      country_name = match[1].strip
      country_code = country_name_to_code(country_name)
      return {city: country_name, country_code: country_code, full_text: location_text, is_country_placeholder: true}
    end

    if (match = location_text.match(/([A-Za-z\s\-]+)\s*\(([A-Za-z\s]{2,})\)/))
      city = match[1].strip.titleize
      country = match[2].strip
      country_code = country_name_to_code(country)
      return {city: city, country_code: country_code, full_text: location_text}
    end

    {city: location_text, country_code: nil, full_text: location_text}
  end

  def country_name_to_code(country_name)
    mapping = {
      "France" => "FR", "FR" => "FR",
      "Germany" => "DE", "DE" => "DE",
      "Belgium" => "BE", "BE" => "BE",
      "Netherlands" => "NL", "NL" => "NL",
      "Spain" => "ES", "ES" => "ES",
      "Italy" => "IT", "IT" => "IT",
      "Turkey" => "TR", "TR" => "TR",
      "Austria" => "AT", "AT" => "AT",
      "Switzerland" => "CH", "CH" => "CH",
      "Egypt" => "EG", "EG" => "EG",
      "Korea" => "KR", "KR" => "KR",
      "Vietnam" => "VN", "VN" => "VN",
      "USA" => "US", "US" => "US",
      "Luxembourg" => "LU", "LU" => "LU",
      "Portugal" => "PT", "PT" => "PT",
      "Greece" => "GR", "GR" => "GR",
      "Poland" => "PL", "PL" => "PL",
      "Czech Republic" => "CZ", "CZ" => "CZ",
      "Slovenia" => "SI", "SI" => "SI",
      "Denmark" => "DK", "DK" => "DK"
    }
    mapping[country_name] || country_name[0, 2].upcase rescue "XX"
  end

  def find_or_create_location_from_text(location_text)
    return nil if location_text.blank?

    components = parse_location_components(location_text)
    return nil unless components

    existing = Location.find_by(name: components[:city])
    return existing if existing

    Location.create!(
      name: components[:city],
      address: components[:full_text],
      data: {
        country_code: components[:country_code],
        created_from: "umb_scraper",
        created_at: Time.current.iso8601
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[Umb::DetailsScraper] Could not create location '#{location_text}': #{e.message}"
    nil
  end

  def find_or_create_season_from_date(date)
    return nil if date.blank?

    season = Season.season_from_date(date)
    return season if season

    year = date.year
    season_start_year = date.month >= 7 ? year : year - 1
    season_end_year = season_start_year + 1
    season_name = "#{season_start_year}/#{season_end_year}"

    Season.find_or_create_by!(name: season_name) do |s|
      s.ba_id = nil
      s.data = "created_from: umb_scraper, start: #{Date.new(season_start_year, 7, 1)}, end: #{Date.new(season_end_year, 6, 30)}"
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[Umb::DetailsScraper] Could not create season for date #{date}: #{e.message}"
    Season.find_by(name: "Unknown Season")
  end

  def find_or_create_umb_organizer
    umb = Region.find_by(shortname: "UMB")
    return umb if umb

    Region.create!(
      shortname: "UMB",
      name: "Union Mondiale de Billard",
      email: "info@umb-carom.org",
      website: "https://www.umb-carom.org",
      scrape_data: {
        "created_from" => "umb_scraper",
        "description" => "World governing body for carom billiards",
        "created_at" => Time.current.iso8601
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Umb::DetailsScraper] CRITICAL: Could not create UMB region: #{e.message}"
    Region.find_by(shortname: "UNKNOWN")
  end
end
