# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/role_tool_map"

# Plan 14-G.2 / D-14-G6: 8 obsolete MAPPING/Per-Role-Tests gelöscht (Phase-13-mcp_role-Enum
# durch D-14-G6 ersatzlos entfernt). Verbleibend: ALL_TOOLS-Drift-Guard (14-G.1-Substrate).
# Per-Record-Authority-Check ist in BaseTool.authorize! (14-G.2); KEIN MAPPING-Hash mehr.
class McpServer::RoleToolMapTest < ActiveSupport::TestCase
  # Drift-Guard für 14-G.1-Stub + Phase-22-Erweiterung: ALL_TOOLS-Größe muss stabil sein.
  # 22 → 23: Plan 22-01 T2-Mount-Fix (CcWhoami hinzugefügt; HTTP-Pfad nutzt ALL_TOOLS, nicht collect_tools).
  test "ALL_TOOLS-Stub-Größe = 23 (14-G.1-Substrate + 22-01-Erweiterung CcWhoami)" do
    assert_equal 23, McpServer::RoleToolMap::ALL_TOOLS.size,
      "Stub-Drift: ALL_TOOLS-Count hat sich geändert. Falls beabsichtigt → Plan-Bezug aktualisieren."
  end

  # Plan 22-01 T2-Mount-Fix: CcWhoami ist auf der hardcoded ALL_TOOLS-Liste,
  # nicht nur via collect_tools sichtbar.
  test "ALL_TOOLS enthält CcWhoami (Plan 22-01 Foundation für HTTP-MCP-Mount)" do
    assert_includes McpServer::RoleToolMap::ALL_TOOLS, :CcWhoami,
      "cc_whoami muss im HTTP-MCP-Mount (McpController via ToolRegistry) sichtbar sein."
  end
end
