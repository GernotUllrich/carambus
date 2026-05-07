# frozen_string_literal: true
require "test_helper"

class McpServer::CcSessionTest < ActiveSupport::TestCase
  setup do
    @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    @prev_user = ENV["CC_USERNAME"]
    @prev_pw   = ENV["CC_PASSWORD"]
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
    doc = Nokogiri::HTML('<html><body><table>data</table></body></html>')
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
end
