# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/role_tool_map"

# MCP Multi-User-Hosting (v0.3, Plan 13-02, D-13-01-D Option-B-Override)
# Tests für lib/mcp_server/role_tool_map.rb
class McpServer::RoleToolMapTest < ActiveSupport::TestCase
  test "MAPPING covers all 5 mcp_role enum values" do
    expected_keys = %i[mcp_public_read mcp_sportwart mcp_turnierleiter mcp_landessportwart mcp_admin]
    assert_equal expected_keys.sort, McpServer::RoleToolMap::MAPPING.keys.sort
  end

  test "MAPPING is frozen + each value array is frozen" do
    assert McpServer::RoleToolMap::MAPPING.frozen?
    McpServer::RoleToolMap::MAPPING.each_value do |arr|
      assert arr.frozen?, "Tool-Array für Rolle ist nicht frozen"
    end
  end

  test "mcp_public_read enthält nur Read-Tools (keine Write-Tools)" do
    tools = McpServer::RoleToolMap::MAPPING[:mcp_public_read]
    write_tools = %i[
      RegisterForTournament AssignPlayerToTeilnehmerliste RemoveFromTeilnehmerliste
      FinalizeTeilnehmerliste UpdateTournamentDeadline UnregisterForTournament
    ]
    write_tools.each do |wt|
      assert_not tools.include?(wt), "mcp_public_read sollte #{wt} NICHT enthalten"
    end
  end

  test "mcp_sportwart enthält Sportwart-Write-Tools aber NICHT cc_assign/cc_remove/cc_finalize" do
    tools = McpServer::RoleToolMap::MAPPING[:mcp_sportwart]
    assert tools.include?(:RegisterForTournament)
    assert tools.include?(:UpdateTournamentDeadline)
    assert tools.include?(:UnregisterForTournament)
    assert_not tools.include?(:AssignPlayerToTeilnehmerliste)
    assert_not tools.include?(:RemoveFromTeilnehmerliste)
    assert_not tools.include?(:FinalizeTeilnehmerliste)
  end

  test "mcp_turnierleiter enthält Akkreditierungs-Tools aber NICHT cc_update_deadline" do
    tools = McpServer::RoleToolMap::MAPPING[:mcp_turnierleiter]
    assert tools.include?(:AssignPlayerToTeilnehmerliste)
    assert tools.include?(:RemoveFromTeilnehmerliste)
    assert tools.include?(:FinalizeTeilnehmerliste)
    assert tools.include?(:RegisterForTournament)
    assert_not tools.include?(:UpdateTournamentDeadline)
  end

  test "mcp_landessportwart und mcp_admin haben identische Tools (LSW als CC-Experte)" do
    lsw_tools = McpServer::RoleToolMap::MAPPING[:mcp_landessportwart].sort
    admin_tools = McpServer::RoleToolMap::MAPPING[:mcp_admin].sort
    assert_equal admin_tools, lsw_tools
  end

  test "EXPECTED_COUNTS pro Rolle stimmt mit MAPPING-Größe überein" do
    McpServer::RoleToolMap::EXPECTED_COUNTS.each do |role, count|
      assert_equal McpServer::RoleToolMap::MAPPING[role].size, count, "Count-Mismatch für #{role}"
    end
  end

  test "Tool-Counts: public_read=16, sportwart=19, turnierleiter=21, lsw=22, admin=22 (Drift-Guard)" do
    expected = {
      mcp_public_read: 16,
      mcp_sportwart: 19,
      mcp_turnierleiter: 21,
      mcp_landessportwart: 22,
      mcp_admin: 22
    }
    expected.each do |role, count|
      actual = McpServer::RoleToolMap::EXPECTED_COUNTS[role]
      assert_equal count, actual,
        "Drift-Guard: Tool-Count für #{role} hat sich geändert (#{actual} vs erwartet #{count}). " \
        "Falls beabsichtigt: Wert hier + Plan-13-02-Doku aktualisieren."
    end
  end
end
