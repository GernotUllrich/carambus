# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/role_tool_map"

# Plan 14-G.2 / D-14-G6: 8 obsolete MAPPING/Per-Role-Tests gelöscht (Phase-13-mcp_role-Enum
# durch D-14-G6 ersatzlos entfernt). Verbleibend: ALL_TOOLS-Drift-Guard (14-G.1-Substrate).
# Per-Record-Authority-Check ist in BaseTool.authorize! (14-G.2); KEIN MAPPING-Hash mehr.
class McpServer::RoleToolMapTest < ActiveSupport::TestCase
  # NEUER Drift-Guard für 14-G.1-Stub: ALL_TOOLS-Größe muss stabil sein.
  test "ALL_TOOLS-Stub-Größe = 22 (14-G.1-Substrate)" do
    assert_equal 22, McpServer::RoleToolMap::ALL_TOOLS.size,
      "Stub-Drift: ALL_TOOLS-Count hat sich geändert. Falls beabsichtigt → Plan 14-G.1 + 14-G.2 abgleichen."
  end
end
