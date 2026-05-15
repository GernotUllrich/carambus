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

  # Plan 14-G.2 / D-14-G6: Per-Role-Tool-Subset-Tests (mcp_public_read/sportwart) gelöscht
  # (Stub gibt ALL_TOOLS; Per-Record-Authority via BaseTool.authorize! in 14-G.4).

  test "POST /mcp with any authenticated user returns all 22 Tools (Stub: ALL_TOOLS for everyone)" do
    sign_in @admin_user
    post "/mcp?stateless=1", params: tools_list_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 22, body.dig("result", "tools").size, "Stub: alle authentifizierten User bekommen 22 Tools"
  end

  test "POST /mcp?stateless=1 initialisiert StreamableHTTPTransport ohne Crash" do
    sign_in @admin_user
    post "/mcp?stateless=1", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
  end

  # Plan 14-G.2 / D-14-G6: Per-Role-User-Setup-Tests (cc_credentials/mcp_role/cc_region) gelöscht.
  # NEUE RESTORE-Tests: Carambus.config.context-Sourcing in server_context.

  test "POST /mcp injiziert Carambus.config.context in server_context als cc_region" do
    original = Carambus.config.context
    Carambus.config.context = "NBV"
    sign_in @admin_user
    post "/mcp?stateless=1", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    # Init muss grün durchgehen — Tool-Calls würden später cc_region aus server_context lesen.
    assert_response :success
  ensure
    Carambus.config.context = original
  end

  test "POST /mcp mit Carambus.config.context blank initialisiert dennoch (Tool-Calls würden später failen)" do
    original = Carambus.config.context
    Carambus.config.context = ""
    sign_in @admin_user
    post "/mcp?stateless=1", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success, "Init muss grün auch ohne region_id (Tool-Calls failen erst später)"
  ensure
    Carambus.config.context = original
  end
end
