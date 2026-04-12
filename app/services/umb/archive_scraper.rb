# frozen_string_literal: true

require "nokogiri"

# Scrapt das UMB-Turnier-Archiv durch sequentielles Scannen von IDs.
# Holt jede Detailseite (TournametDetails.aspx?ID=N) und speichert neue Turniere.
#
# ApplicationService gemäß D-03 — hat DB-Seiteneffekte.
# Delegiert HTTP an Umb::HttpClient, Datums-Parsing an Umb::DateHelpers,
# Disziplin-Erkennung an Umb::DisciplineDetector.
class Umb::ArchiveScraper
  BASE_URL = "https://files.umb-carom.org"
  TOURNAMENT_DETAILS_URL = "#{BASE_URL}/public/TournametDetails.aspx"

  def initialize
    @http = Umb::HttpClient.new
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

  # Scrapt Turnier-IDs von start_id bis end_id und speichert neu entdeckte Turniere.
  # Bricht früh ab wenn max_consecutive_404s aufeinanderfolgende 404s erreicht werden.
  #
  # @param start_id [Integer] Erste zu prüfende ID
  # @param end_id [Integer] Letzte zu prüfende ID (inklusiv)
  # @param batch_size [Integer] Rate-Limiting: Sleep nach jeweils dieser Anzahl IDs
  # @return [Integer] Anzahl gespeicherter Turniere
  def call(start_id: 1, end_id: 500, batch_size: 50)
    Rails.logger.info "[Umb::ArchiveScraper] Scraping tournament archive: IDs #{start_id}..#{end_id}"

    total_found = 0
    total_saved = 0
    not_found_count = 0
    max_consecutive_404s = 50

    (start_id..end_id).each do |id|
      break if not_found_count >= max_consecutive_404s

      Rails.logger.info "[Umb::ArchiveScraper] Checking tournament ID #{id}..."

      detail_url = "#{TOURNAMENT_DETAILS_URL}?ID=#{id}"
      html = @http.fetch_url(detail_url)

      if html.blank? || html.include?("404") || html.length < 500
        not_found_count += 1
        Rails.logger.debug "[Umb::ArchiveScraper] Tournament ID #{id} not found (consecutive 404s: #{not_found_count})"
        next
      end

      not_found_count = 0
      total_found += 1

      begin
        doc = Nokogiri::HTML(html)
        tournament_data = parse_tournament_detail_for_archive(doc, id, detail_url)

        if tournament_data && save_archived_tournament(tournament_data)
          total_saved += 1
          Rails.logger.info "[Umb::ArchiveScraper] Saved tournament ID #{id}: #{tournament_data[:name]}"
        end
      rescue StandardError => e
        Rails.logger.error "[Umb::ArchiveScraper] Error parsing tournament ID #{id}: #{e.message}"
      end

      # Rate-Limiting: alle batch_size IDs kurz warten
      sleep 1 if (id % batch_size) == 0
    end

    Rails.logger.info "[Umb::ArchiveScraper] Archive scan complete: found #{total_found}, saved #{total_saved}"
    total_saved
  rescue StandardError => e
    Rails.logger.error "[Umb::ArchiveScraper] Error in archive scan: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    0
  end

  private

  # Parst eine Detailseite für das Archiv-Scanning.
  # @return [Hash, nil] Turnierdaten oder nil wenn ungültig
  def parse_tournament_detail_for_archive(doc, external_id, detail_url)
    tournament_info = {}

    doc.css("table tr").each do |row|
      cells = row.css("td")
      next unless cells.size == 2

      label = cells[0].text.strip.downcase
      value = cells[1].text.strip

      case label
      when /tournament:/i
        tournament_info[:name] = value
      when /starts on:/i
        tournament_info[:start_date] = Umb::DateHelpers.parse_date(value)
      when /ends on:/i
        tournament_info[:end_date] = Umb::DateHelpers.parse_date(value)
      when /organized by:/i
        tournament_info[:organizer] = value
      when /place:/i
        city, country = parse_location_country(value)
        tournament_info[:location] = value
        tournament_info[:country] = country
      end
    end

    return nil unless tournament_info[:name].present?

    discipline = Umb::DisciplineDetector.detect(tournament_info[:name])
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
        scraped_from: "sequential_scan",
        scraped_at: Time.current.iso8601
      }
    }
  end

  # Speichert ein einzelnes archiviertes Turnier — überspringt Duplikate.
  # @return [Boolean] true wenn gespeichert
  def save_archived_tournament(tournament_data)
    return false unless tournament_data[:name].present?

    existing = InternationalTournament.find_by(
      international_source: @umb_source,
      external_id: tournament_data[:external_id]
    )

    if existing
      Rails.logger.debug "[Umb::ArchiveScraper] Tournament #{tournament_data[:external_id]} already exists"
      return false
    end

    discipline_id = tournament_data[:discipline]&.id ||
      Discipline.find_by("name ILIKE ?", "%dreiband%groß%")&.id ||
      Discipline.find_by("name ILIKE ?", "%dreiband%gross%")&.id

    season = find_or_create_season_from_date(tournament_data[:start_date]) if tournament_data[:start_date]
    season ||= Season.find_by(name: "Unknown Season")

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
      organizer_type: "Region",
      modus: "international",
      plan_or_show: "show",
      single_or_league: "single",
      state: tournament_data[:start_date] && tournament_data[:start_date] < Date.today ? "finished" : "planned",
      data: tournament_data[:data].merge(
        country: tournament_data[:country],
        organizer_text: tournament_data[:organizer],
        tournament_type: tournament_data[:tournament_type]
      ).to_json
    )

    if tournament.save(validate: false)
      true
    else
      Rails.logger.error "[Umb::ArchiveScraper] Failed to save tournament: #{tournament.errors.full_messages}"
      false
    end
  end

  # Bestimmt den Turniertyp anhand des Namens.
  def determine_tournament_type(name, type_hint = nil)
    name_lower = name.downcase
    hint_lower = type_hint&.downcase || ""

    return "world_championship" if hint_lower.include?("world championship")
    return "world_cup" if hint_lower.include?("world cup")
    return "european_championship" if hint_lower.include?("european championship")
    return "invitation" if hint_lower.include?("invitational") || hint_lower.include?("promotional")

    case name_lower
    when /world championship/ then "world_championship"
    when /world cup/ then "world_cup"
    when /european championship/ then "european_championship"
    when /world masters/ then "invitation"
    when /national championship/ then "national_championship"
    when /general assembly/ then "other"
    else "other"
    end
  end

  # Parst Ortsstring in [Stadt, Land].
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

  # Parst Ortsinformationen in Komponenten.
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

  # Wandelt Ländernamen in ISO-2-Buchstaben-Codes um.
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

  # Sucht oder erstellt einen Location-Datensatz aus Ortstext.
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
    Rails.logger.warn "[Umb::ArchiveScraper] Could not create location '#{location_text}': #{e.message}"
    nil
  end

  # Sucht oder erstellt eine Season aus einem Datum.
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
    Rails.logger.warn "[Umb::ArchiveScraper] Could not create season for date #{date}: #{e.message}"
    Season.find_by(name: "Unknown Season")
  end

  # Sucht oder erstellt die UMB-Veranstalter-Region.
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
    Rails.logger.error "[Umb::ArchiveScraper] CRITICAL: Could not create UMB region: #{e.message}"
    Region.find_by(shortname: "UNKNOWN")
  end
end
