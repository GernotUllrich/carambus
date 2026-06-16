# frozen_string_literal: true

require "test_helper"

class McpServer::CcSessionTest < ActiveSupport::TestCase
  setup do
    @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    @prev_user = ENV["CC_USERNAME"]
    @prev_pw = ENV["CC_PASSWORD"]
    McpServer::CcSession.reset!
    McpServer::CcSession._client_override = nil
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = @prev_mock
    ENV["CC_USERNAME"] = @prev_user
    ENV["CC_PASSWORD"] = @prev_pw
    McpServer::CcSession.reset!
  end

  test "production + mock-mode raises (failsafe per D-08)" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises(RuntimeError, /Mock mode not allowed in production/) do
        McpServer::CcSession.client_for
      end
    end
  end

  test "mock-mode in test env returns MockClient" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    client = McpServer::CcSession.client_for
    assert_instance_of McpServer::Tools::MockClient, client
  end

  test "missing CC_USERNAME and CC_PASSWORD: client_for darf ENV-frei booten (Login läuft über Setting.login_to_cc)" do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    ENV["CC_USERNAME"] = nil
    ENV["CC_PASSWORD"] = nil
    client = nil
    assert_nothing_raised do
      client = McpServer::CcSession.client_for
    end
    assert_instance_of RegionCc::ClubCloudClient, client
    assert_nil client.username, "username should be nil — Setting.login_to_cc holt Credentials aus Rails Credentials"
    assert_nil client.userpw, "userpw should be nil — siehe oben"
  end

  test "TTL: cookie_expired? nach 35 Minuten" do
    assert McpServer::CcSession.cookie_expired?(Time.now - 35 * 60)
    refute McpServer::CcSession.cookie_expired?(Time.now - 5 * 60)
    assert McpServer::CcSession.cookie_expired?(nil)
  end

  test "mock-mode cookie gibt MOCK_SESSION_ID zurück und setzt session_started_at" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    token = McpServer::CcSession.cookie
    assert_equal "MOCK_SESSION_ID", token
    assert_in_delta Time.now.to_i, McpServer::CcSession.session_started_at.to_i, 5
  end

  test "reauth_if_needed! gibt true zurück wenn Doc Login-Redirect-Formular enthält" do
    doc = Nokogiri::HTML('<html><body><form action="/login.php"><input name="username"></form></body></html>')
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    assert McpServer::CcSession.reauth_if_needed!(doc)
  end

  test "reauth_if_needed! gibt false zurück bei normaler Response" do
    doc = Nokogiri::HTML("<html><body><table>data</table></body></html>")
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    refute McpServer::CcSession.reauth_if_needed!(doc)
  end

  test "TTL-Ablauf löst transparenten Re-Login aus" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    first = McpServer::CcSession.cookie
    McpServer::CcSession.session_started_at = Time.now - 31 * 60
    second = McpServer::CcSession.cookie
    assert_in_delta Time.now.to_i, McpServer::CcSession.session_started_at.to_i, 5
    assert_equal first, second  # Mock-Token ist stabil
  end

  # v0.3 Plan 13-04.1 (D-13-04-A teilweise): server_context-Routing-Tests
  # ---------------------------------------------------------------------
  # Verifizieren dass CcSession.client_for + region_cc_base_url server_context propagieren.
  # v0.3-Pilot-Boundary: Login-Flow (Setting.login_to_cc) bleibt single-Admin-global;
  # diese Tests adressieren NUR die base_url-Routing-Schicht.

  test "client_for: mock_mode bypassed server_context (gibt immer MockClient)" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    client = McpServer::CcSession.client_for({cc_region: "BVBW"})
    assert_instance_of McpServer::Tools::MockClient, client
  end

  test "region_cc_base_url: server_context Vorrang vor ENV (via effective_cc_region)" do
    prev = ENV["CC_REGION"]
    ENV["CC_REGION"] = "nbv"
    # Mit server_context cc_region=BVBW → region_cc_base_url soll für BVBW resolved werden
    bvbw_url = McpServer::CcSession.region_cc_base_url({cc_region: "BVBW"})
    nbv_url = McpServer::CcSession.region_cc_base_url({cc_region: "NBV"})
    # Defensive: jede region_cc_base_url ist entweder String oder nil — kein Crash
    assert(bvbw_url.is_a?(String) || bvbw_url.nil?)
    assert(nbv_url.is_a?(String) || nbv_url.nil?)
    # Falls beide Regions in DB existieren und unterschiedliche base_urls haben, müssen sie sich unterscheiden
    if bvbw_url && nbv_url
      refute_equal bvbw_url, nbv_url, "BVBW und NBV müssen unterschiedliche region_cc.base_url haben"
    end
  ensure
    ENV["CC_REGION"] = prev
  end

  test "region_cc_base_url: nil server_context fällt auf ENV/Setting (Backwards-Compat)" do
    prev = ENV["CC_REGION"]
    ENV["CC_REGION"] = "nbv"
    # ohne server_context → effective_cc_region nutzt ENV "nbv" → "NBV"
    result = McpServer::CcSession.region_cc_base_url(nil)
    # Defensive: String oder nil; kein Crash (Backwards-Compat-Floor)
    assert(result.is_a?(String) || result.nil?)
  ensure
    ENV["CC_REGION"] = prev
  end

  test "client_for: unbekannte Region → Fallback auf Carambus.config.cc_base_url (kein Crash)" do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    # Region "ZZZ-NONEXISTENT" → Region.find_by → nil → region_cc_base_url returns nil → Fallback Carambus.config
    client = nil
    assert_nothing_raised do
      client = McpServer::CcSession.client_for({cc_region: "ZZZ-NONEXISTENT"})
    end
    assert_instance_of RegionCc::ClubCloudClient, client
  end

  test "client_for: server_context.cc_region propagiert in region_cc_base_url-Call" do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    captured = nil
    # Override region_cc_base_url temporär um Param-Propagation zu verifizieren
    McpServer::CcSession.singleton_class.send(:alias_method, :_orig_region_cc_base_url, :region_cc_base_url)
    begin
      McpServer::CcSession.singleton_class.send(:define_method, :region_cc_base_url) do |ctx|
        captured = ctx
        "https://test-bvbw.example.org"
      end
      McpServer::CcSession.client_for({cc_region: "BVBW"})
      assert_equal({cc_region: "BVBW"}, captured, "server_context muss in region_cc_base_url propagieren")
    ensure
      McpServer::CcSession.singleton_class.send(:alias_method, :region_cc_base_url, :_orig_region_cc_base_url)
      McpServer::CcSession.singleton_class.send(:remove_method, :_orig_region_cc_base_url)
    end
  end

  # ---------------------------------------------------------------------
  # Plan 24-01 T2: Auto-Logout-Erkennung + with_session_recovery
  # ---------------------------------------------------------------------
  # Fixtures aus heutiger Live-Capture (curl gegen LSW-Endpoint mit stale-SID):
  # test/fixtures/cc/auto_logout_stub.html (499 bytes, HTTP 200 mit goOut()+sessionLogout).

  def auto_logout_fixture_body
    File.read(Rails.root.join("test/fixtures/cc/auto_logout_stub.html"))
  end

  test "session_expired?: erkennt Auto-Logout-Stub aus live-Fixture (onLoad goOut + sessionLogout)" do
    assert McpServer::CcSession.session_expired?(auto_logout_fixture_body),
      "Auto-Logout-Fixture muss als expired erkannt werden"
  end

  test "session_expired?: erkennt onLoad='goOut()' isoliert" do
    body = "<html><body onLoad='goOut()'>x</body></html>"
    assert McpServer::CcSession.session_expired?(body)
  end

  test "session_expired?: erkennt sessionLogout/index2.php-Form-Action isoliert" do
    body = %(<form action='../../../phpUtilities/sessionLogout/index2.php'></form>)
    assert McpServer::CcSession.session_expired?(body)
  end

  test "session_expired?: false bei normaler HTML-Response" do
    refute McpServer::CcSession.session_expired?("<html><body><table>data</table></body></html>")
  end

  test "session_expired?: false bei nil/blank (defensive)" do
    refute McpServer::CcSession.session_expired?(nil)
    refute McpServer::CcSession.session_expired?("")
  end

  test "session_expired?: akzeptiert Net::HTTPResponse-like Objekt mit .body" do
    stub_resp = Struct.new(:body, :code).new(auto_logout_fixture_body, "200")
    assert McpServer::CcSession.session_expired?(stub_resp)
  end

  test "session_expired?: akzeptiert Nokogiri-Doc via .to_html" do
    doc = Nokogiri::HTML(auto_logout_fixture_body)
    assert McpServer::CcSession.session_expired?(doc)
  end

  test "with_session_recovery: erfolgreicher Single-Retry bei erster Auto-Logout-Response" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"  # mock-mode: login! liefert MOCK_SESSION_ID ohne IO
    call_count = 0
    expired = Struct.new(:body, :code).new(auto_logout_fixture_body, "200")
    ok_body = "<html><body><a href='showMeldeliste.php?p=20|10|*|*|2025/2026|1312&'>x</a></body></html>"
    ok = Struct.new(:body, :code).new(ok_body, "200")

    res, doc = McpServer::CcSession.with_session_recovery do |_client, _sid|
      call_count += 1
      if call_count == 1
        [expired, Nokogiri::HTML(expired.body)]
      else
        [ok, Nokogiri::HTML(ok.body)]
      end
    end

    assert_equal 2, call_count, "Block muss genau zweimal aufgerufen werden (Original + Retry)"
    assert_equal ok, res, "Zweite (gute) Response wird zurückgegeben"
    assert_match(/1312/, doc.to_html, "Doc enthält den Pipe-Pattern-Anchor")
  end

  test "with_session_recovery: raises SessionRecoveryFailed wenn zweite Response auch Auto-Logout-Stub" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    call_count = 0
    expired = Struct.new(:body, :code).new(auto_logout_fixture_body, "200")

    assert_raises(McpServer::CcSession::SessionRecoveryFailed) do
      McpServer::CcSession.with_session_recovery do |_client, _sid|
        call_count += 1
        [expired, Nokogiri::HTML(expired.body)]
      end
    end
    assert_equal 2, call_count, "Block wird zweimal probiert, dann raise"
  end

  test "with_session_recovery: raises SessionRecoveryFailed wenn Setting.login_to_cc fehlschlägt" do
    ENV["CARAMBUS_MCP_MOCK"] = nil  # non-mock-mode: login! ruft Setting.login_to_cc
    # Pre-seed eine SID so dass erster cookie-Aufruf NICHT login! triggert
    McpServer::CcSession.session_id = "PRESEEDED_PHPSESSID_32_CHARS_xx"
    McpServer::CcSession.session_started_at = Time.now
    expired = Struct.new(:body, :code).new(auto_logout_fixture_body, "200")

    Setting.singleton_class.send(:alias_method, :_orig_login_to_cc, :login_to_cc)
    begin
      Setting.singleton_class.send(:define_method, :login_to_cc) do
        raise StandardError, "simulated CC login fail"
      end
      assert_raises(McpServer::CcSession::SessionRecoveryFailed) do
        McpServer::CcSession.with_session_recovery do |_client, _sid|
          [expired, Nokogiri::HTML(expired.body)]
        end
      end
    ensure
      Setting.singleton_class.send(:alias_method, :login_to_cc, :_orig_login_to_cc)
      Setting.singleton_class.send(:remove_method, :_orig_login_to_cc)
    end
  end

  test "with_session_recovery: gute Response beim ersten Aufruf → kein Retry, kein Re-Login" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    call_count = 0
    ok = Struct.new(:body, :code).new("<html><body>fine</body></html>", "200")

    res, _doc = McpServer::CcSession.with_session_recovery do |_client, _sid|
      call_count += 1
      [ok, Nokogiri::HTML(ok.body)]
    end

    assert_equal 1, call_count
    assert_equal ok, res
  end

  # ---------------------------------------------------------------------
  # Plan 39-02: per-CC-Account-Cache + cc_login_user (mechanism-only)
  # ---------------------------------------------------------------------
  CcAcct = McpServer::CcAccountResolver::CcAccount

  test "cookie_for: zwei verschiedene CC-Accounts → zwei unabhängige Session-Slots" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    acc_a = CcAcct.new(login_username: "sw-a", password: "pw-a", source: :own, acting_user_id: 1)
    acc_b = CcAcct.new(login_username: "sw-b", password: "pw-b", source: :own, acting_user_id: 2)
    assert_equal "MOCK_SESSION_ID", McpServer::CcSession.cookie_for(acc_a)
    assert_equal "MOCK_SESSION_ID", McpServer::CcSession.cookie_for(acc_b)
    # zwei getrennte Slots — keine gegenseitige Überschreibung
    assert_equal "sw-a", McpServer::CcSession.cc_login_user("sw-a")
    assert_equal "sw-b", McpServer::CcSession.cc_login_user("sw-b")
  end

  test "cc_login_user: liefert aktiven Account nach cookie_for, Default-Admin nach cookie" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    acc = CcAcct.new(login_username: "sw-x", password: "pw", source: :own, acting_user_id: 1)
    McpServer::CcSession.cookie_for(acc)
    assert_equal "sw-x", McpServer::CcSession.cc_login_user, "aktiver Key = sw-x"
    McpServer::CcSession.cookie # Default-Pfad → aktiver Key zurück auf Default
    assert_equal "mock-admin", McpServer::CcSession.cc_login_user
  end

  test "cookie_for: nil/blank account fällt defensiv auf Default-cookie zurück" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    assert_equal "MOCK_SESSION_ID", McpServer::CcSession.cookie_for(nil)
    blank = CcAcct.new(login_username: nil, password: nil, source: :none, acting_user_id: nil)
    assert_equal "MOCK_SESSION_ID", McpServer::CcSession.cookie_for(blank)
  end

  test "reset!(key) leert nur einen Account; reset! leert alle" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    acc_a = CcAcct.new(login_username: "ra-a", password: "p", source: :own, acting_user_id: 1)
    acc_b = CcAcct.new(login_username: "ra-b", password: "p", source: :own, acting_user_id: 2)
    McpServer::CcSession.cookie_for(acc_a)
    McpServer::CcSession.cookie_for(acc_b)
    McpServer::CcSession.reset!("ra-a")
    assert_nil McpServer::CcSession.cc_login_user("ra-a")
    assert_equal "ra-b", McpServer::CcSession.cc_login_user("ra-b")
    McpServer::CcSession.reset!
    assert_nil McpServer::CcSession.cc_login_user("ra-b")
  end

  test "with_session_recovery(account:): account-aware Single-Retry (mock)" do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    acc = CcAcct.new(login_username: "rec-sw", password: "pw", source: :own, acting_user_id: 1)
    call_count = 0
    expired = Struct.new(:body, :code).new(auto_logout_fixture_body, "200")
    ok = Struct.new(:body, :code).new("<html><body>ok</body></html>", "200")
    res, _doc = McpServer::CcSession.with_session_recovery(account: acc) do |_client, sid|
      call_count += 1
      assert_equal "MOCK_SESSION_ID", sid
      (call_count == 1) ? [expired, Nokogiri::HTML(expired.body)] : [ok, Nokogiri::HTML(ok.body)]
    end
    assert_equal 2, call_count
    assert_equal ok, res
  end
end
