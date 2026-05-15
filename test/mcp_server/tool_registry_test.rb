# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/tool_registry"
require_relative "../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Plan 14-G.2 / D-14-G6: 4 obsolete Per-Role-Tests gelöscht (mcp_role-Enum entfernt).
# Verbleibend: defensiv-nil-Test + Stub-Smoketest (14-G.1-Substrate).
# Per-Record-Authority-Check ist in BaseTool.authorize! (14-G.2).
class McpServer::ToolRegistryTest < ActiveSupport::TestCase
  test "tools_for(nil) liefert leeres Array (defensive Default)" do
    assert_equal [], McpServer::ToolRegistry.tools_for(nil)
  end

  # NEUER Stub-Smoketest für 14-G.1-Stub: jeder nicht-nil User bekommt ALL_TOOLS-Liste.
  test "tools_for(any_authenticated_user) liefert ALL_TOOLS (14-G.1-Stub-Verhalten)" do
    u = User.new(email: "tr-stub@example.com", password: "password123")
    tools = McpServer::ToolRegistry.tools_for(u)
    assert_equal McpServer::RoleToolMap::ALL_TOOLS, tools,
      "Stub-Verhalten: jeder authentifizierte User bekommt ALL_TOOLS"
  end
end
