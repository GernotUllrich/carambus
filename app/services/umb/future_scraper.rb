# frozen_string_literal: true

require "nokogiri"

# Scrapt zukünftige UMB-Turniere von der offiziellen Webseite und
# erstellt/aktualisiert InternationalTournament-Datensätze.
#
# ApplicationService gemäß D-03 — hat DB-Seiteneffekte.
# Delegiert HTTP an Umb::HttpClient, Datums-Parsing an Umb::DateHelpers,
# Disziplin-Erkennung an Umb::DisciplineDetector.
class Umb::FutureScraper
  FUTURE_TOURNAMENTS_URL = "https://files.umb-carom.org/public/FutureTournaments.aspx"
  BASE_URL = "https://files.umb-carom.org"

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

  # Scrapt die UMB-Future-Tournaments-Seite und speichert alle gefundenen Turniere.
  # Gibt die Anzahl gespeicherter/aktualisierter Turniere zurück.
  #
  # @return [Integer] Anzahl gespeicherter Turniere
  def call
    Rails.logger.info "[Umb::FutureScraper] Fetching future tournaments from UMB"

    html = @http.fetch_url(FUTURE_TOURNAMENTS_URL)
    return 0 if html.blank?

    doc = Nokogiri::HTML(html)
    tournaments = parse_future_tournaments(doc)

    Rails.logger.info "[Umb::FutureScraper] Found #{tournaments.size} future tournaments"

    saved_count = save_tournaments(tournaments)
    @umb_source.mark_scraped!

    Rails.logger.info "[Umb::FutureScraper] Saved #{saved_count} tournaments"
    saved_count
  rescue StandardError => e
    Rails.logger.error "[Umb::FutureScraper] Error scraping future tournaments: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    0
  end

  private

  # Parst HTML-Tabelle der zukünftigen Turniere.
  # @return [Array<Hash>]
  def parse_future_tournaments(doc)
    tournaments = []
    current_year = Time.current.year
    current_month = nil
    row_count = 0
    pending_cross_month = {}

    doc.css("table tr").each do |row|
      row_count += 1
      cells = row.css("td")

      next if cells.empty?

      row_text = row.text.strip
      first_cell_raw = cells[0]&.text
      first_cell_lines = first_cell_raw&.split(/\n+/)&.map(&:strip)&.reject(&:blank?) || []
      first_line = first_cell_lines.first || ""

      Rails.logger.info "[Umb::FutureScraper] Row #{row_count}: #{cells.size} cells, first_line='#{first_line&.first(50)}'"

      # Jahreszeile erkennen (z.B. "2027")
      year_found_this_row = false
      if first_line.match?(/^\s*(2026|2027|2028|2029|2030)\s*$/)
        if (match = first_line.match(/^\s*(2026|2027|2028|2029|2030)\s*$/))
          current_year = match[1].to_i
          year_found_this_row = true
          Rails.logger.info "[Umb::FutureScraper] Found year: #{current_year}"
        end
      end

      # Monatszeile erkennen (nach Jahrescheck)
      month_found_this_row = false
      %w[January February March April May June July August September October November December].each do |month_name|
        if row_text.match?(/\b#{month_name}\b/i)
          month_num = Date::MONTHNAMES.index(month_name)
          if month_num
            current_month = month_num
            month_found_this_row = true
            Rails.logger.info "[Umb::FutureScraper] Found month: #{month_name} (#{current_month}) with year=#{current_year}"
            break
          end
        end
      end

      # Nur-Jahr-Zeilen überspringen
      next if year_found_this_row && !month_found_this_row

      # Zeilen mit zu wenigen Spalten überspringen
      next if cells.size < 5

      tournament_data = extract_tournament_from_row(
        cells,
        current_month: current_month,
        current_year: current_year,
        pending_cross_month: pending_cross_month
      )

      if tournament_data
        Rails.logger.info "[Umb::FutureScraper] Row #{row_count}: Extracted: #{tournament_data[:name]}"
        tournaments << tournament_data
      end
    end

    Rails.logger.info "[Umb::FutureScraper] Parsed #{tournaments.size} tournament entries"
    tournaments.compact
  rescue StandardError => e
    Rails.logger.error "[Umb::FutureScraper] Error parsing tournaments: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    []
  end

  # Extrahiert Turnierdaten aus einer einzelnen Tabellenzeile.
  # UMB-Struktur: Datum | Name | Typ | Organisation | Ort
  # @return [Hash, nil]
  def extract_tournament_from_row(cells, current_month:, current_year:, pending_cross_month:)
    date_text = cells[0]&.text&.strip
    name_text = cells[1]&.text&.strip
    type_text = cells[2]&.text&.strip
    org_text = cells[3]&.text&.strip
    location_text = cells[4]&.text&.strip

    # Kopfzeilen überspringen
    return nil if date_text.match?(/^Date$/i)
    return nil if name_text.match?(/^(Tournament|Type|Organization|Place)$/i)

    # Monats-Kopfzeilen mit verschobenen Daten überspringen
    if date_text.match?(/^(January|February|March|April|May|June|July|August|September|October|November|December)/i)
      return nil
    end

    # Zu kurze/leere Namen überspringen
    return nil if name_text.blank? || name_text.length < 5

    # Fragmentzeilen überspringen (weniger als 3 Wörter)
    return nil if name_text.split(/\s+/).size < 3

    # Nur-Datums-Muster überspringen (Fragmentzeilen wie "26 -", "- 01")
    return nil if name_text.match?(/^-?\s*\d{1,2}\s*-\s*\d{0,2}\s*$/)

    # Monat-mit-Zahl-Muster überspringen (fehlerhafte Zeilen)
    return nil if name_text.match?(/^(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d/i)

    # Ort bereinigen (wird auch für monatsübergreifende Übereinstimmung benötigt)
    cleaned_location = extract_location(location_text)
    if cleaned_location.blank?
      return nil
    end

    # Monatsübergreifende Ereignisse verarbeiten
    key = "#{name_text}|#{cleaned_location}"

    if date_text.match?(/^(\d{1,2})\s*-\s*$/)
      # Beginn eines monatsübergreifenden Ereignisses (z.B. "26 -")
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
      return nil
    elsif date_text.match?(/^-\s*(\d{1,2})$/)
      # Ende eines monatsübergreifenden Ereignisses (z.B. "- 05")
      end_day = date_text.match(/^-\s*(\d{1,2})$/)[1].to_i

      if pending_cross_month[key]
        start_info = pending_cross_month[key]
        start_month_abbr = Date::ABBR_MONTHNAMES[start_info[:start_month]]
        end_month_abbr = Date::ABBR_MONTHNAMES[current_month]

        start_year = start_info[:start_year]
        end_year = current_month < start_info[:start_month] ? start_year + 1 : start_year

        enhanced_date = "#{start_month_abbr} #{start_info[:start_day]} - #{end_month_abbr} #{end_day}, #{start_year}"
        pending_cross_month.delete(key)

        return {
          name: name_text,
          location: cleaned_location,
          tournament_type_hint: type_text,
          organization: org_text,
          date_range: enhanced_date,
          source: "umb",
          source_url: FUTURE_TOURNAMENTS_URL
        }
      else
        Rails.logger.warn "[Umb::FutureScraper] Orphaned cross-month end: #{name_text} (- #{end_day})"
        return nil
      end
    end

    # Reguläres Ereignis (vollständiger Datumsbereich)
    enhanced_date = Umb::DateHelpers.enhance_date_with_context(date_text, current_month, current_year)
    return nil if enhanced_date.nil?

    {
      name: name_text,
      location: cleaned_location,
      tournament_type_hint: type_text,
      organization: org_text,
      date_range: enhanced_date,
      source: "umb",
      source_url: FUTURE_TOURNAMENTS_URL
    }
  rescue StandardError => e
    Rails.logger.warn "[Umb::FutureScraper] Failed to extract tournament from row: #{e.message}"
    nil
  end

  # Bereinigt Ortstext: "NICE (France)" → "Nice, France", "N/A (Korea)" → "Korea"
  # @return [String, nil]
  def extract_location(text)
    return nil if text.blank?

    # N/A-Muster zuerst prüfen
    if (match = text.match(/N\/A\s*\(([^)]+)\)/i))
      return match[1].strip
    end

    # Organisations-Infos überspringen
    return nil if text.match?(/^UMB\s*\//)
    return nil if text.match?(/^WCBS/)

    # "CITY (Country)" → "City, Country"
    if (match = text.match(/([A-Z\s]+)\s*\(([^)]+)\)/))
      city = match[1].strip.titleize
      country = match[2].strip
      return "#{city}, #{country}"
    end

    text.strip
  end

  # Speichert/aktualisiert alle geparsten Turniere in der Datenbank.
  # @return [Integer] Anzahl gespeicherter Turniere
  def save_tournaments(tournaments)
    saved_count = 0

    tournaments.each do |data|
      begin
        dates = Umb::DateHelpers.parse_date_range(data[:date_range])

        if dates[:start_date].blank?
          Rails.logger.info "[Umb::FutureScraper] Skipping #{data[:name]} - no valid date"
          next
        end

        discipline = Umb::DisciplineDetector.detect(data[:name]) ||
          Discipline.find_by("name ILIKE ?", "%dreiband%groß%") ||
          Discipline.find_by("name ILIKE ?", "%dreiband%gross%")

        unless discipline
          Rails.logger.warn "[Umb::FutureScraper] Skipping #{data[:name]} - no discipline found"
          next
        end

        tournament_type = determine_tournament_type(data[:name], data[:tournament_type_hint])

        # Duplikat-Prüfung: gleicher Titel + Ort + Datum (±30 Tage)
        candidates = InternationalTournament
          .where(title: data[:name])
          .where(location_text: data[:location])
          .where("date BETWEEN ? AND ?",
            dates[:start_date] - 30.days,
            dates[:start_date] + 30.days)
          .to_a

        existing = candidates.min_by { |t| (t.date.to_date - dates[:start_date]).abs }

        tournament = existing || InternationalTournament.new(
          title: data[:name],
          date: dates[:start_date]
        )

        if tournament.new_record?
          season = find_or_create_season_from_date(dates[:start_date])
          umb_organizer = find_or_create_umb_organizer
          location_record = find_or_create_location_from_text(data[:location]) if data[:location].present?

          tournament.organizer = umb_organizer
          tournament.season = season

          tournament.assign_attributes(
            end_date: dates[:end_date],
            location_text: data[:location],
            location_id: location_record&.id,
            discipline: discipline,
            international_source: @umb_source,
            source_url: data[:source_url],
            modus: "international",
            single_or_league: "single",
            plan_or_show: "show",
            state: dates[:start_date] > Date.today ? "planned" : "finished",
            data: {
              umb_official: true,
              umb_type: data[:tournament_type_hint],
              umb_organization: data[:organization],
              tournament_type: tournament_type,
              scraped_at: Time.current.iso8601
            }
          )

          if tournament.save
            Rails.logger.info "[Umb::FutureScraper] Created tournament: #{data[:name]} (#{dates[:start_date]})"
            saved_count += 1
          else
            Rails.logger.error "[Umb::FutureScraper] Failed to save tournament: #{tournament.errors.full_messages}"
          end
        else
          # Bestehendes Turnier aktualisieren
          tournament_data = tournament.data.is_a?(String) ? JSON.parse(tournament.data) : (tournament.data || {})
          tournament_data.merge!(
            umb_type: data[:tournament_type_hint],
            umb_organization: data[:organization],
            tournament_type: tournament_type,
            scraped_at: Time.current.iso8601
          )

          if tournament.organizer_id.blank?
            umb_organizer = find_or_create_umb_organizer
            if umb_organizer
              tournament.organizer_id = umb_organizer.id
              tournament.organizer_type = "Region"
            end
          end

          tournament.update(
            end_date: dates[:end_date],
            location_text: data[:location],
            source_url: data[:source_url],
            organizer_id: tournament.organizer_id,
            organizer_type: tournament.organizer_type,
            data: tournament_data.merge(
              umb_official: true,
              umb_type: data[:tournament_type_hint],
              umb_organization: data[:organization],
              last_updated: Time.current.iso8601
            )
          )
          Rails.logger.info "[Umb::FutureScraper] Updated tournament: #{data[:name]}"
        end
      rescue StandardError => e
        Rails.logger.error "[Umb::FutureScraper] Error saving tournament #{data[:name]}: #{e.message}"
      end
    end

    saved_count
  end

  # Bestimmt den Turniertyp anhand von Name und Typ-Hinweis.
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

  # Parst Ortsinformationen in Komponenten (Stadt, Ländercode).
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
      "Germany" => "DE", "DE" => "DE", "Deutschland" => "DE",
      "Belgium" => "BE", "BE" => "BE", "Belgique" => "BE", "België" => "BE",
      "Netherlands" => "NL", "NL" => "NL", "Nederland" => "NL",
      "Spain" => "ES", "ES" => "ES", "España" => "ES",
      "Italy" => "IT", "IT" => "IT", "Italia" => "IT",
      "Turkey" => "TR", "TR" => "TR", "Türkiye" => "TR",
      "Austria" => "AT", "AT" => "AT", "Österreich" => "AT",
      "Switzerland" => "CH", "CH" => "CH", "Schweiz" => "CH",
      "Egypt" => "EG", "EG" => "EG",
      "Korea" => "KR", "KR" => "KR", "South Korea" => "KR",
      "Vietnam" => "VN", "VN" => "VN",
      "USA" => "US", "US" => "US", "United States" => "US",
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
    Rails.logger.warn "[Umb::FutureScraper] Could not create location '#{location_text}': #{e.message}"
    nil
  end

  # Sucht oder erstellt eine Season aus einem Datum (Billard-Saison beginnt am 1. Juli).
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
    Rails.logger.warn "[Umb::FutureScraper] Could not create season for date #{date}: #{e.message}"
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
    Rails.logger.error "[Umb::FutureScraper] CRITICAL: Could not create UMB region: #{e.message}"
    Region.find_by(shortname: "UNKNOWN")
  end
end
