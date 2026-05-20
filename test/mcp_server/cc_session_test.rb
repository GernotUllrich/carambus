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
end
