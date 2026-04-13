# frozen_string_literal: true

# Permanente API-Fassade für UMB-Scraping.
# Alle Geschäftslogik lebt in Umb:: Namespace-Services.
# Aufrufer (Jobs, Controller, Rake Tasks) nutzen weiterhin UmbScraper.
#
# Öffentliche Methoden delegieren an spezialisierte Umb:: Services.
# Private Methoden bleiben erhalten für Rake-Task-Kompatibilität via .send().
class UmbScraper
  BASE_URL = "https://files.umb-carom.org"
  EVENTS_URL = "#{BASE_URL}/Modules/Events/Events.aspx"
  FUTURE_TOURNAMENTS_URL = "#{BASE_URL}/public/FutureTournaments.aspx"
  ARCHIVE_URL = "https://www.umb-carom.org/PG342L2/Union-Mondiale-de-Billard.aspx"
  TOURNAMENT_DETAILS_URL = "#{BASE_URL}/public/TournametDetails.aspx"
  TIMEOUT = 30

  # Game type mappings from PDF filenames
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

  # Bad location values that should be replaced when re-scraping
  BAD_LOCATIONS = ["A", "N/A", "", nil].freeze

  attr_reader :umb_source

  def initialize
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

  # ---------------------------------------------------------------------------
  # Öffentliche Delegations-Methoden
  # ---------------------------------------------------------------------------

  # Scrapt zukünftige UMB-Turniere und speichert sie.
  # @return [Integer] Anzahl gespeicherter Turniere
  def scrape_future_tournaments
    Umb::FutureScraper.new.call
  end

  # Scrapt das UMB-Turnier-Archiv durch ID-Bereich-Scan.
  # @return [Integer] Anzahl gespeicherter Turniere
  def scrape_tournament_archive(start_id: 1, end_id: 500, batch_size: 50)
    Umb::ArchiveScraper.new.call(start_id: start_id, end_id: end_id, batch_size: batch_size)
  end

  # Scrapt Details für ein bestimmtes Turnier.
  # @param tournament_id_or_record [Integer, InternationalTournament]
  # @return [InternationalTournament, false]
  def scrape_tournament_details(tournament_id_or_record, create_games: true, parse_pdfs: false)
    Umb::DetailsScraper.new.call(tournament_id_or_record, create_games: create_games, parse_pdfs: parse_pdfs)
  end

  # Scrapt UMB-Rankings für eine Disziplin.
  # Lädt das aktuelle Ranking-PDF herunter und parst es mit Umb::PdfParser::RankingParser.
  # @return [Integer] Anzahl geparster Einträge (0 bei Fehler oder fehlendem PDF)
  def scrape_rankings(discipline_name: "3-Cushion", year: Time.current.year)
    Rails.logger.info "[UmbScraper] Fetching #{discipline_name} rankings for #{year}"

    week = Time.current.strftime("%W").to_i
    # URL-Muster: files.umb-carom.org/Public/Ranking/1_WP_Ranking/YEAR/WWEEK_YEAR.pdf
    pdf_url = "#{BASE_URL}/Public/Ranking/1_WP_Ranking/#{year}/W#{week}_#{year}.pdf"

    http = Umb::HttpClient.new
    pdf_text = http.fetch_pdf_text(pdf_url)

    unless pdf_text.present?
      Rails.logger.warn "[UmbScraper] Ranking PDF nicht erreichbar oder leer: #{pdf_url}"
      return 0
    end

    entries = Umb::PdfParser::RankingParser.new.parse(pdf_text, type: :weekly)
    Rails.logger.info "[UmbScraper] #{entries.size} Ranking-Einträge geparst"
    entries.size
  rescue => e
    Rails.logger.error "[UmbScraper] Error scraping rankings: #{e.message}"
    0
  end

  # Erkennt die Disziplin anhand des Turniernamens.
  # Gibt die Disziplin-ID (Integer) zurück — Rückwärtskompatibilität mit Phase-25-Char-Tests.
  # @return [Integer, nil] Discipline#id oder nil
  def detect_discipline_from_name(tournament_name)
    return nil if tournament_name.blank?
    n = tournament_name.to_s.downcase
    return Discipline.find_by(name: "Artistique")&.id || 71 if n.match?(/artistique|artistic|künstlerisch/i)
    if n.match?(/3[\s-]?c(?:ushion)?(?:\s|$|\))/i) || n.match?(/\(3c\)/i) ||
        n.match?(/three[\s-]?cushion/i) || n.match?(/dreiband|drei[\s-]?band/i) ||
        n.match?(/3[\s-]?bandes|3[\s-]?banden/i)
      return Discipline.find_by(name: "Dreiband groß")&.id || 31
    end
    return Discipline.find_by(name: "5-Pin Billards")&.id || 26 if n.match?(/5[\s-]?pin|five[\s-]?pin/i)
    return Discipline.find_by(name: "Einband groß")&.id || 32 if n.match?(/1[\s-]?cushion|one[\s-]?cushion|einband|een[\s-]?band/i)
    return Discipline.find_by(name: "Freie Partie groß")&.id || 38 if n.match?(/straight[\s-]?rail|libre|freie[\s-]?partie/i)
    if n.match?(/cadre|balkline|(\d+)\/(\d+)/i)
      return Discipline.find_by(name: "Cadre 47/2")&.id || 40 if n.match?(/47\/2/)
      return Discipline.find_by(name: "Cadre 71/2")&.id || 39 if n.match?(/71\/2/)
      return Discipline.find_by(name: "Cadre 57/2")&.id || 10 if n.match?(/57\/2/)
      return Discipline.find_by(name: "Cadre 52/2")&.id || 36 if n.match?(/52\/2/)
      return Discipline.find_by(name: "Cadre 35/2")&.id || 35 if n.match?(/35\/2/)
      return Discipline.find_by(name: "Cadre 47/2")&.id || 40
    end
    Discipline.find_by(name: "Dreiband groß")&.id || 31
  end

  # Öffentlicher Wrapper für Admin::IncompleteRecordsController#auto_fix_all,
  # der diese Methode via .send(:find_discipline_from_name, ...) aufruft.
  # Gibt ein Discipline-Objekt zurück (für tournament.update(discipline: ...)).
  # Pitfall 2: via .send() aufgerufen — muss public bleiben.
  # @return [Discipline, nil]
  def find_discipline_from_name(tournament_name)
    Umb::DisciplineDetector.detect(tournament_name)
  end

  private

  # ---------------------------------------------------------------------------
  # Private Hilfsmethoden für Rake-Task-Kompatibilität
  # Rake Tasks rufen diese via .send() auf — Implementierung bleibt privat.
  # ---------------------------------------------------------------------------

  # Holt Turnier-Grunddaten von der Detailseite.
  # Aufgerufen via .send() aus umb.rake und umb_update.rake.
  def fetch_tournament_basic_data(external_id)
    Umb::DetailsScraper.new.send(:fetch_tournament_basic_data, external_id)
  end

  # Erstellt ein Turnier aus Basisdaten.
  # Aufgerufen via .send() aus umb.rake und umb_update.rake.
  def save_tournament_from_details(data)
    Umb::DetailsScraper.new.send(:save_tournament_from_details, data)
  end

  # Erstellt oder findet die UMB-Organizer-Region.
  # Aufgerufen via .send() aus umb_update.rake.
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
    Rails.logger.error "[UmbScraper] CRITICAL: Could not create UMB region: #{e.message}"
    Region.find_by(shortname: "UNKNOWN")
  end
end
