# frozen_string_literal: true

require "test_helper"

# Unit tests for RegionCc::ClubCloudClient
# Verifiziert: URL-Aufbau, Header, Cookies, dry_run-Logik, ArgumentError fuer unbekannte Actions.
# Alle HTTP-Anfragen werden via WebMock abgefangen — kein echtes Netzwerk.
class RegionCc::ClubCloudClientTest < ActiveSupport::TestCase
  BASE_URL = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"
  TEST_SESSION_ID = "abc123testsession"

  setup do
    @client = RegionCc::ClubCloudClient.new(
      base_url: BASE_URL,
      username: "test_user",
      userpw: "test_pass"
    )
  end

  # ---------------------------------------------------------------------------
  # Test 1: Initialisierung speichert Attribute — keine DB-Aufrufe
  # ---------------------------------------------------------------------------
  test "stores base_url, username, userpw on initialization" do
    assert_equal BASE_URL, @client.base_url
    assert_equal "test_user", @client.username
    assert_equal "test_pass", @client.userpw
  end

  # ---------------------------------------------------------------------------
  # Test 2: #get raises ArgumentError fuer unbekannte action
  # ---------------------------------------------------------------------------
  test "get raises ArgumentError for unknown action" do
    assert_raises(ArgumentError) do
      @client.get("nonexistent_action_xyz_abc")
    end
  end

  # ---------------------------------------------------------------------------
  # Test 3: #get baut korrekte URL aus PATH_MAP, setzt PHPSESSID-Cookie, gibt [response, doc] zurueck
  # ---------------------------------------------------------------------------
  test "get builds correct URL from PATH_MAP, sets PHPSESSID cookie, returns [response, doc]" do
    expected_url = "#{BASE_URL}/admin/report/showLeagueList.php"
    stub_request(:get, /showLeagueList/)
      .to_return(status: 200, body: "<html><body>League List</body></html>", headers: {"Content-Type" => "text/html"})

    res, doc = @client.get("showLeagueList", {}, {session_id: TEST_SESSION_ID})

    assert_equal "200", res.code
    assert_kind_of Nokogiri::HTML::Document, doc

    # Verify cookie was sent
    assert_requested :get, /showLeagueList/, headers: {"Cookie" => "PHPSESSID=#{TEST_SESSION_ID}"}
  end

  # ---------------------------------------------------------------------------
  # Test 4: #post setzt Content-Type, PHPSESSID-Cookie, respektiert dry_run
  # ---------------------------------------------------------------------------
  test "post sets content-type and PHPSESSID cookie" do
    stub_request(:post, /createLeagueSave/)
      .to_return(status: 200, body: "<html><body>OK</body></html>", headers: {})

    res, doc = @client.post("createLeagueSave", {fedId: 20}, {session_id: TEST_SESSION_ID, armed: "1"})

    assert_equal "200", res.code
    assert_kind_of Nokogiri::HTML::Document, doc
    assert_requested :post, /createLeagueSave/,
      headers: {
        "Cookie" => "PHPSESSID=#{TEST_SESSION_ID}",
        "Content-Type" => "application/x-www-form-urlencoded"
      }
  end

  test "post skips non-read-only action when dry_run (opts[:armed] is blank)" do
    # dry_run = opts[:armed].blank? — blank armed means skip non-read-only
    stub_request(:post, /createLeagueSave/)
      .to_return(status: 200, body: "<html></html>", headers: {})

    # No armed key = dry_run mode, createLeagueSave is NOT read-only → should skip HTTP
    res, doc = @client.post("createLeagueSave", {fedId: 20}, {session_id: TEST_SESSION_ID})

    assert_nil res
    assert_nil doc
    # No HTTP request should have been made
    assert_not_requested :post, /createLeagueSave/
  end

  test "post executes read-only action even in dry_run mode" do
    # showLeagueList is read_only: true — should execute even without armed
    stub_request(:post, /showLeagueList/)
      .to_return(status: 200, body: "<html><body>List</body></html>", headers: {})

    res, doc = @client.post("showLeagueList", {}, {session_id: TEST_SESSION_ID})

    assert_equal "200", res.code
    assert_kind_of Nokogiri::HTML::Document, doc
    assert_requested :post, /showLeagueList/
  end

  # ---------------------------------------------------------------------------
  # Test 5: #post_with_formdata verwendet Multipart, setzt PHPSESSID-Cookie, verarbeitet referer
  # ---------------------------------------------------------------------------
  test "post_with_formdata sets PHPSESSID cookie and sends multipart request" do
    stub_request(:post, /createLeagueSave/)
      .to_return(status: 200, body: "<html><body>Created</body></html>", headers: {})

    res, doc = @client.post_with_formdata(
      "createLeagueSave",
      {leagueName: "Test League"},
      {session_id: TEST_SESSION_ID, armed: "1"}
    )

    assert_equal "200", res.code
    assert_kind_of Nokogiri::HTML::Document, doc
    assert_requested :post, /createLeagueSave/,
      headers: {"Cookie" => "PHPSESSID=#{TEST_SESSION_ID}"}
  end

  test "post_with_formdata skips non-read-only action in dry_run mode" do
    stub_request(:post, /createLeagueSave/)
      .to_return(status: 200, body: "<html></html>", headers: {})

    res, doc = @client.post_with_formdata("createLeagueSave", {leagueName: "Test"}, {})

    assert_nil res
    assert_nil doc
    assert_not_requested :post, /createLeagueSave/
  end

  # ---------------------------------------------------------------------------
  # Test 6: #get_with_url akzeptiert explizite URL statt PATH_MAP-Lookup
  # ---------------------------------------------------------------------------
  test "get_with_url accepts explicit URL instead of PATH_MAP lookup" do
    custom_url = "#{BASE_URL}/some/custom/path.php"
    stub_request(:get, /custom\/path/)
      .to_return(status: 200, body: "<html><body>Custom</body></html>", headers: {})

    res, doc = @client.get_with_url("home", custom_url, {param: "value"}, {session_id: TEST_SESSION_ID})

    assert_equal "200", res.code
    assert_kind_of Nokogiri::HTML::Document, doc
    assert_requested :get, /custom\/path/
  end

  # ---------------------------------------------------------------------------
  # Test 7: PATH_MAP enthält bekannte Eintraege mit korrekten Pfaden und read_only-Flags
  # ---------------------------------------------------------------------------
  test "PATH_MAP contains known entries with correct paths and read_only flags" do
    assert_kind_of Hash, RegionCc::ClubCloudClient::PATH_MAP

    # Verify known entries: [path, read_only]
    assert_equal ["", true], RegionCc::ClubCloudClient::PATH_MAP["home"]
    assert_equal ["/admin/report/showLeagueList.php", true], RegionCc::ClubCloudClient::PATH_MAP["showLeagueList"]
    assert_equal ["/admin/league/createLeagueSave.php", false], RegionCc::ClubCloudClient::PATH_MAP["createLeagueSave"]
  end

  # ---------------------------------------------------------------------------
  # Plan 14-G.12 Task 1 — Sportwart-Cluster komplett (myclub-Pfad)
  # ---------------------------------------------------------------------------
  test "PATH_MAP contains complete sportwart cluster under /admin/myclub/meldewesen/single/" do
    # 4 Keys existieren bereits (Plan 04-04 / Plan 08-02):
    assert_equal ["/admin/myclub/meldewesen/single/cc_add.php", false],
                 RegionCc::ClubCloudClient::PATH_MAP["addPlayerToMeldeliste"]
    assert_equal ["/admin/myclub/meldewesen/single/editMeldelisteSave.php", false],
                 RegionCc::ClubCloudClient::PATH_MAP["saveMeldeliste"]
    assert_equal ["/admin/myclub/meldewesen/single/showMeldeliste.php", true],
                 RegionCc::ClubCloudClient::PATH_MAP["showCommittedMeldeliste"]
    assert_equal ["/admin/myclub/meldewesen/single/cc_remove.php", false],
                 RegionCc::ClubCloudClient::PATH_MAP["removePlayerFromMeldeliste"]

    # 2 Keys NEU (Plan 14-G.12 — Sportwart-Discovery):
    assert_equal ["/admin/myclub/meldewesen/single/showMeldelistenList.php", true],
                 RegionCc::ClubCloudClient::PATH_MAP["sportwart-showMeldelistenList"]
    assert_equal ["/admin/myclub/meldewesen/single/editMeldelisteCheck.php", true],
                 RegionCc::ClubCloudClient::PATH_MAP["sportwart-editMeldelisteCheck"]
  end

  # ---------------------------------------------------------------------------
  # Plan 14-G.12 Task 1 — Backwards-Compat: LSW-Pfade bleiben unverändert
  # ---------------------------------------------------------------------------
  test "PATH_MAP keeps LSW paths unchanged (no Plan 14-G.12 regression)" do
    # LSW-Pfade (/admin/einzel/meldelisten/) sind für Verbandsadministrator-Operationen
    # (z.B. Plan-06-03 Meldeschluss-Verschiebung); Sportwart-Pfade
    # (/admin/myclub/meldewesen/single/) sind die parallele Club-scoped Variante.
    assert_equal ["/admin/einzel/meldelisten/showMeldelistenList.php", true],
                 RegionCc::ClubCloudClient::PATH_MAP["showMeldelistenList"]
    assert_equal ["/admin/einzel/meldelisten/editMeldelisteCheck.php", false],
                 RegionCc::ClubCloudClient::PATH_MAP["editMeldelisteCheck"]
  end

  # ---------------------------------------------------------------------------
  # Test 8: Keine ActiveRecord-Referenzen in der Klasse
  # ---------------------------------------------------------------------------
  test "ClubCloudClient has no ActiveRecord references" do
    source = File.read(Rails.root.join("app/services/region_cc/club_cloud_client.rb"))

    # These patterns indicate AR coupling
    refute_match(/ApplicationRecord/, source)
    refute_match(/belongs_to|has_many|has_one/, source)
    refute_match(/\.find\b|\.find_by\b|\.where\b|\.create\b|\.save\b/, source)
    refute_match(/ActiveRecord/, source)
  end

  # ---------------------------------------------------------------------------
  # Bonus: referer wird korrekt mit base_url vorangestellt
  # ---------------------------------------------------------------------------
  test "post sets referer header with base_url prepended" do
    stub_request(:post, /createLeagueSave/)
      .to_return(status: 200, body: "<html></html>", headers: {})

    @client.post(
      "createLeagueSave",
      {referer: "/admin/some/page.php", fedId: 20},
      {session_id: TEST_SESSION_ID, armed: "1"}
    )

    assert_requested :post, /createLeagueSave/,
      headers: {"Referer" => "#{BASE_URL}/admin/some/page.php"}
  end
end
