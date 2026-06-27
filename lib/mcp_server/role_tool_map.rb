# frozen_string_literal: true

module McpServer
  # Tool-Tier-Mapping (Phase 34-01, v1.0):
  # BASE_READ_TOOLS = read-only Tools fuer jeden authentifizierten User.
  # WRITE_TOOLS = CC-Schreiboperationen, nur fuer Personas mit cc_write_access?
  # (Sportwart + Turnierleiter + system_admin). ToolRegistry.tools_for kombiniert
  # die Tiers persona-basiert. Per-Record-Authority bleibt orthogonal in
  # BaseTool.authorize! (TournamentPolicy) — Tier-Gating ist Defense-in-Depth davor.
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
      ListLeagues
      LeagueStandings
      LeagueSchedule
      PartyLineup
      PartyStatus
      ListPlayersByClubAndDiscipline
      ListPlayersByName
      ListOpenTournaments
      SearchPlayer
      CheckPlayerDisciplineExperience
      MyTournaments
      MyResults
      MyRanking
      MyTeams
      MyPartyGames
      DocSearch
      SmartSearch
    ].freeze

    # Write-Tools — CC-Schreiboperationen. Gating: nur Personas mit cc_write_access?
    # (Sportwart + Turnierleiter + system_admin) bekommen diese via ToolRegistry.tools_for.
    # Phase 34-01: FastAssignToTeilnehmerliste ergaenzt (Drift-Fix — Chat nutzte es,
    # Registry kannte es nicht; vgl. project_chat_service_separate_tool_list).
    WRITE_TOOLS = %i[
      RegisterForTournament
      UpdateTournamentDeadline
      UnregisterForTournament
      AssignPlayerToTeilnehmerliste
      RemoveFromTeilnehmerliste
      FastAssignToTeilnehmerliste
      FinalizeTeilnehmerliste
      AssignTournamentLeiter
      RemoveTournamentLeiter
      PrepareTournament
      OpenInTournamentApp
      SetPartyLineup
      StartPartyDay
    ].freeze

    # Self-Service-Tools (Phase 35-01) — fuer JEDEN authentifizierten User; self-scoped
    # (eigenes Profil, z.B. Spielerprofil verknuepfen), NICHT von cc_write_access? abhaengig
    # und KEIN CC-Admin-Write. Hält das 34-01-Gating sauber (read-only ≠ keine Self-Service).
    SELF_SERVICE_TOOLS = %i[
      LinkMyPlayer
    ].freeze

    # All-Tools (Read + Self-Service + Write) — Tool-Set fuer schreibberechtigte Personas.
    ALL_TOOLS = (BASE_READ_TOOLS + SELF_SERVICE_TOOLS + WRITE_TOOLS).uniq.freeze
  end
end
