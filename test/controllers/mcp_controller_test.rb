# frozen_string_literal: true

require "test_helper"

# Integration-Tests für McpController (v0.3 Plan 13-03).
# Testet Devise-Auth + Per-User-Tool-Subset + Stateless-Optional-Flag + server_context-Init.
class McpControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @public_read_user = User.create!(
      email: "mcp_public@example.com", password: "password123",
      mcp_role: :mcp_public_read
    )
    # Plan 14-02.1-fix / D-14-02-G: cc_region ist Pflicht für mcp_role > public_read
    @sportwart_user = User.create!(
      email: "mcp_sport@example.com", password: "password123",
      mcp_role: :mcp_sportwart, cc_credentials: '{"username":"x","password":"y"}', cc_region: "NBV"
    )
    @admin_user = User.create!(
      email: "mcp_admin@example.com", password: "password123",
      mcp_role: :mcp_admin, cc_credentials: '{"username":"x","password":"y"}', cc_region: "NBV"
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
    sign_in @public_read_user
    post "/mcp?stateless=1", params: tools_list_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
    body = JSON.parse(response.body)
    assert body.dig("result", "tools").is_a?(Array),
      "Response erwartet result.tools-Array, got: #{body.inspect[0..300]}"
    tool_names = body.dig("result", "tools").map { |t| t["name"] }
    assert_equal 16, tool_names.size, "mcp_public_read sollte 16 Tools haben, hat: #{tool_names.size}"
    refute tool_names.any? { |n| n.include?("register") || n.include?("assign") || n.include?("finalize") },
      "mcp_public_read sollte keine Write-Tools haben, hat aber: #{tool_names.inspect}"
  end

  test "POST /mcp with mcp_admin user returns all 22 Tools" do
    sign_in @admin_user
    post "/mcp?stateless=1", params: tools_list_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 22, body.dig("result", "tools").size, "mcp_admin sollte 22 Tools haben"
  end

  test "POST /mcp with mcp_sportwart user returns 19 Tools (no cc_finalize/cc_assign/cc_remove)" do
    sign_in @sportwart_user
    post "/mcp?stateless=1", params: tools_list_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
    body = JSON.parse(response.body)
    tool_names = body.dig("result", "tools").map { |t| t["name"] }
    assert_equal 19, tool_names.size, "mcp_sportwart sollte 19 Tools haben, hat: #{tool_names.size}"
    refute tool_names.any? { |n| n.include?("finalize") || n.include?("assign") || n.include?("remove_from_teilnehmer") },
      "mcp_sportwart sollte kein cc_finalize/cc_assign/cc_remove haben, hat aber: #{tool_names.inspect}"
  end

  test "POST /mcp?stateless=1 initialisiert StreamableHTTPTransport ohne Crash" do
    sign_in @admin_user
    post "/mcp?stateless=1", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
  end

  test "POST /mcp mit Per-User-cc_region wird in server_context propagiert (Init OK)" do
    @sportwart_user.update!(cc_region: "nbv")
    sign_in @sportwart_user
    post "/mcp", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
  end

  test "POST /mcp ohne cc_credentials + mcp_role != public_read: Init funktioniert (Tool-Calls failen erst später)" do
    no_creds_user = User.create!(
      email: "mcp_nocreds@example.com", password: "password123",
      mcp_role: :mcp_sportwart, cc_region: "NBV" # KEIN cc_credentials
    )
    sign_in no_creds_user
    post "/mcp", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
  end

  # Plan 14-02.1-fix / D-14-02-G: McpController#require_user_cc_region-Guard
  test "POST /mcp mit User ohne cc_region (mcp_role > public_read) → 422 + Profile-Edit-Hinweis" do
    no_region_user = User.create!(
      email: "mcp_no_region@example.com", password: "password123",
      mcp_role: :mcp_sportwart
      # cc_region absichtlich nicht gesetzt (Profile-Edit-Hinweis-Test)
    )
    sign_in no_region_user
    post "/mcp", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal(-32602, body.dig("error", "code"))
    assert_match(/Profil hat keine Region/i, body.dig("error", "message"))
  end
end
