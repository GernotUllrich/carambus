# frozen_string_literal: true

require "test_helper"

# Characterization tests for UmbScraperV2.
# Pinnt das Verhalten von UmbScraperV2 vor der Phase-27-Extraktion.
#
# AUFNAHME-ANLEITUNG (VCR-Kassette einmalig aufnehmen):
#
#   1. Stelle sicher, dass eine Internetverbindung zu files.umb-carom.org besteht.
#      Pruefen: curl -I "https://files.umb-carom.org/public/TournametDetails.aspx?ID=428"
#
#   2. Starte die Aufnahme gegen die echte UMB-Seite:
#      RECORD_VCR=true bin/rails test test/characterization/umb_scraper_v2_char_test.rb
#
#   3. Pruefe, dass die Kassette erstellt wurde:
#      ls test/snapshots/vcr/umb/scraper_v2_tournament.yml
#
#   4. Lauf ohne RECORD_VCR zur Verifikation (Replay-Modus):
#      bin/rails test test/characterization/umb_scraper_v2_char_test.rb
#
# OHNE INTERNETZUGANG:
#   VCR-Tests ohne Kassette werden uebersprungen (skip).
#   WebMock-Tests (Fehlerbehandlung) laufen immer durch.
#
class UmbScraperV2CharTest < ActiveSupport::TestCase
  VCR_RECORD_MODE = ENV["RECORD_VCR"] ? :new_episodes : :none

  # External ID of a known UMB tournament for VCR recording.
  # 428 = 2022 UMB World Cup 3-Cushion Antalya (publicly accessible)
  KNOWN_TOURNAMENT_EXTERNAL_ID = 428

  # Prueft ob eine VCR-Kassette bereits vorhanden ist.
  def cassette_exists?(name)
    File.exist?(Rails.root.join("test", "snapshots", "vcr", "#{name}.yml"))
  end

  # Fuehrt einen VCR-Test aus. Wenn keine Kassette vorhanden und kein RECORD_VCR gesetzt,
  # wird der Test uebersprungen (skip) statt fehlzuschlagen.
  def with_vcr_cassette(name, &block)
    if VCR_RECORD_MODE == :none && !cassette_exists?(name)
      skip "VCR-Kassette '#{name}.yml' fehlt. Aufnehmen mit: RECORD_VCR=true bin/rails test test/characterization/umb_scraper_v2_char_test.rb"
    end
    VCR.use_cassette(name, record: VCR_RECORD_MODE, &block)
  end

  setup do
    @scraper = UmbScraperV2.new
  end

  # ===========================================================================
  # A. initialize — InternationalSource-Erstellung
  # ===========================================================================

  test "initialize creates UMB international source" do
    # UmbScraperV2.new muss eine InternationalSource fuer UMB finden oder anlegen.
    assert_instance_of UmbScraperV2, @scraper

    source = InternationalSource.find_by(source_type: "umb")
    assert_not_nil source, "InternationalSource fuer UMB muss existieren"
    assert_equal "Union Mondiale de Billard", source.name
    assert_equal "umb", source.source_type
    assert_equal UmbScraperV2::BASE_URL, source.base_url
  end

  test "initialize is idempotent — repeated calls return same source" do
    # find_or_create_by! muss idempotent sein: kein Duplikat bei zweitem Aufruf.
    scraper2 = UmbScraperV2.new
    assert_equal @scraper.umb_source.id, scraper2.umb_source.id
    assert_equal 1, InternationalSource.where(source_type: "umb").count
  end

  # ===========================================================================
  # B. scrape_tournament — Happy Path (VCR-abgesichert)
  # ===========================================================================

  test "scrape_tournament processes tournament detail page" do
    with_vcr_cassette("umb/scraper_v2_tournament") do
      result = @scraper.scrape_tournament(KNOWN_TOURNAMENT_EXTERNAL_ID)

      # Charakterisiert den Rueckgabewert: nil oder InternationalTournament.
      # Nach der Aufnahme wird eine InternationalTournament-Instanz erwartet.
      assert_not_nil result, "scrape_tournament soll bei vorhandener Seite kein nil zurueckgeben"
      assert_instance_of InternationalTournament, result
      assert result.persisted?, "Tournament muss gespeichert sein"

      # Pflichtfelder
      assert_not_nil result.title, "title muss vorhanden sein"
      assert_not_nil result.date, "date muss vorhanden sein"
      assert_equal KNOWN_TOURNAMENT_EXTERNAL_ID.to_s, result.external_id
      assert_equal @scraper.umb_source, result.international_source
    end
  end

  # ===========================================================================
  # C. scrape_tournament — Fehlerbehandlung (WebMock-Stubs, kein VCR)
  # ===========================================================================

  test "scrape_tournament returns nil for non-existent tournament ID" do
    # UMB liefert bei unbekannter ID eine leere oder minimalste HTML-Antwort.
    # Charakterisiert: scrape_tournament gibt nil zurueck wenn HTML zu kurz ist.
    stub_url = "https://files.umb-carom.org/public/TournametDetails.aspx?ID=999999"
    stub_request(:get, stub_url).to_return(
      status: 200,
      body: "<html><body>Not found</body></html>",
      headers: { "Content-Type" => "text/html" }
    )

    result = @scraper.scrape_tournament(999_999)
    assert_nil result, "scrape_tournament soll nil zurueckgeben wenn HTML zu kurz ist (< 500 Zeichen)"
  end

  test "scrape_tournament handles network error gracefully" do
    # Netzwerkfehler duerfen nicht als Exception propagiert werden.
    # Charakterisiert: fetch_url fangt StandardError ab und gibt nil zurueck.
    stub_url = "https://files.umb-carom.org/public/TournametDetails.aspx?ID=777"
    stub_request(:get, stub_url).to_timeout

    assert_nothing_raised do
      result = @scraper.scrape_tournament(777)
      assert_nil result, "scrape_tournament soll bei Timeout nil zurueckgeben"
    end
  end

  test "scrape_tournament handles HTTP 404 gracefully" do
    # HTTP-Fehlerantworten: scrape_tournament gibt nil zurueck.
    stub_url = "https://files.umb-carom.org/public/TournametDetails.aspx?ID=404"
    stub_request(:get, stub_url).to_return(
      status: 404,
      body: "Not Found",
      headers: {}
    )

    result = @scraper.scrape_tournament(404)
    assert_nil result, "scrape_tournament soll bei 404 nil zurueckgeben"
  end

  test "scrape_tournament handles HTTP 500 gracefully" do
    # Server-Fehler: scrape_tournament gibt nil zurueck.
    stub_url = "https://files.umb-carom.org/public/TournametDetails.aspx?ID=500"
    stub_request(:get, stub_url).to_return(
      status: 500,
      body: "Internal Server Error",
      headers: {}
    )

    result = @scraper.scrape_tournament(500)
    assert_nil result, "scrape_tournament soll bei 500 nil zurueckgeben"
  end
end
