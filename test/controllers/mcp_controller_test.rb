# frozen_string_literal: true

require "test_helper"

# Integration-Tests für McpController (v0.3 Plan 13-03).
# Testet Devise-Auth + Per-User-Tool-Subset + Stateless-Optional-Flag + server_context-Init.
class McpControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @public_read_user = User.create!(
      email: "mcp_public@example.com", password: "password123",

    )
    # Plan 14-02.1-fix / D-14-02-G: cc_region ist Pflicht für mcp_role > public_read
    @sportwart_user = User.create!(
      email: "mcp_sport@example.com", password: "password123",

    )
    @admin_user = User.create!(
      email: "mcp_admin@example.com", password: "password123",

    )
  end

  def init_payload
    {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2025-03-26",
        capabilities: {},
        clientInfo: {name: "test-client", version: "1.0"}
      }
    }
  end

  def tools_list_payload
    {jsonrpc: "2.0", id: 2, method: "tools/list", params: {}}
  end

  test "POST /mcp without auth returns 401 (JSON-Accept)" do
    post "/mcp", params: init_payload.to_json,
      headers: {"Content-Type" => "application/json", "Accept" => "application/json"}
    assert_response :unauthorized
  end

  test "POST /mcp with authenticated mcp_public_read user returns Read-Tools-only subset (16)" do
    skip "Pending 14-G.2 (D-14-G6: mcp_role-basierte Tool-Subsets entfernt; Stub gibt ALL_TOOLS)"
  end

  test "POST /mcp with mcp_admin user returns all 22 Tools" do
    sign_in @admin_user
    post "/mcp?stateless=1", params: tools_list_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 22, body.dig("result", "tools").size, "mcp_admin sollte 22 Tools haben"
  end

  test "POST /mcp with mcp_sportwart user returns 19 Tools (no cc_finalize/cc_assign/cc_remove)" do
    skip "Pending 14-G.2 (D-14-G6: Per-Role-Tool-Subset entfernt; Authority-Check wandert in BaseTool)"
  end

  test "POST /mcp?stateless=1 initialisiert StreamableHTTPTransport ohne Crash" do
    sign_in @admin_user
    post "/mcp?stateless=1", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
  end

  test "POST /mcp mit Per-User-cc_region wird in server_context propagiert (Init OK)" do
    skip "Pending 14-G.2 (D-14-G6: users.cc_region gedroppt; Region via Carambus.config.region_id)"
  end

  test "POST /mcp ohne cc_credentials + mcp_role != public_read: Init funktioniert (Tool-Calls failen erst später)" do
    skip "Pending 14-G.2 (D-14-G6: users.cc_credentials + mcp_role gedroppt)"
  end

  test "POST /mcp mit User ohne cc_region (mcp_role > public_read) → 422 + Profile-Edit-Hinweis" do
    skip "Pending 14-G.2 (D-14-G6: require_user_cc_region-Guard entfernt; Authority-Check via Sportwart-Wirkbereich)"
  end
end
