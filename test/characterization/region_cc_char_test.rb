# frozen_string_literal: true

require "test_helper"

# Characterization tests for RegionCc sync operations.
# VCR-Kassetten zeichnen echte ClubCloud-API-Antworten auf.
# Erster Lauf: echte API erforderlich. Danach: Offline via Kassetten.
#
# AUFNAHME-ANLEITUNG (VCR-Kassetten einmalig aufnehmen):
#
#   1. Stelle sicher, dass ClubCloud-Credentials in config/credentials/test.yml.enc vorhanden sind.
#      Pruefen: RAILS_ENV=test bin/rails runner "puts RegionCc.first&.base_url"
#
#   2. Starte die Aufnahme gegen die echte API:
#      RECORD_VCR=true bin/rails test test/characterization/region_cc_char_test.rb
#
#   3. Pruefe, dass die Kassetten erstellt wurden:
#      ls test/snapshots/vcr/region_cc_*.yml
#
#   4. Lauf ohne RECORD_VCR zur Verifikation (Replay-Modus):
#      bin/rails test test/characterization/region_cc_char_test.rb
#
# OHNE API-ZUGANG:
#   Tests ohne VCR-Kassetten (offline, kein RECORD_VCR) laufen durch, solange sie
#   kein echtes HTTP benoetigen. VCR-Tests die Kassetten erfordern werden uebersprungen
#   bis Kassetten aufgezeichnet wurden.
#
class RegionCcCharTest < ActiveSupport::TestCase
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
      skip "VCR-Kassette '#{name}.yml' fehlt. Aufnehmen mit: RECORD_VCR=true bin/rails test test/characterization/region_cc_char_test.rb"
    end
    VCR.use_cassette(name, record: VCR_RECORD_MODE, &block)
  end

  # ---------------------------------------------------------------------------
  # Setup: Minimale RegionCc-Instanz fuer HTTP-Tests
  # ---------------------------------------------------------------------------
  # Verwendet fixtures(:nbv) als Region-Referenz, da region_id NOT NULL sein muss.
  # base_url: Echte club-cloud.de Subdomain — wird durch VCR-Kassette abgefangen.
  # username/userpw: Werden von VCR-Konfiguration in vcr_setup.rb herausgefiltert.

  setup do
    @region = regions(:nbv)
    @region_cc = RegionCc.create!(
      region: @region,
      name: "NBV ClubCloud (Test)",
      shortname: "nbv",
      context: "nbv",
      cc_id: 20,
      base_url: "https://e12112e2454d41f1824088919da39bc0.club-cloud.de",
      username: "test_user",
      userpw: "test_password"
    )
  end

  teardown do
    @region_cc.destroy if @region_cc.persisted?
  end

  # ===========================================================================
  # A. HTTP-Methoden — Grundlegende Transportschicht
  # ===========================================================================

  test "get_cc raises ArgumentError for unknown action" do
    # Dokumentiert: get_cc validiert action gegen PATH_MAP und wirft ArgumentError
    assert_raises(ArgumentError) do
      @region_cc.get_cc("unknown_action_xyz")
    end
  end

  test "post_cc dry_run returns [nil, nil] for write action without :armed" do
    # Dokumentiert: post_cc mit write-only-Action und ohne armed: true ist ein Dry-Run.
    # PATH_MAP["createLeagueSave"] hat read_only: false → dry_run verhindert echten Request.
    # Rueckgabewert: [nil, nil] da doc und res nur bei echtem Request gesetzt werden.
    result = @region_cc.post_cc("createLeagueSave", { fedId: @region_cc.cc_id })
    assert_kind_of Array, result
    res, doc = result
    assert_nil res, "Dry-Run darf keinen echten HTTP-Request senden (res muss nil sein)"
    assert_nil doc, "Dry-Run darf kein Dokument zurueckgeben (doc muss nil sein)"
  end

  test "get_cc sends GET request and returns [res, doc] tuple" do
    with_vcr_cassette("region_cc_http_get") do
      result = @region_cc.get_cc("showLeagueList", {
        fedId: @region_cc.cc_id,
        branchId: 6,
        subBranchId: 1,
        seasonId: 8
      })
      assert_kind_of Array, result
      assert_equal 2, result.length
      _res, doc = result
      assert_kind_of Nokogiri::HTML::Document, doc
    end
  end

  test "post_cc returns [res, doc] tuple for read-only action" do
    with_vcr_cassette("region_cc_http_post") do
      result = @region_cc.post_cc("showLeagueList", {
        fedId: @region_cc.cc_id,
        branchId: 6,
        subBranchId: 1,
        seasonId: 8
      })
      assert_kind_of Array, result
      assert_equal 2, result.length
      _res, doc = result
      assert_kind_of Nokogiri::HTML::Document, doc
    end
  end

  # ===========================================================================
  # B. League-Sync Tests
  # ===========================================================================

  test "sync_leagues returns [array, error_string] for unknown season" do
    # Dokumentiert: sync_leagues hat rescue StandardError am Ende.
    # ArgumentError fuer unbekannte Saison wird abgefangen → [[], error_string].
    # Echtes Verhalten: kein propagierter Exception — stiller Fehlerpfad.
    leagues, err = @region_cc.sync_leagues(
      context: "nbv",
      season_name: "9999/0000",
      exclude_league_ba_ids: []
    )
    assert_kind_of Array, leagues
    assert_empty leagues
    assert_kind_of String, err
    assert err.include?("9999/0000"), "Fehlermeldung soll season_name enthalten: #{err}"
  end

  test "sync_leagues returns [array, error_string] when DBU region missing in test env" do
    # Dokumentiert: sync_leagues ruft Region.find_by_shortname("DBU").id auf (Zeile 1890).
    # In Tests fehlt DBU-Fixture → NoMethodError wird durch rescue StandardError abgefangen.
    # Rueckgabe: [[], "undefined method 'id' for nil:NilClass"] statt Exception.
    leagues, err = @region_cc.sync_leagues(
      context: "nbv",
      season_name: Season.first&.name || "2024/2025",
      exclude_league_ba_ids: []
    )
    assert_kind_of Array, leagues
    assert_kind_of String, err
    assert err.present?, "Fehlermeldung muss vorhanden sein (DBU-Region fehlt in Test-Fixtures)"
  end

  test "sync_league_teams_new returns truthy value when error is silently rescued" do
    # Dokumentiert: sync_league_teams_new hat rescue StandardError => e der ALLE Fehler abfaengt.
    # Bei fehlendem DBU-Fixtures ODER unbekannter Saison: Exception gelogged, gibt Logger#error Rueckgabe zurueck.
    # WICHTIG: kein Exception propagiert trotz ArgumentError/NoMethodError intern.
    result = @region_cc.sync_league_teams_new(
      context: "nbv",
      season_name: "9999/0000",
      exclude_league_ba_ids: []
    )
    # rescue gibt Logger#error Rueckgabewert (true) zurueck — kein Exception
    assert_not_nil result
  end

  test "sync_league_teams_new returns truthy value when portal region missing in test env" do
    # Dokumentiert: sync_league_teams_new ruft Region.find_by_shortname("portal").id auf.
    # In Tests: NoMethodError → rescue StandardError → Logger#error → returns true.
    result = @region_cc.sync_league_teams_new(
      context: "nbv",
      season_name: Season.first&.name || "2024/2025",
      exclude_league_ba_ids: []
    )
    assert_not_nil result
  end

  test "sync_league_plan raises NoMethodError when League class requires DBU region" do
    # Dokumentiert: sync_league_plan hat KEINEN rescue wrapper.
    # League::DBU_ID = Region.find_by_shortname("DBU").id (league.rb:68) schlaegt fehl
    # wenn DBU-Region in Tests fehlt → NoMethodError propagiert.
    # Dies ist eine bekannte Test-Einschraenkung: sync_league_plan benoetigt DBU-Fixture.
    assert_raises(NoMethodError) do
      @region_cc.sync_league_plan(
        context: "nbv",
        season_name: Season.first&.name || "2024/2025",
        exclude_league_ba_ids: []
      )
    end
  end

  # ===========================================================================
  # C. Tournament-Sync Tests
  # ===========================================================================

  test "sync_tournaments returns [array, error_string] for unknown season" do
    # Dokumentiert: sync_tournaments hat rescue StandardError => e am Ende.
    # ArgumentError fuer unbekannte Saison wird abgefangen → [[], error_string].
    # Dies ist das ECHTE Verhalten (kein propagierter Exception).
    tournaments, err = @region_cc.sync_tournaments(
      context: "nbv",
      season_name: "9999/0000"
    )
    assert_kind_of Array, tournaments
    assert_empty tournaments
    assert_kind_of String, err
    assert err.present?, "Fehlermeldung muss vorhanden sein"
  end

  test "sync_tournaments returns [tournaments_array, nil] on success" do
    with_vcr_cassette("region_cc_sync_tournaments") do
      tournaments, err = @region_cc.sync_tournaments(
        context: "nbv",
        season_name: Season.first&.name || "2024/2025"
      )
      assert_kind_of Array, tournaments
      assert_nil err, "Kein Fehler erwartet bei erfolgreichem sync_tournaments"
    end
  end

  test "fix_tournament_structure runs without raising for valid season" do
    with_vcr_cassette("region_cc_fix_tournament") do
      # Mit leerer DB: kein Tournament gefunden, kein HTTP-Request
      assert_nothing_raised do
        @region_cc.fix_tournament_structure(
          context: "nbv",
          season_name: Season.first&.name || "2024/2025",
          exclude_tournament_ba_ids: []
        )
      end
    end
  end

  # ===========================================================================
  # D. Party/Game-Sync Tests
  # ===========================================================================

  test "sync_parties returns [parties, party_ccs] tuple" do
    with_vcr_cassette("region_cc_sync_parties") do
      # Mit leerer DB und context: nbv: kein BranchCc vorhanden → leere Arrays
      result = @region_cc.sync_parties(
        context: "nbv",
        season_name: Season.first&.name || "2024/2025"
      )
      assert_kind_of Array, result
      assert_equal 2, result.length, "sync_parties muss [parties, party_ccs] zurueckgeben"
      parties, party_ccs = result
      assert_kind_of Array, parties
      assert_kind_of Array, party_ccs
    end
  end

  test "sync_party_games runs without raising for empty parties list" do
    # Dokumentiert: sync_party_games mit leerer Liste: kein Fehler, kein HTTP-Request
    assert_nothing_raised do
      @region_cc.sync_party_games([], context: "nbv")
    end
  end

  test "sync_game_details runs without raising for valid context" do
    with_vcr_cassette("region_cc_sync_game_details") do
      # Mit leerer DB: kein BranchCc, kein HTTP-Request
      assert_nothing_raised do
        @region_cc.sync_game_details(
          context: "nbv",
          season_name: Season.first&.name || "2024/2025",
          exclude_league_ba_ids: [],
          exclude_season_names: []
        )
      end
    end
  end

  # ===========================================================================
  # E. Admin URL Discovery Tests
  # ===========================================================================

  test "ensure_admin_base_url! returns base_url when already valid club-cloud.de URL" do
    # Dokumentiert: fruehes Return wenn base_url bereits club-cloud.de und nicht ndbv.de
    result = @region_cc.ensure_admin_base_url!
    assert_equal @region_cc.base_url, result
  end

  test "ensure_admin_base_url! returns a URL when base_url contains ndbv.de" do
    with_vcr_cassette("region_cc_discover_admin_url") do
      # Simuliere ungueltige base_url: Methode versucht Discovery vom public site
      @region_cc.base_url = "https://www.ndbv.de"
      result = @region_cc.ensure_admin_base_url!
      assert result.present?, "ensure_admin_base_url! muss eine URL zurueckgeben"
      assert result.include?("club-cloud.de") || result.start_with?("https://"),
             "Rueckgabe muss gueltige URL sein, bekommen: #{result}"
    end
  end
end
