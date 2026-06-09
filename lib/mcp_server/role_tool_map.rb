# frozen_string_literal: true

module McpServer
  # Final Stub (Plan 14-G.2 / D-14-G6):
  # Per-Record-Authority-Check ist in BaseTool.authorize! (TournamentPolicy-Konsumption)
  # statt in ToolRegistry. ToolRegistry liefert für alle authentifizierten User ALL_TOOLS.
  # Per-Tool-Authority erfolgt in 14-G.4-Refactor der Write-Tools via authorize!-Helper.
  #
  # Frozen-Array-Pattern aus Phase-13 bleibt erhalten — das Mapping ist auf eine
  # einzige „all"-Liste reduziert (keine mcp_role-Differenzierung mehr).
  module RoleToolMap
    # Read-only Tools
    # Plan 22-01 T2-Mount-Fix (2026-05-31): CcWhoami hinzugefügt — Tool war im
    # collect_tools (Stdio-Pfad) bereits enthalten, aber HTTP-Pfad (McpController)
    # nutzt diese hardcoded Liste statt collect_tools. Ohne Eintrag hier ist
    # cc_whoami im HTTP-MCP-Client-Tool-List unsichtbar.
    BASE_READ_TOOLS = %i[
      CcWhoami
      LookupRegion
      LookupClub
      LookupLeague
      LookupCategory
      LookupSerie
      LookupTeam
      LookupTournament
      LookupSpielbericht
      LookupMeldelisteForTournament
      LookupTeilnehmerliste
      ListClubsByDiscipline
      ListPlayersByClubAndDiscipline
      ListPlayersByName
      ListOpenTournaments
      SearchPlayer
      CheckPlayerDisciplineExperience
    ].freeze

    # Write-Tools (Sportwart + Turnierleiter zusammen — 14-G.2 trennt das wieder authority-basiert)
    WRITE_TOOLS = %i[
      RegisterForTournament
      UpdateTournamentDeadline
      UnregisterForTournament
      AssignPlayerToTeilnehmerliste
      RemoveFromTeilnehmerliste
      FinalizeTeilnehmerliste
    ].freeze

    # All-Tools (Stub-Inhalt für jeden authentifizierten User)
    ALL_TOOLS = (BASE_READ_TOOLS + WRITE_TOOLS).uniq.freeze
  end
end
