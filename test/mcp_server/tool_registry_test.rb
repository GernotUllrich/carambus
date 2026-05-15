# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/tool_registry"
require_relative "../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# MCP Multi-User-Hosting (v0.3, Plan 13-02) — Phase-13-Per-Role-Tool-Subsets gedroppt durch D-14-G6.
# Tests skip-markiert — Restore in Plan 14-G.2 (Authority-Layer-Refactor mit Sportwart/TL-Authority-Check).
class McpServer::ToolRegistryTest < ActiveSupport::TestCase
  test "tools_for(nil) liefert leeres Array (defensive Default)" do
    assert_equal [], McpServer::ToolRegistry.tools_for(nil)
  end

  test "tools_for(user) liefert Array entsprechend user.mcp_role" do
    skip "Pending 14-G.2 (D-14-G6: mcp_role gedroppt; Stub gibt allen Usern ALL_TOOLS)"
  end

  test "tool_count_for(nil) = 0 + unbekannte Rolle = 0" do
    skip "Pending 14-G.2: Stub-tool_count_for ignoriert role_key und gibt immer ALL_TOOLS.size zurück"
  end

  test "tool_count_for(:mcp_public_read) = 16 (Read-Tools-Count)" do
    skip "Pending 14-G.2 (D-14-G6: Per-Role-Counts entfallen; neue Authority-basierte Counts in 14-G.2)"
  end

  test "tool_classes_for(user) resolved zu McpServer::Tools::*-Klassen erbend von BaseTool" do
    skip "Pending 14-G.2: tool_classes_for-Detail-Test ohne mcp_role obsolet; neue Authority-Klassen-Resolution in 14-G.2"
  end

  # NEUER Stub-Smoketest für 14-G.1-Stub: jeder nicht-nil User bekommt ALL_TOOLS-Liste.
  test "tools_for(any_authenticated_user) liefert ALL_TOOLS (14-G.1-Stub-Verhalten)" do
    u = User.new(email: "tr-stub@example.com", password: "password123")
    tools = McpServer::ToolRegistry.tools_for(u)
    assert_equal McpServer::RoleToolMap::ALL_TOOLS, tools,
      "Stub-Verhalten: jeder authentifizierte User bekommt ALL_TOOLS"
  end
end
