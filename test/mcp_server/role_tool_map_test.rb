# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/mcp_server/role_tool_map"

# Phase 34-01 (v1.0): RoleToolMap-Tiers (BASE_READ_TOOLS + WRITE_TOOLS).
# Drift-Guard für ALL_TOOLS-Größe + Tier-Inhalt. Per-Record-Authority-Check ist
# in BaseTool.authorize! (14-G.2); KEIN MAPPING-Hash mehr.
class McpServer::RoleToolMapTest < ActiveSupport::TestCase
  # Drift-Guard: 23 → 24 (34-01) → 26 (34-04) → 27 (35-01) → 30 (35-02 Mein-Billard)
  # → 32 (36-02 Doku/Suche: DocSearch/SmartSearch) → 33 (42-01 PrepareTournament-Spike)
  # → 34 (43-01 OpenInTournamentApp-Spike) → 35 (45-01 ListLeagues, cc_list_leagues)
  # → 38 (45-02 LeagueStandings/LeagueSchedule/PartyLineup)
  # → 40 (45-03 MyTeams/MyPartyGames "meine Mannschaft")
  # → 41 (46-01 SetPartyLineup, cc_set_party_lineup — lokale Aufstellungs-Vorbereitung).
  # → 43 (47-03 StartPartyDay [WRITE] + PartyStatus [READ] — Thin-Bridge-Chat-Spieltagssteuerung).
  test "ALL_TOOLS-Größe = 43 (41 + Phase-47-03 StartPartyDay/PartyStatus)" do
    assert_equal 43, McpServer::RoleToolMap::ALL_TOOLS.size,
      "Drift-Guard: ALL_TOOLS-Count hat sich geändert. Falls beabsichtigt → Plan-Bezug aktualisieren."
  end

  # Phase 35-02: Mein-Billard read-only Tools — für ALLE Rollen (BASE_READ_TOOLS), kein CC-Write.
  test "BASE_READ_TOOLS enthält Mein-Billard-Tools, NICHT in WRITE_TOOLS (Phase 35-02)" do
    my_tools = %i[MyTournaments MyResults MyRanking]
    my_tools.each { |s| assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, s }
    assert((my_tools & McpServer::RoleToolMap::WRITE_TOOLS).empty?,
      "Mein-Billard-Tools sind read-only (self-scoped), KEIN CC-Admin-Write")
  end

  # Phase 36-02: Doku/Suche read-only Tools — für ALLE Rollen (BASE_READ_TOOLS), kein CC-Write.
  test "BASE_READ_TOOLS enthält Doku/Suche-Tools, NICHT in WRITE_TOOLS (Phase 36-02)" do
    tools = %i[DocSearch SmartSearch]
    tools.each { |s| assert_includes McpServer::RoleToolMap::BASE_READ_TOOLS, s }
    assert((tools & McpServer::RoleToolMap::WRITE_TOOLS).empty?,
      "Doku/Suche-Tools sind read-only, KEIN CC-Admin-Write")
  end

  # Phase 35-01: Self-Service-Stufe (für alle Rollen; kein CC-Admin-Write).
  test "SELF_SERVICE_TOOLS enthält LinkMyPlayer (Phase 35-01)" do
    assert_includes McpServer::RoleToolMap::SELF_SERVICE_TOOLS, :LinkMyPlayer
    assert (McpServer::RoleToolMap::SELF_SERVICE_TOOLS & McpServer::RoleToolMap::WRITE_TOOLS).empty?,
      "Self-Service ist NICHT CC-Admin-Write"
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
  test "ALL_TOOLS == (BASE_READ_TOOLS + SELF_SERVICE_TOOLS + WRITE_TOOLS).uniq" do
    assert_equal (McpServer::RoleToolMap::BASE_READ_TOOLS + McpServer::RoleToolMap::SELF_SERVICE_TOOLS + McpServer::RoleToolMap::WRITE_TOOLS).uniq,
      McpServer::RoleToolMap::ALL_TOOLS
  end

  # Plan 22-01 T2-Mount-Fix: CcWhoami ist auf der Read-Liste (HTTP-MCP-Mount sichtbar).
  test "ALL_TOOLS enthält CcWhoami (Plan 22-01 Foundation für HTTP-MCP-Mount)" do
    assert_includes McpServer::RoleToolMap::ALL_TOOLS, :CcWhoami,
      "cc_whoami muss im HTTP-MCP-Mount (McpController via ToolRegistry) sichtbar sein."
  end
end
