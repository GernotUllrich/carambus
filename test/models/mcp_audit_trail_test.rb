# frozen_string_literal: true

require "test_helper"

# v0.3 Plan 13-05 (D-13-01-D Multi-User-Filtering):
# McpAuditTrail Model-Tests + Scopes.
class McpAuditTrailTest < ActiveSupport::TestCase
  test "create: minimal-required Felder (Stdio-Pfad ohne user_id)" do
    entry = McpAuditTrail.create!(
      tool_name: "cc_register_for_tournament",
      operator: "unknown",
      payload: {meldeliste_cc_id: 1310, armed: true},
      result: "success"
    )
    assert entry.persisted?
    assert_nil entry.user_id
    assert_equal({"meldeliste_cc_id" => 1310, "armed" => true}, entry.payload)
  end

  test "create: mit user_id (HTTP-Pfad)" do
    user = User.create!(email: "audit-http@test.de", password: "password123",)
    entry = McpAuditTrail.create!(
      user: user,
      tool_name: "cc_register_for_tournament",
      operator: "carambus_admin",
      payload: {armed: true},
      result: "success"
    )
    assert_equal user.id, entry.user_id
    assert_equal user, entry.user
  end

  test "for_user-Scope: filtert pro User" do
    u1 = User.create!(email: "audit-u1@test.de", password: "password123",)
    u2 = User.create!(email: "audit-u2@test.de", password: "password123",)
    McpAuditTrail.create!(user: u1, tool_name: "t1", payload: {}, result: "success", operator: "x")
    McpAuditTrail.create!(user: u2, tool_name: "t1", payload: {}, result: "success", operator: "x")
    McpAuditTrail.create!(user: u1, tool_name: "t1", payload: {}, result: "success", operator: "x")

    u1_entries = McpAuditTrail.for_user(u1)
    assert_equal 2, u1_entries.count
    assert u1_entries.all? { |e| e.user_id == u1.id }
  end

  test "armed_writes-Scope: filtert armed:true via jsonb" do
    McpAuditTrail.create!(tool_name: "t_armed", payload: {armed: true}, result: "success", operator: "x")
    McpAuditTrail.create!(tool_name: "t_armed", payload: {armed: false}, result: "success", operator: "x")
    McpAuditTrail.create!(tool_name: "t_armed", payload: {}, result: "success", operator: "x")

    armed = McpAuditTrail.for_tool("t_armed").armed_writes
    assert_equal 1, armed.count
    assert_equal true, armed.first.payload["armed"]
  end
end
