# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/role_tool_map"

# Phase 34-01 (v1.0): RoleToolMap-Tiers (BASE_READ_TOOLS + WRITE_TOOLS).
# Drift-Guard für ALL_TOOLS-Größe + Tier-Inhalt. Per-Record-Authority-Check ist
# in BaseTool.authorize! (14-G.2); KEIN MAPPING-Hash mehr.
class McpServer::RoleToolMapTest < ActiveSupport::TestCase
  # Drift-Guard: 23 → 24 (34-01 FastAssign) → 26 (34-04 Assign/RemoveTournamentLeiter).
  test "ALL_TOOLS-Größe = 26 (24 + Phase-34-04 Assign/RemoveTournamentLeiter)" do
    assert_equal 26, McpServer::RoleToolMap::ALL_TOOLS.size,
      "Drift-Guard: ALL_TOOLS-Count hat sich geändert. Falls beabsichtigt → Plan-Bezug aktualisieren."
  end

  # Phase 34-04: TL-Delegations-Tools (Carambus-interne Zuordnung, kein CC-Write).
  test "WRITE_TOOLS enthält Assign/RemoveTournamentLeiter (Phase 34-04)" do
    assert_includes McpServer::RoleToolMap::WRITE_TOOLS, :AssignTournamentLeiter
    assert_includes McpServer::RoleToolMap::WRITE_TOOLS, :RemoveTournamentLeiter
  end

  # Phase 34-01 Drift-Fix: Chat nutzte FastAssign, Registry kannte es nicht.
  test "WRITE_TOOLS enthält FastAssignToTeilnehmerliste (Phase 34-01 Drift-Fix)" do
    assert_includes McpServer::RoleToolMap::WRITE_TOOLS, :FastAssignToTeilnehmerliste,
      "FastAssignToTeilnehmerliste muss als Write-Tool registriert sein (Chat ⇄ Registry vereinheitlicht)."
  end

  # ALL_TOOLS == (READ + WRITE).uniq — Tiers überschneidungsfrei zusammengesetzt.
  test "ALL_TOOLS == (BASE_READ_TOOLS + WRITE_TOOLS).uniq" do
    assert_equal (McpServer::RoleToolMap::BASE_READ_TOOLS + McpServer::RoleToolMap::WRITE_TOOLS).uniq,
      McpServer::RoleToolMap::ALL_TOOLS
  end

  # Plan 22-01 T2-Mount-Fix: CcWhoami ist auf der Read-Liste (HTTP-MCP-Mount sichtbar).
  test "ALL_TOOLS enthält CcWhoami (Plan 22-01 Foundation für HTTP-MCP-Mount)" do
    assert_includes McpServer::RoleToolMap::ALL_TOOLS, :CcWhoami,
      "cc_whoami muss im HTTP-MCP-Mount (McpController via ToolRegistry) sichtbar sein."
  end
end
