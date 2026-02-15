# frozen_string_literal: true

require "test_helper"

class TournamentScraperTest < ActiveSupport::TestCase
  # Tournament scraping tests
  # 
  # Philosophie: Nur Tests die WIRKLICH laufen und Wert liefern!
  # Keine skip-Tests - entweder es funktioniert oder wir löschen es.
  
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @discipline = disciplines(:carom_3band)
  end
  
  # ============================================================================
  # FIXTURE VALIDATION TESTS
  # ============================================================================
  
  test "tournament list HTML fixture can be loaded" do
    # Prüft ob die Fixture existiert und valides HTML ist
    html_path = Rails.root.join('test/fixtures/html/tournament_list_nbv_2025_2026.html')
    
    assert File.exist?(html_path), 
           "Fixture file should exist: #{html_path}"
    
    html = File.read(html_path)
    assert html.present?, "Fixture should have content"
    assert html.include?('<html') || html.include?('<!DOCTYPE'), 
           "Fixture should be HTML"
    
    # Parse mit Nokogiri
    doc = Nokogiri::HTML(html)
    assert doc.present?, "Should be parseable HTML"
  end
  
  test "tournament details HTML fixture can be loaded" do
    # Prüft ob die Details-Fixture existiert und valides HTML ist
    html_path = Rails.root.join('test/fixtures/html/tournament_details_nbv_870.html')
    
    assert File.exist?(html_path), 
           "Fixture file should exist: #{html_path}"
    
    html = File.read(html_path)
    assert html.present?, "Fixture should have content"
    assert html.include?('<html') || html.include?('<!DOCTYPE'), 
           "Fixture should be HTML"
    
    # Parse mit Nokogiri
    doc = Nokogiri::HTML(html)
    assert doc.present?, "Should be parseable HTML"
    
    # Prüfe ob Tournament-Details-Struktur vorhanden ist
    detail_table = doc.css("aside table.silver")[0]
    assert detail_table.present?, "Should have detail table (aside table.silver)"
  end
  
  test "tournament details fixture has correct structure" do
    # ClubCloud zeigt Liste links (<article>) + Details rechts (<aside>)
    # Die Fixture enthält beides!
    html = File.read(Rails.root.join('test/fixtures/html/tournament_details_nbv_870.html'))
    doc = Nokogiri::HTML(html)
    
    # Prüfe Liste (links)
    article = doc.css("article")[0]
    assert article.present?, "Should have article with tournament list"
    
    tournament_links = doc.css("article a").select { |a| a['href']&.include?('sb_meisterschaft.php?p=20--2025/2026-') }
    assert tournament_links.size > 0, "Should have tournament links in list"
    
    # Prüfe Details (rechts)
    aside = doc.css("aside")[0]
    assert aside.present?, "Should have aside with tournament details"
    
    # Prüfe Details-Tabelle
    detail_table = doc.css("aside table.silver")[0]
    assert detail_table.present?, "Should have detail table"
    
    # Prüfe wichtige Details-Felder
    assert doc.text.include?("TURNIER - DETAILS"), "Should have details header"
    assert doc.text.include?("Kürzel"), "Should have Kürzel field"
    assert doc.text.include?("Datum"), "Should have Datum field"
    assert doc.text.include?("Location"), "Should have Location field"
    assert doc.text.include?("Meldeschluss"), "Should have Meldeschluss field"
    assert doc.text.include?("Sparte"), "Should have Sparte field"
    assert doc.text.include?("Disziplin"), "Should have Disziplin field"
    
    # Details sind für cc_id=853: "2. NordCup Cadre 35/2"
    assert doc.text.include?("2. NordCup Cadre 35/2"), "Should show tournament name"
    assert doc.text.include?("2 NC"), "Should show shortname"
  end
  
  # ============================================================================
  # WEBMOCK VALIDATION
  # ============================================================================
  
  test "WebMock stubbing works" do
    # Test ob WebMock grundsätzlich funktioniert
    test_html = "<html><body>Test Response</body></html>"
    
    stub_request(:get, "https://ndbv.de/test_page")
      .to_return(status: 200, body: test_html)
    
    response = Net::HTTP.get(URI("https://ndbv.de/test_page"))
    
    assert_equal test_html, response, "WebMock should intercept HTTP request"
  end
  
  # ============================================================================
  # BASIC SCRAPING BEHAVIOR TESTS
  # ============================================================================
  
  test "scraping skips when not region organizer" do
    club_tournament = create_scrapable_tournament(
      organizer: clubs(:bcw),
      organizer_type: "Club"
    )
    
    # Should return early without scraping
    assert_nil club_tournament.scrape_single_tournament_public,
               "Should not scrape non-region tournaments"
  end
end
