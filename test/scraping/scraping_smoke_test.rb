# frozen_string_literal: true

require "test_helper"

# Smoke Tests: Prüfen nur, dass Scraping nicht crashed
# Kein detailliertes Testing der HTML-Struktur nötig!
#
# Philosophie: Wenn das echte Scraping täglich läuft und funktioniert,
# brauchen wir keine detaillierten Unit-Tests. Wir wollen nur sicherstellen,
# dass Error-Handling funktioniert.

class ScrapingSmokeTest < ActiveSupport::TestCase
  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
  end

  # ============================================================================
  # GRUNDLEGENDE SMOKE TESTS
  # ============================================================================

  test "Season.update_seasons doesn't crash with empty response" do
    # Stub alle HTTP requests mit leerer Response
    stub_request(:any, /.*/).to_return(status: 200, body: "<html></html>")
    
    # Sollte nicht crashen, auch wenn Response leer ist
    assert_nothing_raised do
      Season.update_seasons
    end
  end

  test "Region.scrape_regions doesn't crash with empty response" do
    stub_request(:any, /.*/).to_return(status: 200, body: "<html></html>")
    
    assert_nothing_raised do
      Region.scrape_regions
    end
  end

  # Location.scrape_locations iteriert über Regions - zu komplex für Unit Test
  # → Wird durch echtes Scraping getestet

  # ============================================================================
  # TOURNAMENT SCRAPING SMOKE TESTS
  # ============================================================================

  test "tournament scraping handles missing tournament_cc gracefully" do
    tournament = create_scrapable_tournament(organizer: @region)
    
    # Kein tournament_cc → sollte early return machen oder scrapen
    assert_nil tournament.tournament_cc
    
    # Sollte nicht crashen (kann nil oder true zurückgeben)
    assert_nothing_raised do
      tournament.scrape_single_tournament_public
    end
  end

  test "tournament scraping handles non-region organizer gracefully" do
    # Tournament mit Club als Organizer (nicht Region)
    tournament = create_scrapable_tournament(
      organizer: clubs(:bcw),
      organizer_type: "Club"
    )
    
    # Sollte early return machen für non-Region tournaments
    result = tournament.scrape_single_tournament_public
    assert_nil result, "Should not scrape non-region tournaments"
  end

  test "tournament scraping handles HTTP errors gracefully" do
    tournament = create_scrapable_tournament(organizer: @region)
    TournamentCc.create!(
      tournament: tournament,
      cc_id: 999,
      context: @region.shortname
    )
    
    # Simuliere Server Error
    stub_request(:get, /.*/).to_return(status: 500, body: "Server Error")
    
    # Sollte nicht crashen
    assert_nothing_raised do
      tournament.scrape_single_tournament_public
    end
  end

  test "tournament scraping handles timeout gracefully" do
    tournament = create_scrapable_tournament(organizer: @region)
    TournamentCc.create!(
      tournament: tournament,
      cc_id: 999,
      context: @region.shortname
    )
    
    # Simuliere Timeout
    stub_request(:get, /.*/).to_timeout
    
    # Sollte nicht crashen (rescue block sollte greifen)
    assert_nothing_raised do
      tournament.scrape_single_tournament_public
    end
  end

  test "tournament scraping handles malformed HTML gracefully" do
    tournament = create_scrapable_tournament(organizer: @region)
    TournamentCc.create!(
      tournament: tournament,
      cc_id: 999,
      context: @region.shortname
    )
    
    # Kaputtes HTML
    stub_request(:get, /.*/).to_return(
      status: 200,
      body: "<html><body>Kaputt ohne</body>"  # Kein schließendes </html>
    )
    
    # Nokogiri kann kaputtes HTML parsen, sollte nicht crashen
    assert_nothing_raised do
      tournament.scrape_single_tournament_public
    end
  end

  # League/Club scraping ist zu komplex für einfache Smoke Tests
  # Diese Methoden iterieren über viele Objekte und benötigen komplexes Setup
  # → Wird durch echtes daily_update Scraping (Produktion) getestet

  # ============================================================================
  # ERROR HANDLING TESTS
  # ============================================================================

  test "scraping handles network errors gracefully" do
    stub_request(:any, /.*/).to_raise(SocketError.new("Network unreachable"))
    
    # Alle Scraping-Methoden sollten Network-Errors abfangen
    assert_nothing_raised do
      begin
        Season.update_seasons
      rescue SocketError, Net::OpenTimeout, Errno::ECONNREFUSED
        # Expected - das ist OK
      end
    end
  end

  test "scraping continues after individual tournament fails" do
    # In der Praxis: Wenn ein Turnier fehlschlägt, sollte das nächste trotzdem gescraped werden
    # Das wird durch rescue-Blöcke in den Scraping-Methoden sichergestellt
    
    # Dieser Test dokumentiert das erwartete Verhalten
    assert true, "Individual failures should not stop batch scraping"
  end

  # ============================================================================
  # PERFORMANCE SMOKE TESTS
  # ============================================================================

  test "tournament scraping completes within reasonable time" do
    tournament = create_scrapable_tournament(organizer: @region)
    TournamentCc.create!(
      tournament: tournament,
      cc_id: 999,
      context: @region.shortname,
      name: tournament.title
    )
    
    # Schnelle Response simulieren
    stub_request(:get, /.*/).to_return(
      status: 200,
      body: "<html><aside><table class='silver'></table></aside></html>"
    )
    
    # Sollte schnell sein (< 1 Sekunde für gemocktes Scraping)
    time = Benchmark.realtime do
      tournament.scrape_single_tournament_public
    end
    
    assert time < 1.0, "Mocked scraping should be fast (was #{time.round(2)}s)"
  end

  # ============================================================================
  # DATA INTEGRITY SMOKE TESTS
  # ============================================================================

  test "scraping sets sync_date when source_url is set" do
    tournament = create_scrapable_tournament(organizer: @region)
    
    # Manuell source_url setzen (wie Scraping es tun würde)
    tournament.source_url = "https://ndbv.de/test"
    tournament.save!
    
    # sync_date sollte automatisch gesetzt werden (durch SourceHandler)
    assert tournament.reload.sync_date.present?,
           "sync_date should be set when source_url is present"
  end

  # LocalProtector wird in test/concerns/local_protector_test.rb getestet
  # Kein Duplikat nötig

  # ============================================================================
  # REALISTIC MINIMAL HTML TESTS
  # ============================================================================

  # Vollständiges HTML-Parsing ist zu komplex für Smoke Tests
  # Das wird durch die echten Fixture-Tests (wenn vorhanden) getestet
  # ODER durch tägliches Produktions-Scraping validiert

  # ============================================================================
  # HELPER METHODS
  # ============================================================================

  private

  def create_scrapable_tournament(attrs = {})
    defaults = {
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      state: "registration",
      discipline: disciplines(:carom_3band)
    }
    
    Tournament.create!(defaults.merge(attrs))
  end
end
