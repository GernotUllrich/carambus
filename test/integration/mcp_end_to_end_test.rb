# frozen_string_literal: true

require "test_helper"

# v0.3 Plan 13-06 (D-13-01-D Multi-User-Hosting): End-to-End-Integration-Test
# für den vollständigen HTTP-MCP-Stack:
#   Devise-Auth → McpController → server_context → Tool → AuditTrail-DB-Entry.
#
# Boundary: 0 Live-CC-Writes — CARAMBUS_MCP_MOCK=1 + AuditTrail.write_entry direkt.
class McpEndToEndTest < ActionDispatch::IntegrationTest
  setup do
    @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    McpServer::CcSession._client_override = nil
    McpAuditTrail.delete_all
    @sportwart = User.create!(
      email: "sportwart-e2e@test.de",
      password: "password123",



    )
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = @prev_mock
    McpAuditTrail.delete_all
  end

  test "POST /mcp tools/list mit eingeloggtem Sportwart liefert per-User-Tool-Subset" do
    sign_in @sportwart
    post "/mcp?stateless=1",
      params: {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list",
        params: {}
      }.to_json,
      headers: {"Content-Type" => "application/json", "Accept" => "application/json, text/event-stream"}
    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("result"), "tools/list-Response sollte result-Key haben"
    tools = body.dig("result", "tools") || []
    assert tools.is_a?(Array)
    assert tools.size > 0, "Sportwart sollte mehr als 0 Tools sehen"
  end

  test "POST /mcp initialize → result-Schema mit protocolVersion/capabilities/serverInfo" do
    sign_in @sportwart
    post "/mcp?stateless=1",
      params: {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {protocolVersion: "2025-03-26", capabilities: {}, clientInfo: {name: "e2e", version: "0"}}
      }.to_json,
      headers: {"Content-Type" => "application/json", "Accept" => "application/json, text/event-stream"}
    assert_response :success
    body = JSON.parse(response.body)
    assert body["result"].is_a?(Hash), "initialize-Response sollte result-Hash haben"
    assert body.dig("result", "protocolVersion").present?
    assert body.dig("result", "serverInfo").present?
  end

  test "AuditTrail-DB-Entry wird geschrieben wenn Tool armed:true mit user_id aufgerufen wird" do
    # Direkter Tool-Aufruf — verifiziert user_id-Propagation durch AuditTrail.write_entry.
    # HTTP-Tool-Call-Dispatch ist durch test/controllers/mcp_controller_test.rb (Plan 13-03)
    # bereits gecovered; hier fokussieren wir auf den DATA-FLOW (DB-Persistenz pro User).
    before_count = McpAuditTrail.count
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament",
      operator: "mock-admin",
      payload: {meldeliste_cc_id: 1310, player_cc_id: 99999, armed: true},
      pre_validation_results: [],
      read_back_status: "match",
      result: "success",
      user_id: @sportwart.id
    )
    assert_equal before_count + 1, McpAuditTrail.count
    last = McpAuditTrail.order(:created_at).last
    assert_equal @sportwart.id, last.user_id
    assert_equal "cc_register_for_tournament", last.tool_name
    assert_equal true, last.payload["armed"]
  end

  # Plan 14-G.2 / D-14-G6: Per-User-Tool-Subset-Test gelöscht (ALL_TOOLS für alle authenticated User;
  # Per-Record-Authority via BaseTool.authorize! in 14-G.4 Tool-Refactor).

  test "POST /mcp ohne Auth (kein Cookie, kein Bearer) liefert 401" do
    post "/mcp?stateless=1",
      params: {jsonrpc: "2.0", id: 1, method: "tools/list", params: {}}.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream"
      }

    assert_response :unauthorized
  end

  test "POST /mcp mit invalidem Bearer-JWT liefert 401" do
    post "/mcp?stateless=1",
      params: {jsonrpc: "2.0", id: 1, method: "tools/list", params: {}}.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream",
        "Authorization" => "Bearer invalid.token.string"
      }

    assert_response :unauthorized
  end

  test "Bearer-JWT-Auth funktioniert auch nach sign_out via JTI-Revocation" do
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(@sportwart, :user, nil)

    # Erst-Call: Token valid → 200
    post "/mcp?stateless=1",
      params: {jsonrpc: "2.0", id: 1, method: "tools/list", params: {}}.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream",
        "Authorization" => "Bearer #{token}"
      }
    assert_response :success

    # Force-Revoke via JTIMatcher (analog DELETE /users/sign_out)
    User.revoke_jwt({"jti" => extract_jti(token), "sub" => @sportwart.id.to_s}, @sportwart)
    @sportwart.reload

    # Re-Call mit revoked Token → 401
    post "/mcp?stateless=1",
      params: {jsonrpc: "2.0", id: 1, method: "tools/list", params: {}}.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json, text/event-stream",
        "Authorization" => "Bearer #{token}"
      }
    assert_response :unauthorized
  end

  private

  def extract_jti(token)
    payload = JWT.decode(token, nil, false).first
    payload["jti"]
  end
end
