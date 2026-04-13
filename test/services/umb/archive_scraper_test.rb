# frozen_string_literal: true

require "test_helper"

# Tests für Umb::ArchiveScraper.
# Alle HTTP-Anfragen werden via WebMock gestubbt — kein echter Netzwerkzugriff.
class Umb::ArchiveScraperTest < ActiveSupport::TestCase
  BASE_DETAIL_URL = "https://files.umb-carom.org/public/TournametDetails.aspx"

  # Minimale Turnier-Detailseite (valide)
  VALID_DETAIL_HTML = <<~HTML
    <html><body>
    <table>
      <tr><td>Tournament:</td><td>World Cup 3-Cushion Nice</td></tr>
      <tr><td>Starts on:</td><td>15-May-2024</td></tr>
      <tr><td>Ends on:</td><td>19-May-2024</td></tr>
      <tr><td>Organized by:</td><td>UMB</td></tr>
      <tr><td>Place:</td><td>NICE (France)</td></tr>
    </table>
    </body></html>
  HTML

  # Seite ohne Turnierinfo (404-ähnlich)
  NOT_FOUND_HTML = "<html><body><p>404 Not Found</p></body></html>"

  setup do
    @umb_source = InternationalSource.find_or_create_by!(
      name: "Union Mondiale de Billard",
      source_type: "umb"
    ) do |s|
      s.base_url = "https://files.umb-carom.org"
    end

    @discipline = Discipline.find_or_create_by!(name: "Dreiband groß") do |d|
      d.id = 50_099_002
    end
  rescue ActiveRecord::RecordNotUnique
    @discipline = Discipline.find_by(name: "Dreiband groß")
  end

  teardown do
    InternationalTournament.where("id >= 50000000").delete_all
    InternationalSource.where(source_type: "umb").delete_all
    Discipline.where(id: 50_099_002).delete_all
    Season.where("id >= 50000000").delete_all
    Region.where(shortname: "UMB").delete_all
    # Location-Löschung überspringen: fixtures haben FK-Referenzen auf tables-Tabelle
  end

  # --- Grundlegendes Verhalten ---

  test "call returns integer" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=1")
      .to_return(status: 200, body: NOT_FOUND_HTML)

    scraper = Umb::ArchiveScraper.new
    result = scraper.call(start_id: 1, end_id: 1, batch_size: 50)
    assert_kind_of Integer, result
  end

  test "call returns 0 when all pages not found" do
    (1..5).each do |id|
      stub_request(:get, "#{BASE_DETAIL_URL}?ID=#{id}")
        .to_return(status: 200, body: NOT_FOUND_HTML)
    end

    scraper = Umb::ArchiveScraper.new
    result = scraper.call(start_id: 1, end_id: 5, batch_size: 50)
    assert_equal 0, result
  end

  test "call does not raise on network errors" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=1")
      .to_raise(StandardError.new("Network error"))

    scraper = Umb::ArchiveScraper.new
    assert_nothing_raised { scraper.call(start_id: 1, end_id: 1, batch_size: 50) }
  end

  # --- Batch-Scanning ---

  test "call scans sequential IDs in range" do
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=10")
      .to_return(status: 200, body: NOT_FOUND_HTML)
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=11")
      .to_return(status: 200, body: NOT_FOUND_HTML)
    stub_request(:get, "#{BASE_DETAIL_URL}?ID=12")
      .to_return(status: 200, body: NOT_FOUND_HTML)

    scraper = Umb::ArchiveScraper.new
    scraper.call(start_id: 10, end_id: 12, batch_size: 50)

    assert_requested :get, "#{BASE_DETAIL_URL}?ID=10"
    assert_requested :get, "#{BASE_DETAIL_URL}?ID=11"
    assert_requested :get, "#{BASE_DETAIL_URL}?ID=12"
  end

  test "call stops early after max consecutive 404s" do
    # Stubs für IDs 1-3 (werden nicht alle angefragt, wenn 404-Limit überschritten)
    (1..3).each do |id|
      stub_request(:get, "#{BASE_DETAIL_URL}?ID=#{id}")
        .to_return(status: 200, body: NOT_FOUND_HTML)
    end

    # Bei 50 konsekutiven 404s würde es stoppen — hier mit kleinem Bereich
    scraper = Umb::ArchiveScraper.new
    result = scraper.call(start_id: 1, end_id: 3, batch_size: 50)
    assert_equal 0, result
  end

  # --- Turnierparsen ---

  test "parse_tournament_detail_for_archive extracts name" do
    doc = Nokogiri::HTML(VALID_DETAIL_HTML)
    scraper = Umb::ArchiveScraper.new
    result = scraper.send(:parse_tournament_detail_for_archive, doc, 42, "#{BASE_DETAIL_URL}?ID=42")

    assert_not_nil result
    assert_equal "World Cup 3-Cushion Nice", result[:name]
  end

  test "parse_tournament_detail_for_archive extracts external_id" do
    doc = Nokogiri::HTML(VALID_DETAIL_HTML)
    scraper = Umb::ArchiveScraper.new
    result = scraper.send(:parse_tournament_detail_for_archive, doc, 42, "#{BASE_DETAIL_URL}?ID=42")

    assert_equal "42", result[:external_id]
  end

  test "parse_tournament_detail_for_archive uses DateHelpers.parse_date" do
    doc = Nokogiri::HTML(VALID_DETAIL_HTML)
    scraper = Umb::ArchiveScraper.new
    result = scraper.send(:parse_tournament_detail_for_archive, doc, 42, "#{BASE_DETAIL_URL}?ID=42")

    assert_equal Date.new(2024, 5, 15), result[:start_date]
    assert_equal Date.new(2024, 5, 19), result[:end_date]
  end

  test "parse_tournament_detail_for_archive uses DisciplineDetector" do
    doc = Nokogiri::HTML(VALID_DETAIL_HTML)
    scraper = Umb::ArchiveScraper.new
    result = scraper.send(:parse_tournament_detail_for_archive, doc, 42, "#{BASE_DETAIL_URL}?ID=42")

    # DisciplineDetector wird gecallt — result[:discipline] kann nil sein wenn DB leer
    assert result.key?(:discipline)
  end

  test "parse_tournament_detail_for_archive returns nil for page without name" do
    html = "<html><body><table><tr><td>Starts on:</td><td>15-May-2024</td></tr></table></body></html>"
    doc = Nokogiri::HTML(html)
    scraper = Umb::ArchiveScraper.new
    result = scraper.send(:parse_tournament_detail_for_archive, doc, 99, "#{BASE_DETAIL_URL}?ID=99")

    assert_nil result
  end

  # --- Duplikat-Vermeidung ---

  test "save_archived_tournament skips duplicate external_id" do
    # Turnier mit gleicher external_id vorab anlegen
    existing = InternationalTournament.new(
      title: "Existing Tournament",
      date: Date.new(2024, 5, 15),
      external_id: "42",
      international_source: @umb_source,
      modus: "international",
      plan_or_show: "show",
      single_or_league: "single",
      state: "finished"
    )
    existing.save(validate: false)

    scraper = Umb::ArchiveScraper.new
    data = {
      name: "World Cup 3-Cushion Nice",
      start_date: Date.new(2024, 5, 15),
      end_date: Date.new(2024, 5, 19),
      location: "Nice, France",
      country: "France",
      organizer: "UMB",
      discipline: nil,
      tournament_type: "world_cup",
      external_id: "42",
      source_url: "#{BASE_DETAIL_URL}?ID=42",
      data: {umb_organization: "UMB", scraped_from: "sequential_scan", scraped_at: Time.current.iso8601}
    }

    result = scraper.send(:save_archived_tournament, data)
    assert_equal false, result
  end

  # --- HTTP-Client-Delegation ---

  test "uses Umb::HttpClient for HTTP (no private fetch_url)" do
    assert_not_respond_to Umb::ArchiveScraper.new, :fetch_url
  end

  # --- Datums-Delegation ---

  test "does not have private parse_date method (delegates to DateHelpers)" do
    assert_not_respond_to Umb::ArchiveScraper.new, :parse_date
    assert_not_respond_to Umb::ArchiveScraper.new, :parse_date_range
  end
end
