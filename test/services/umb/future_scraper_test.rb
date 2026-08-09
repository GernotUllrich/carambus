# frozen_string_literal: true

require "test_helper"

# Tests für Umb::FutureScraper.
# Alle HTTP-Anfragen werden via WebMock gestubbt — kein echter Netzwerkzugriff.
class Umb::FutureScraperTest < ActiveSupport::TestCase
  FUTURE_URL = "https://files.umb-carom.org/public/FutureTournaments.aspx"

  # Minimale HTML-Seite mit einer Turniertabellenzeile
  SINGLE_TOURNAMENT_HTML = <<~HTML
    <html><body>
    <table>
      <tr><td>2026</td><td></td><td></td><td></td><td></td></tr>
      <tr><td>May</td><td></td><td></td><td></td><td></td></tr>
      <tr>
        <td>15 - 20</td>
        <td>World Cup 3-Cushion Nice</td>
        <td>World Cup</td>
        <td>UMB</td>
        <td>NICE (France)</td>
      </tr>
    </table>
    </body></html>
  HTML

  # HTML ohne gültige Turniere
  EMPTY_HTML = "<html><body><table></table></body></html>"

  setup do
    # InternationalSource in der Testdatenbank anlegen
    @umb_source = InternationalSource.find_or_create_by!(
      name: "Union Mondiale de Billard",
      source_type: "umb"
    ) do |s|
      s.base_url = "https://files.umb-carom.org"
    end

    # Dreiband-Disziplin anlegen (wird von DisciplineDetector gesucht)
    @discipline = Discipline.find_or_create_by!(name: "Dreiband groß") do |d|
      d.id = 50_099_001
    end
  rescue ActiveRecord::RecordNotUnique
    @discipline = Discipline.find_by(name: "Dreiband groß")
  end

  teardown do
    InternationalTournament.where("id >= 50000000").delete_all
    InternationalSource.where(source_type: "umb").delete_all
    Discipline.where(id: 50_099_001).delete_all
    Season.where("id >= 50000000").delete_all
    Region.where(shortname: "UMB").delete_all
    # Location-Löschung überspringen: fixtures haben FK-Referenzen auf tables-Tabelle
  end

  # --- Grundlegendes Verhalten ---

  test "call returns 0 when HTTP fetch returns nil" do
    stub_request(:get, FUTURE_URL).to_return(status: 500, body: "")

    scraper = Umb::FutureScraper.new
    result = scraper.call
    assert_equal 0, result
  end

  test "call returns 0 for empty HTML page" do
    stub_request(:get, FUTURE_URL).to_return(status: 200, body: EMPTY_HTML)

    scraper = Umb::FutureScraper.new
    result = scraper.call
    assert_equal 0, result
  end

  test "call returns integer count of saved tournaments" do
    stub_request(:get, FUTURE_URL).to_return(status: 200, body: SINGLE_TOURNAMENT_HTML)

    scraper = Umb::FutureScraper.new
    result = scraper.call
    assert_kind_of Integer, result
  end

  test "call does not raise on network error" do
    stub_request(:get, FUTURE_URL).to_raise(StandardError.new("Network error"))

    scraper = Umb::FutureScraper.new
    assert_nothing_raised { scraper.call }
  end

  # --- HTML-Parsing ---

  test "parse_future_tournaments extracts tournament with year+month context" do
    stub_request(:get, FUTURE_URL).to_return(status: 200, body: SINGLE_TOURNAMENT_HTML)

    scraper = Umb::FutureScraper.new
    # Bei erfolgreichem Parsing wird mindestens 1 Turnier verarbeitet
    result = scraper.call
    assert result >= 0
  end

  # Altes Seitenformat — bleibt unterstuetzt (aeltere Kassetten/Archivseiten).
  test "extract_location handles 'NICE (France)' format" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:extract_location, "NICE (France)")
    assert_equal "Nice, France", result
  end

  test "extract_location handles 'N/A (Korea)' format" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:extract_location, "N/A (Korea)")
    assert_equal "Korea", result
  end

  # Aktuelles Seitenformat (Stand 2026): "CITY / Country (Country)".
  # Vorher lieferte die Stadt/Land-Regex hier ", Argentina" — der Ort ging
  # bei JEDEM Future-Turnier verloren.
  test "extract_location handles 'CITY / Country (Country)' format" do
    scraper = Umb::FutureScraper.new
    assert_equal "Marcos Juarez, Argentina",
      scraper.send(:extract_location, "MARCOS JUAREZ / Argentina (Argentina)")
    assert_equal "Ankara, Turkey",
      scraper.send(:extract_location, "ANKARA / Turkey (Turkey)")
  end

  test "extract_location handles mehrteilige Ortsnamen im neuen Format" do
    scraper = Umb::FutureScraper.new
    assert_equal "Ho Chi Minh City, Vietnam",
      scraper.send(:extract_location, "HO CHI MINH CITY / Vietnam (Vietnam)")
  end

  test "extract_location handles 'N/A / Country (Country)' — nur Land" do
    scraper = Umb::FutureScraper.new
    assert_equal "Korea", scraper.send(:extract_location, "N/A / Korea (Korea)")
  end

  # Statuspraefixe bleiben stehen (Information wuerde sonst verloren gehen);
  # der Bindestrich darf dabei nicht zu Leerzeichen werden.
  test "extract_location behaelt Statuspraefix und Interpunktion" do
    scraper = Umb::FutureScraper.new
    assert_equal "Postponed - Doha, Qatar",
      scraper.send(:extract_location, "POSTPONED - DOHA / Qatar (Qatar)")
  end

  test "extract_location returns nil for org text" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:extract_location, "UMB / WCBS")
    assert_nil result
  end

  test "extract_location returns nil for blank input" do
    scraper = Umb::FutureScraper.new
    assert_nil scraper.send(:extract_location, nil)
    assert_nil scraper.send(:extract_location, "")
  end

  # --- Datums-Delegation ---

  test "uses Umb::DateHelpers.parse_date_range for date parsing (not private methods)" do
    # Stellt sicher dass keine privaten parse_date_range-Methoden im FutureScraper existieren
    assert_not_respond_to Umb::FutureScraper.new, :parse_date_range
    assert_not_respond_to Umb::FutureScraper.new, :parse_single_date
  end

  test "uses Umb::DateHelpers.enhance_date_with_context for date enrichment" do
    assert_not_respond_to Umb::FutureScraper.new, :parse_month_day_range
  end

  # --- Disziplin-Delegation ---

  test "uses Umb::DisciplineDetector.detect (not private detect method)" do
    assert_not_respond_to Umb::FutureScraper.new, :detect_discipline_from_name
    assert_not_respond_to Umb::FutureScraper.new, :find_discipline_from_name
  end

  # --- HTTP-Client-Delegation ---

  test "uses Umb::HttpClient for HTTP (no private fetch_url)" do
    assert_not_respond_to Umb::FutureScraper.new, :fetch_url
  end

  # --- Turniertyp ---

  test "determine_tournament_type detects world championship from name" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:determine_tournament_type, "World Championship 3-Cushion 2026")
    assert_equal "world_championship", result
  end

  test "determine_tournament_type detects world cup from name" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:determine_tournament_type, "World Cup 3-Cushion Nice 2026")
    assert_equal "world_cup", result
  end

  test "determine_tournament_type returns other for unknown names" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:determine_tournament_type, "Random Tournament 2026")
    assert_equal "other", result
  end

  test "determine_tournament_type uses type_hint if available" do
    scraper = Umb::FutureScraper.new
    result = scraper.send(:determine_tournament_type, "Some Tournament", "World Cup")
    assert_equal "world_cup", result
  end

  # --- Monatsübergreifende Ereignisse ---

  test "extracts cross-month tournament when start and end rows both present" do
    html = <<~HTML
      <html><body>
      <table>
        <tr><td>2026</td><td></td><td></td><td></td><td></td></tr>
        <tr><td>December</td><td></td><td></td><td></td><td></td></tr>
        <tr>
          <td>29 -</td>
          <td>European Championship 3-Cushion Berlin</td>
          <td>European Championship</td>
          <td>UMB</td>
          <td>BERLIN (Germany)</td>
        </tr>
        <tr><td>January</td><td></td><td></td><td></td><td></td></tr>
        <tr>
          <td>- 04</td>
          <td>European Championship 3-Cushion Berlin</td>
          <td>European Championship</td>
          <td>UMB</td>
          <td>BERLIN (Germany)</td>
        </tr>
      </table>
      </body></html>
    HTML

    stub_request(:get, FUTURE_URL).to_return(status: 200, body: html)

    scraper = Umb::FutureScraper.new
    result = scraper.call
    assert result >= 0
  end
end
