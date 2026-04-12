# frozen_string_literal: true

require "test_helper"

# Characterization tests for UmbScraper critical paths.
# VCR-Kassetten zeichnen echte UMB-Antworten auf.
# Erster Lauf: echte API erforderlich. Danach: Offline via Kassetten.
#
# AUFNAHME-ANLEITUNG (VCR-Kassetten einmalig aufnehmen):
#
#   1. Stelle sicher, dass das Internet erreichbar ist (files.umb-carom.org).
#
#   2. Starte die Aufnahme gegen die echte API:
#      RECORD_VCR=true bin/rails test test/characterization/umb_scraper_char_test.rb
#
#   3. Pruefe, dass die Kassetten erstellt wurden:
#      ls test/snapshots/vcr/umb/
#
#   4. Lauf ohne RECORD_VCR zur Verifikation (Replay-Modus):
#      bin/rails test test/characterization/umb_scraper_char_test.rb
#
# OHNE API-ZUGANG:
#   Tests ohne VCR-Kassetten (offline, kein RECORD_VCR) laufen durch, solange sie
#   kein echtes HTTP benoetigen. VCR-Tests die Kassetten erfordern werden uebersprungen
#   bis Kassetten aufgezeichnet wurden.
#
# Kassetten werden in test/snapshots/vcr/umb/ gespeichert.
#
class UmbScraperCharTest < ActiveSupport::TestCase
  VCR_RECORD_MODE = ENV["RECORD_VCR"] ? :new_episodes : :none

  # Prueft ob eine VCR-Kassette bereits vorhanden ist.
  # Tests die echte HTTP-Antworten benoetigen werden uebersprungen wenn keine Kassette vorhanden.
  def cassette_exists?(name)
    File.exist?(Rails.root.join("test", "snapshots", "vcr", "#{name}.yml"))
  end

  # Fuehrt einen VCR-Test aus. Wenn keine Kassette vorhanden und kein RECORD_VCR gesetzt,
  # wird der Test uebersprungen (skip) statt fehlzuschlagen.
  def with_vcr_cassette(name, &block)
    if VCR_RECORD_MODE == :none && !cassette_exists?(name)
      skip "VCR-Kassette '#{name}.yml' fehlt. Aufnehmen mit: RECORD_VCR=true bin/rails test test/characterization/umb_scraper_char_test.rb"
    end
    VCR.use_cassette(name, record: VCR_RECORD_MODE, &block)
  end

  # ---------------------------------------------------------------------------
  # Setup: UmbScraper-Instanz erzeugen
  # ---------------------------------------------------------------------------
  # UmbScraper#initialize ruft find_or_create_by! auf InternationalSource auf.
  # Dies geschieht automatisch — kein extra Fixture notwendig.

  setup do
    @scraper = UmbScraper.new
  end

  # ===========================================================================
  # A. Initialisierung
  # ===========================================================================

  test "initialize creates UMB international source" do
    # Dokumentiert: initialize erstellt/findet InternationalSource mit name='Union Mondiale de Billard'
    assert_instance_of UmbScraper, @scraper
    source = InternationalSource.find_by(name: "Union Mondiale de Billard")
    assert_not_nil source, "InternationalSource fuer UMB muss nach initialize vorhanden sein"
    assert_equal "umb", source.source_type
  end

  # ===========================================================================
  # B. Discipline Detection (Pure Logic — kein HTTP)
  # ===========================================================================

  test "detect_discipline_from_name maps 3-Cushion variants to Dreiband gross" do
    # Dokumentiert: 3-Cushion und Varianten werden auf Dreiband gross gemappt (ID 31 als Fallback)
    expected_id = Discipline.find_by(name: "Dreiband groß")&.id || 31

    assert_equal expected_id, @scraper.detect_discipline_from_name("World Cup 3-Cushion Antalya")
    assert_equal expected_id, @scraper.detect_discipline_from_name("3C Championship 2024")
    assert_equal expected_id, @scraper.detect_discipline_from_name("(3C) World Cup")
    assert_equal expected_id, @scraper.detect_discipline_from_name("Three Cushion World Championship")
    assert_equal expected_id, @scraper.detect_discipline_from_name("Dreiband Weltmeisterschaft")
  end

  test "detect_discipline_from_name maps 1-Cushion to Einband gross" do
    # Dokumentiert: 1-Cushion wird auf Einband gross gemappt (ID 32 als Fallback)
    expected_id = Discipline.find_by(name: "Einband groß")&.id || 32

    assert_equal expected_id, @scraper.detect_discipline_from_name("1-Cushion World Championship")
    assert_equal expected_id, @scraper.detect_discipline_from_name("Einband WM 2024")
  end

  test "detect_discipline_from_name maps Artistique correctly" do
    # Dokumentiert: Artistique wird auf Artistique gemappt (ID 71 als Fallback)
    expected_id = Discipline.find_by(name: "Artistique")&.id || 71

    assert_equal expected_id, @scraper.detect_discipline_from_name("Artistique World Championship")
    assert_equal expected_id, @scraper.detect_discipline_from_name("Artistic Billiards 2024")
  end

  test "detect_discipline_from_name returns nil for blank name" do
    # Dokumentiert: nil Eingabe → nil Rueckgabe (fruehes Return)
    assert_nil @scraper.detect_discipline_from_name(nil)
    assert_nil @scraper.detect_discipline_from_name("")
  end

  test "detect_discipline_from_name defaults to Dreiband gross for unknown names" do
    # Dokumentiert: unbekannte Namen fallen auf Dreiband gross zurueck
    expected_id = Discipline.find_by(name: "Dreiband groß")&.id || 31
    assert_equal expected_id, @scraper.detect_discipline_from_name("Unknown Billiard Sport 2024")
  end

  # ===========================================================================
  # C. scrape_rankings — Stub
  # ===========================================================================

  test "scrape_rankings is a stub returning zero" do
    # Dokumentiert: scrape_rankings ist noch nicht implementiert — gibt immer 0 zurueck
    result = @scraper.scrape_rankings(discipline_name: "3-Cushion", year: 2024)
    assert_equal 0, result, "scrape_rankings muss 0 zurueckgeben (Stub)"
  end

  # ===========================================================================
  # D. scrape_future_tournaments (VCR)
  # ===========================================================================

  test "scrape_future_tournaments returns integer count" do
    with_vcr_cassette("umb/scraper_future_tournaments") do
      result = @scraper.scrape_future_tournaments
      assert_kind_of Integer, result, "scrape_future_tournaments muss Integer zurueckgeben"
      assert result >= 0, "Ergebnis muss >= 0 sein"
    end
  end

  # ===========================================================================
  # E. scrape_tournament_archive (VCR, kleiner ID-Bereich)
  # ===========================================================================

  test "scrape_tournament_archive processes ID range and returns integer" do
    # Kleiner Bereich (IDs 1-3) um sleep-Aufrufe (id % 10 == 0) zu vermeiden
    with_vcr_cassette("umb/scraper_archive_scan") do
      result = @scraper.scrape_tournament_archive(start_id: 1, end_id: 3, batch_size: 50)
      assert_kind_of Integer, result, "scrape_tournament_archive muss Integer zurueckgeben"
      assert result >= 0, "Ergebnis muss >= 0 sein"
    end
  end

  # ===========================================================================
  # F. fetch_tournament_basic_data (VCR)
  # ===========================================================================

  test "fetch_tournament_basic_data returns hash or nil for valid ID" do
    with_vcr_cassette("umb/scraper_basic_data") do
      # Bekannte UMB-ID (ID 1 — erster Eintrag im Archiv)
      result = @scraper.fetch_tournament_basic_data(1)
      # Dokumentiert: entweder Hash mit :name und :external_id oder nil (nicht gefunden)
      assert(result.nil? || result.is_a?(Hash),
        "fetch_tournament_basic_data muss Hash oder nil zurueckgeben, bekam: #{result.class}")
      if result.is_a?(Hash)
        assert result.key?(:external_id), "Hash muss :external_id enthalten"
        assert result.key?(:name), "Hash muss :name enthalten"
      end
    end
  end

  # ===========================================================================
  # G. scrape_tournament_details (Fixture-backed via WebMock)
  # ===========================================================================

  test "scrape_tournament_details processes detail page HTML from fixture" do
    # Hybridansatz (D-02): WebMock statt VCR fuer fixture-backed Test
    # Dies stellt sicher, dass der Test auch ohne echte UMB-Verbindung laeuft.
    fixture_html = File.read(Rails.root.join("test", "fixtures", "html", "umb_tournament_detail.html"))
    detail_url = "#{UmbScraper::TOURNAMENT_DETAILS_URL}?ID=9999"

    stub_request(:get, detail_url).to_return(
      status: 200,
      body: fixture_html,
      headers: { "Content-Type" => "text/html" }
    )

    # InternationalTournament mit passender external_id erstellen.
    # save(validate: false) umgeht Pflichtfeld-Validierungen (season, organizer)
    # die fuer Charakterisierungstests nicht relevant sind.
    source = @scraper.umb_source
    tournament = InternationalTournament.new(
      title: "Test Tournament",
      external_id: "9999",
      international_source: source,
      modus: "international",
      plan_or_show: "show",
      single_or_league: "single"
    )
    tournament.save(validate: false)

    # create_games: false und parse_pdfs: false um Nebeneffekte zu minimieren
    result = @scraper.scrape_tournament_details(tournament, create_games: false, parse_pdfs: false)

    # Dokumentiert: gibt truthy-Wert zurueck wenn Verarbeitung erfolgreich
    assert result, "scrape_tournament_details muss truthy zurueckgeben bei gueltiger HTML-Seite"

    # Ort aus Fixture-HTML wurde uebernommen
    tournament.reload
    assert_not_nil tournament.location_text, "location_text sollte aus der Detail-Seite gesetzt worden sein"
  ensure
    tournament&.destroy if tournament&.persisted?
  end

  test "scrape_tournament_details returns false when no detail URL available" do
    # Dokumentiert: gibt false zurueck wenn weder external_id noch umb_detail_url vorhanden
    source = @scraper.umb_source
    tournament = InternationalTournament.new(
      title: "Tournament Without External ID",
      international_source: source,
      modus: "international",
      plan_or_show: "show",
      single_or_league: "single"
    )
    tournament.save(validate: false)

    result = @scraper.scrape_tournament_details(tournament, create_games: false, parse_pdfs: false)
    assert_equal false, result, "scrape_tournament_details muss false zurueckgeben wenn keine URL vorhanden"
  ensure
    tournament&.destroy if tournament&.persisted?
  end

  test "scrape_tournament_details with VCR cassette" do
    with_vcr_cassette("umb/scraper_detail_page") do
      source = @scraper.umb_source
      tournament = InternationalTournament.new(
        title: "VCR Test Tournament",
        external_id: "1",
        international_source: source,
        modus: "international",
        plan_or_show: "show",
        single_or_league: "single"
      )
      tournament.save(validate: false)

      result = @scraper.scrape_tournament_details(tournament, create_games: false, parse_pdfs: false)
      # Dokumentiert: entweder truthy (Verarbeitung OK) oder false (HTTP-Fehler)
      assert(result == true || result == false || result.is_a?(InternationalTournament),
        "scrape_tournament_details muss boolean oder InternationalTournament zurueckgeben")
    ensure
      tournament&.destroy if tournament&.persisted?
    end
  end
end
