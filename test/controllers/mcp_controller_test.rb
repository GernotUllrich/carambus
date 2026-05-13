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
    @sportwart_user = User.create!(
      email: "mcp_sport@example.com", password: "password123",
      mcp_role: :mcp_sportwart, cc_credentials: '{"username":"x","password":"y"}'
    )
    @admin_user = User.create!(
      email: "mcp_admin@example.com", password: "password123",
      mcp_role: :mcp_admin, cc_credentials: '{"username":"x","password":"y"}'
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
      mcp_role: :mcp_sportwart # KEIN cc_credentials
    )
    sign_in no_creds_user
    post "/mcp", params: init_payload.to_json, headers: {"Content-Type" => "application/json"}
    assert_response :success
  end
end
