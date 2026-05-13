# frozen_string_literal: true

require "test_helper"

# v0.3 Plan 13-06 (D-13-01-D Multi-User-Filtering): Integration-Test für
# Multi-User-Audit-Trail-Filtering via McpAuditTrail-Scopes.
# Verifiziert dass 2 User mit verschiedenen mcp_role/cc_region keine
# AuditTrail-Cross-Contamination haben.
class McpMultiUserAuditTest < ActionDispatch::IntegrationTest
  setup do
    @prev_mock = ENV["CARAMBUS_MCP_MOCK"]
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    McpServer::CcSession._client_override = nil
    McpAuditTrail.delete_all
    @sportwart = User.create!(
      email: "mu-sportwart@test.de",
      password: "password123",
      mcp_role: :mcp_sportwart,
      cc_region: "BVBW",
      cc_credentials: '{"username":"sw","password":"y"}'
    )
    @turnierleiter = User.create!(
      email: "mu-tl@test.de",
      password: "password123",
      mcp_role: :mcp_turnierleiter,
      cc_region: "NBV",
      cc_credentials: '{"username":"tl","password":"y"}'
    )
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = @prev_mock
    McpAuditTrail.delete_all
  end

  test "2 User schreiben AuditTrails → for_user-Scope trennt sauber pro user_id" do
    2.times do |i|
      McpServer::AuditTrail.write_entry(
        tool_name: "cc_register_for_tournament",
        operator: "mock-cc",
        payload: {iter: i, armed: true},
        pre_validation_results: [],
        read_back_status: "match",
        result: "success",
        user_id: @sportwart.id
      )
    end
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_assign_player_to_teilnehmerliste",
      operator: "mock-cc",
      payload: {armed: true},
      pre_validation_results: [],
      read_back_status: "match",
      result: "success",
      user_id: @turnierleiter.id
    )

    sw_entries = McpAuditTrail.for_user(@sportwart)
    tl_entries = McpAuditTrail.for_user(@turnierleiter)
    assert_equal 2, sw_entries.count, "Sportwart sollte 2 AuditTrails haben"
    assert_equal 1, tl_entries.count, "Turnierleiter sollte 1 AuditTrail haben"
    assert sw_entries.all? { |e| e.user_id == @sportwart.id }, "for_user darf keinen Turnierleiter-Entry zurückgeben"
    assert tl_entries.all? { |e| e.user_id == @turnierleiter.id }, "for_user darf keinen Sportwart-Entry zurückgeben"
  end

  test "armed_writes-Scope filtert payload[armed]=true cross-user" do
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament", operator: "x",
      payload: {armed: true}, pre_validation_results: [],
      read_back_status: "match", result: "success", user_id: @sportwart.id
    )
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament", operator: "x",
      payload: {armed: false}, pre_validation_results: [],
      read_back_status: nil, result: "dry-run", user_id: @sportwart.id
    )
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_assign_player_to_teilnehmerliste", operator: "x",
      payload: {armed: true}, pre_validation_results: [],
      read_back_status: "match", result: "success", user_id: @turnierleiter.id
    )

    armed = McpAuditTrail.armed_writes
    assert_equal 2, armed.count, "armed_writes muss genau die 2 armed:true-Entries finden"
    assert armed.all? { |e| e.payload["armed"] == true }
  end

  test "for_user kombinierbar mit armed_writes (composable scopes)" do
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament", operator: "x",
      payload: {armed: true}, pre_validation_results: [],
      read_back_status: "match", result: "success", user_id: @sportwart.id
    )
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_register_for_tournament", operator: "x",
      payload: {armed: false}, pre_validation_results: [],
      read_back_status: nil, result: "dry-run", user_id: @sportwart.id
    )
    McpServer::AuditTrail.write_entry(
      tool_name: "cc_assign", operator: "x",
      payload: {armed: true}, pre_validation_results: [],
      read_back_status: "match", result: "success", user_id: @turnierleiter.id
    )

    sw_armed = McpAuditTrail.for_user(@sportwart).armed_writes
    assert_equal 1, sw_armed.count, "Sportwart hat 1 armed:true Entry"
    assert_equal "cc_register_for_tournament", sw_armed.first.tool_name
  end
end
